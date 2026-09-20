# ADR-004 — Base du résident descendue à `$B800`, `ATTRIB` externalisé

Date : 2026-09-21. État : accepté (v0.14.0). Amende l'ADR-002 (base) et
l'ADR-003 (contrat des commandes externes).

## Contexte

Après la complétion de la saisie (0.13.0), le résident `$C000-$FBFF` n'a
plus que 82 octets de marge : trop peu pour la moindre correction et rien
pour la suite de l'éditeur de ligne (suggestion automatique) ou de
l'interpréteur (`FOR`, `SHIFT`). L'ADR-002 interdisait de descendre sous
`$C000` sans décision explicite ; l'ADR-003 prévoit d'externaliser.

## Options

1. Rogner les tampons (`HIST_SIZE`, `BAT_DEPTH`, `listbuf`) : quelques
   centaines d'octets, chaque coupe est une régression fonctionnelle.
2. Externaliser `MOVE` et `ATTRIB` (backlog B12) : `ATTRIB` ≈ 370 octets ;
   `MOVE` partage tout son code avec `COPY` (`copy_move`) et ne rendrait
   qu'une trentaine d'octets.
3. Descendre la base à `$B800` : + 2 048 octets, zone programme réduite de
   47 104 à 45 056 octets (`$0800-$B7FF`).

## Décision (bmarty, 2026-09-21)

Options 2 et 3 ensemble : `ATTRIB` devient `BIN/ATTRIB.NEO`
(`examples/ext/ATTRIB.asm`, jokers dans `examples/ext/glob.inc` réutilisable)
avec une sortie identique à l'octet ; la base passe à **`$B800`**
(`NEODOS_BASE`, `mkneo B800 B800`). `MOVE` reste interne (gain nul). Marge
après le sprint : ≈ 2,5 Ko.

## Conséquences

- **Contrat des externes** : l'en-tête est à `NEODOS_BASE` = `$B800`
  (`$B803` signature, `$B809` version, `$B80C` ligne de commande, `$B80E`
  vecteur `putc`). `neoext.inc` et `examples/args.asm` sont à jour ; un
  programme externe compilé pour la 0.13.0 (adresses `$C0xx`) ne trouve plus
  la signature et retombe sur la sortie directe du noyau (sans redirection),
  sans ligne de commande.
- Programmes : `$0800-$B7FF`. `EDIT` limite son texte à `$B5FF` (au lieu de
  `$BDFF`), `SORT` à 37 Ko ; `SMASH.NEO` (test) écrase depuis `$B800`.
- `MEM` affiche 45 056 / 17 408 octets.
- **Trinity** embarque l'image NeoDOS (`neodos_binary.h`, `NEODOS_LOAD`) et
  la charge par 1,3 : il doit être reconstruit avec l'image 0.14.0 et
  `NEODOS_LOAD = $B800` ; tant que ce n'est pas fait, `EXIT` sur Trinity
  relance l'ancienne image embarquée en `$C000` (test `09_exit` : la
  bannière affichée après `EXIT` est celle de l'image embarquée dans la
  Phosphoneo/Trinity du poste). Story T-13 à ouvrir côté Trinity.
- Bug latent corrigé au passage (révélé par le déplacement) : `dest_path`
  lisait `dirbuf` non initialisé (`MOVE`/`COPY` vers un répertoire comme
  première commande renommait en charabia) ; `start` met désormais toute la
  zone données à zéro.
- `IF ERRORLEVEL` après `ATTRIB` n'est plus significatif (limite connue des
  externes, ADR-003).
