# NeoDOS — un « MS-DOS » pour le Neo6502

NeoDOS est un interpréteur de commandes façon MS-DOS (COMMAND.COM) écrit en
assembleur 65C02 pour le [Neo6502](http://www.neo6502.com). Il remplace
NeoBASIC comme environnement de travail : invite `A:\>`, commandes internes
DOS (`DIR`, `CD`, `MD`, `RD`, `DEL`, `REN`, `COPY`, `TYPE`, …), lancement des
programmes `.NEO`, scripts `.BAT` avec `AUTOEXEC.BAT` au démarrage.

> MS-DOS est du code x86 : il ne peut pas être « porté » sur un 65C02. NeoDOS
> est une réécriture native qui reproduit l'expérience utilisateur de MS-DOS
> au-dessus de l'API fichiers du firmware Neo6502 (voir
> [docs/adr/ADR-001](docs/adr/ADR-001-dos-natif.md)).

```
NeoDOS version 0.21.1
(C) 2026 bmarty - Neo6502 disk operating system

A:\>dir
 Volume in drive A is USB0
 Directory of A:\

GAMES                <DIR>
HELLO.NEO               66
README.TXT              31
        2 file(s)         97 bytes
        1 dir(s)
A:\>hello
Hello from a NeoDOS program!
A:\>
```

## Téléchargement

Version bêta publiée sur le serveur Prophet (catégorie « en développement ») :
`https://prophet.3617.fr/app/neodos` — depuis le Neo6502 avec un modem,
`prophet.neo`/ProphetGui téléchargent `neodos.neo`, `AUTOEXEC.BAT` et
`HELLO.NEO`.

## Démarrage rapide

Prérequis : `64tass`, `python3`, `make` ; pour les tests et le lancement :
[Phosphoneo](https://github.com/benedictemarty/phosphoneo) (émulateur
headless) ou l'émulateur officiel `neo` du firmware.

```sh
make            # build/neodos.neo (+ storage/HELLO.NEO et les .BAT d'exemple)
make run        # NeoDOS dans Phosphoneo (SDL), stockage = storage/
make test       # suite de tests sur cible (Phosphoneo headless, ~5 s)
```

Sur la carte avec **Trinity** (firmware de référence) : `make dist` puis copier
le contenu de `build/dist/` à la racine de la clé USB — `boot/neodos.neo` et
`boot/auto.txt` font démarrer NeoDOS à la place de NeoBASIC (`EXIT` y
revient). Avec un firmware sans menu `boot/` : depuis NeoBASIC,
`run "neodos.neo"`. Trinity n'ayant pas (encore) les fonctions volumes et
date/heure du fork, `B:`, `DATE`, `TIME` y sont inactifs (message explicite).

## Commandes

