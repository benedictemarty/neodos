# ADR-002 — NeoDOS résident en haut de la RAM (`$D000-$FBFF`)

Date : 2026-09-19. État : accepté ; amendé le 2026-09-19 (v0.2.0 : `$D000` ; v0.3.0 : `$C800` ; v0.4.0 : `$C000`).

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

Option 2. v0.1.0 : base `$D800` (9 Ko). v0.2.0 : `$D000` (11 Ko). v0.3.0 :
`$C800` (13 Ko). v0.4.0 : base **`$C000`** (15 Ko : ≈ 9 Ko de code, 5,6 Ko de
tampons dont `listbuf` 1,25 Ko pour les jokers, `batstack` 582 octets pour
`CALL`, `outbuf` 128 pour la redirection ; v0.5.0 : `listbuf` 1 Ko, `argrest` 200 ; v0.6.0 : `screenline` supprimé, code factorisé, historique 200 octets, ≈ 80 octets de marge). Les
programmes disposent de `$0800-$BFFF` (47 104 octets) ; page zéro NeoDOS
`$80-$AF`, hors des zones du noyau (`$E0-$EF`, `$FC-$FF`).

Limite retenue : ne pas descendre sous `$C000` sans décision explicite —
NeoBASIC lui-même occupe `$0800-$4B8A`, et 47 Ko restent confortables pour les
programmes, mais chaque sprint a coûté 2 Ko.

## Conséquences

- Un programme qui écrit au-dessus de `$C000` détruit NeoDOS (documenté).
- Base : `NEODOS_BASE` dans `src/const.inc` et `C000` dans le Makefile.
- `MEM` affiche ces deux zones ; `.cerror` à l'assemblage si l'image
  dépasse `$FC00`.
