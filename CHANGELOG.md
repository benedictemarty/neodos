# CHANGELOG — NeoDOS

Toutes les modifications notables sont consignées ici (format Keep a
Changelog, versions SemVer). Auteur : bmarty.

## [0.19.0] — 2026-09-21

Sprint 19 : retour carte — `COPY … .` (`Error 20`) et `EXIT` fiabilisé.

### Corrigé
- **`COPY fichier .` répondait `Error 20` sur la carte** (rapport bmarty :
  `COPY \PROPHETGUI\PROPHETGUI\PROPHETGUI.NEO .`). Cause : NeoDOS fait un
  Stat (3,16) de la destination pour savoir si c'est un répertoire ; FatFs
  (`f_stat`) renvoie `FR_INVALID_NAME` ($14 = 20) pour le répertoire
  d'origine (`.`, `\`, `..` remontant à l'origine). L'erreur était ignorée,
  la destination prise pour un *fichier* nommé `.`, et `f_open(".")`
  échouait avec le même code. `copy_move` (COPY et MOVE) traite désormais
  cette réponse comme « répertoire ». Invisible sur Phosphoneo (le `stat(".")`
  de l'hôte réussit) : à valider sur carte (recette 2.11).
- Même défaut dans les externes : `TREE` sans argument (défaut `.`), `XCOPY`
  (source ou destination `.`), `ATTRIB .` — routine commune `stat_path` de
  `neoext.inc`.
- `Error 20` s'affiche désormais `Invalid file name` (table `err_api`).
- **`EXIT`** : `cmd_exit` faisait `1,3` puis `jmp (0)` depuis le code de
  NeoDOS — or 1,3 charge l'image résidente **par-dessus `$B800-$FBFF`**, donc
  au retour de `WaitMessage` le CPU reprenait dans la nouvelle image à une
  adresse quelconque (ça marchait par chance ; avec le décalage de 35 octets
  de cette version, l'image embarquée affichait `Access denied` et sautait sa
  bannière). `EXIT` passe maintenant par le stub en `$0100` (`stub_exit` :
  `1,3` + `jmp (0)` hors de la zone écrasée). Référence `09_exit` : la
  bannière de l'image embarquée suit directement `A:\>exit`.

### Modifié
- Références des tests régénérées (tailles des externes).

## [0.18.0] — 2026-09-21

Sprint 18 : `REBOOT` (reset matériel complet, B13).

### Ajouté
- **`REBOOT`** (commande externe `BIN/REBOOT.NEO`, `examples/ext/REBOOT.asm`) :
  reset matériel complet par la fonction 1,7 — le RP2040 redémarre par son
  watchdog et le 65C02 avec lui (Trinity affiche `Resetting.`). Complément
  « à froid » de Ctrl+Alt+Suppr, qui ne relance que NeoDOS. `REBOOT /?` (ou
  tout argument) affiche l'usage. Si 1,7 rend la main (émulateur sans reset
  matériel) : `Hardware reset not available.`, `ERRORLEVEL 1`.
