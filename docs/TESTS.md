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
`~/Phosphoneo/build/phosphoneo`), version avec les touches d'édition du
typer (commit `ef145e3` de Phosphoneo, 2026-09-19 : `\z` = Ctrl+Alt+Suppr).
Depuis le 2026-09-20 (commit `02da22d`), Phosphoneo est compilé contre la
branche `trinity` du firmware : les références suivent **Trinity**. Au
2026-09-21 (Trinity 0.7.0) : volumes 3,24-26 (« Volume in drive A is
HOST0 ») et date/heure 1,20-21 sont de retour (0.6.0) ; 1,3 recharge
l'image NeoDOS embarquée dans le firmware (0.14.0 en `$B800` depuis Trinity
0.7.0), donc `EXIT` relance NeoDOS au lieu de NeoBASIC. Une Phosphoneo
compilée contre une Trinity plus ancienne (0.5 : pas de volumes ni de
date/heure, image 0.12.0 en `$C000`) fait échouer une douzaine de cas sur
ces seuls points — régénérer avec `--ref` après avoir relu le diff.

## Structure

- `tests/cases/NOM.keys` : texte frappé, une commande par ligne ; une ligne
  terminée par `\c` est frappée sans Entrée (réponse à `Y/N` ; sur la
  dernière ligne : la console est capturée en cours de saisie) ; `\u \d \l
  \r` (flèches), `\h` `\k` (Début/Fin), `\x` (Suppr), `\b` (Retour
  arrière), `\e` (Échap), `\t` (Tab), `\1`..`\8` (F1..F8) sont les touches
  du typer Phosphoneo (les autres antislashs sont des séparateurs DOS ;
  éviter `\d`, `\t`… en début de nom en minuscules).
