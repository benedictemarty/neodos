; hello.asm — programme d'exemple pour NeoDOS : affiche un message et rend
; la main à l'invite (RTS). Chargé en $0800 par « HELLO » depuis NeoDOS.
;   64tass --mw65c02 --nostart -o hello.bin hello.asm
;   python3 tools/mkneo.py hello.bin HELLO.NEO 0800 0800 "Hello"
WriteCharacter  = $FFF1
WaitMessage     = $FFF4
                * = $0800
                ldx     #0
_loop           lda     msg,x
                beq     _done
                jsr     WriteCharacter
                jsr     WaitMessage
                inx
                bra     _loop
_done           rts
msg             .text   "Hello from a NeoDOS program!", 13, 0
