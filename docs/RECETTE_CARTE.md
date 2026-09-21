# Recette NeoDOS sur carte Neo6502 — v0.15.0

Fiche pas à pas pour valider NeoDOS sur la carte réelle (rien n'y a été
validé depuis la 0.8.1 : seul le gel de `poker.neo`, corrigé, avait été
constaté). Chaque étape indique ce que l'écran doit montrer ; noter toute
différence, même mineure (texte, casse, ligne en trop), et me la dicter.

Prérequis : firmware **Trinity 0.7.0 ou plus** (`~/neo-carte/trinity-0.7.x-…-USB.uf2`),
qui embarque NeoDOS 0.14.0 en `$B800` (la clé `boot/neodos.neo` apporte la 0.15.0 ; `VER` doit dire 0.15.0 au démarrage) ; une clé USB FAT32 ; le clavier USB.

## 0. Préparer la clé

```
make dist
```
Copier le contenu de `build/dist/` à la racine de la clé :
`boot/neodos.neo`, `boot/auto.txt`, `AUTOEXEC.BAT`, `DEMO.BAT`, `HELLO.NEO`,
`BIN/` (ATTRIB, DELTREE, EDIT, FIND, MORE, SORT, TREE, XCOPY, REBOOT, ARGS). Ajouter
quelques fichiers de test : un `README.TXT` de plusieurs lignes, un
`GAMES/` avec un fichier dedans, `poker.neo` si disponible.

## 1. Démarrage (5 min)

