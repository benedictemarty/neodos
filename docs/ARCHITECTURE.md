# Architecture de NeoDOS

## Vue d'ensemble

```
 clavier/écran ──► firmware RP2040 ◄── API $FF00 (groupes 1 système,
                   (console, FatFs)      2 console, 3 fichiers)
                                             ▲
                                             │ SendMessage/WaitMessage ($FFF7/$FFF4)
                                    ┌────────┴─────────┐
                                    │ NeoDOS ($C000)   │
                                    │ shell ─ commands │
                                    │   │   wildcard   │
                                    │   │      batch   │
                                    │ console          │
                                    └──────────────────┘
                                             │ Load File (3,2) + JSR $FF08
                                             ▼
                                    programme .NEO ($0800-$BFFF)
```

NeoDOS ne touche pas au matériel : tout passe par le bloc de contrôle de
l'API (`$FF00-$FF0B`) et les vecteurs du noyau 6502 (`ReadLine $FFEB`,
`WriteCharacter $FFF1`, `WaitMessage $FFF4`, `SendMessage $FFF7`).

## Fichiers

| Fichier | Rôle |
|---|---|
| `src/neodos.asm` | point d'entrée, `VERSION`, ordre des `.include`, contrôle de taille |
| `src/const.inc` | adresses (noyau, API, page zéro), codes d'erreur, attributs |
| `src/macros.inc` | `#api g,f`, `#print`, `#println`, `#setparam`, `#setptr` |
| `src/shell.asm` | démarrage, boucle, invite (`PROMPT`), lecture de ligne, analyse, dispatch, lancement `.NEO` (+ `PATH`), redirection `>`, messages d'erreur |
| `src/commands.asm` | table des commandes et leurs implémentations (`copy_move` commun à `COPY`/`MOVE`/`XCOPY` via `opfn`) |
| `src/wildcard.asm` | `has_wild`, `match_glob`, `split_path`, `collect_matches`/`list_next`, `build_path`, `apply_pattern` (REN) |
| `src/lineedit.asm` | éditeur de ligne (`readline_ed`), historique (`hist_add`, `hist_entry`) |
| `src/batch.asm` | `AUTOEXEC.BAT`, exécution d'un `.BAT` depuis `batbuf`, `%n`, `GOTO`, `CALL`, pile des niveaux |
| `src/console.asm` | `putc`, `puts` (texte inline), pstrings, décimal 32 bits |
| `src/data.asm` | tampons (non émis dans le `.neo`, réservés en RAM) |

## Flux d'une commande

1. `show_prompt` : `build_cwdpath` (volume 3,26 → lettre, répertoire 3,23
   avec `/` → `\` ; `cwdpath` = `A:\CHEMIN`) puis `build_prompt` interprète
   `promptfmt` (`$p`, `$g`, `$d`… ; `promptskip` = longueur de la dernière
   ligne de l'invite).
2. `read_command` → `readline_ed` : lecture touche par touche (2,1) ; la
   ligne est dans `linebuf` avec un curseur `lpos`, l'écran est tenu en
   miroir par les codes de contrôle de la console (insertion 5, suppression
   26, retour arrière 8, gauche/droite 1/4 ; `column` = (`promptskip` +
   `lpos`) mod 53 pour passer d'une ligne d'écran à l'autre avec 23/19).
   `getkey` interroge aussi Key Status (1,2) sur Suppr : avec Ctrl et Alt →
   `warm_restart` (attend le relâchement, 8,1, `CD /`, 2,12, `jmp start`).
   Haut/Bas rappellent une entrée de `histbuf` (pstrings consécutives,
   `hcount`/`hused` ; la plus ancienne est retirée quand la place manque).
   `execute_line` appelle d'abord `redir_setup` (voir Redirection).
3. `parse_line` : `cmdbuf` = premier mot en majuscules (arrêt sur espace,
   `\`, `/`, `.` après la 1re lettre, `:` sauf pour `X:`) ; `argrest` = reste
   brut ; `arg1`/`arg2` = deux premiers mots du reste.
4. `execute_line` : `X:` → `cmd_drive` ; sinon recherche dans `cmdtable`
   (pstring + adresse) ; sinon `run_program`.
5. `run_program` → `try_run` : nom tel que tapé puis en majuscules ; avec
   extension `.NEO`/`.BAT` ou en essayant `.NEO` puis `.BAT` (File Stat 3,16).
   Sans succès, chaque entrée de `PATH` (`path_next`, séparateur `;`) est
   essayée avec `build_path`. Avant `JSR $FF08`, `linebuf` est recopié en
   `$0200` (contrat des commandes externes).
   `.NEO` : fermeture de la redirection, des canaux (3,5 `$FF`) et du répertoire (3,19), Load
   File (3,2) — le firmware dépose `JMP exec` en `$FF08` — puis `JSR $FF08`.
   Au retour : pile réinitialisée, reprise du batch en cours ou invite.

Toutes les chaînes échangées avec l'API sont des pstrings (octet de
longueur). `to_apipath` convertit `\` en `/` avant l'appel.

## Convention d'appel de l'API

`#api g,f` = `JSR SendMessage ; .byte g,f ; JSR WaitMessage`. `KSendMessage`
attend d'abord la fin de la commande précédente ; comme `putc` attend la fin
de chaque écriture console, aucune commande n'est jamais en cours quand une
routine écrit ses paramètres dans `$FF04+`.

## Jokers

`cmd_dir`/`cmd_del`/`cmd_copy`/`cmd_ren` : `has_wild` sur l'argument →
`split_path` (dernier `/` : `dirbuf` + `patbuf`) → pour `DIR`, filtrage à
la volée par `match_glob` pendant Read Directory ; pour `DEL`/`COPY`/`REN`,
`collect_matches` remplit d'abord `listbuf` (pstrings, `lcount`) puis la
liste est parcourue (`list_first`/`list_next`, `ptr2`) — on ne modifie jamais
un répertoire pendant son énumération. `build_path` recompose
`dirbuf/nom` ; `apply_pattern` fabrique le nouveau nom de `REN` (base et
extension séparées au dernier `.`).

`match_glob` : parcours itératif avec retour arrière sur le dernier `*`
(`mstar_p`/`mstar_n`) ; comparaison en majuscules ; en fin de nom le reste du
motif doit être fait de `*`.

## Mémoire

| Zone | Contenu |
|---|---|
| `$80-$B5` | page zéro : `ptr`, `ptr2`, `tmp`, `cnt`, `idx`, `flag`, `num` (32), `total` (32), `nfiles`, `ndirs`, `bptr`, `blen`, `sptr`, jokers (`mstar_*`, `lptr`, `lcount`, `lidx`), DIR (`dirflags`, `dirlines`, `dircol`), `apply_pattern` (`sp_*`, `pp_*`, `oidx`), `wflag`, `errsave`, IF (`negate`, `cond`, `preverr`), batch (`bx`, `by`), `redir`, `opfn`, `attr_set`/`attr_clr`, éditeur (`lpos`, `llen`, `hcur`), `caps` |
| `$C000-$E83F` | code (≈ 10,3 Ko ; `codeend`) |
| `$E840-$FB3D` | tampons : `promptbuf`, `cwdbuf`, `linebuf`, `cmdbuf`, `arg1`, `arg2`, `argrest` (201), `namebuf`, `iobuf` (256), `batbuf` (1 024), `dirbuf`, `patbuf`, `newname`, `listbuf` (1 024), `errorlevel`, `batname` (64), `batargs` (128), `batdepth`, `batstack` (582), `outbuf` (128), `pathbuf` (129), `promptfmt` (49), `cwdpath`, `runword`, `promptskip`, `dpsave`, `hcount`, `hused`, `histbuf` (200) |
| `$FB3E-$FBFF` | libre (≈ 190 octets de marge ; `batbuf` ramené à 768 ; `.cerror` si `dataend > $FC00`) |

La page zéro `$E0-$EF` et `$FC-$FF` est réservée au noyau (ordonnanceur
F-61) et n'est pas utilisée.

## Batch

Le `.BAT` est chargé entier dans `batbuf` (`batch_load` : File Stat puis
Load File 3,2, 768 octets max) ; `batname` garde son chemin et `batargs`
la ligne de commande qui l'a lancé (`%0`-`%9`). `batch_next` (pile 6502
réinitialisée à chaque ligne : `CALL`/`GOTO` y sautent) lit une ligne par
`batch_getline` (CR, LF ou CR/LF ; `%d` remplacé par le mot `d` de `batargs`
via `insert_arg`), ignore les `:label`, gère `@` et l'écho (`echo_off`), puis
appelle `execute_line`. Un `.NEO` lancé depuis un batch revient dans
`batch_next` (`bat_active`).

