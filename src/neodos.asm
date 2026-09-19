; ***************************************************************************
;  NeoDOS — interpréteur de commandes façon MS-DOS pour le Neo6502
;  Auteur : bmarty <bmarty@mailo.com>
;  Assemblage : 64tass --mw65c02 --nostart (voir Makefile)
;
;  NeoDOS est un fichier .neo chargé en $C000 (exec $C000). Il remplace
;  NeoBASIC comme environnement de commande : l'utilisateur dispose d'une
;  invite « A:\> », des commandes internes DOS (DIR, CD, MD, RD, DEL, REN,
;  COPY, TYPE, CLS, VER, VOL, DATE, TIME, ECHO, PAUSE, REM, MEM, HELP, EXIT)
;  et lance les programmes .NEO ou les scripts .BAT (AUTOEXEC.BAT au
;  démarrage). Toutes les entrées/sorties passent par l'API du firmware
;  (bloc de contrôle $FF00).
; ***************************************************************************

VERSION         = "0.9.0"

                .include "const.inc"
                .include "macros.inc"

                * = NEODOS_BASE
                jmp     start                   ; $C000
                .text   "NEODOS"                ; $C003 : signature (commandes externes)
                .byte   0, 9, 0                 ; $C009 : version majeure, mineure, correctif
                .word   linebuf                 ; $C00C : ligne de commande (pstring, 200 max)

                .include "shell.asm"
                .include "commands.asm"
                .include "batch.asm"
                .include "wildcard.asm"
                .include "lineedit.asm"
                .include "stub.asm"
                .include "console.asm"
codeend
                .include "data.asm"

                .cerror dataend > NEODOS_TOP, "NeoDOS depasse $FC00"
