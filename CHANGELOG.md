# CHANGELOG — NeoDOS

Toutes les modifications notables sont consignées ici (format Keep a
Changelog, versions SemVer). Auteur : bmarty.

## [0.1.0] — 2026-09-19

Sprint 1 : MVP « un DOS utilisable à la place de NeoBASIC ».

### Ajouté
- Interpréteur de commandes en assembleur 65C02 (64tass), chargé en `$D800`
  (fichier `build/neodos.neo`), invite `A:\CHEMIN>` (lecteur = volume du
  firmware, répertoire courant via 3,23).
- Commandes internes : `DIR` (format DOS : `<DIR>`, tailles 32 bits, totaux
  fichiers/octets/répertoires, en-tête volume et chemin), `CD`/`CHDIR`,
  `MD`/`MKDIR`, `RD`/`RMDIR`, `DEL`/`ERASE`, `REN`/`RENAME`, `COPY`, `TYPE`,
  `CLS`, `VER`, `VOL`, `MEM`, `DATE`, `TIME`, `ECHO` (`ON`/`OFF`/texte/`.`),
  `PAUSE`, `REM`, `HELP`, `EXIT`/`BASIC`, changement de lecteur `X:`.
- Lancement des programmes `.NEO` (Load File 3,2 puis `JSR $FF08`) : nom tel
  que tapé puis en majuscules, extension facultative ; retour à l'invite si
  le programme se termine par `RTS`.
- Scripts `.BAT` (1 Ko max, chargés en mémoire) : écho des lignes façon DOS,
  `@` en tête, `ECHO OFF`, reprise après un programme `.NEO`,
  `AUTOEXEC.BAT` exécuté au démarrage.
- Messages d'erreur DOS (`Bad command or file name`, `File not found`,
  `Invalid directory`, `Access denied`, `Syntax error`, …) dérivés des codes
  d'erreur de l'API fichiers.
- Exemples : `examples/hello.asm` → `storage/HELLO.NEO`, `AUTOEXEC.BAT`,
  `DEMO.BAT`.
- Tests sur cible : `tests/run_tests.py` (Phosphoneo headless, frappe
  scriptée, capture console + état du stockage), 9 cas, `make test`.
- Documentation : README, plan agile, architecture, manuel, tests, ADR-001
  (DOS natif plutôt qu'émulation x86), ADR-002 (NeoDOS en `$D800`).