| # | Action | Attendu |
|---|---|---|
| 1.1 | Flasher (BOOTSEL → `RPI-RP2` → copier l'UF2), alimenter, clé + clavier branchés | bannière `Trinity Firmware: v0.7.x`, menu `Boot : 1 NeoDOS 2 neodos.neo …` puis `-> NeoDOS` (auto.txt) |
| 1.2 | Lecture de la bannière | `NeoDOS version 0.15.0`, `(C) 2026 bmarty…`, puis les lignes d'`AUTOEXEC.BAT` (Welcome…, `DIR`, `HELLO`), invite `A:\>` |
| 1.3 | `VER` | `NeoDOS version 0.15.0` / `Neo6502 firmware 0.7.x` |
| 1.4 | `MEM` | `45056 bytes free for programs ($0800-$B7FF)` / `17408 bytes reserved for NeoDOS ($B800-$FBFF)` |
| 1.5 | `VOL` | `Volume in drive A is …` (nom du volume de la clé) ou `has no label` |
| 1.6 | `DATE` puis `TIME` | une date et une heure (PCF8563) ou `Date/time not supported…` — noter lequel |

## 2. Fichiers et répertoires (10 min)

| # | Action | Attendu |
|---|---|---|
| 2.1 | `DIR` | liste avec tailles, `n file(s) … bytes`, `n dir(s)` ; `[BIN]`, `[GAMES]` |
| 2.2 | `DIR /W` puis `DIR *.NEO` | 4 colonnes ; seuls les `.NEO` |
| 2.3 | `TYPE README.TXT` | le texte, lignes correctes (CR/LF) |
| 2.4 | `MD ESSAI` — `CD ESSAI` — `CD` | invite `A:\ESSAI>` ; `CD` seul affiche `A:\ESSAI` |
| 2.5 | `CD ..` puis `CD \` | retour `A:\>` (le `..` est celui de FatFs, jamais testé sur carte) |
| 2.6 | `COPY README.TXT ESSAI` — `DIR ESSAI` | `1 file(s) copied` ; `README.TXT` dans ESSAI, même taille |
| 2.7 | **`MOVE README.TXT ESSAI\R2.TXT`** — `DIR ESSAI` | `1 file(s) moved` ; `R2.TXT` avec un **nom lisible** (bug `dirbuf` corrigé en 0.14.0 : avant, le premier MOVE vers un répertoire pouvait produire un nom en charabia) |
| 2.8 | `REN ESSAI\R2.TXT README.TXT` — `COPY ESSAI\*.* .` | fichier renommé ; copie de retour `1 file(s) copied` |
| 2.9 | `DEL ESSAI\*.*` (répondre `Y`) — `RD ESSAI` — `DIR` | question `Y/N`, suppression, répertoire disparu |
| 2.11 | `CD GAMES` — `COPY \README.TXT .` — `DIR` — `CD \` — `TREE` | `1 file(s) copied`, `README.TXT` dans `GAMES` (0.18.0 et avant : `Error 20`, FatFs refuse `Stat(".")`) ; `TREE` sans argument liste l'arborescence (même cause) |
| 2.10 | `ATTRIB README.TXT` — `ATTRIB +R README.TXT` — `ATTRIB README.TXT` — `DEL README.TXT` | `     README.TXT` puis `   R README.TXT` ; `Access denied` sur le DEL (lecture seule) ; `ATTRIB -R README.TXT` pour finir |

## 3. Édition de ligne (5 min)

| # | Action | Attendu |
|---|---|---|
| 3.1 | Taper `ECHO abc`, Entrée, puis Flèche haut | la ligne `ECHO abc` réapparaît ; Flèche bas → ligne vide |
| 3.2 | Taper `ECHO ad`, Flèche gauche ×1, taper `bc`, Entrée | affiche `abcd` (insertion au curseur) |
| 3.3 | Taper `TYPE REA` puis **Tab** | complété en `TYPE README.TXT` |
| 3.4 | Taper `DIR GA` puis **Tab**, Tab encore | `DIR GAMES\` puis le nom du fichier dedans |
| 3.5 | Taper `EC` puis **F8** | `ECHO abcd` (dernière commande commençant par `EC`) ; F8 encore → `ECHO abc` |
| 3.6 | Échap sur une ligne à moitié tapée | ligne effacée |
| 3.8 | Taper `EC` (sans Entrée) | la suite `HO abcd` apparaît **en gris** après le curseur (suggestion) ; → l'accepte, la ligne devient `ECHO abcd` en couleur normale ; Échap pour annuler |
| 3.7 | Une ligne de plus de 53 caractères, Début (Home), Fin (End) | le curseur passe d'une ligne d'écran à l'autre sans décaler le texte |

## 4. Programmes et scripts (10 min)

| # | Action | Attendu |
|---|---|---|
| 4.1 | `HELLO` | message de HELLO.NEO, retour à l'invite |
| 4.2 | `DEMO` | le script se déroule, retour à l'invite |
| 4.3 | `MORE README.TXT`, `TREE /F`, `FIND "a" README.TXT`, `SORT README.TXT` | commandes externes trouvées via `PATH \BIN` ; sortie cohérente ; `TREE` liste `BIN` et `GAMES` |
| 4.4 | `SORT README.TXT > TRI.TXT` puis `TYPE TRI.TXT` | fichier créé, lignes triées (redirection d'une externe, vecteur `putc`) |
| 4.5 | `EDIT NOTE.TXT` : taper deux lignes, Échap, `X` | retour à l'invite ; `TYPE NOTE.TXT` montre les deux lignes |
| 4.6 | `poker.neo` (si présent) : `POKER` | le jeu tourne (chargé en `$0200`), pas de gel (régression 0.8.0) |
| 4.7 | Quitter le programme par sa sortie normale | retour à `A:\>` (stub `$0100` : NeoDOS intact ou rechargé depuis `boot/neodos.neo`) |
| 4.8 | `SMASH` (fourni dans les tests, à copier sur la clé si voulu) | `Smashing $B800-$FBFF…` puis NeoDOS **rechargé** : bannière, AUTOEXEC rejoué, invite |
| 4.9 | `EXIT` | NeoDOS relancé par le firmware (bannière **0.14.0** : c'est l'image embarquée dans Trinity 0.7.x, pas celle de la clé) |
| 4.10 | **Ctrl+Alt+Suppr** à l'invite | redémarrage à chaud : écran effacé, bannière, AUTOEXEC rejoué |
| 4.11 | `PAUSE` puis **Ctrl+Alt+Suppr** | redémarrage à chaud (pas de simple levée de la pause) |
| 4.12 | `FOREVER` (script `@ECHO OFF` / `:TOP` / `GOTO TOP`, à créer avec `EDIT`) puis **Ctrl+Alt+Suppr** | le script en boucle est interrompu, redémarrage à chaud |
| 4.14 | Programme dont l'image dépasse `$B800` (ProphetGui `legacy.neo`, `$A000-$FBE6`) lancé à l'invite | le programme démarre (0.19.0 et avant : plantage au chargement) ; à sa sortie NeoDOS est rechargé depuis `boot/neodos.neo` |
| 4.13 | `REBOOT` | `Resetting.` puis reset matériel complet : logo du firmware, menu de boot / `boot/auto.txt`, NeoDOS relancé depuis la clé |

## 5. Volumes (si deux clés / SD)

| # | Action | Attendu |
|---|---|---|
| 5.1 | `B:` puis `DIR` | contenu du second volume, invite `B:\>` ; `A:` pour revenir |
| 5.2 | `COPY A:\README.TXT B:\` | `1 file(s) copied` |

## 6. Ce qu'il faut me rapporter

- Pour chaque ligne : OK, ou le texte exact affiché.
- Un gel : ce qui était à l'écran et la dernière touche.
- Une différence avec Phosphoneo : préciser (casse d'un nom, `..`, dates).

Résultats à consigner dans `docs/AGILE_PLAN.md` (story S41/B9) et dans le
CHANGELOG ; chaque défaut devient une story du sprint suivant.
