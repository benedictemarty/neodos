# ADR-003 — NeoDOS résident gelé à `$C000`, extensions en commandes externes

Date : 2026-09-19. État : accepté (décision bmarty, sprint 7).

## Contexte

Six sprints ont fait passer le résident de `$D800` à `$C000` ; il reste moins
de 200 octets de marge et le backlog (`EDIT`, `XCOPY /S`, `FOR`, `SHIFT`,
concaténation `COPY`) demande plusieurs Ko. Chaque descente de la base
retire de la mémoire aux programmes (`$0800-$BFFF` : 47 Ko aujourd'hui).

## Options

1. Descendre la base (`$B000`, `$A000`…) à chaque sprint : simple, mais
   grignote la zone programme sans fin.
2. **Commandes externes** : comme MS-DOS (`EDIT.COM`, `XCOPY.EXE`…), les
   fonctions volumineuses sont des programmes `.NEO` indépendants, chargés
   en `$0800` à l'appel et trouvés via `PATH` ; le résident ne grossit plus.
3. Geler les fonctionnalités.

## Décision

Option 2. Le résident NeoDOS reste en `$C000-$FBFF` (marge à préserver pour
les corrections). Toute fonctionnalité nouvelle de plus d'une centaine
d'octets devient un programme `NOM.NEO` dans le dépôt (`examples/` puis
`storage/BIN/`), écrit avec la même chaîne (64tass, `tools/mkneo.py`), qui
utilise directement l'API du firmware. Le mécanisme existe déjà : nom inconnu
→ `NOM.NEO` dans le répertoire courant puis dans `PATH` ; retour à l'invite
par `RTS` ; `%ERRORLEVEL` non transmis (limite connue).

## Conséquences

- Les commandes externes n'ont pas accès aux routines internes de NeoDOS
  (analyse de ligne, jokers) : elles reçoivent leur ligne de commande via
  le tampon `linebuf` de NeoDOS ? Non — l'adresse n'est pas stable. Contrat
  retenu : la ligne de commande est recopiée en `$0200` (pstring, 200
  caractères max) avant le lancement d'un `.NEO` (à faire, sprint suivant).
- `AUTOEXEC.BAT` devra positionner `PATH` (par exemple `PATH \BIN`).
- Les descentes de base restent possibles mais exigent une décision
  explicite (ADR-002).
