; FIND.asm — commande externe NeoDOS : FIND [/I] [/N] [/C] [/V] "texte" fichier
; Affiche les lignes du fichier contenant le texte (/I : casse ignorée,
; /N : numéros de ligne, /C : seulement le nombre, /V : lignes ne contenant
; pas le texte). Le texte peut être entre guillemets (espaces permis).
;   make examples  ->  storage/BIN/FIND.NEO
ptr             = $80
sptr            = $82
cnt             = $84
flags           = $85           ; bit0 /I, bit1 /N, bit2 /C, bit3 /V
llen            = $86
lineno          = $88           ; 16 bits
matches         = $8A           ; 16 bits
prevcr          = $8C
ptr2            = $8E
lastpos         = $90           ; line_matches : dernière position de départ
                * = $0800
                jmp     main
                .include "neoext.inc"

main            stz     flags
                stz     pattern
                stz     filebuf
                jsr     parse_cmdline
                lda     pattern
                beq     _usage
                lda     filebuf
                bne     _open
_usage          #println "Usage: FIND [/I] [/N] [/C] [/V] 'text' file"
                rts
_open           stz     DParams
                #setparam 1, filebuf
                stz     DParams+3
                #api    3,4
                lda     DError
                beq     +
                #println "File not found"
                rts
+               stz     lineno
                stz     lineno+1
                stz     matches
                stz     matches+1
                stz     llen
                stz     prevcr
_block          stz     DParams
                #setparam 1, iobuf
                stz     DParams+3
                lda     #1
                sta     DParams+4
                #api    3,8
                lda     DError
                bne     _eof
                lda     DParams+3
                ora     DParams+4
                beq     _eof
                lda     DParams+3
                sta     cnt
                ldx     #0
_char           lda     iobuf,x
                cmp     #10
                bne     +
                lda     prevcr
                bne     _skipc                  ; LF après CR
                lda     #CR
+               stz     prevcr
                cmp     #CR
                bne     _add
                lda     #1
                sta     prevcr
                jsr     end_line
                bra     _skipc
_add            ldy     llen
                cpy     #200
                bcs     _skipc
                sta     linebuf,y
                inc     llen
_skipc          inx
                dec     cnt
                bne     _char
                jmp     _block
_eof            lda     llen                    ; dernière ligne sans CR
                beq     +
                jsr     end_line
+               stz     DParams
                #api    3,5
                lda     flags
                and     #4
                beq     _done
                lda     matches
                ldy     matches+1
                jsr     print16
                jsr     newline
_done           rts

; end_line : ligne complète dans linebuf (llen) : test et affichage
end_line        phx                             ; (X = index du bloc)
                inc     lineno
                bne     +
                inc     lineno+1
+               jsr     line_matches            ; C=1 si le texte est présent
                lda     #0
                rol     a                       ; A = 1 si présent
                pha
                lda     flags
                and     #8                      ; /V : inverse
                beq     +
                pla
                eor     #1
                pha
+               pla
                beq     _no
                inc     matches
                bne     +
                inc     matches+1
+               lda     flags
                and     #4                      ; /C : pas d'affichage
                bne     _no
                lda     flags
                and     #2
                beq     +
                lda     #'['                    ; /N : « [n] »
                jsr     putc
                lda     lineno
                ldy     lineno+1
                jsr     print16
                lda     #']'
                jsr     putc
+               ldy     #0
-               cpy     llen
                bcs     +
                lda     linebuf,y
                jsr     putc
                iny
                bra     -
+               jsr     newline
_no             stz     llen
                plx
                rts

; line_matches : C=1 si pattern (pstring) apparaît dans linebuf[0..llen)
line_matches    lda     pattern
                beq     _yes
                cmp     llen
                beq     +
                bcs     _no                     ; motif plus long que la ligne
+               lda     llen
                sec
                sbc     pattern                 ; dernière position de départ
                sta     lastpos
                ldx     #0                      ; X = position de départ
