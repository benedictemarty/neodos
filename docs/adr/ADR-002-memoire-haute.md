# ADR-002 — NeoDOS résident en haut de la RAM (`$D000-$FBFF`)

Date : 2026-09-19. État : accepté ; amendé le 2026-09-19 (v0.2.0 : base `$D000`).

## Contexte

NeoBASIC est chargé en `$0800` et les programmes `.neo` s'y chargent aussi.
Un interpréteur de commandes doit survivre au lancement d'un programme pour
reprendre la main (retour à l'invite, suite d'un `.BAT`).

## Options

1. NeoDOS en `$0800` comme NeoBASIC : tout programme l'écrase ; il faudrait
   le recharger depuis le disque à chaque retour (lent, dépend du chemin).
2. NeoDOS en haut de la RAM, sous le noyau (`$FC00`) : reste résident ; la
   zone programme est réduite d'autant.

## Décision

Option 2. v0.1.0 : base `$D800` (9 Ko). v0.2.0 : base **`$D000`** (11 Ko :
≈ 6,6 Ko de code, 4,3 Ko de tampons dont `listbuf` 1,25 Ko pour les jokers,
≈ 320 octets de marge). Les programmes disposent de `$0800-$CFFF`
(51 200 octets) ; page zéro NeoDOS `$80-$A9`, hors des zones du noyau
(`$E0-$EF`, `$FC-$FF`).

## Conséquences

- Un programme qui écrit au-dessus de `$D000` détruit NeoDOS (documenté).
- La marge est faible : un prochain sprint volumineux déplacera la base
  (`NEODOS_BASE` dans `src/const.inc`, `D000` dans le Makefile).
- `MEM` affiche ces deux zones ; `.cerror` à l'assemblage si l'image
  dépasse `$FC00`.
