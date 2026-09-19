; args.asm — commande externe d'exemple : affiche la ligne de commande que
; NeoDOS lui transmet en $0200 (pstring : longueur puis caractères), puis
; rend la main (RTS). Modèle pour toute commande externe (ADR-003).
;   64tass --mw65c02 --nostart -o args.bin args.asm
;   python3 tools/mkneo.py args.bin ARGS.NEO 0800 0800 "Args"
WriteCharacter  = $FFF1
WaitMessage     = $FFF4
CMDLINE         = $0200
                * = $0800
                ldx     #0
-               lda     msg,x
                beq     +
                jsr     putc
                inx
                bra     -
+               ldx     CMDLINE                 ; longueur
                beq     _end
                ldy     #1
-               lda     CMDLINE,y
                jsr     putc
                iny
                dex
                bne     -
_end            lda     #13
                jsr     putc
                rts
putc            jsr     WriteCharacter
                jmp     WaitMessage
msg             .text   "Command line: ", 0
