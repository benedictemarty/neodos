# CHANGELOG — NeoDOS

Toutes les modifications notables sont consignées ici (format Keep a
Changelog, versions SemVer). Auteur : bmarty.

## [0.2.0] — 2026-09-19

Sprint 2 : jokers et pagination.

### Ajouté
- Jokers DOS `*` et `?` (`src/wildcard.asm`) : correspondance insensible à
  la casse avec retour arrière, `*.*` équivalent à `*`, découpage
  `répertoire\motif`, collecte des entrées correspondantes (255 noms, 1,25 Ko).
- `DIR motif`, `DIR chemin\motif` (`File not found` si rien ne correspond,
  comme MS-DOS) ; `DIR /P` (pause « Press any key to continue . . . » toutes
  les 28 lignes) ; `DIR /W` (4 colonnes de 13, répertoires entre crochets).
- `DEL motif` (fichiers seulement ; confirmation `Are you sure (Y/N)?` pour
  `*` et `*.*`).
- `COPY motif répertoire` et `COPY fichier répertoire` (nom de base conservé),
  compte « n file(s) copied » ; refus explicite de copier plusieurs fichiers
  vers un seul.
- `REN motif motif` avec substitution façon DOS, nom et extension traités
  séparément (`REN *.TXT *.BAK`, `REN C?RL.BAK X?RL.OLD`).
- Tests `10_wild_dir`, `10b_dir_w`, `11_wild_del`, `12_wild_ren_copy`,
  `13_dir_p` (fixture `MANY/` de 35 fichiers) ; le runner accepte `\c` en fin
  de ligne (frappe sans Entrée, pour répondre Y/N).

### Modifié
- NeoDOS chargé en `$D000` (au lieu de `$D800`) pour loger le tampon de
  liste ; programmes en `$0800-$CFFF` (51 200 octets). ADR-002 amendé.
- `err_api` prend le code d'erreur dans A (les affichages intermédiaires
  remettaient `$FF02` à zéro : « Error 0 »).

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
