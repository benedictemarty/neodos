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

- `tests/cases/NOM.keys` : texte frappé, une commande par ligne.
- `tests/expected/NOM.txt` : console attendue (à partir de « NeoDOS version »,
  sans lignes vides ni espaces de fin) puis `--- files ---` et la liste triée
  des fichiers du stockage après le test.
- `tests/fixtures/` : fichiers présents au démarrage (`README.TXT`,
  `CTRL.TXT`, `GAMES/A.TXT`, `CHAIN.BAT`) ; `storage/` (exemples) est ajouté.

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

`AUTOEXEC.BAT` est exercé par tous les cas (bannière « Welcome to NeoDOS »).

## Non couvert (à faire sur carte)

Volumes multiples (`B:`), clé USB / carte SD réelles, `PAUSE` interactif.
