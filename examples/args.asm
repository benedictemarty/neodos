; args.asm — commande externe d'exemple : affiche la ligne de commande que
; NeoDOS lui transmet, puis rend la main (RTS). Modèle pour toute commande
; externe (ADR-003) : en-tête NeoDOS en $C000 — $C003 signature « NEODOS »,
; $C009 version (3 octets), $C00C pointeur vers la ligne (pstring : longueur
; puis caractères). Ne jamais écrire dans $C000-$FBFF (NeoDOS résident).
;   64tass --mw65c02 --nostart -o args.bin args.asm
;   python3 tools/mkneo.py args.bin ARGS.NEO 0800 0800 "Args"
WriteCharacter  = $FFF1
WaitMessage     = $FFF4
NEODOS_SIG      = $C003
NEODOS_CMDLINE  = $C00C
cmd             = $80                           ; pointeur page zéro
                * = $0800
                lda     NEODOS_SIG              ; lancé depuis NeoDOS ?
                cmp     #'N'
                bne     _end
                lda     NEODOS_SIG+1
                cmp     #'E'
                bne     _end
                lda     NEODOS_CMDLINE
                sta     cmd
                lda     NEODOS_CMDLINE+1
                sta     cmd+1
                ldx     #0
-               lda     msg,x
                beq     +
                jsr     putc
                inx
                bra     -
+               lda     (cmd)                   ; longueur
                beq     _end
                tax
                ldy     #1
-               lda     (cmd),y
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