- Test `41_ext_reboot` (usage, appel, `IF ERRORLEVEL 1` — sur Phosphoneo 1,7
  n'imprime que `Hardware reset.` sur stdout et revient).

### Modifié
- `HELP` : la ligne des commandes de `BIN\` rappelle le chemin de recherche
  (`PATH \BIN`) et liste `REBOOT` ; `name[.NEO]` précise l'ordre (répertoire
  courant, puis `PATH`).
- Manuel : adresses de l'en-tête des commandes externes corrigées (`$B803`…,
  et non plus `$C003`…), octet `ERRORLEVEL` `$B810` mentionné.
- Références des tests régénérées (`BIN/REBOOT.NEO` dans les listes).

## [0.17.0] — 2026-09-21

Sprint 17 : Ctrl+Alt+Suppr généralisé (redémarrage à chaud partout).

### Ajouté
- **Ctrl+Alt+Suppr** n'est plus limité à l'invite : il redémarre NeoDOS à
  chaud aussi pendant `PAUSE`, `DIR /P` (« Press any key »), les questions
  `Y/N` (`DEL *.*`, `DELTREE`) et **entre deux lignes d'un script `.BAT`**
  — un script en boucle (`:TOP` / `GOTO TOP`) peut ainsi être interrompu.
- Routines communes `check_cad` (état de Suppr + Ctrl + Alt par 1,2 →
  `warm_restart`) et `wait_key` (attente d'une touche avec ce contrôle) ;
  `getkey` s'appuie dessus.
- Test `40_cad_batch_pause` (fixture `FOREVER.BAT`) : script infini puis
  `PAUSE`, chacun interrompu par `\z`.

### Modifié
- Références des tests régénérées (`FOREVER.BAT` apparaît dans les listes).
- Hors attente clavier (affichage d'un `TYPE` long, programme `.NEO` en
  cours), la combinaison n'est toujours pas vue : un programme externe
  garde le clavier.

## [0.16.0] — 2026-09-21

Sprint 16 : scripts .BAT — FOR, SHIFT, ERRORLEVEL des commandes externes.

### Ajouté
- **`FOR %v IN (ensemble) DO commande`** : pour chaque élément, la commande
  est exécutée avec `%v` (ou `%%v`, forme .BAT de DOS) remplacé. Un élément
  contenant des jokers (`*.TXT`, `GAMES\*.C`) est développé en fichiers ;
  les autres sont pris littéralement. `FOR %f IN (*.TXT a b) DO TYPE %f`. Pas
  de FOR imbriqué ; un `.NEO` dans `DO` ne revient pas dans la boucle.
- **`SHIFT`** : décale les paramètres du script (`%0←%1`, `%1←%2`…) ; sans
  effet hors d'un script. Boucle classique `:LOOP / IF "%1"=="" GOTO END /
  … / SHIFT / GOTO LOOP`.
- **`ERRORLEVEL` renvoyé par les commandes externes** : l'en-tête gagne un
  octet en `base+16` (`$B810`) que le programme écrit avant de rendre la
  main ; NeoDOS le relit dans `errorlevel`, donc `IF ERRORLEVEL 1` est
  significatif après `FIND`, `ATTRIB`, `SORT`, `MORE`… `neoext.inc` fournit
  `fail` (code 1) et `exit_code` ; les commandes externes signalent leurs
  erreurs (usage, fichier absent…) et `FIND` renvoie 1 si aucune ligne ne
  correspond (comme DOS).
- Tests `38_for_shift`, `39_ext_errorlevel` (fixtures `SHIFT.BAT`, `ERRLVL.BAT`).

### Modifié
- Somme de contrôle du stub : calculée à partir de `base+17` (après l'en-tête)
  au lieu de `base` — l'octet `ERRORLEVEL` mutable de l'en-tête ne doit pas la
  fausser (sinon NeoDOS se rechargeait après chaque commande externe).

### Corrigé
- **Suggestion automatique bornée à la ligne d'écran** : la boucle
  d'affichage dessinait la suite complète de l'entrée d'historique (jusqu'à
  `(ptr2)`), pas `sglen` ; une suggestion qui débordait passait à la ligne,
  faisait défiler l'écran et laissait des résidus. Elle est maintenant
  tronquée à la fin de la ligne d'écran courante (aucun défilement).

## [0.15.0] — 2026-09-21

Sprint 15 : suggestion automatique de la saisie.

### Ajouté
- **Suggestion automatique** (façon `fish`) : quand le curseur est en fin de
  ligne, la suite de la commande la plus récente de l'historique qui
  commence par la ligne tapée s'affiche **en gris** (encre 9 ; gras en mode
  Hercules) après le curseur, recalculée à chaque touche ; **→ ou Fin** en fin
  de ligne l'acceptent, toute autre touche la fait disparaître. Historique
  seul (en mémoire, aucun accès disque) ; l'encre du texte normal est relue
  par 2,18 (Read Ink/Paper ; 7 si la fonction est absente). Tab (fichiers)
  et F8 (recherche par préfixe) inchangés. `show_sugg`/`hide_sugg`/`_accept`
  dans `lineedit.asm`, ≈ 190 octets ; page zéro `sglen`, `sgidx`, `sgink`.
- Test `37_suggest` ; le runner accepte `\c` sur la dernière ligne (frappe
  sans Entrée final, pour capturer une suggestion à l'écran).

## [0.14.0] — 2026-09-21

Sprint 14 : base `$B800`, `ATTRIB` externalisé (ADR-004).

### Modifié
- **Résident en `$B800-$FBFF`** (était `$C000`) : + 2 048 octets ; programmes
  en `$0800-$B7FF` (45 056 octets, `MEM`). En-tête des commandes externes à
  `$B803`/`$B809`/`$B80C`/`$B80E` (`neoext.inc`, `examples/args.asm`) — un
  externe compilé pour la 0.13.0 ne reconnaît plus NeoDOS. `EDIT` : texte
  jusqu'à `$B5FF` ; `SORT` : 37 Ko max ; `SMASH.NEO` écrase depuis `$B800`.
- **`ATTRIB` devient `BIN/ATTRIB.NEO`** (`examples/ext/ATTRIB.asm`, ≈ 1,3 Ko,
  sortie identique à l'octet à l'ancienne commande interne ; `IF ERRORLEVEL`
  n'est plus significatif après lui). Nouveau `examples/ext/glob.inc`
  (`has_wild`, `split_path`, `match_glob`) pour les externes à jokers.
  `HELP` liste les externes ; « EXIT : Reload the resident environment ».
- Marge du résident : 82 → **≈ 2 500 octets**. `MOVE` reste interne : il
  partage `copy_move` avec `COPY` (gain ≈ 30 octets seulement).
- Trinity reconstruit avec l'image 0.14.0 et `NEODOS_LOAD = $B800`
  (Trinity 0.7.0, 2026-09-21) : `EXIT` relance la 0.14.0. Références des
  tests alignées sur Trinity 0.6+/0.7 (volumes « is HOST0 » et date/heure de
  retour, bannière 0.14.0 après `EXIT`).

### Ajouté
- `docs/RECETTE_CARTE.md` : fiche de recette sur carte (Trinity 0.7+, clé
  `make dist`) — démarrage, fichiers, édition de ligne (Tab, F8), programmes,
  stub, volumes ; publication Prophet 0.14.0.

### Corrigé
- **`start` met toute la zone données à zéro** : `dest_path` lisait la
  longueur de `dirbuf` non initialisée — le premier `MOVE`/`COPY` vers un
  répertoire renommait le fichier en charabia si la RAM n'était pas vierge
  (invisible en `$C000` par chance, systématique en `$B800`, probable sur
  carte). Le runner de tests ne plante plus sur une console non UTF-8.

## [0.13.0] — 2026-09-20

Sprint 13 : complétion automatique de la saisie.

### Ajouté
- **Tab** : complète le mot sous le curseur avec les noms du répertoire
  (fichiers et sous-répertoires, chemins `\` ou `/` acceptés) : le plus long
  préfixe commun des entrées qui commencent par le texte tapé est inséré
  (`type FRU` → `type FRUITS.TXT` ; `dir MANY\F3` reste `F3` s'il y a
  `F30`..`F35`) ; une correspondance unique qui est un répertoire reçoit un
  `\` final pour enchaîner (`GAMES\SU` → `GAMES\SUB\`). Aucune
  correspondance ou répertoire inexistant : la ligne ne change pas.
  Réutilise la machinerie des jokers (`split_path`, `collect_open` /
  `collect_loop`, `build_path`) ; `ins_char` factorise l'insertion.
- **F8** (DOSKEY) : rappelle la commande la plus récente de l'historique
  qui commence par le texte tapé jusqu'au curseur ; F8 à nouveau remonte à
  la précédente ; toute autre touche termine la recherche. Le firmware ne
  produit pas de code ASCII pour les touches de fonction : NeoDOS déclare au
  démarrage un texte de raccourci d'un octet (`$88`) pour F8 (API 2,4).
- Test `36_completion` ; le typer des tests accepte `\t` (Tab) et `\8` (F8).

### Modifié
- Résident : `linebuf` ramené à 201 octets (la ligne est limitée à 200),
  `LISTBUF_SIZE` 960 → 896 ; marge restante ≈ 80 octets sous `$FC00`.
  Exception assumée à l'ADR-003 (la complétion ne peut pas être une commande
  externe : elle vit dans l'éditeur de ligne).
- Références des tests alignées sur **Trinity 0.5** (Phosphoneo recompilé
  contre la branche `trinity`) : « Volume in drive A has no label »,
  « Date/time not supported by this firmware », et `EXIT` relance NeoDOS
  (Trinity embarque NeoDOS comme environnement résident : 1,3 le recharge ;
  NeoBASIC est `boot/neobasic.bin`).

### Corrigé
- `DIR` / `VOL` sans fonction 3,26 (Trinity) : la lettre de lecteur était
  `'A' + résidu de DParams` (« drive a ») ; `DParams` est mis à 0 avant
  l'appel.

## [0.12.0] — 2026-09-20

Sprint 12 : `EDIT`, l'éditeur plein écran.

### Ajouté
- **`EDIT fichier`** (`BIN/EDIT.NEO`, ~2,3 Ko) : éditeur de texte plein écran
  (ligne d'état, 28 lignes, ligne d'aide avec le numéro de ligne) ; texte en
  `$2000-$BDFF` (≈ 38 Ko), CR/LF et LF seuls acceptés, sauvegarde en CR/LF ;
  flèches, Début/Fin, PgUp/PgDn, saisie en insertion, Tab, Retour arrière et
  Suppr (fusion de lignes), Entrée (scission) ; Échap → menu `S` sauver,
  `X` sauver et quitter, `Q` quitter sans sauver ; `*` dans la ligne d'état
  si modifié ; fichier absent = nouveau. Redessin complet à chaque touche
  (simple ; ~1 500 caractères).
- Tests `35_ext_edit` (édition, fusion, scission, sauvegarde relue par
  `TYPE`), `35b_ext_edit_new` (nouveau fichier, `S` puis `Q`, usage).

## [0.11.0] — 2026-09-20

Sprint 11 : `FIND`, `SORT`, redirection des commandes externes.

### Ajouté
- En-tête NeoDOS : **`$C00E` = vecteur `putc`** (sortie console du résident,
  redirection `>` comprise). `neoext.inc` l'utilise quand NeoDOS est présent :
  la sortie d'une commande externe va dans le fichier de `> f` / `>> f`. La
  redirection n'est plus fermée avant le lancement d'un programme (seuls les
  canaux 0 et 7 et le répertoire le sont).
- **`FIND [/I] [/N] [/C] [/V] "texte" fichier`** (`BIN/FIND.NEO`) : lignes
  contenant le texte (guillemets facultatifs, espaces permis) ; `/I` casse
  ignorée, `/N` numéros, `/C` compte seul, `/V` lignes sans le texte.
- **`SORT [/R] fichier`** (`BIN/SORT.NEO`) : tri des lignes (ASCII, casse
  confondue ; `/R` décroissant), fichier chargé en `$2000` (40 Ko max,
  2 048 lignes), tri de Shell sur une table de pointeurs.
- Tests `32_ext_sort`, `33_ext_find`, `34_ext_redirect` (fixture `FRUITS.TXT`).

## [0.10.0] — 2026-09-20

Sprint 10 : `XCOPY /S` et `DELTREE` en commandes externes.

### Ajouté
- `examples/ext/walk.inc` : parcours récursif générique (pile `skip[depth]`,
  crochets `hook_file` / `hook_enter` / `hook_leave`, `join`).
- **`XCOPY source destination [/S]`** (`BIN/XCOPY.NEO`) : copie les fichiers
  d'un répertoire (créé au besoin) ; `/S` reproduit les sous-répertoires
  (chemin de destination tenu en parallèle) ; « n file(s) copied ».
- **`DELTREE répertoire`** (`BIN/DELTREE.NEO`) : supprime un répertoire et
  tout son contenu après confirmation `Y/N` (fichiers à l'aller, répertoires
  au retour).
- Tests `30_ext_xcopy`, `31_ext_deltree`.

### Modifié
- `XCOPY` retiré du résident (une commande interne ne peut pas être remplacée
  par `BIN\XCOPY.NEO`) : −180 octets, marge ≈ 250 octets.

## [0.9.0] — 2026-09-20

Sprint 9 : premières commandes externes (ADR-003), le résident étant plein.

### Ajouté
- `examples/ext/neoext.inc` : base des commandes externes (API, `putc`,
  `puts`, `putpstr`, `getkey`, `cmd_arg` qui lit le n-ième mot de la ligne de
  commande via l'en-tête NeoDOS `$C00C`) ; règle Makefile générique
  `examples/ext/NOM.asm` → `storage/BIN/NOM.NEO` ; `make dist` copie `BIN/`.
- **`MORE fichier`** (`BIN/MORE.NEO`) : affichage paginé (28 lignes,
  « -- More -- », touche = suite, `Q` = fin), CR/LF/CR-LF, tabulations.
- **`TREE [chemin] [/F]`** (`BIN/TREE.NEO`) : arborescence récursive (8
  niveaux) avec fichiers sur `/F` ; le firmware n'ayant qu'un répertoire
  ouvert à la fois, chaque niveau est ré-énuméré en sautant les
  sous-répertoires déjà visités (pile de compteurs).
- Tests `28_ext_tree`, `29_ext_more` (fixtures `GAMES/SUB/DEEP`, `LONG.TXT`).

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