- `tests/cases/NOM.api` (facultatif) : groupes API à journaliser ; la
  référence contient alors une section `--- api ---` avec les fonctions
  distinctes appelées (vérifie qu'un programme graphique a bien tourné).
- `tests/expected/NOM.txt` : console attendue (à partir de « NeoDOS version »,
  sans lignes vides ni espaces de fin) puis `--- files ---` et la liste triée
  des fichiers du stockage après le test.
- `boot/neodos.neo` est ajouté à chaque stockage de test (rechargement par
  le stub ; exclu du listing `--- files ---`).
- `tests/fixtures/` : fichiers présents au démarrage (`README.TXT`,
  `CTRL.TXT`, `GAMES/A.TXT`, `CHAIN.BAT`, `MANY/F01..F35.DAT`, scripts
  `ARGS.BAT`, `LOOP.BAT`, `SUB.BAT`, `SUB2.BAT`, `CALLER.BAT`, `BIN/HI.NEO`,
  `BIN/TOOL.BAT`) ; `storage/` (exemples) est ajouté.

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
| `09_exit` | `EXIT` : 1,3 → sur Trinity, l'image NeoDOS **embarquée dans le firmware** est relancée (bannière 0.14.0 depuis Trinity 0.7.0 ; la référence dépend de la Trinity avec laquelle Phosphoneo est compilé) ; sur le firmware d'origine ce serait NeoBASIC (`42`) |
| `10_wild_dir` | `DIR *.TXT`, `DIR GAMES\*.TXT`, `DIR R*`, `DIR ?TRL.TXT`, motif sans correspondance |
| `10b_dir_w` | `DIR /W` (racine, sous-répertoire, motif), commutateur inconnu ignoré |
| `11_wild_del` | `COPY *.TXT GAMES`, `DEL GAMES\*.*` refusé (N) puis accepté (Y), motif sans correspondance |
| `12_wild_ren_copy` | `REN *.TXT *.BAK`, `REN C?RL.BAK X?RL.OLD`, `COPY fichier répertoire`, `COPY motif fichier` refusé, `REN` vers un nom existant |
| `13_dir_p` | `DIR MANY /P` : pause après 28 lignes, reprise sur une touche |
| `14_bat_args_if` | `%0`-`%3`, `%` littéral, `IF "%1"=="A"`, `IF NOT`, `IF EXIST`, `IF a == b` |
| `15_bat_goto` | `GOTO label`, `GOTO :label`, `Label not found`, `GOTO` hors script, `IF` sans argument / faux / vrai |
| `17_path` | `PATH` vide / fixé / effacé, programme et script trouvés via `PATH`, avec extension, absent |
| `18_prompt` | `PROMPT $n$g`, `[$p] $$`, `$d$_$p$g` (invite sur deux lignes), retour au défaut |
| `19_redirect` | `ECHO > f`, `>> f` (existant et absent), message d'erreur redirigé, `>` sans nom |
| `19b_redirect_dir` | `DIR > f` (résultats API préservés pendant l'écriture), `DIR` vide, `COPY > f` |
| `20_move` | `MOVE` vers un répertoire, vers un nom, motif vers répertoire, motif vers un nom refusé, source absente |
| `21_xcopy` | `XCOPY` d'un répertoire vers un nouveau, d'un motif vers un existant, source absente, syntaxe |
| `22_attrib` | `BIN/ATTRIB.NEO` (externe depuis 0.14.0, sortie identique à l'ancienne interne) : affichage, `+R`, `-R +A`, motif, répertoire, attribut inconnu, absent, sans argument |
| `23_lineedit` | historique (Haut/Bas, fin de liste), Échap, insertion au curseur, Suppr, Début/Fin, Retour arrière |
| `24_ctrl_alt_del` | Ctrl+Alt+Suppr : redémarrage à chaud (bannière, racine, `AUTOEXEC.BAT`) |
| `41_ext_reboot` | `BIN/REBOOT.NEO` : `REBOOT /?` (usage), `REBOOT` (1,7 revient sur Phosphoneo → `Hardware reset not available.`), `IF ERRORLEVEL 1` |
| `42_big_load_over` | `BIG.NEO` (`$B000-$C100`) recouvre NeoDOS pendant le chargement : message du programme, puis NeoDOS rechargé (`stub_run`) ; avec la 0.19.0 le programme ne démarrait pas |
| `40_cad_batch_pause` | Ctrl+Alt+Suppr pendant un script en boucle (`FOREVER.BAT`) puis pendant `PAUSE` : deux redémarrages à chaud |
| `25_external_args` | commande externe via `PATH` depuis un sous-répertoire, chemin absolu comme commande, ligne de commande en `$0200`, `PATH ;` |
| `26_run_at_0200` | programme llvm-mos réel chargé en `$0200` (`POKER.NEO`) lancé depuis NeoDOS : appels graphiques (groupe 5) observés (régression du gel 0.8.0) |
| `27_smash_reload` | `SMASH.NEO` écrase `$B800-$FBFF` puis `RTS` : NeoDOS rechargé depuis `boot/neodos.neo`, `AUTOEXEC.BAT` rejoué, invite fonctionnelle |
| `28_ext_tree` | `TREE GAMES /F` (fichiers puis sous-répertoires, 3 niveaux), chemin invalide, `MORE` sans argument / fichier absent |
| `29_ext_more` | `MORE LONG.TXT` (70 lignes) : pause à 28 lignes, espace = suite, `Q` = fin, retour à l'invite |
| `30_ext_xcopy` | `XCOPY` un niveau, `/S` (3 fichiers, 2 niveaux vérifiés par `TREE /F`), sans argument, source invalide |
| `31_ext_deltree` | `DELTREE` refusé (N) puis accepté (Y), répertoire disparu, chemin invalide, sans argument |
| `32_ext_sort` | `SORT` croissant / `/R`, sans argument, fichier absent |
| `33_ext_find` | `FIND` sensible à la casse, `/I /N`, `/C`, `/V`, usage, fichier absent |
| `34_ext_redirect` | sortie de `FIND`, `SORT`, `TREE` redirigée par `>` et `>>` (vecteur `$C00E`) |
| `35_ext_edit` | `EDIT` : déplacements, insertion, fusion et scission de lignes, sauvegarde `X`, relecture par `TYPE` (CR/LF) |
| `35b_ext_edit_new` | `EDIT` d'un fichier absent : création, `S` puis `Q`, usage sans argument |
| `38_for_shift` | `FOR` (jokers, littéraux, `%%v`, `IF` dans `DO`, `x` sans `%`, `DO` vide, sans `DO` = erreurs), `SHIFT` (hors script, décalage) |
| `39_ext_errorlevel` | `IF ERRORLEVEL` après les commandes externes (`FIND` sans/avec correspondance, `ATTRIB` fichier absent, `MORE` sans argument) |
| `37_suggest` | suggestion automatique : `ech` + → accepte `echo help` (la plus récente), `echo hell` + → `echo hello`, `echo he` + Fin, frappe/retours arrière sans artefact, fantôme `echo hello` visible derrière `ech` (dernière ligne sans Entrée, `\c`) |
| `36_completion` | Tab : nom unique, chemin en deux Tab (`\` ajouté après un répertoire), préfixe commun (`F3`), aucune correspondance ; F8 : préfixe `ec`, F8 répété, ligne vide puis Échap |
| `16_bat_call` | `CALL` imbriqué sur 2 niveaux avec `%1`, reprise de l'appelant, `IF ERRORLEVEL` après `DEL` raté, `CALL` d'un script absent, `CALL` depuis l'invite |

`AUTOEXEC.BAT` est exercé par tous les cas (bannière « Welcome to NeoDOS »).
L'ordre des entrées de `DIR` est celui du système de fichiers hôte (stable
sur ext4 pour un même jeu de noms).

## Non couvert (à faire sur carte)

Volumes multiples (`B:`), clé USB / carte SD réelles, `PAUSE` interactif.
