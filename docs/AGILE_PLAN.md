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

## Sprint 2 — Jokers et pagination (2026-09-19) — livré, v0.2.0

| Story | État |
|---|---|
| S8 Correspondance de motifs DOS (`*`, `?`, insensible à la casse, `*.*` = tout) | fait |
| S9 `DIR motif`, `DIR chemin\motif`, « File not found » si rien | fait |
| S10 `DEL motif` (fichiers seulement, confirmation `Y/N` pour `*` et `*.*`) | fait |
| S11 `COPY motif répertoire`, `COPY fichier répertoire`, compte des copies | fait |
| S12 `REN motif motif` (substitution nom/extension façon DOS) | fait |
| S13 `DIR /P` (pause par page de 28 lignes) et `DIR /W` (4 colonnes, `[DIR]`) | fait |
| S14 Base déplacée en `$D000` (tampon de liste pour les jokers), tests, docs | fait |

## Sprint 3 — Scripts .BAT avancés (2026-09-19) — livré, v0.3.0

| Story | État |
|---|---|
| S15 Paramètres `%0`-`%9` dans les lignes de batch (`DEMO A B` → `%1`=A) | fait |
| S16 `ERRORLEVEL` : 0 si la dernière commande a réussi, 1 sinon | fait |
| S17 `IF [NOT] EXIST fichier`, `IF [NOT] a==b`, `IF [NOT] ERRORLEVEL n` + commande | fait |
| S18 `GOTO label` / lignes `:label` (« Label not found » sinon) | fait |
| S19 `CALL script [args]` : batch imbriqué (3 niveaux), retour à l'appelant | fait |
| S20 Base en `$C800`, tests, docs | fait |

## Sprint 4 — PATH, PROMPT, redirection (2026-09-19) — livré, v0.4.0

| Story | État |
|---|---|
| S21 `PATH [dir;dir]` : recherche des `.NEO`/`.BAT` dans les répertoires listés | fait |
| S22 `PROMPT [texte]` : `$p $g $n $d $t $_ $$`, défaut `$p$g` | fait |
| S23 Redirection `commande > fichier` et `>> fichier` (CR/LF), messages inclus | fait |
| S24 Base en `$C000`, tests, docs | fait |

## Sprint 5 — MOVE, XCOPY, ATTRIB (2026-09-19) — livré, v0.5.0

| Story | État |
|---|---|
| S25 `MOVE source|motif destination` (renommage, vers un répertoire ou un nom) | fait |
| S26 `XCOPY source[\motif] destination` : copie d'un répertoire (créé au besoin), un niveau | fait |
| S27 `ATTRIB [+R -R +H -H +S -S +A -A] [fichier|motif]` : affiche / modifie les attributs | fait |
| S28 Tampons réduits (`listbuf` 1 Ko, `argrest` 200) pour rester en `$C000`, tests, docs | fait |

## Sprint 6 — Consolidation et historique (2026-09-19) — livré, v0.6.0

| Story | État |
|---|---|
| S29 Réduction du code : raccourcis `p0_*`/`ptr_*` pour les motifs répétés (−344 octets) | fait |
| S30 Éditeur de ligne NeoDOS (`lineedit.asm`) : insertion, Suppr, flèches, Début/Fin, Échap | fait |
| S31 Historique de commandes (Haut/Bas, 200 octets, doublons consécutifs ignorés) | fait |
| S32 Phosphoneo : `--type-keys` accepte flèches/Début/Fin/Suppr/Retour arrière ; test `23_lineedit` | fait |

## Sprint 7 — Ctrl+Alt+Suppr et commandes externes (2026-09-19) — livré, v0.7.0

| Story | État |
|---|---|
| S33 Ctrl+Alt+Suppr à l'invite : redémarrage à chaud (fichiers fermés, son coupé, racine, écran effacé, NeoDOS relancé) | fait |
| S34 ADR-003 : résident gelé à `$C000`, extensions en commandes externes `.NEO` via `PATH` | fait |
| S35 Phosphoneo : `\z` = Ctrl+Alt+Suppr dans `--type-keys` ; test `24_ctrl_alt_del` | fait |
| S36 Ligne de commande transmise aux `.NEO` en `$0200` (contrat des commandes externes) | fait (sprint 8) |

## Sprint 8 — Trinity et commandes externes (2026-09-19) — livré, v0.8.0

| Story | État |
|---|---|
| S37 Trinity (firmware de référence, sans 3,24-26 ni 1,20-21) : sonde des fonctions au démarrage, dégradation propre (`A:` seul, « has no label », `DATE`/`TIME` refusés, `$d $t` ignorés) | fait — à valider sur carte |
| S38 `make dist` : image de clé pour Trinity (`boot/neodos.neo` + `boot/auto.txt`, `AUTOEXEC.BAT` avec `PATH \BIN`, `BIN/`) | fait |
| S39 Première commande externe `BIN/ARGS.NEO` (contrat `$0200`), chemin absolu comme commande (`\BIN\ARGS.NEO`) | fait |
| S40 Mémo au projet firmware (`docs/MEMO-NEODOS-2026-09-19.md` sur `trinity`, story T-10) | fait |
| S41 Validation sur carte Trinity (B9) | à faire — dépend de bmarty |

## Correctif 0.8.1 (2026-09-20) — retour de test carte

| Story | État |
|---|---|
| S42 Gel de `poker.neo` (chargé en `$0200`) : la copie de la ligne de commande en `$0200` écrasait le programme → en-tête `$C000` avec pointeur | fait |
| S43 Documenter la pile llvm-mos (`$F600`) qui détruit NeoDOS ; option `--defsym=__stack=0xC000` | fait (doc) |

## Backlog (priorisé)

| # | Story | Notes |
|---|---|---|
| B3 | Date/heure des fichiers dans `DIR` | l'API 3,18 ne les renvoie pas : évolution firmware |
| B6 | `COPY` avec concaténation, `XCOPY /S` (sous-répertoires, récursif) | mémoire : pile de chemins |
| B9 | Validation sur carte (USB, SD, plusieurs volumes `A:`/`B:`) | |
| B10 | `EDIT.NEO` : éditeur de texte plein écran (commande externe, ADR-003) | gros chantier |
| B12 | `XCOPY.NEO /S`, `FOR`, `SHIFT` en commandes externes ou après décision mémoire | ADR-003 |
| B13 | Commande `REBOOT` (reset matériel complet, fonction 1,7) | à confirmer |
| B11 | Intégration dans le firmware à la place de `basic_binary.h` (option) | refusé pour l'instant : `.neo` seulement |

## Risques et points ouverts

- Les émulateurs (`neo`, Phosphoneo) ne normalisent pas `..` dans le
  répertoire courant (`A:\GAMES\..`) et sont sensibles à la casse des noms ;
  la carte (FatFs) n'a pas ces limites. Demandé au projet firmware (T-10).
- **Firmware de référence = Trinity** (depuis le 2026-09-19) : pas de volumes
  ni de date/heure tant que T-09/T-10 ne sont pas repris ; NeoDOS se dégrade
  proprement mais `B:`, `DATE`, `TIME` restent inertes sur carte.
- Un programme `.NEO` qui écrit au-dessus de `$C000` détruit NeoDOS ; le
  retour à l'invite n'est alors pas possible (reset).
