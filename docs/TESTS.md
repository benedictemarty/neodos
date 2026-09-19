# Tests — NeoDOS

## Principe

Les tests s'exécutent **sur cible** : `build/neodos.neo` tourne dans
Phosphoneo en mode headless, les commandes sont frappées au clavier
(`--type-keys`), la console texte (53×30) est capturée
(`--screenshot-text`) et l'état du stockage est relevé après le test.

```
make test                      # tous les cas
python3 tests/run_tests.py 03_type   # un cas
python3 tests/run_tests.py --ref     # régénère les références (à relire !)
```

Variable `PHOSPHONEO` : chemin de l'émulateur (défaut
`~/Phosphoneo/build/phosphoneo`).

## Structure

- `tests/cases/NOM.keys` : texte frappé, une commande par ligne ; une ligne
  terminée par `\c` est frappée sans Entrée (réponse à `Y/N`).
- `tests/expected/NOM.txt` : console attendue (à partir de « NeoDOS version »,
  sans lignes vides ni espaces de fin) puis `--- files ---` et la liste triée
  des fichiers du stockage après le test.
- `tests/fixtures/` : fichiers présents au démarrage (`README.TXT`,
  `CTRL.TXT`, `GAMES/A.TXT`, `CHAIN.BAT`, `MANY/F01..F35.DAT`, scripts
  `ARGS.BAT`, `LOOP.BAT`, `SUB.BAT`, `SUB2.BAT`, `CALLER.BAT`) ; `storage/`
  (exemples) est ajouté.

Le budget de cycles est calculé d'après le nombre de touches (≈ 700 000
cycles par touche, 6 trames) ; un test dure environ 0,5 s.

## Cas

| Cas | Couvre |
|---|---|
| `01_info` | `VER`, `HELP`, `MEM`, `VOL` |
| `02_dir_cd` | `DIR` (courant, relatif, absolu, `..`), `CD` (relatif, `\`, affichage, erreur) |
| `03_type` | `TYPE` : CR/LF, tabulation, caractères de contrôle, fichier absent, syntaxe |
| `04_copy_ren_del` | `COPY`, `REN`, `DEL` (fichier, absent, répertoire refusé), erreurs |
| `05_md_rd` | `MD`, `RD` (vide, absent, fichier), syntaxe |
| `06_run` | `.NEO` (avec/sans extension, minuscules), `.BAT` (écho, `@`), reprise après programme, commande inconnue |
| `07_echo_misc` | `ECHO` (état, ON/OFF, texte, `.`), `REM`, `X:` invalide, `CLS` |
| `08_date_time` | `DATE`/`TIME` affichage, réglage, valeurs invalides |
| `09_exit` | `EXIT` : retour à NeoBASIC (`print 6*7` → 42) |
| `10_wild_dir` | `DIR *.TXT`, `DIR GAMES\*.TXT`, `DIR R*`, `DIR ?TRL.TXT`, motif sans correspondance |
| `10b_dir_w` | `DIR /W` (racine, sous-répertoire, motif), commutateur inconnu ignoré |
| `11_wild_del` | `COPY *.TXT GAMES`, `DEL GAMES\*.*` refusé (N) puis accepté (Y), motif sans correspondance |
| `12_wild_ren_copy` | `REN *.TXT *.BAK`, `REN C?RL.BAK X?RL.OLD`, `COPY fichier répertoire`, `COPY motif fichier` refusé, `REN` vers un nom existant |
| `13_dir_p` | `DIR MANY /P` : pause après 28 lignes, reprise sur une touche |
| `14_bat_args_if` | `%0`-`%3`, `%` littéral, `IF "%1"=="A"`, `IF NOT`, `IF EXIST`, `IF a == b` |
| `15_bat_goto` | `GOTO label`, `GOTO :label`, `Label not found`, `GOTO` hors script, `IF` sans argument / faux / vrai |
| `16_bat_call` | `CALL` imbriqué sur 2 niveaux avec `%1`, reprise de l'appelant, `IF ERRORLEVEL` après `DEL` raté, `CALL` d'un script absent, `CALL` depuis l'invite |

`AUTOEXEC.BAT` est exercé par tous les cas (bannière « Welcome to NeoDOS »).
L'ordre des entrées de `DIR` est celui du système de fichiers hôte (stable
sur ext4 pour un même jeu de noms).

## Non couvert (à faire sur carte)

Volumes multiples (`B:`), clé USB / carte SD réelles, `PAUSE` interactif.