_start          ldy     #0
_cmp            lda     linebuf,x
                jsr     fold
                sta     ptr
                lda     pattern+1,y
                jsr     fold
                cmp     ptr
                bne     _next
                inx
                iny
                cpy     pattern
                bne     _cmp
_yes            sec
                rts
_next           txa                             ; X = départ + Y : revenir
                sty     ptr
                sec
                sbc     ptr
                tax
                inx
                cpx     lastpos
                beq     _start
                bcc     _start
_no             clc
                rts

; fold : majuscule si /I
fold            pha
                lda     flags
                and     #1
                beq     _asis
                pla
                cmp     #'a'
                bcc     _r
                cmp     #'z'+1
                bcs     _r
                and     #$DF
_r              rts
_asis           pla
                rts

; parse_cmdline : ligne NeoDOS -> flags, pattern (guillemets ou mot), filebuf
parse_cmdline   lda     NEODOS_SIG
                cmp     #'N'
                beq     +
_jr             rts
+               lda     NEODOS_CMDLINE
                sta     ptr2
                lda     NEODOS_CMDLINE+1
                sta     ptr2+1
                ldy     #1                      ; saute le nom du programme
-               tya
                cmp     (ptr2)
                beq     +
                bcs     _jr
+               lda     (ptr2),y
                iny
                cmp     #' '
                bne     -
_word           tya                             ; espaces
                cmp     (ptr2)
                beq     +
                bcs     _jr
+               lda     (ptr2),y
                cmp     #' '
                bne     +
                iny
                bra     _word
+               cmp     #'/'
                beq     _switch
                cmp     #'"'
                beq     _quoted
                lda     pattern                 ; mot : motif puis fichier
                bne     _file
                ldx     #0
-               tya
                cmp     (ptr2)
                beq     +
                bcs     _pend
+               lda     (ptr2),y
                cmp     #' '
                beq     _pend
                inx
                sta     pattern,x
                iny
                bra     -
_pend           stx     pattern
                bra     _word
_quoted         iny
                ldx     #0
-               tya
                cmp     (ptr2)
                beq     +
                bcs     _qend
+               lda     (ptr2),y
                iny
                cmp     #'"'
                beq     _qend
                inx
                sta     pattern,x
                bra     -
_qend           stx     pattern
                bra     _word
_switch         iny
                lda     (ptr2),y
                iny
                and     #$DF
                ldx     #1
                cmp     #'I'
                beq     _set
                ldx     #2
                cmp     #'N'
                beq     _set
                ldx     #4
                cmp     #'C'
                beq     _set
                ldx     #8
                cmp     #'V'
                beq     _set
                bra     _word
_set            txa
                ora     flags
                sta     flags
                bra     _word
_file           ldx     #0
-               tya
                cmp     (ptr2)
                beq     +
                bcs     _fend
+               lda     (ptr2),y
                cmp     #' '
                beq     _fend
                cmp     #'\'
                bne     +
                lda     #'/'
+               inx
                sta     filebuf,x
                iny
                bra     -
_fend           stx     filebuf
                jmp     _word
_r              rts

; print16 : A (bas) Y (haut) en décimal
print16         sta     num
                sty     num+1
                ldy     #0
_pow            lda     #0
                sta     digits,y
-               lda     num
                cmp     pow10lo,y
                lda     num+1
                sbc     pow10hi,y
                bcc     +
                lda     num
                sbc     pow10lo,y
                sta     num
                lda     num+1
                sbc     pow10hi,y
                sta     num+1
                phy
                tya
                tax
                inc     digits,x
                ply
                bra     -
+               iny
                cpy     #5
                bne     _pow
                ldy     #0
_lead           lda     digits,y
                bne     _out
                iny
                cpy     #4
                bne     _lead
_out            lda     digits,y
                ora     #'0'
                jsr     putc
                iny
                cpy     #5
                bne     _out
                rts
pow10lo         .byte   <10000, <1000, <100, <10, <1
pow10hi         .byte   >10000, >1000, >100, >10, >1
num             .fill   2
digits          .fill   5
argbuf          .fill   122
pattern         .fill   122
filebuf         .fill   122
linebuf         .fill   200
iobuf           .fill   256
