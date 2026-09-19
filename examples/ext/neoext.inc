; neoext.inc — base des commandes externes NeoDOS (programmes .NEO en $0800)
;
; Contrat NeoDOS (ADR-003) : en-tête en $C000 — $C003 « NEODOS », $C009
; version, $C00C pointeur vers la ligne de commande (pstring). Zone libre pour
; le programme : $0800-$BFFF (ne pas écrire dans $C000-$FBFF si l'on veut
; revenir vite à l'invite ; sinon NeoDOS se recharge). Retour par RTS.

ReadCharacter   = $FFEE
WriteCharacter  = $FFF1
WaitMessage     = $FFF4
SendMessage     = $FFF7
DCommand        = $FF00
DFunction       = $FF01
DError          = $FF02
DParams         = $FF04
NEODOS_SIG      = $C003
NEODOS_CMDLINE  = $C00C
CR              = 13

api             .macro
                jsr     SendMessage
                .byte   \1, \2
                jsr     WaitMessage
                .endm
print           .macro
                jsr     puts
                .null   \1
                .endm
println         .macro
                jsr     puts
                .text   \1
                .byte   CR, 0
                .endm
setparam        .macro
                lda     #<\2
                sta     DParams+\1
                lda     #>\2
                sta     DParams+\1+1
                .endm

; putc : écrit A (préservé) et attend
putc            pha
                jsr     WriteCharacter
                jsr     WaitMessage
                pla
                rts
newline         lda     #CR
                jmp     putc

; puts : texte inline terminé par 0
puts            pla
                sta     sptr
                pla
                sta     sptr+1
                phy
                ldy     #0
_next           inc     sptr
                bne     +
                inc     sptr+1
+               lda     (sptr),y
                beq     _done
                jsr     putc
                bra     _next
_done           ply
                lda     sptr+1
                pha
                lda     sptr
                pha
                rts

; putpstr : pstring pointée par ptr
putpstr         phy
                lda     (ptr)
                beq     _done
                sta     cnt
                ldy     #1
_loop           lda     (ptr),y
                jsr     putc
                iny
                dec     cnt
                bne     _loop
_done           ply
                rts

; getkey : attend une touche -> A
getkey          #api    2,1
                lda     DParams
                beq     getkey
                rts

; cmd_arg : copie le mot n° A (0 = nom du programme) de la ligne de commande
; NeoDOS dans argbuf (pstring) ; argbuf vide si absent ou hors NeoDOS
cmd_arg         sta     cnt
                stz     argbuf
                lda     NEODOS_SIG
                cmp     #'N'
                bne     _done
                lda     NEODOS_SIG+1
                cmp     #'E'
                bne     _done
                lda     NEODOS_CMDLINE
                sta     ptr
                lda     NEODOS_CMDLINE+1
                sta     ptr+1
                ldy     #1
_skip           tya                             ; sauter les espaces
                cmp     (ptr)
                beq     +
                bcs     _done
+               lda     (ptr),y
                cmp     #' '
                bne     _word
                iny
                bra     _skip
_word           lda     cnt
                beq     _copy
                dec     cnt
-               tya                             ; sauter ce mot
                cmp     (ptr)
                beq     +
                bcs     _done
+               lda     (ptr),y
                cmp     #' '
                beq     _skip
                iny
                bra     -
_copy           ldx     #0
-               tya
                cmp     (ptr)
                beq     +
                bcs     _end
+               lda     (ptr),y
                cmp     #' '
                beq     _end
                cmp     #'\'
                bne     +
                lda     #'/'
+               inx
                sta     argbuf,x
                iny
                cpx     #120
                bne     -
_end            stx     argbuf
_done           rts
