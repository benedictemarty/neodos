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
NeoDOS version 0.1.0
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

## Démarrage rapide

Prérequis : `64tass`, `python3`, `make` ; pour les tests et le lancement :
[Phosphoneo](https://github.com/benedictemarty/phosphoneo) (émulateur
headless) ou l'émulateur officiel `neo` du firmware.

```sh
make            # build/neodos.neo (+ storage/HELLO.NEO et les .BAT d'exemple)
make run        # NeoDOS dans Phosphoneo (SDL), stockage = storage/
make test       # suite de tests sur cible (Phosphoneo headless, ~5 s)
```

Sur la carte : copier `build/neodos.neo` (et, au choix, `storage/*`) sur la
clé USB, puis depuis NeoBASIC : `run "neodos.neo"`. `EXIT` revient à NeoBASIC.

## Commandes

| Commande | Rôle |
|---|---|
| `DIR [chemin]` | liste un répertoire (`<DIR>`, tailles, totaux) |
| `CD [chemin]`, `CHDIR` | change ou affiche le répertoire courant (`CD ..`, `CD \`) |
| `MD`, `MKDIR` / `RD`, `RMDIR` | crée / supprime (vide) un répertoire |
| `DEL`, `ERASE` | supprime un fichier |
| `REN`, `RENAME` | renomme un fichier |
| `COPY src dst` | copie un fichier |
| `TYPE fichier` | affiche un fichier texte (CR, LF, CR/LF, tabulations) |
| `X:` | change de lecteur (volume `X` − `A` du firmware, 0-3) |
| `CLS`, `VER`, `VOL`, `MEM` | écran, versions, nom du volume, mémoire |
| `DATE [aaaa-mm-jj]`, `TIME [hh:mm[:ss]]` | affiche / règle l'horloge (fonctions 1,20 / 1,21) |
| `ECHO [ON\|OFF\|texte\|.]`, `PAUSE`, `REM` | commandes de script |
| `HELP` | aide en ligne |
| `EXIT`, `BASIC` | retour à NeoBASIC |
| `nom[.NEO]`, `nom[.BAT]` | lance un programme ou un script |

Les chemins acceptent `\` ou `/`. Le nom d'un programme est cherché tel que
tapé puis en majuscules (les volumes FAT de la carte ignorent la casse, le
stockage hôte des émulateurs non). Détails : [docs/MANUEL_UTILISATION.md](docs/MANUEL_UTILISATION.md).

## Organisation du dépôt

```
src/          sources 64tass : neodos.asm (entrée), shell, commands, batch, console
examples/     HELLO.NEO (programme d'exemple, source hello.asm), AUTOEXEC.BAT, DEMO.BAT
storage/      image de stockage de démonstration (make examples)
tests/        run_tests.py + cas (.keys) et références (expected/), fixtures
tools/        mkneo.py (emballage .neo)
docs/         AGILE_PLAN, ARCHITECTURE, MANUEL_UTILISATION, TESTS, adr/
```

## Carte mémoire

| Zone | Usage |
|---|---|
| `$0000-$00FF` | page zéro (NeoDOS : `$80-$9F`) |
| `$0800-$D7FF` | programmes lancés depuis l'invite (53 248 octets) |
| `$D800-$FBFF` | NeoDOS (code ≈ 4,6 Ko + tampons) |
| `$FC00-$FFFF` | noyau 6502 du firmware, API `$FF00` |

## Licence

EUPL v1.2 — © 2026 bmarty <bmarty@mailo.com>.
