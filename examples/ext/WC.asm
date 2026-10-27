; WC.asm — commande externe NeoDOS : WC fichier — nombre de lignes, de mots
; et d'octets du fichier (compteurs 32 bits), puis son nom, comme wc Unix :
; «       6       7      41 FRUITS.TXT ». Une ligne se termine par CR LF, LF
; ou CR ; une dernière ligne sans fin de ligne compte. Un mot est une suite
; de caractères au-dessus de l'espace. Suit la redirection « > ».
; ERRORLEVEL 1 si le fichier est absent ou la ligne de commande incorrecte.
;   make examples  ->  storage/BIN/WC.NEO
ptr             = $80
sptr            = $82
cnt             = $84
rptr            = $86
rend            = $88
prevcr          = $8A
nlines          = $8B           ; (tf_args) non utilisé
inword          = $8D
last            = $8E
tmp             = $8F
                * = $0800
                jmp     main
                .include "neoext.inc"
                .include "textfile.inc"

main            lda     #1
                jsr     cmd_arg
                lda     argbuf+1                ; pas d'option
                cmp     #'/'
                beq     _usage
                jsr     tf_args
                bcc     +
_usage          jsr     fail
                #println "Usage: WC file"
                rts
+               jsr     tf_open
                bcc     +
                rts
+               ldx     #11                     ; compteurs à zéro
-               stz     counts,x
                dex
                bpl     -
                stz     inword
                lda     #CR
                sta     last
_byte           jsr     tf_byte
                bcs     _end
                sta     last
                ldx     #8                      ; octets
                jsr     inc32
                lda     last
                cmp     #CR
                beq     _cr
                cmp     #10
                beq     _lf
                stz     prevcr
                cmp     #' '+1
                bcc     _space
                lda     inword                  ; début de mot ?
                bne     _byte
                inc     inword
                ldx     #4                      ; mots
                jsr     inc32
                bra     _byte
_cr             lda     #1
                sta     prevcr
                bra     _nl
_lf             lda     prevcr                  ; LF après CR : même ligne
                stz     prevcr
                bne     _space
_nl             ldx     #0                      ; lignes
                jsr     inc32
_space          stz     inword
                bra     _byte
_end            lda     last                    ; dernière ligne sans fin
                cmp     #CR
                beq     +
                cmp     #10
                beq     +
                ldx     #0
                jsr     inc32
+               jsr     tf_close
                ldx     #0
                jsr     print32
                ldx     #4
                jsr     print32
                ldx     #8
                jsr     print32
                lda     #' '
                jsr     putc
                ldx     #1                      ; nom, « / » rendus en « \ »
_name           cpx     filebuf
                beq     +
                bcs     _eol
+               lda     filebuf,x
                cmp     #'/'
                bne     +
                lda     #'\'
+               jsr     putc
                inx
                bra     _name
_eol            jmp     newline

; inc32 : counts+X (32 bits) += 1
inc32           inc     counts,x
                bne     +
                inc     counts+1,x
                bne     +
                inc     counts+2,x
                bne     +
                inc     counts+3,x
+               rts

; print32 : counts+X (32 bits) en décimal, cadré à droite sur 8 colonnes
print32         ldy     #3                      ; copie de travail
-               lda     counts,x
                sta     num,y
                inx
                dey
                bpl     -
                ldy     #0                      ; chiffres, du plus fort
_pow            lda     #0
                sta     digits,y
_sub            tya                             ; num >= 10^(9-y) ?
                asl     a
                asl     a
                tax
                lda     num+3
                cmp     pow10+3,x
                lda     num+2
                sbc     pow10+2,x
                lda     num+1
                sbc     pow10+1,x
                lda     num
                sbc     pow10,x
                bcc     _next
                lda     num+3
                sbc     pow10+3,x
                sta     num+3
                lda     num+2
                sbc     pow10+2,x
                sta     num+2
                lda     num+1
                sbc     pow10+1,x
                sta     num+1
                lda     num
                sbc     pow10,x
                sta     num
                lda     digits,y
                inc     a
                sta     digits,y
                bra     _sub
_next           iny
                cpy     #10
                bne     _pow
                ldy     #0                      ; zéros de tête -> espaces
-               lda     digits,y
                bne     +
                cpy     #9
                beq     +
                lda     #' '
                sta     digits,y
                iny
                bra     -
+               cpy     #2                      ; 8 colonnes (chiffres 2-9),
                bcc     +                       ; plus si le nombre l'exige
                ldy     #2
+
-               lda     digits,y
                cmp     #' '
                beq     +
                ora     #'0'
+               jsr     putc
                iny
                cpy     #10
                bne     -
                rts
; puissances de 10, octet fort en premier (num aussi)
pow10           .byte   $3B,$9A,$CA,$00, $05,$F5,$E1,$00, $00,$98,$96,$80
                .byte   $00,$0F,$42,$40, $00,$01,$86,$A0, $00,$00,$27,$10
                .byte   $00,$00,$03,$E8, $00,$00,$00,$64, $00,$00,$00,$0A
                .byte   $00,$00,$00,$01
num             .fill   4
digits          .fill   10
counts          .fill   12                      ; lignes, mots, octets
argbuf          .fill   122
filebuf         .fill   122