| Commande | Rôle |
|---|---|
| `DIR [chemin][motif] [/P] [/W]` | liste un répertoire (`<DIR>`, tailles, totaux) ; `/P` pause par page, `/W` colonnes |
| `CD [chemin]`, `CHDIR` | change ou affiche le répertoire courant (`CD ..`, `CD \`) |
| `MD`, `MKDIR` / `RD`, `RMDIR` | crée / supprime (vide) un répertoire |
| `DEL`, `ERASE` | supprime des fichiers (`DEL *.BAK` ; confirmation pour `*.*`) |
| `REN`, `RENAME` | renomme (`REN *.TXT *.BAK`, substitution nom/extension) |
| `COPY src dst`, `MOVE src dst` | copie / déplace un fichier ou un motif vers un répertoire (`COPY *.TXT SAVES`) |
| `TYPE fichier` | affiche un fichier texte (CR, LF, CR/LF, tabulations) |
| `X:` | change de lecteur (volume `X` − `A` du firmware, 0-3) |
| `CLS`, `VER`, `VOL`, `MEM` | écran, versions, nom du volume, mémoire |
| `DATE [aaaa-mm-jj]`, `TIME [hh:mm[:ss]]` | affiche / règle l'horloge (fonctions 1,20 / 1,21) |
| `ECHO [ON\|OFF\|texte\|.]`, `PAUSE`, `REM` | commandes de script |
| `IF [NOT] EXIST f \| a==b \| ERRORLEVEL n cmd`, `GOTO label`, `CALL script` | scripts : conditions, sauts, imbrication ; paramètres `%0`-`%9` |
| `FOR %v IN (jeu) DO cmd`, `SHIFT` | boucle sur un jeu (jokers développés) ; décalage des paramètres `%1`… |
| `PATH [rép;rép]`, `PROMPT [texte]` | répertoires de recherche des programmes ; format de l'invite (`$p$g`, `$n`, `$d`, `$t`, `$_`) |
| `commande > fichier`, `>> fichier` | redirige la sortie vers un fichier |
| `HELP` | aide en ligne |
| `ATTRIB [+R -H…] [fichier]`, `EDIT fichier`, `MORE`, `TREE [/F]`, `XCOPY [/S]`, `DELTREE`, `FIND [/I /N /C /V]`, `SORT [/R]`, `REBOOT`, `COLOR fe` | commandes **externes** (`BIN/*.NEO`, via `PATH \BIN`) : attributs, éditeur plein écran, pagination, arborescence, copie et suppression récursives, recherche, tri, reset matériel, couleurs ; leur sortie suit la redirection `>` |

Édition de ligne : flèches, Début/Fin, Suppr, Échap ; **Haut/Bas** rappellent l'historique des commandes (conservé dans `boot/neodos.his` d'un démarrage à l'autre) ; **Tab** complète le nom de fichier ou de répertoire sous le curseur ; **F8** rappelle la dernière commande commençant par le texte tapé (DOSKEY) ; en fin de ligne, la suite de la dernière commande correspondante est **suggérée en gris** au fil de la frappe (→ ou Fin pour l'accepter). **Ctrl+Alt+Suppr** redémarre NeoDOS à chaud (à l'invite, pendant `PAUSE`/`DIR /P`/`Y/N`, ou entre deux lignes d'un script).

Un programme qui écrase la zone de NeoDOS (pile C de llvm-mos en `$F600`, gros programme) et rend la main par `RTS` revient quand même à l'invite : un stub en `$0100` vérifie NeoDOS et le **recharge depuis `/boot/neodos.neo`** (ou `/neodos.neo`) — comme le firmware recharge NeoBASIC depuis la flash.
| `EXIT`, `BASIC` | recharge l'environnement résident du firmware (1,3 : NeoBASIC sur le firmware d'origine, NeoDOS lui-même sur Trinity) |
| `nom[.NEO]`, `nom[.BAT]` | lance un programme ou un script (ligne de commande : pointeur en `$C00C`) |

Les chemins acceptent `\` ou `/` ; les jokers `*` et `?` s'appliquent à
`DIR`, `DEL`, `COPY`, `REN` (insensibles à la casse). Le nom d'un programme est cherché tel que
tapé puis en majuscules (les volumes FAT de la carte ignorent la casse, le
stockage hôte des émulateurs non). Détails : [docs/MANUEL_UTILISATION.md](docs/MANUEL_UTILISATION.md).

## Organisation du dépôt

```
src/          sources 64tass : neodos.asm (entrée), shell, commands, wildcard, batch, console
examples/     HELLO.NEO, args/smash (tests), ext/ (commandes externes : neoext.inc, MORE, TREE), .BAT
storage/      image de stockage de démonstration (make examples)
tests/        run_tests.py + cas (.keys) et références (expected/), fixtures
tools/        mkneo.py (emballage .neo)
docs/         AGILE_PLAN, ARCHITECTURE, MANUEL_UTILISATION, TESTS, RECETTE_CARTE, adr/
```

## Carte mémoire

| Zone | Usage |
|---|---|
| `$0000-$00FF` | page zéro (NeoDOS : `$80-$B7`) |
| `$0800-$B7FF` | programmes lancés depuis l'invite (45 056 octets) |
| `$B800-$FBFF` | NeoDOS (code ≈ 10 Ko + tampons ≈ 4,6 Ko + ≈ 2,5 Ko de marge ; en-tête des commandes externes en `$B803`) |
| `$FC00-$FFFF` | noyau 6502 du firmware, API `$FF00` |

## Licence

EUPL v1.2 — © 2026 bmarty <bmarty@mailo.com>.
