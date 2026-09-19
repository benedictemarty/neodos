# Architecture de NeoDOS

## Vue d'ensemble

```
 clavier/écran ──► firmware RP2040 ◄── API $FF00 (groupes 1 système,
                   (console, FatFs)      2 console, 3 fichiers)
                                             ▲
                                             │ SendMessage/WaitMessage ($FFF7/$FFF4)
                                    ┌────────┴─────────┐
                                    │ NeoDOS ($D000)   │
                                    │ shell ─ commands │
                                    │   │   wildcard   │
                                    │   │      batch   │
                                    │ console          │
                                    └──────────────────┘
                                             │ Load File (3,2) + JSR $FF08
                                             ▼
                                    programme .NEO ($0800-$CFFF)
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
| `src/batch.asm` | `AUTOEXEC.BAT`, exécution d'un `.BAT` depuis `batbuf` |
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
| `$80-$A9` | page zéro : `ptr`, `ptr2`, `tmp`, `cnt`, `idx`, `flag`, `num` (32), `total` (32), `nfiles`, `ndirs`, `bptr`, `blen`, `sptr`, jokers (`mstar_*`, `lptr`, `lcount`, `lidx`), DIR (`dirflags`, `dirlines`, `dircol`), `apply_pattern` (`sp_*`, `pp_*`, `oidx`), `wflag`, `errsave` |
| `$D000-$E9FF` | code (≈ 6,6 Ko ; `codeend`) |
| `$EA00-$FABB` | tampons : `promptbuf`, `cwdbuf`, `screenline`, `linebuf`, `cmdbuf`, `arg1`, `arg2`, `argrest`, `namebuf`, `iobuf` (256), `batbuf` (1 024), `dirbuf`, `patbuf`, `newname`, `listbuf` (1 280) |
| `$FABC-$FBFF` | libre (≈ 320 octets de marge ; `.cerror` si `dataend > $FC00`) |

La page zéro `$E0-$EF` et `$FC-$FF` est réservée au noyau (ordonnanceur
F-61) et n'est pas utilisée.

## Batch

Le `.BAT` est chargé entier dans `batbuf` (Load File 3,2 ; taille vérifiée
par File Stat, 1 024 octets max). `batch_next` découpe les lignes (CR, LF ou
CR/LF), gère `@` et l'écho (`echo_off`), puis appelle `execute_line`. Un
`.NEO` lancé depuis un batch revient dans `batch_next` (`bat_active`) ; un
`.BAT` lancé depuis un batch le remplace (pas de `CALL`, comme MS-DOS).

## Format `.neo`

`tools/mkneo.py` : en-tête `03 'N' 'E' 'O'`, version, adresse d'exécution,
puis blocs (contrôle, adresse de chargement, taille, commentaire ASCIIZ,
données). NeoDOS = un bloc en `$D000`, exec `$D000`.
