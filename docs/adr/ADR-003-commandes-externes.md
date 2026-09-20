# ADR-003 — NeoDOS résident gelé (base `$C000`, puis `$B800` depuis l'ADR-004), extensions en commandes externes

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

- Exception (0.13.0) : la complétion de la saisie (Tab, F8) fait partie de
  l'éditeur de ligne et ne peut pas être externalisée ; elle a été payée
  par `linebuf` (256 → 201) et `listbuf` (960 → 896), marge ≈ 80 octets.

- Les commandes externes n'ont pas accès aux routines internes de NeoDOS
  (analyse de ligne, jokers). Contrat (v0.8.1 ; la copie en `$0200` de la
  0.8.0 écrasait les programmes llvm-mos chargés à cette adresse) : en-tête
  en `NEODOS_BASE` (`$C000` jusqu'à la 0.13.0, `$B800` depuis la 0.14.0 — ADR-004) — base+3 signature `NEODOS`, base+9 version (3 octets),
  base+12 pointeur vers la ligne de commande (pstring, 200 max), base+14
  (v0.11.0) vecteur `putc` du résident pour que la sortie suive `>` ; exemple
  `examples/args.asm` → `BIN/ARGS.NEO`.
- `AUTOEXEC.BAT` devra positionner `PATH` (par exemple `PATH \BIN`).
- Les descentes de base restent possibles mais exigent une décision
  explicite (ADR-002).
