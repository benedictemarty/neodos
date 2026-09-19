# ADR-002 — NeoDOS résident en haut de la RAM (`$D000-$FBFF`)

Date : 2026-09-19. État : accepté ; amendé le 2026-09-19 (v0.2.0 : base `$D000` ; v0.3.0 : base `$C800`).

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

Option 2. v0.1.0 : base `$D800` (9 Ko). v0.2.0 : base `$D000` (11 Ko).
v0.3.0 : base **`$C800`** (13 Ko : ≈ 7,9 Ko de code, 5 Ko de tampons dont
`listbuf` 1,25 Ko pour les jokers et `batstack` 582 octets pour `CALL`,
≈ 330 octets de marge). Les programmes disposent de `$0800-$C7FF`
(49 152 octets) ; page zéro NeoDOS `$80-$AE`, hors des zones du noyau
(`$E0-$EF`, `$FC-$FF`).

## Conséquences

- Un programme qui écrit au-dessus de `$C800` détruit NeoDOS (documenté).
- La marge est faible : un prochain sprint volumineux déplacera la base
  (`NEODOS_BASE` dans `src/const.inc`, `C800` dans le Makefile).
- `MEM` affiche ces deux zones ; `.cerror` à l'assemblage si l'image
  dépasse `$FC00`.
