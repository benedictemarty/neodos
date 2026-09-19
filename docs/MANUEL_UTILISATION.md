# Manuel d'utilisation — NeoDOS

## Lancer NeoDOS

- **Émulateur** : `make run` (Phosphoneo, fenêtre SDL, stockage `storage/`)
  ou `make run-neo` (émulateur officiel).
- **Carte** : copier `build/neodos.neo` sur la clé USB (et, si souhaité, le
  contenu de `storage/`), puis dans NeoBASIC : `run "neodos.neo"`.

Au démarrage, NeoDOS affiche sa bannière, exécute `AUTOEXEC.BAT` s'il existe
dans le répertoire courant, puis affiche l'invite `A:\>`.

## L'invite

`A:\GAMES>` : `A` est le lecteur (volume 0 du firmware ; `B` = volume 1, …),
`\GAMES` le répertoire courant. Les commandes ne distinguent pas majuscules et
minuscules ; les chemins acceptent `\` ou `/`.

## Fichiers et répertoires

| Commande | Exemple |
|---|---|
| `DIR [chemin][motif] [/P] [/W]` | `DIR`, `DIR GAMES`, `DIR \`, `DIR *.TXT`, `DIR GAMES\*.NEO /W`, `DIR /P` |
| `CD [chemin]` | `CD GAMES`, `CD ..`, `CD \`, `CD` (affiche le répertoire) |
| `MD chemin` | `MD SAVES` |
| `RD chemin` | `RD SAVES` (le répertoire doit être vide) |
| `DEL fichier\|motif` | `DEL OLD.TXT`, `DEL *.BAK`, `DEL SAVES\*.*` (confirmation) ; refuse un répertoire : `Access denied` |
| `REN ancien nouveau` | `REN A.TXT B.TXT`, `REN *.TXT *.BAK`, `REN C?RL.BAK X?RL.OLD` |
| `COPY source destination` | `COPY A.TXT B.TXT`, `COPY A.TXT GAMES` (même nom dans GAMES), `COPY *.TXT GAMES` |
| `TYPE fichier` | `TYPE README.TXT` |
| `X:` | `B:` change de lecteur (`Invalid drive specification` si absent) |

`DIR` affiche pour chaque entrée le nom, `<DIR>` ou la taille en octets,
puis le nombre de fichiers, le total des octets et le nombre de répertoires.
`/P` marque une pause toutes les 28 lignes (« Press any key to continue »),
`/W` affiche les noms sur 4 colonnes, répertoires entre crochets. Sans
correspondance : `File not found`.

### Jokers

`*` remplace une suite quelconque de caractères, `?` un seul ; la casse est
ignorée ; `*.*` désigne tous les fichiers. Le motif porte sur la dernière
partie du chemin (`GAMES\*.NEO`). `DEL` avec joker ne touche jamais aux
répertoires et demande confirmation (`Y/N`) pour `*` et `*.*`. `REN` avec
jokers applique le second motif nom et extension séparément : `*` recopie le
reste de la partie source, `?` un caractère (`REN *.TXT *.BAK`,
`REN A?.DAT B?.DAT`). `COPY` avec joker exige un répertoire de destination.

## Programmes

Tapez le nom d'un fichier `.NEO` (avec ou sans extension) : `HELLO` ou
`HELLO.NEO`. Le nom est cherché tel que tapé puis en majuscules. Le programme
est chargé à l'adresse indiquée par son en-tête (en général `$0800`) et
lancé ; s'il se termine par `RTS`, NeoDOS reprend la main.

Un programme ne doit pas écrire entre `$D000` et `$FBFF` (zone NeoDOS).

## Scripts .BAT

Un fichier `.BAT` (1 024 octets maximum) contient une commande par ligne.
`AUTOEXEC.BAT` est lancé au démarrage.

```
@ECHO OFF
REM Commentaire
ECHO Bonjour
ECHO.
DIR
HELLO
PAUSE
```

- `ECHO OFF` / `ECHO ON` : arrête / reprend l'écho des lignes ; `@` en tête
  d'une ligne supprime son écho ; `ECHO.` affiche une ligne vide.
- `PAUSE` attend une touche ; `REM` est un commentaire.
- Un programme `.NEO` lancé depuis un script rend la main au script ; un
  `.BAT` lancé depuis un script le remplace.

## Système

| Commande | Rôle |
|---|---|
| `CLS` | efface l'écran |
| `VER` | versions de NeoDOS et du firmware |
| `VOL` | nom du volume courant |
| `MEM` | mémoire disponible pour les programmes |
| `DATE [aaaa-mm-jj]` | affiche ou règle la date |
| `TIME [hh:mm[:ss]]` | affiche ou règle l'heure |
| `HELP` | liste des commandes |
| `EXIT` ou `BASIC` | retour à NeoBASIC |

## Messages d'erreur

| Message | Cause |
|---|---|
| `Bad command or file name` | commande inconnue, ni `.NEO` ni `.BAT` trouvé |
| `File not found` / `Path not found` | fichier ou chemin inexistant |
| `Invalid directory` | `CD` vers un répertoire inexistant |
| `Access denied` | `DEL` sur un répertoire, volume en lecture seule |
| `Syntax error` | argument manquant |
| `Too many files` | plus de 255 noms (ou 1,25 Ko) pour un joker |
| `Cannot copy several files to one file` | `COPY motif fichier` |
| `Duplicate file name or file not found` | `REN` impossible (cible existante…) |
| `Invalid drive specification` | lettre de lecteur sans volume monté |
| `Batch file too large (max 1024 bytes)` | script trop long |
| `Error nn` | autre code d'erreur de l'API fichiers |

## Limites connues (v0.1)

- Pas de `IF`/`GOTO`/`CALL` dans les scripts, pas de `PATH`, pas de dates de
  fichiers dans `DIR` (voir le backlog dans `docs/AGILE_PLAN.md`).
- Sur les émulateurs, le stockage hôte est sensible à la casse et `CD ..`
  laisse `..` dans le chemin affiché ; la carte (FAT) n'a pas ces limites.
