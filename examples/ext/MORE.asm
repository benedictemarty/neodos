; more.asm — commande externe NeoDOS : MORE fichier — affiche un fichier
; texte page par page (« -- More -- », touche : page suivante, Q : quitter).
;   make examples  ->  storage/BIN/MORE.NEO
ptr             = $80
sptr            = $82
cnt             = $84
lines           = $85
prevcr          = $86
PAGE_LINES      = 28
                * = $0800
                jmp     main
                .include "neoext.inc"

main            lda     #1
                jsr     cmd_arg                 ; argbuf = fichier
                lda     argbuf
                bne     _open
                jsr     fail
                #println "Usage: MORE file"
                rts
_open           stz     DParams                 ; canal 0, lecture seule
                #setparam 1, argbuf
                stz     DParams+3
                #api    3,4
                lda     DError
                beq     +
                jsr     fail
                #println "File not found"
                rts
+               stz     lines
                stz     prevcr
_block          stz     DParams
                #setparam 1, iobuf
                stz     DParams+3
                lda     #1
                sta     DParams+4               ; 256 octets
                #api    3,8
                lda     DError
                bne     _close
                lda     DParams+3
                ora     DParams+4
                beq     _close
                lda     DParams+3
                sta     cnt
                ldx     #0
_char           lda     iobuf,x
                cmp     #10
                bne     +
                lda     prevcr                  ; LF après CR : ignoré
                bne     _skip
                lda     #CR
+               cmp     #CR
                beq     _cr
                cmp     #9
                bne     +
                lda     #' '
+               cmp     #32
                bcc     _skip
                stz     prevcr
                jsr     putc
                bra     _skip
_cr             jsr     putc
                lda     #1
                sta     prevcr
                inc     lines
                lda     lines
                cmp     #PAGE_LINES
                bcc     _skip
                stz     lines
                #print  "-- More --"
                jsr     getkey
                pha
                lda     #CR
                jsr     putc
                pla
                and     #$DF
                cmp     #'Q'
                beq     _close
_skip           inx
                dec     cnt
                bne     _char
                jmp     _block
_close          stz     DParams
                #api    3,5
                lda     prevcr
                bne     +
                jsr     newline
+               rts

argbuf          .fill   122
iobuf           .fill   256
