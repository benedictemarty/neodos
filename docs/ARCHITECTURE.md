# Architecture de NeoDOS

## Vue d'ensemble

```
 clavier/écran ──► firmware RP2040 ◄── API $FF00 (groupes 1 système,
                   (console, FatFs)      2 console, 3 fichiers)
                                             ▲
                                             │ SendMessage/WaitMessage ($FFF7/$FFF4)
                                    ┌────────┴─────────┐
                                    │ NeoDOS ($C800)   │
                                    │ shell ─ commands │
                                    │   │   wildcard   │
                                    │   │      batch   │
                                    │ console          │
                                    └──────────────────┘
                                             │ Load File (3,2) + JSR $FF08
                                             ▼
                                    programme .NEO ($0800-$C7FF)
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
| `src/shell.asm` | démarrage, boucle, invite, lecture de ligne, analyse, table de dispatch, lancement `.NEO`, messages d'erreur |
| `src/commands.asm` | table des commandes et leurs implémentations |
| `src/wildcard.asm` | `has_wild`, `match_glob`, `split_path`, `collect_matches`/`list_next`, `build_path`, `apply_pattern` (REN) |
| `src/batch.asm` | `AUTOEXEC.BAT`, exécution d'un `.BAT` depuis `batbuf`, `%n`, `GOTO`, `CALL`, pile des niveaux |
| `src/console.asm` | `putc`, `puts` (texte inline), pstrings, décimal 32 bits |
| `src/data.asm` | tampons (non émis dans le `.neo`, réservés en RAM) |

## Flux d'une commande

1. `show_prompt` : volume courant (3,26) → lettre ; répertoire courant (3,23)
   avec `/` → `\` ; `promptbuf` = `A:\CHEMIN>`.
2. `read_command` : `ReadLine` du noyau renvoie **toute la ligne d'écran**
   (invite comprise) ; on saute `len(promptbuf)` caractères → `linebuf`.
3. `parse_line` : `cmdbuf` = premier mot en majuscules (arrêt sur espace,
   `\`, `/`, `.` après la 1re lettre, `:` sauf pour `X:`) ; `argrest` = reste
   brut ; `arg1`/`arg2` = deux premiers mots du reste.
4. `execute_line` : `X:` → `cmd_drive` ; sinon recherche dans `cmdtable`
   (pstring + adresse) ; sinon `run_program`.
5. `run_program` → `try_run` : nom tel que tapé puis en majuscules ; avec
   extension `.NEO`/`.BAT` ou en essayant `.NEO` puis `.BAT` (File Stat 3,16).
   `.NEO` : fermeture des canaux (3,5 `$FF`) et du répertoire (3,19), Load
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
| `$80-$AE` | page zéro : `ptr`, `ptr2`, `tmp`, `cnt`, `idx`, `flag`, `num` (32), `total` (32), `nfiles`, `ndirs`, `bptr`, `blen`, `sptr`, jokers (`mstar_*`, `lptr`, `lcount`, `lidx`), DIR (`dirflags`, `dirlines`, `dircol`), `apply_pattern` (`sp_*`, `pp_*`, `oidx`), `wflag`, `errsave`, IF (`negate`, `cond`, `preverr`), batch (`bx`, `by`) |
| `$C800-$E6C3` | code (≈ 7,9 Ko ; `codeend`) |
| `$E6C4-$FAAE` | tampons : `promptbuf`, `cwdbuf`, `screenline`, `linebuf`, `cmdbuf`, `arg1`, `arg2`, `argrest`, `namebuf`, `iobuf` (256), `batbuf` (1 024), `dirbuf`, `patbuf`, `newname`, `listbuf` (1 280), `errorlevel`, `batname` (64), `batargs` (128), `batdepth`, `batstack` (582) |
| `$FAAF-$FBFF` | libre (≈ 330 octets de marge ; `.cerror` si `dataend > $FC00`) |

La page zéro `$E0-$EF` et `$FC-$FF` est réservée au noyau (ordonnanceur
F-61) et n'est pas utilisée.

## Batch

Le `.BAT` est chargé entier dans `batbuf` (`batch_load` : File Stat puis
Load File 3,2, 1 024 octets max) ; `batname` garde son chemin et `batargs`
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

## Format `.neo`

`tools/mkneo.py` : en-tête `03 'N' 'E' 'O'`, version, adresse d'exécution,
puis blocs (contrôle, adresse de chargement, taille, commentaire ASCIIZ,
données). NeoDOS = un bloc en `$C800`, exec `$C800`.
