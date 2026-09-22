; ***************************************************************************
;  NeoDOS — interpréteur de commandes façon MS-DOS pour le Neo6502
;  Auteur : bmarty <bmarty@mailo.com>
;  Assemblage : 64tass --mw65c02 --nostart (voir Makefile)
;
;  NeoDOS est un fichier .neo chargé en $B800 (exec $B800 ; ADR-004). Il remplace
;  NeoBASIC comme environnement de commande : l'utilisateur dispose d'une
;  invite « A:\> », des commandes internes DOS (DIR, CD, MD, RD, DEL, REN,
;  COPY, TYPE, CLS, VER, VOL, DATE, TIME, ECHO, PAUSE, REM, MEM, HELP, EXIT)
;  et lance les programmes .NEO ou les scripts .BAT (AUTOEXEC.BAT au
;  démarrage). Toutes les entrées/sorties passent par l'API du firmware
;  (bloc de contrôle $FF00).
; ***************************************************************************

VERSION         = "0.21.0"

                .include "const.inc"
                .include "macros.inc"

                * = NEODOS_BASE
                jmp     start                   ; base+0
                .text   "NEODOS"                ; base+3 : signature (commandes externes)
                .byte   0, 16, 0                ; base+9 : version majeure, mineure, correctif
                .word   linebuf                 ; base+12 : ligne de commande (pstring, 200 max)
                .word   putc                    ; base+14 : sortie console de NeoDOS (A ; redirection >)
hdr_errlvl      .byte   0                       ; base+16 : code de retour écrit par un programme (ERRORLEVEL)

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
