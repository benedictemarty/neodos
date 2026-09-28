# Architecture de NeoDOS

## Vue d'ensemble

```
 clavier/écran ──► firmware RP2040 ◄── API $FF00 (groupes 1 système,
                   (console, FatFs)      2 console, 3 fichiers)
                                             ▲
                                             │ SendMessage/WaitMessage ($FFF7/$FFF4)
                                    ┌────────┴─────────┐
                                    │ NeoDOS ($B800)   │
                                    │ shell ─ commands │
                                    │   │   wildcard   │
                                    │   │      batch   │
                                    │ console          │
                                    └──────────────────┘
                                             │ Load File (3,2) + JSR $FF08
                                             ▼
                                    programme .NEO ($0800-$B7FF)
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
| `src/commands.asm` | table des commandes et leurs implémentations (`copy_move` commun à `COPY`/`MOVE` via `opfn` ; `ATTRIB` externalisé en 0.14.0) |
| `src/wildcard.asm` | `has_wild`, `match_glob`, `split_path`, `collect_matches`/`list_next`, `build_path`, `apply_pattern` (REN) |
| `src/lineedit.asm` | éditeur de ligne (`readline_ed`, `ins_char`), historique (`hist_add`, `hist_entry`), complétion Tab (`_tab`) et F8 (`_f8`) |
| `src/stub.asm` | stub de retour des programmes (`$0100`) : vérification et rechargement de NeoDOS |
| `src/batch.asm` | `AUTOEXEC.BAT`, exécution d'un `.BAT` depuis `batbuf`, `%n`, `GOTO`, `CALL`, `FOR`, `SHIFT`, pile des niveaux |
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
   `check_cad` interroge Key Status (1,2) sur Suppr : avec Ctrl et Alt →
   `warm_restart` (attend le relâchement, 8,1, `CD /`, 2,12, `jmp start`) ;
   `neodos_back` (retour de programme) appelle `kbd_flush` : si le timer 1,1 a
   avancé de ≥ `KBD_FLUSH_CS` (200 = 2 s) depuis `runtick` (relevé dans
   `try_run`), la file 2,1 est vidée (jeux lisant le clavier par 1,2).
   `EXIT` copie le stub en `$0100` et saute à `stub_exit` (1,3 puis
   `jmp (0)`) : 1,3 recharge l'image résidente par-dessus `$B800-$FBFF` ;
   `wait_key` = attente d'une touche avec ce contrôle, utilisée par `getkey`,
   `PAUSE`, `DIR /P` et `ask_yn` ; `batch_next` appelle aussi `check_cad`
   avant chaque ligne de script.
   Haut/Bas rappellent une entrée de `histbuf` (pstrings consécutives,
   `hcount`/`hused` ; la plus ancienne est retirée quand la place manque).
   `hist_add` marque `histdirty` ; `hist_flush` (appelé par `try_run` avant
   un programme, `warm_restart` et `cmd_exit`, non à chaque commande : voir
   B16/Trinity T-31) fait `hist_save` : Store File (3,3) de l'image brute
   `hcount`/`hused`/`histbuf` (202 octets) dans `/boot/neodos.his`, erreurs
   ignorées ; `start` appelle `hist_load` (Stat de la taille exacte, Load
   File, puis parcours des pstrings : longueurs 1-254 totalisant `hused`
   en `hcount` entrées, sinon historique vide).
   **Tab** : le mot sous le curseur (depuis l'espace précédent) + `*` est
   copié dans `arg1`, converti (`to_apipath`), découpé (`split_path` →
   `dirbuf`/`patbuf`) ; `collect_open` (silencieux si le répertoire n'existe
   pas) puis `collect_loop` collectent les entrées correspondantes dans
   `listbuf` ; le plus long préfixe commun (`cnt`, casse ignorée) est inséré
   par `ins_char` au-delà de ce qui est tapé (`patbuf` − 1) ; pour une
   correspondance unique, `build_path` + `stat_namebuf` (3,16) ajoutent `\`
   si c'est un répertoire. `tabdone` (page zéro `$B1`) : posé à la fin d'un
   Tab, remis à 0 par toute autre touche (et à l'entrée de `readline_ed`) ;
   un Tab avec `tabdone` à 1 ne relit pas le répertoire — le résultat serait
   le même, rien ne pouvant changer sur le disque pendant la saisie. Après
   l'ajout d'un `\`, `tabdone` reste à 0 : le Tab suivant parcourt le
   répertoire. Une rafale de Tab ne fait donc qu'un parcours (0.25.0, B16 :
   clavier muet et traits rouges pendant les accès disque, Trinity T-31). **F8** : `f8len` = longueur du préfixe (la ligne
   jusqu'au curseur à la première pression, remise à 0 par toute autre
   touche) ; recherche depuis `hcur` vers les entrées plus anciennes (`idx`)
   d'une commande de même préfixe, puis `_recall`. Les touches de fonction
   n'ont pas de code ASCII dans le firmware : `start` déclare pour F8 un
   texte de raccourci d'un octet `KEY_F8` = `$88` (API 2,4, `f8text`).
   **Suggestion automatique** : la boucle `_key` appelle `show_sugg` avant
   `getkey` et `hide_sugg` après. `show_sugg` (curseur en fin de ligne non
   vide) cherche depuis `hcount`−1 une entrée plus longue de même préfixe,
   note `sgidx`/`sglen`, relit l'encre courante (2,18 → `sgink`), écrit la
   suite en encre 9 puis ramène le curseur par `cur_left` (avec un `lpos`
   temporaire, pour les passages de ligne) ; `hide_sugg` écrit `sglen`
   espaces puis autant de retours arrière (la console gère les passages de
   ligne) et garde `sglen` pour `_accept` (Droite/Fin en fin de ligne :
   insertion par `ins_char` des caractères manquants).
   `execute_line` appelle d'abord `redir_setup` (voir Redirection).
3. `parse_line` : `cmdbuf` = premier mot en majuscules (arrêt sur espace,
   `\`, `/`, `.` après la 1re lettre, `:` sauf pour `X:`) ; `argrest` = reste
   brut ; `arg1`/`arg2` = deux premiers mots du reste.
4. `execute_line` : `X:` → `cmd_drive` ; sinon recherche dans `cmdtable`
   (pstring + adresse) ; sinon `run_program`.
5. `run_program` → `try_run` : nom tel que tapé puis en majuscules ; avec
   extension `.NEO`/`.BAT` ou en essayant `.NEO` puis `.BAT` (File Stat 3,16).
   Sans succès, chaque entrée de `PATH` (`path_next`, séparateur `;`) est
   essayée avec `build_path`. La ligne reste dans `linebuf`, dont l'adresse
   est publiée dans l'en-tête `$B800` (`jmp start`, `NEODOS` en `$B803`, version en `$B809`,
   pointeur en `$B80C`, vecteur `putc` en `$B80E`, code de retour `ERRORLEVEL` en `$B810` — écrit par le programme, lu par NeoDOS, hors de la somme de contrôle du stub qui part de `$B811` ; `$C0xx` jusqu'à la 0.13.0) : contrat des commandes externes — rien n'est écrit
   dans la zone programme (un programme peut se charger dès `$0200`).
   `.NEO` : vidage de la redirection (qui reste ouverte : un programme écrivant
   par le vecteur `putc` y participe), fermeture des canaux 0 et 7 et du
   répertoire (3,19), `zp_save` (page zéro à préserver : `bptr`, `blen`,
   `redir`, `caps` → `zpsave`), Load File (3,2) — le firmware dépose
   `JMP exec` en `$FF08` — puis `JSR $FF08`.
   Au retour (`neodos_back`) : pile réinitialisée, `zp_restore`, **32,19
   Toolbox Reset** (Trinity T-88, ≥ 0.16.49 : fenêtres, menus, contrôles,
   dialogues, événements remis à l'état du démarrage, rien n'est dessiné ;
   ignorée par un firmware plus ancien — aussi appelée par `start`, pour le
   cas où NeoDOS est rechargé après avoir été écrasé), fermeture
   de la redirection (`try_run` ne revenant pas, la fin de `execute_line`
   n'est pas atteinte), reprise du batch en cours ou invite.

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
| `$80-$BD` | page zéro : `ptr`, `ptr2`, `tmp`, `cnt`, `idx`, `flag`, `num` (32), `total` (32), `nfiles`, `ndirs`, `bptr`, `blen`, `sptr`, jokers (`mstar_*`, `lptr`, `lcount`, `lidx`), DIR (`dirflags`, `dirlines`, `dircol`), `apply_pattern` (`sp_*`, `pp_*`, `oidx`), `wflag`, `errsave`, IF (`negate`, `cond`, `preverr`), batch (`bx`, `by`), `redir`, `opfn`, `tabdone`, éditeur (`lpos`, `llen`, `hcur`, `f8len`, suggestion `sglen`/`sgidx`/`sgink`), `FOR` (`forvar`/`foritem`/`formatch`), `caps`, `api_call` (`aret`, `$BE-$BF`) |
| `$B800-$E489` | code (11 402 octets en 0.27.1 ; `codeend`) — taille du fichier `neodos.neo` |
| `$E48A-$F7E2` | tampons (mis à zéro par `start`) : `promptbuf`, `cwdbuf`, `linebuf` (201), `cmdbuf`, `arg1`, `arg2`, `argrest` (201), `namebuf`, `iobuf` (256), `batbuf` (768), `dirbuf`, `patbuf`, `newname`, `listbuf` (896), `errorlevel`, `batname` (64), `batargs` (128), `batdepth`, `batstack` (582), `outbuf` (128), `pathbuf` (129), `promptfmt` (49), `cwdpath`, `runword`, `promptskip`, `dpsave`, `runtick`, `asave`, `zpsave` (6), `hcount`, `hused`, `histbuf` (200), `forset` (101), `fortpl` (161) |
| `$F7E3-$FBFF` | libre (1 053 octets en 0.27.1 ; `.cerror` si `dataend > $FC00`) |

La page zéro `$E0-$EF` et `$FC-$FF` est réservée au noyau (ordonnanceur
F-61) et n'est pas utilisée.

### Réduction de l'empreinte (0.27.1)

Le résident occupe une zone fixe (`$B800-$FBFF`, ADR-004 : l'en-tête des
commandes externes est en `$B800`) ; gagner des octets agrandit la marge
laissée aux fonctions futures, pas la mémoire des programmes. 0.27.1 :
11 753 → 11 402 octets de code (−351), marge 703 → 1 053 octets, sans
changement de comportement (53/53) :

- `#api` : `jsr api_call` + 2 octets (5 au lieu de 8, 64 appels, −170) ;
  `api_call` (`console.asm`) respecte le contrat du noyau — A, X, Y, C et V
  préservés, N/Z selon A (`KSendMessage`/`KWaitMessage` de Trinity) ;
