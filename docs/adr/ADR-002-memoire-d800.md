# ADR-002 — NeoDOS résident en `$D800-$FBFF`

Date : 2026-09-19. État : accepté.

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

Option 2, base `$D800` (9 Ko : ≈ 4,6 Ko de code, 2,6 Ko de tampons, 1,9 Ko
de marge). Les programmes disposent de `$0800-$D7FF` (53 248 octets) ; page
zéro NeoDOS `$80-$9F`, hors des zones du noyau (`$E0-$EF`, `$FC-$FF`).

## Conséquences

- Un programme qui écrit au-dessus de `$D800` détruit NeoDOS (documenté).
- `MEM` affiche ces deux zones ; `.cerror` à l'assemblage si l'image
  dépasse `$FC00`.