`CALL` (`cmd_call`) empile `batname`/`batargs`/`bptr` dans `batstack`
(`BAT_DEPTH` = 3 niveaux de 194 octets, `level_addr`) puis `run_batch` sur
l'appelé ; `batch_end` dépile, recharge le fichier de l'appelant et reprend à
`bptr`. `GOTO` (`cmd_goto`) rebalaye `batbuf` depuis le début à la recherche
de `:label`. `IF` (`cmd_if`, dans `commands.asm`) évalue `NOT`, `EXIST`,
`ERRORLEVEL` (lit `preverr`, le niveau de la commande précédente : `errorlevel`
est remis à 0 au début de chaque `execute_line`, à 1 par `errlvl1` dans les
chemins d'erreur) ou `a==b`, puis recopie le reste de la ligne dans `linebuf`
et appelle `execute_line`.

## Fonctions du firmware absentes

`detect_caps` (démarrage) précharge un paramètre puis appelle 3,26 et 1,20 :
sur carte une fonction inconnue laisse les paramètres intacts (`WARN_GROUP`
vide en `PICO`), ce qui révèle son absence. `caps` (bit 0 volumes, bit 1
date/heure) est consulté par `print_volname`, `cmd_drive`, `DATE`/`TIME`
(`need_datetime`) et `$d`/`$t` de l'invite ; `build_cwdpath` précharge P0 = 0
avant 3,26 (lettre `A` par défaut).

## Redirection

`redir_setup` cherche le premier `>` de `linebuf`, lit `>>` éventuel et le
nom qui suit, tronque la ligne, ouvre le fichier sur `CH_OUT` (mode 3, ou 2
puis Seek à la taille pour `>>` ; création si absent) et arme `redir` (bit 7).
Les macros `#setparam`/`#setptr` les plus fréquentes sont remplacées par
`p0_arg1`, `p0_namebuf`, `ptr_arg1`, `ptr_arg2`, `ptr_namebuf` (3 octets par
appel au lieu de 8-10).

`putc` teste `redir` par `BIT` et envoie alors dans `outbuf` (`redir_put`,
CR → CR LF) ; `redir_flush` écrit le tampon (3,9) en sauvegardant et
restaurant `DParams`/`DError`, car un affichage peut survenir entre un appel
API et la lecture de son résultat (`DIR`). `redir_close` (fin de
`execute_line`, `mainloop`, `batch_next`, lancement d'un `.NEO`) vide et
ferme.

## Format `.neo`

`tools/mkneo.py` : en-tête `03 'N' 'E' 'O'`, version, adresse d'exécution,
puis blocs (contrôle, adresse de chargement, taille, commentaire ASCIIZ,
données). NeoDOS = un bloc en `$C000`, exec `$C000`.