- `HELP` en un seul bloc `puts` ; en-tête de volume (`vol_line`, partagé par
  `VOL` et `DIR`), message de pause (`press_msg`), ligne de version
  (`ver_line`) et « Invalid drive specification » (`err_drive`) mis en
  commun (−181).

Écarté : codage des suites d'espaces dans les messages (≈ 110 octets, source
illisible). Plus gros bloc restant : `HELP` (870 octets).

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

## Survie aux programmes (stub de retour)

Le résident peut être écrasé par un programme (pile C llvm-mos en `$F600`).
`install_stub` copie avant chaque lancement `stub_image` (assemblée en
`.logical $0100`) en bas de la page pile et y inscrit la somme de contrôle
16 bits du code (`sum_code`, routine du stub appelée en place) ; `try_run`
pousse `STUB_BASE-1` comme adresse de retour, place le nom en `$FF04-$FF07`
et saute à **`stub_run`** (queue du stub) qui fait le Load File (3,2) puis
`JMP $FF08` : le chargement peut recouvrir `$B800-$FBFF` (programme de
`$A000` à `$FBE6` par exemple), NeoDOS ne doit exécuter aucune instruction
entre le 3,2 et le saut. Chargement raté : `intact` → message (`load_error`)
ou rechargement. Au `RTS` du
programme, le stub vérifie les sentinelles `canary_lo`/`canary_hi` (`$A5`,
premier et dernier octets des données) et la somme du code : intact →
`jmp neodos_back` (pile réinitialisée, batch ou invite) ; sinon Load File
(3,2) de `/boot/neodos.neo` puis `/neodos.neo` et `JMP $FF08` (→ `start`) ;
si les deux manquent, 1,3 + `jmp (0)` (`stub_exit`, aussi le chemin de
`EXIT`). Le stub occupe `$0100-$01E0` ; la partie à préserver après le
lancement s'arrête à `stub_critical` (`$01C5`), la queue (`stub_run`) ne
sert que pendant le chargement. Limite : un programme qui utilise plus de
58 octets de pile matérielle ou écrit en `$0100-$01C5` détruit le stub
(reset ; Trinity relance NeoDOS via `boot/auto.txt`).

