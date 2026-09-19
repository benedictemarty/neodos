; smash.asm — programme de test : écrase toute la zone de NeoDOS ($C000-$FBFF,
; comme le ferait la pile C de llvm-mos ou un gros programme) puis rend la
; main par RTS. NeoDOS doit se recharger depuis /boot/neodos.neo.
WriteCharacter  = $FFF1
WaitMessage     = $FFF4
                * = $0800
                ldx     #0
-               lda     msg,x
                beq     +
                jsr     WriteCharacter
                jsr     WaitMessage
                inx
                bra     -
+               lda     #$C0
                sta     $81
                stz     $80
                ldy     #0
                lda     #0
-               sta     ($80),y
                iny
                bne     -
                inc     $81
                lda     $81
                cmp     #$FC
                bne     -
                rts
msg             .text   "Smashing $C000-$FBFF...", 13, 0
