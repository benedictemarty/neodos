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
| S41 Validation sur carte Trinity (B9) : fiche `docs/RECETTE_CARTE.md` (2026-09-21, 40 étapes en 6 sections) | fiche prête — exécution par bmarty |

## Correctif 0.8.1 (2026-09-20) — retour de test carte

| Story | État |
|---|---|
| S42 Gel de `poker.neo` (chargé en `$0200`) : la copie de la ligne de commande en `$0200` écrasait le programme → en-tête `$C000` avec pointeur | fait |
| S43 Documenter la pile llvm-mos (`$F600`) qui détruit NeoDOS ; option `--defsym=__stack=0xC000` | fait (doc) |

## Correctif 0.8.2 (2026-09-20) — survie aux programmes

| Story | État |
|---|---|
| S44 Stub de retour en `$0100` : vérification (somme de contrôle, sentinelles) et rechargement de NeoDOS depuis `/boot/neodos.neo` | fait |
| S45 Story Trinity T-11 : `1,3` appliquant `boot/auto.txt` à chaque appel (rendrait le stub inutile) | proposée |
| S46 Bug `run_batch` (copie de `batargs`) trouvé par la fixture SMASH | fait |

## Sprint 9 — Commandes externes (2026-09-20) — livré, v0.9.0

| Story | État |
|---|---|
| S47 Base `examples/ext/neoext.inc` (API, sortie, `cmd_arg`) et règle Makefile générique | fait |
| S48 `MORE.NEO` : affichage paginé | fait |
| S49 `TREE.NEO` : arborescence récursive avec pile de compteurs (un seul répertoire ouvert dans l'API) | fait |
| S50 Tests 28/29, docs, `make dist` avec `BIN/` | fait |

## Sprint 10 — XCOPY /S et DELTREE (2026-09-20) — livré, v0.10.0

| Story | État |
|---|---|
| S51 `walk.inc` : parcours récursif générique avec crochets | fait |
| S52 `XCOPY.NEO` (`/S`), `XCOPY` interne retiré du résident | fait |
| S53 `DELTREE.NEO` avec confirmation | fait |
| S54 Tests 30/31, docs | fait |

## Sprint 11 — FIND, SORT, redirection des externes (2026-09-20) — livré, v0.11.0

| Story | État |
|---|---|
| S55 Vecteur `putc` en `$C00E`, redirection gardée ouverte pendant un programme | fait |
| S56 `FIND.NEO` (`/I /N /C /V`, texte entre guillemets) | fait |
| S57 `SORT.NEO` (`/R`, tri de Shell, 40 Ko) | fait |
| S58 Tests 32-34, docs | fait |

## Sprint 12 — EDIT (2026-09-20) — livré, v0.12.0

| Story | État |
|---|---|
| S59 `EDIT.NEO` : chargement/sauvegarde CR/LF, affichage 28 lignes avec défilement, curseur | fait |
| S60 Navigation, insertion, Retour arrière/Suppr (fusion), Entrée (scission), menu Échap | fait |
| S61 Tests 35/35b, docs | fait |

## Sprint 13 — Complétion de la saisie (2026-09-20) — livré, v0.13.0

| Story | État |
|---|---|
| S62 Tab : complétion du nom de fichier/répertoire sous le curseur (préfixe commun, `\` après un répertoire unique) via la machinerie des jokers | fait |
| S63 F8 : rappel de l'historique par préfixe (DOSKEY), raccourci F8 déclaré par 2,4 | fait |
| S64 Test 36, typer `\t`/`\8`, docs ; références alignées sur Trinity 0.5 (volumes, date/heure, `EXIT` relance NeoDOS) ; lettre de lecteur sans 3,26 corrigée | fait |

## Sprint 14 — Base `$B800`, ATTRIB externe (2026-09-21) — livré, v0.14.0

| Story | État |
|---|---|
| S65 Base du résident `$B800` (ADR-004) : `NEODOS_BASE`, Makefile, contrat des externes (`neoext.inc`, `args.asm`), `EDIT`/`SORT`/`SMASH` rebornés, `MEM` | fait |
| S66 `BIN/ATTRIB.NEO` (`glob.inc` réutilisable), `cmd_attrib` retiré du résident, HELP | fait |
| S67 Zone données mise à zéro au démarrage (bug `dest_path`/`dirbuf` non initialisé révélé par la nouvelle base) ; références 0.14.0 ; docs | fait |
| S68 Trinity : reconstruire avec l'image 0.14.0 et `NEODOS_LOAD = $B800` (dépôt Trinity, livré dans Trinity 0.7.0 le 2026-09-21 ; `EXIT` relance la 0.14.0, vérifié dans `neo` et Phosphoneo) | fait |

## Sprint 15 — Suggestion automatique (2026-09-21) — livré, v0.15.0

| Story | État |
|---|---|
| S69 Suggestion en gris de la suite de la dernière commande correspondante, → / Fin pour accepter, encre relue par 2,18 | fait |
| S70 Test 37, runner `\c` final, docs | fait |

## Sprint 16 — Scripts .BAT : FOR, SHIFT, ERRORLEVEL externe (2026-09-21) — livré, v0.16.0

| Story | État |
|---|---|
| S71 `FOR %v IN (jeu) DO cmd` (jokers développés via `collect_matches`, `%%v`) | fait |
| S72 `SHIFT` (décalage des `%n`) | fait |
| S73 `ERRORLEVEL` des commandes externes (octet `$B810` de l'en-tête, `fail`/`exit_code` de `neoext.inc`, somme du stub à partir de `$B811`) | fait |
| S74 Tests 38/39, correctif suggestion débordante, docs | fait |

## Sprint 17 — Ctrl+Alt+Suppr généralisé (2026-09-21) — livré, v0.17.0

| Story | État |
|---|---|
| S75 `check_cad` / `wait_key` : détection commune de Ctrl+Alt+Suppr dans toutes les attentes clavier (`getkey`, `PAUSE`, `DIR /P`, `Y/N`) | fait |
| S76 Contrôle en tête de `batch_next` : un script en boucle peut être interrompu | fait |
| S77 Test `40_cad_batch_pause` (fixture `FOREVER.BAT`), références régénérées, docs | fait |

## Sprint 18 — REBOOT (2026-09-21) — livré, v0.18.0

| Story | État |
|---|---|
| S78 `BIN/REBOOT.NEO` : reset matériel complet (1,7), usage sur argument, repli `ERRORLEVEL 1` si 1,7 revient (B13, décision bmarty du 2026-09-21) | fait |
| S79 Test `41_ext_reboot`, références régénérées, docs, recette 4.13 | fait |

## Sprint 19 — Retour carte : `COPY … .`, `EXIT` (2026-09-21) — livré, v0.19.0

| Story | État |
|---|---|
| S80 `COPY`/`MOVE` vers `.`/`\` : Stat `INVALID_NAME` de FatFs = répertoire d'origine (`copy_move`) ; `Invalid file name` dans `err_api` | fait |
| S81 Externes : `stat_path` (`neoext.inc`) pour `TREE` (défaut `.`), `XCOPY`, `ATTRIB` | fait |
| S82 `EXIT` via le stub `$0100` (`stub_exit`) : 1,3 écrase le code de NeoDOS, le `jmp (0)` ne peut pas s'exécuter depuis `$B800+` | fait |
| S83 Recette 2.11 (`COPY … .` sur carte), docs | fait |

## Sprint 20 — Chargement par-dessus NeoDOS (2026-09-21) — livré, v0.20.0

| Story | État |
|---|---|
| S84 `stub_run` : 3,2 + `JMP $FF08` exécutés depuis `$0100` (retour carte ProphetGui/`legacy.neo`) ; `load_error` si échec avec NeoDOS intact | fait |
| S85 Stub factorisé (`load`, `intact`), `stub_critical`, budget de pile documenté | fait |
| S86 Fixture `BIG.NEO` (`make fixtures`), test 42, docs, recette 4.14 | fait |

## Sprint 21 — Historique persistant, COLOR (2026-09-22) — livré, v0.21.0

| Story | État |
|---|---|
| S87 `hist_save`/`hist_load` : `/boot/neodos.his` (image brute 202 o, Stat de la taille, cohérence des pstrings) | fait |
| S88 `BIN/COLOR.NEO` : `COLOR fe` (DOS), `$90+fond`/`$80+encre` + CLS, fond = encre refusé ; `REM COLOR 1F` dans AUTOEXEC.BAT | fait |
| S89 Test 43, `HELP`, docs, recette 4.15 | fait |

## Correctif 0.21.1 (2026-09-22) — retour carte : clavier après un jeu

| Story | État |
|---|---|
| S90 `kbd_flush` au retour d'un programme ayant tourné ≥ 2 s (`runtick`, timer 1,1) : file 2,1 vidée ; fixture `WAITKEY.NEO`, test 44 | fait |

## Sprint 22 — Heure par le modem à la demande (2026-09-22) — livré, v0.22.0

| Story | État |
|---|---|
| S91 `clock_read` : 1,20 → source 0 → 1,23 → relecture ; `clock_note` « (clock not set) » (proposition Trinity T-25) | fait |
| S92 Référence 08, docs, recette 4.17 | fait |

## Backlog (priorisé)

| # | Story | Notes |
|---|---|---|
| B3 | Date/heure des fichiers dans `DIR` | l'API 3,18 ne les renvoie pas : évolution firmware |
| B6 | `COPY` avec concaténation, `XCOPY /S` (sous-répertoires, récursif) | mémoire : pile de chemins |
| B9 | Validation sur carte (USB, SD, plusieurs volumes `A:`/`B:`) | |
| B10 | `EDIT.NEO` : recherche, sélection/copier-coller, défilement horizontal | suite |
| B14 | Suggestion automatique étendue aux noms de fichiers (accès disque à chaque touche : à mesurer sur carte) | éditeur de ligne |
| B15 | `%ERRORLEVEL%` comme variable dans les lignes (au-delà de `IF ERRORLEVEL`) ; `CHOICE` | scripts |
| B12 | `HEAD`/`TAIL`, `WC` en externes ; `MOVE` reste interne (partage `copy_move` avec `COPY`, gain ≈ 30 o) | commandes externes |
| B11 | Intégration dans le firmware à la place de `basic_binary.h` (option) | refusé pour l'instant : `.neo` seulement |

## Risques et points ouverts

- Les émulateurs (`neo`, Phosphoneo) ne normalisent pas `..` dans le
  répertoire courant (`A:\GAMES\..`) et sont sensibles à la casse des noms ;
  la carte (FatFs) n'a pas ces limites. Demandé au projet firmware (T-10).
- **Firmware de référence = Trinity** (depuis le 2026-09-19) : volumes et
  date/heure repris en Trinity 0.6.0 (2026-09-20) ; NeoDOS se dégrade
  proprement sur une Trinity plus ancienne (`B:`, `DATE`, `TIME` inertes). Depuis
  Trinity 0.4.0, **NeoDOS est l'environnement résident embarqué** (1,3 le
  recharge, `EXIT` le relance ; NeoBASIC = `boot/neobasic.bin`) : les tests
  reflètent ce comportement depuis la 0.13.0.
- Résident : ≈ 2,5 Ko de marge depuis la base `$B800` (0.14.0, ADR-004) ;
  les fonctions nouvelles restent des commandes externes (ADR-003), la marge
  sert à l'éditeur de ligne et à l'interpréteur (`FOR`, `SHIFT`, suggestion).
- Un programme `.NEO` qui recouvre `$B800-$FBFF` (au chargement ou à
  l'exécution) détruit NeoDOS : le stub `$0100` le recharge à la sortie du
  programme, à condition que celui-ci rende la main par `RTS` et n'écrase
  pas `$0100-$01C5` (pile matérielle : 58 octets garantis).