`DATE`/`TIME` (affichage) passent par `clock_read` : 1,20 puis, si
Parameter:7 (source) vaut 0, 1,23 (Sync Clock From Modem, Trinity T-25) et
relecture ; `clock_note` ajoute ` (clock not set)` si la source reste 0.

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
`execute_line`, `mainloop`, retour d'un programme dans `neodos_back`) vide
et ferme.

## Concaténation (`COPY a+b dest`)

`copy_move` cherche un `+` dans la source (COPY seulement) et passe alors la
main à la commande externe `CONCAT` par `run_named` (même recherche que
`run_program` — répertoire courant puis `PATH` — pour un nom déjà placé
dans `namebuf`) ; la ligne tapée reste la ligne de commande du programme.
Le résident n'y consacre que 40 octets : une version interne coûtait
465 octets (0.27.0, ADR-003). `CONCAT.NEO` vérifie toutes les sources
(3,16) et la destination avant d'écrire, lit par blocs de 16 Ko (canal 4,
3,8) et écrit sur le canal 5 (3,9) ; ajout à la première source par
Open 2 + Seek à la taille (3,10 puis 3,6).

## Commandes externes

`examples/ext/neoext.inc` : mêmes conventions que le résident (API par
`SendMessage`, `putc`/`puts`/`putpstr`), `cmd_arg` (n-ième mot de la ligne
de commande lue via `$C00C`, `\` → `/`). Chaque programme commence par
`jmp main` (l'include contient du code) et se termine par `RTS` (stub de
retour). `walk.inc` (utilisé par `XCOPY`, `DELTREE`) généralise le parcours de `TREE`
avec des crochets `hook_file`/`hook_enter`/`hook_leave`. `TREE` illustre le parcours récursif avec l'API (un seul répertoire
ouvert à la fois) : pile `skip[depth]` du nombre de sous-répertoires déjà
visités à chaque niveau, ré-énumération à la remontée.

## Format `.neo`

`tools/mkneo.py` : en-tête `03 'N' 'E' 'O'`, version, adresse d'exécution,
puis blocs (contrôle, adresse de chargement, taille, commentaire ASCIIZ,
données). NeoDOS = un bloc en `$B800`, exec `$B800`.
