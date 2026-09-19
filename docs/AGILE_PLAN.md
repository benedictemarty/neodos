# Plan agile — NeoDOS

Projet mené en sprints courts ; chaque sprint livre un `neodos.neo` testé
(`make test` vert), le CHANGELOG et la documentation à jour, un commit par
incrément.

## Vision

Offrir sur le Neo6502 une expérience « MS-DOS » : invite, commandes de
gestion de fichiers, lancement de programmes et scripts batch, à la place de
NeoBASIC (qui reste accessible par `EXIT`).

## Rôles

- Product owner / développeur : bmarty.
- Cible de test : Phosphoneo (headless), émulateur officiel `neo`, carte.

## Definition of Done

1. Code assemblé sans avertissement, image sous `$FC00` (`.cerror`).
2. Tests sur cible ajoutés ou mis à jour, `make test` vert.
3. CHANGELOG, README/manuel, architecture mis à jour.
4. Commit versionné (auteur bmarty <bmarty@mailo.com>).

## Sprint 1 — MVP (2026-09-19) — livré, v0.1.0

| Story | État |
|---|---|
| S1 Invite `A:\CHEMIN>` et boucle de commandes | fait |
| S2 `DIR` au format DOS | fait |
| S3 `CD`, `MD`, `RD`, `DEL`, `REN`, `COPY`, `TYPE` | fait |
| S4 Lancement `.NEO`, retour à l'invite | fait |
| S5 Scripts `.BAT`, `AUTOEXEC.BAT`, `ECHO`, `PAUSE`, `REM` | fait |
| S6 `CLS`, `VER`, `VOL`, `MEM`, `DATE`, `TIME`, `HELP`, `EXIT`, `X:` | fait |
| S7 Tests headless et documentation | fait |

## Backlog (priorisé)

| # | Story | Notes |
|---|---|---|
| B1 | Jokers `*` et `?` pour `DIR`, `DEL`, `COPY`, `REN` | filtrage côté 6502 sur Read Directory |
| B2 | `DIR /P` (pause par page) et `/W` (large) | 30 lignes d'écran |
| B3 | Date/heure des fichiers dans `DIR` | l'API 3,18 ne les renvoie pas : évolution firmware |
| B4 | `PROMPT`, `PATH` (recherche des programmes dans plusieurs répertoires) | |
| B5 | `IF`, `GOTO`, `CALL`, `%1..%9` dans les `.BAT` | |
| B6 | `COPY` avec concaténation, `MOVE`, `XCOPY` de répertoires | |
| B7 | Redirection `>` vers fichier pour `DIR`, `TYPE`, `ECHO` | |
| B8 | Historique de commandes (flèche haut) | ReadLine du noyau ne le fait pas |
| B9 | Validation sur carte (USB, SD, plusieurs volumes `A:`/`B:`) | |
| B10 | `EDIT` : éditeur de texte plein écran | gros chantier |
| B11 | Intégration dans le firmware à la place de `basic_binary.h` (option) | refusé pour l'instant : `.neo` seulement |

## Risques et points ouverts

- Les émulateurs (`neo`, Phosphoneo) ne normalisent pas `..` dans le
  répertoire courant (`A:\GAMES\..`) et sont sensibles à la casse des noms ;
  la carte (FatFs) n'a pas ces limites. À traiter côté émulateurs.
- Un programme `.NEO` qui écrit au-dessus de `$D800` détruit NeoDOS ; le
  retour à l'invite n'est alors pas possible (reset).
