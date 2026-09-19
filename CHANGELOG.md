# CHANGELOG — NeoDOS

Toutes les modifications notables sont consignées ici (format Keep a
Changelog, versions SemVer). Auteur : bmarty.

## [0.8.2] — 2026-09-20

Comment NeoDOS « survit » aux programmes (question bmarty) : comme NeoBASIC,
qui est rechargé depuis la flash par 1,3, NeoDOS se recharge depuis le disque.

### Ajouté
- **Stub de retour** (`src/stub.asm`) : avant chaque lancement, un stub de
  ~150 octets est copié en `$0100` (bas de la page pile) et son adresse est
  poussée comme adresse de retour. Au `RTS` du programme il vérifie NeoDOS
  (somme de contrôle 16 bits du code `$C000..codeend`, sentinelles `$A5` aux
  deux bouts des données) : intact → reprise normale (batch en cours,
  invite) ; sinon → rechargement de `/boot/neodos.neo` puis `/neodos.neo`
  (3,2 + `$FF08`), en dernier recours NeoBASIC (1,3). Un programme llvm-mos
  qui écrase `$C000-$FBFF` avec sa pile C et rend la main revient donc à un
  NeoDOS neuf (`AUTOEXEC.BAT` rejoué).
- `examples/smash.asm` → fixture `SMASH.NEO` (écrase `$C000-$FBFF` puis
  `RTS`) ; test `27_smash_reload` (le runner place `boot/neodos.neo` dans
  chaque stockage de test).

### Corrigé
- `run_batch` : la copie de la ligne de commande dans `batargs` bouclait 256
  fois quand la ligne était vide (`STX` ne positionne pas Z), écrasant
  `batdepth` et `batstack` — sans effet visible tant que la RAM était à
  zéro, détecté avec la fixture SMASH (« File not found » après
  `AUTOEXEC.BAT`, 4 rechargements fantômes).
- `install_stub` : boucle de copie `bpl` fausse au-delà de 128 octets.

### Modifié
- `listbuf` 1 024 → 960 octets. Marge ≈ 30 octets : le résident est plein
  (ADR-003 : toute suite en commandes externes).

## [0.8.1] — 2026-09-20

### Corrigé
- **Gel au lancement des programmes chargés en `$0200`** (llvm-mos : `poker.neo`,
  signalé par bmarty sur carte) : la 0.8.0 recopiait la ligne de commande en
  `$0200` après le chargement, écrasant le début du programme. La ligne n'est
  plus copiée : elle reste dans `linebuf` et NeoDOS publie un **en-tête** en
  `$C000` — `$C003` signature `NEODOS`, `$C009` version (3 octets), `$C00C`
  pointeur vers la ligne (pstring). `examples/args.asm` mis à jour ; test
  `26_run_at_0200` (fixture `POKER/`, programme llvm-mos réel).

### Connu
- Les programmes llvm-mos placent leur pile C en `$F600` (descendante), dans
  la zone de NeoDOS : ils tournent, mais NeoDOS est détruit derrière eux
  (retour impossible ; redémarrer). Pour être compatible : lier avec
  `-Wl,--defsym=__stack=0xC000` (ou ne pas dépasser `$BFFF`).

## [0.8.0] — 2026-09-19

Publié sur le serveur Prophet (`https://prophet.3617.fr`, catégorie
« en développement », paquet `neodos` : `neodos.neo`, `AUTOEXEC.BAT`,
`HELLO.NEO`, jaquette) le 2026-09-19.

Sprint 8 : Trinity et commandes externes.

### Ajouté
- Détection des fonctions du firmware au démarrage (`detect_caps` : 3,26 et
  1,20 sondées avec des paramètres préchargés, car sur carte une fonction
  inconnue ne touche ni les paramètres ni `$FF02`). Sur Trinity (firmware de
  référence, sans les fonctions du fork) : lecteur `A:` seul, `VOL`/`DIR`
  « has no label », `DATE`/`TIME` → « Date/time not supported by this
  firmware », `$d`/`$t` ignorés.
- Contrat des commandes externes : la ligne de commande est recopiée en
  `$0200` (pstring) avant le lancement d'un `.NEO` ; exemple `BIN/ARGS.NEO`
  (`examples/args.asm`) ; test `25_external_args`.
- `make dist` : image de clé USB pour Trinity (`boot/neodos.neo`,
  `boot/auto.txt`, `AUTOEXEC.BAT` avec `PATH \BIN`, `BIN/`).
- Mémo au projet firmware (branche `trinity`, `docs/MEMO-NEODOS-2026-09-19.md`,
  story T-10).

### Corrigé
- Un chemin absolu tapé comme commande (`\BIN\ARGS.NEO x`) était ignoré
  (mot de commande vide).

### Modifié
- `batbuf` 1 024 → 768 octets (scripts de 768 octets max) pour loger la
  détection ; marge ≈ 190 octets.

## [0.7.0] — 2026-09-19

Sprint 7 : Ctrl+Alt+Suppr, commandes externes (ADR-003).

### Ajouté
- **Ctrl+Alt+Suppr** à l'invite : redémarrage à chaud de NeoDOS — attente du
  relâchement de la touche, son coupé (8,1), retour à la racine (3,15),
  écran effacé, relance de `start` (fichiers fermés, `AUTOEXEC.BAT` rejoué).
  Le RP2040 n'est pas réinitialisé (le reset complet 1,7 reste hors NeoDOS).
- ADR-003 : le résident est gelé à `$C000` ; les fonctions volumineuses
  seront des commandes externes `.NEO` trouvées via `PATH`.
