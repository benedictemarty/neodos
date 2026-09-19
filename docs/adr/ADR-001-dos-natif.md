# ADR-001 — Un DOS natif 65C02 plutôt qu'un portage de MS-DOS

Date : 2026-09-19. État : accepté.

## Contexte

La demande initiale est « porter MS-DOS sur le Neo6502 à la place de
NeoBASIC ». MS-DOS est écrit en assembleur x86 et repose sur le BIOS PC ; le
Neo6502 est un 65C02 à 6,25 MHz avec 64 Ko de RAM dont les périphériques
sont pilotés par un RP2040 via une API mémoire (`$FF00`).

## Options

1. **Émuler un x86 sur le 65C02** pour exécuter le vrai MS-DOS : hors de
   portée (performances de quelques kHz, mémoire insuffisante, BIOS à
   réécrire).
2. **Réécrire un interpréteur de commandes DOS en 65C02** au-dessus de l'API
   fichiers du firmware (FatFs) : reproduit l'expérience utilisateur
   (invite, commandes, `.BAT`), s'intègre au modèle d'exécution existant
   (`.neo` chargés en `$0800`).
3. Utiliser un système existant (CP/M-65) : ne répond pas à la demande
   « MS-DOS » et impose son propre format de binaires.

## Décision

Option 2 : NeoDOS, interpréteur natif en assembleur 64tass, fichier `.neo`
(pas de modification du firmware — choix de l'utilisateur), NeoBASIC
accessible par `EXIT`.

## Conséquences

- Aucun binaire MS-DOS ne s'exécute ; les « programmes » sont des `.NEO`.
- Les fonctionnalités DOS sont réimplémentées progressivement (backlog).
- L'accès aux fichiers dépend de l'API groupe 3 (pas de dates de fichiers
  aujourd'hui, un seul répertoire ouvert à la fois).
