# Manuel d'utilisation — NeoDOS

## Lancer NeoDOS

- **Émulateur** : `make run` (Phosphoneo, fenêtre SDL, stockage `storage/`)
  ou `make run-neo` (émulateur officiel).
- **Carte (Trinity)** : `make dist`, copier le contenu de `build/dist/` à la
  racine de la clé (`boot/neodos.neo`, `boot/auto.txt`, `AUTOEXEC.BAT`,
  `BIN/`) : NeoDOS démarre automatiquement (Échap au démarrage = menu du
  firmware). Autre firmware : dans NeoBASIC, `run "neodos.neo"`.

Sur Trinity, le lecteur est toujours `A:` et `DATE`/`TIME` répondent « not
supported by this firmware » (fonctions du fork non reprises).

Au démarrage, NeoDOS affiche sa bannière, exécute `AUTOEXEC.BAT` s'il existe
dans le répertoire courant, puis affiche l'invite `A:\>`.

## L'invite

`A:\GAMES>` : `A` est le lecteur (volume 0 du firmware ; `B` = volume 1, …),
`\GAMES` le répertoire courant. Les commandes ne distinguent pas majuscules et
minuscules ; les chemins acceptent `\` ou `/`.

### Édition de la ligne de commande

Gauche/Droite déplacent le curseur, les caractères tapés s'insèrent, Retour
arrière et Suppr effacent, Début/Fin (Home/End) vont aux extrémités, Échap
efface la ligne. **Haut/Bas** parcourent l'historique des commandes (les
dernières lignes tapées, environ 200 caractères conservés) ; Bas après la
dernière entrée redonne une ligne vide.

**Ctrl+Alt+Suppr** (à l'invite) redémarre NeoDOS à chaud : fichiers fermés,
son coupé, retour à la racine, écran effacé, `AUTOEXEC.BAT` rejoué. Le
firmware n'est pas réinitialisé (les programmes en mémoire sont perdus).

## Fichiers et répertoires

| Commande | Exemple |
|---|---|
| `DIR [chemin][motif] [/P] [/W]` | `DIR`, `DIR GAMES`, `DIR \`, `DIR *.TXT`, `DIR GAMES\*.NEO /W`, `DIR /P` |
| `CD [chemin]` | `CD GAMES`, `CD ..`, `CD \`, `CD` (affiche le répertoire) |
| `MD chemin` | `MD SAVES` |
| `RD chemin` | `RD SAVES` (le répertoire doit être vide) |
| `DEL fichier\|motif` | `DEL OLD.TXT`, `DEL *.BAK`, `DEL SAVES\*.*` (confirmation) ; refuse un répertoire : `Access denied` |
| `REN ancien nouveau` | `REN A.TXT B.TXT`, `REN *.TXT *.BAK`, `REN C?RL.BAK X?RL.OLD` |
| `COPY source destination` | `COPY A.TXT B.TXT`, `COPY A.TXT GAMES` (même nom dans GAMES), `COPY *.TXT GAMES` |
| `MOVE source destination` | `MOVE A.TXT OLD.TXT`, `MOVE *.BAK ARCHIVE` (déplacement par renommage) |
| `XCOPY source destination` | `XCOPY GAMES SAVE` (fichiers de GAMES vers SAVE, créé au besoin), `XCOPY GAMES\*.NEO BIN` |
| `ATTRIB [+R -R +H -H +S -S +A -A] [fichier]` | `ATTRIB *.TXT` (affiche `A S H R`), `ATTRIB +R CONFIG.BAT`, `ATTRIB` seul : tout le répertoire |
| `TYPE fichier` | `TYPE README.TXT` |
| `X:` | `B:` change de lecteur (`Invalid drive specification` si absent) |

`DIR` affiche pour chaque entrée le nom, `<DIR>` ou la taille en octets,
puis le nombre de fichiers, le total des octets et le nombre de répertoires.
`/P` marque une pause toutes les 28 lignes (« Press any key to continue »),
`/W` affiche les noms sur 4 colonnes, répertoires entre crochets. Sans
correspondance : `File not found`.

### Jokers

`*` remplace une suite quelconque de caractères, `?` un seul ; la casse est
ignorée ; `*.*` désigne tous les fichiers. Le motif porte sur la dernière
partie du chemin (`GAMES\*.NEO`). `DEL` avec joker ne touche jamais aux
répertoires et demande confirmation (`Y/N`) pour `*` et `*.*`. `REN` avec
jokers applique le second motif nom et extension séparément : `*` recopie le
reste de la partie source, `?` un caractère (`REN *.TXT *.BAK`,
`REN A?.DAT B?.DAT`). `COPY` avec joker exige un répertoire de destination.

## Programmes

Tapez le nom d'un fichier `.NEO` (avec ou sans extension) : `HELLO` ou
`HELLO.NEO`. Le nom est cherché tel que tapé puis en majuscules. Le programme
est chargé à l'adresse indiquée par son en-tête (en général `$0800`) et
lancé ; s'il se termine par `RTS`, NeoDOS reprend la main.

Un programme peut écrire entre `$C000` et `$FBFF` (zone NeoDOS — les
programmes llvm-mos y placent leur pile C en `$F600`) à condition de rendre
la main par `RTS` : NeoDOS détecte qu'il a été écrasé et se recharge depuis
`/boot/neodos.neo` (ou `/neodos.neo` à la racine — garder l'un des deux sur
la clé), avec `AUTOEXEC.BAT` rejoué ; s'il est intact, l'invite (ou le
script en cours) reprend directement. Un
programme trouve sa ligne de commande complète via l'en-tête de NeoDOS :
`$C003` = `NEODOS`, `$C009` = version, `$C00C` = adresse de la ligne (octet de
longueur puis les caractères) : c'est le contrat des **commandes externes**
(`BIN\ARGS.NEO` l'affiche). `PATH \BIN` dans `AUTOEXEC.BAT` rend ces commandes accessibles
de partout.

`PATH BIN;GAMES` : un nom qui n'est ni une commande interne ni un fichier du
répertoire courant est ensuite cherché dans `BIN` puis `GAMES` (avec et sans
extension `.NEO`/`.BAT`, tel que tapé puis en majuscules). `PATH` affiche la
liste, `PATH ;` l'efface. `PATH` est typiquement placé dans `AUTOEXEC.BAT`.

## Scripts .BAT

Un fichier `.BAT` (768 octets maximum) contient une commande par ligne.
`AUTOEXEC.BAT` est lancé au démarrage.

```
@ECHO OFF
REM Commentaire
ECHO Bonjour
ECHO.
DIR
HELLO
PAUSE
```

- `ECHO OFF` / `ECHO ON` : arrête / reprend l'écho des lignes ; `@` en tête
  d'une ligne supprime son écho ; `ECHO.` affiche une ligne vide.
- `PAUSE` attend une touche ; `REM` est un commentaire.
- Un programme `.NEO` lancé depuis un script rend la main au script ; un
  `.BAT` lancé depuis un script **sans** `CALL` le remplace.

### Paramètres, conditions, sauts, appels

```
@ECHO OFF
REM usage : INSTALL source destination
IF "%1"=="" GOTO usage
IF NOT EXIST %1 GOTO missing
COPY %1 %2
IF ERRORLEVEL 1 ECHO copy failed
CALL NOTIFY %2
GOTO end
:usage
ECHO INSTALL source destination
GOTO end
:missing
ECHO %1 not found
:end
```

- `%0` est le nom du script tel que tapé, `%1`…`%9` les mots qui suivent
  (vide si absent) ; `%` suivi d'autre chose qu'un chiffre reste littéral.
- `IF [NOT] EXIST fichier commande` ; `IF [NOT] a==b commande` (`a == b` et
  `"a"=="b"` acceptés, comparaison exacte) ; `IF [NOT] ERRORLEVEL n commande`
  (vrai si le niveau d'erreur de la commande précédente est ≥ n : 1 après un
  message d'erreur, 0 sinon). Les `IF` se chaînent.
- `GOTO label` saute à la ligne `:label` (casse ignorée) ; « Label not
  found » arrête le script.
- `CALL script [args]` exécute un autre `.BAT` puis reprend à la ligne
  suivante (3 niveaux d'imbrication, chaque niveau garde ses `%n`).

## Redirection

`commande > fichier` écrit la sortie de la commande dans le fichier (créé ou
tronqué) ; `>> fichier` l'ajoute à la fin (le fichier est créé au besoin).
Les messages d'erreur y vont aussi ; les lignes se terminent par CR/LF.

```
DIR > LISTE.TXT
ECHO Sauvegarde du %d >> JOURNAL.TXT
TYPE A.TXT >> TOUT.TXT
```

## Invite

`PROMPT texte` change l'invite ; codes : `$p` chemin courant (`A:\GAMES`),
`$g` `>`, `$l` `<`, `$n` lettre du lecteur, `$d` date, `$t` heure, `$_`
retour à la ligne, `$$` `$`, `$b` `|`, `$q` `=`. `PROMPT` seul rétablit
`$p$g`. Exemple : `PROMPT $d $t$_$p$g`.

## Commandes externes (BIN\)

Livrées avec NeoDOS dans `BIN\` (`PATH \BIN` dans `AUTOEXEC.BAT`) :

| Commande | Rôle |
|---|---|
| `MORE fichier` | affiche un fichier texte page par page (`-- More --` : une touche = page suivante, `Q` = fin) |
| `TREE [chemin] [/F]` | arborescence des répertoires (8 niveaux), `/F` avec les fichiers |
| `ARGS …` | affiche la ligne de commande reçue (exemple pour écrire une commande externe) |

Écrire la sienne : `examples/ext/NOM.asm` avec `.include "neoext.inc"`
(`cmd_arg` lit les arguments), `make examples` produit `storage/BIN/NOM.NEO`.

## Système

| Commande | Rôle |
|---|---|
| `CLS` | efface l'écran |
| `VER` | versions de NeoDOS et du firmware |
| `VOL` | nom du volume courant |
| `MEM` | mémoire disponible pour les programmes |
| `DATE [aaaa-mm-jj]` | affiche ou règle la date |
| `TIME [hh:mm[:ss]]` | affiche ou règle l'heure |
| `PATH [rép;rép]` | répertoires de recherche des programmes |
| `PROMPT [texte]` | format de l'invite |
| `HELP` | liste des commandes |
| `EXIT` ou `BASIC` | retour à NeoBASIC |

## Messages d'erreur

| Message | Cause |
|---|---|
| `Bad command or file name` | commande inconnue, ni `.NEO` ni `.BAT` trouvé |
| `File not found` / `Path not found` | fichier ou chemin inexistant |
| `Invalid directory` | `CD` vers un répertoire inexistant |
| `Access denied` | `DEL` sur un répertoire, volume en lecture seule |
| `Syntax error` | argument manquant |
| `Too many files` | plus de 255 noms (ou 1,25 Ko) pour un joker |
| `Destination must be a directory` | `COPY`/`MOVE` de plusieurs fichiers vers un seul nom |
| `Invalid parameter` | `ATTRIB` avec un attribut inconnu |
| `Duplicate file name or file not found` | `REN` impossible (cible existante…) |
| `Label not found` | `GOTO` vers un `:label` absent (fin du script) |
| `Too many nested CALLs` | plus de 3 niveaux de `CALL` |
| `Invalid drive specification` | lettre de lecteur sans volume monté |
| `Batch file too large (max 768 bytes)` | script trop long |
| `Error nn` | autre code d'erreur de l'API fichiers |

## Limites connues (v0.1)

- Pas de `FOR`, `SHIFT`, `%VAR%` dans les scripts, pas de `<` ni `|`, pas
  de `XCOPY /S` (récursif), pas de dates de fichiers dans `DIR` (voir le
  backlog dans `docs/AGILE_PLAN.md`).
- Sur les émulateurs, seul l'attribut `R` est réellement stocké (permissions
  du fichier hôte) ; `H`, `S`, `A` n'ont d'effet que sur la carte (FAT).
- Sur les émulateurs, le stockage hôte est sensible à la casse et `CD ..`
  laisse `..` dans le chemin affiché ; la carte (FAT) n'a pas ces limites.