- Test `24_ctrl_alt_del` (`\z` du typer Phosphoneo).

### Modifié
- `BAT_ARGS_SIZE` 128 → 96 (ligne de commande d'un script) : −128 octets.

## [0.6.0] — 2026-09-19

Sprint 6 : consolidation et historique de commandes.

### Ajouté
- Éditeur de ligne propre à NeoDOS (`src/lineedit.asm`) à la place du
  `ReadLine` du noyau : insertion au curseur, Retour arrière, Suppr,
  Gauche/Droite, Début/Fin, Échap (efface), lignes de 200 caractères sur
  plusieurs lignes d'écran.
- Historique de commandes : Haut/Bas rappellent les lignes précédentes
  (tampon de 200 octets, doublons consécutifs et lignes vides ignorés).
- Test `23_lineedit` ; le runner accepte les séquences `\u \d \l \r \h
  \k \x \b \e` (touches d'édition du typer Phosphoneo, étendu pour
  l'occasion).

### Modifié
- Code réduit de 344 octets (sous-programmes `p0_arg1`, `p0_namebuf`,
  `ptr_arg1`, `ptr_arg2`, `ptr_namebuf` à la place des macros répétées) ;
  `screenline` (256 octets) supprimé ; `cwdbuf`, `cwdpath`, `promptbuf`
  ajustés. Marge ≈ 80 octets sous `$FC00`.
- `promptskip` ne sert plus qu'au calcul de colonne de l'éditeur.

## [0.5.0] — 2026-09-19

Sprint 5 : MOVE, XCOPY, ATTRIB.

### Ajouté
- `MOVE source|motif destination` : déplace par renommage (vers un nom ou un
  répertoire), « n file(s) moved » ; implémentation commune avec `COPY`
  (`copy_move`, fonction API paramétrée).
- `XCOPY source[\motif] destination` : copie les fichiers d'un répertoire
  (ou d'un motif) vers un répertoire créé au besoin (un niveau, pas de `/S`).
- `ATTRIB [+R -R +H -H +S -S +A -A] [fichier|motif|répertoire]` : affiche
  (`A S H R chemin`) ou modifie les attributs ; sans argument, tous les
  fichiers du répertoire courant.
- Tests `20_move`, `21_xcopy`, `22_attrib`.

### Modifié
- `listbuf` ramené à 1 Ko et `argrest` à 200 caractères pour rester en
  `$C000` (marge ≈ 170 octets).
- Message `Cannot copy several files to one file` remplacé par `Destination
  must be a directory` (commun à `COPY` et `MOVE`).

## [0.4.0] — 2026-09-19

Sprint 4 : PATH, PROMPT, redirection.

### Ajouté
- `PATH [rép;rép…]` : les programmes `.NEO` et scripts `.BAT` sont cherchés
  dans le répertoire courant puis dans chaque répertoire de `PATH` (nom tel
  que tapé puis en majuscules) ; `PATH` affiche `PATH=…` ou `No Path`,
  `PATH ;` efface.
- `PROMPT [texte]` : `$p` chemin, `$g` `>`, `$l` `<`, `$n` lettre du lecteur,
  `$d` date, `$t` heure, `$_` retour à la ligne, `$$`, `$b` `|`, `$q` `=` ;
  défaut `$p$g`. La lecture de ligne saute la dernière ligne de l'invite.
- Redirection `commande > fichier` (création) et `>> fichier` (ajout, fichier
  créé s'il n'existe pas) pour toute commande, messages compris ; fins de
  ligne CR/LF ; tampon de 128 octets vidé en préservant les paramètres API.
- Tests `17_path`, `18_prompt`, `19_redirect`, `19b_redirect_dir` (fixture
  `BIN/HI.NEO`, `BIN/TOOL.BAT`).

### Modifié
- NeoDOS chargé en `$C000` ; programmes en `$0800-$BFFF` (47 104 octets).
  ADR-002 amendé.
- `build_cwdpath` (« A:\chemin ») séparé de l'invite pour `DIR` et `CD`.

## [0.3.0] — 2026-09-19

Sprint 3 : scripts .BAT avancés.

### Ajouté
- Paramètres `%0`-`%9` dans les scripts (mots de la ligne de commande qui a
  lancé le script ; `%` suivi d'autre chose reste littéral).
- `ERRORLEVEL` : 0 si la dernière commande a réussi, 1 si elle a affiché une
  erreur ; `IF [NOT] ERRORLEVEL n` (vrai si ≥ n).
- `IF [NOT] EXIST fichier commande`, `IF [NOT] a==b commande` (formes
  `a==b`, `a == b`, `"a"=="b"`, casse exacte), `IF` chaînables.
- `GOTO label` (`:label` accepté, insensible à la casse) ; lignes `:label`
  ignorées à l'exécution ; « Label not found » termine le script.
- `CALL script [args]` : script imbriqué (3 niveaux), l'appelant est rechargé
  et reprend après le `CALL` ; hors script, `CALL` lance simplement le `.BAT`.
- Tests `14_bat_args_if`, `15_bat_goto`, `16_bat_call` (fixtures `ARGS.BAT`,
  `LOOP.BAT`, `SUB.BAT`, `SUB2.BAT`, `CALLER.BAT`).

### Modifié
- NeoDOS chargé en `$C800` (pile des niveaux CALL) ; programmes en
  `$0800-$C7FF` (49 152 octets). ADR-002 amendé.
- La boucle batch (`batch_next`) réinitialise la pile 6502 à chaque ligne.

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
