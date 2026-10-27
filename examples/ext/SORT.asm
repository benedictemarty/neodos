; SORT.asm — commande externe NeoDOS : SORT [/R] fichier — affiche les lignes
; triées (ordre ASCII, majuscules/minuscules confondues ; /R : décroissant).
; Le fichier est chargé entier en $2000 (37 Ko max), la table des lignes
; (2 048 max) en $1000. Tri de Shell sur la table de pointeurs.
;   make examples  ->  storage/BIN/SORT.NEO
ptr             = $80
sptr            = $82
cnt             = $84
reverse         = $85
nlines          = $86           ; 16 bits
gap             = $88           ; 16 bits
i               = $8A
j               = $8C
ptr2            = $8E
ptr3            = $90
tmp             = $92
ea              = $94
eb              = $96
TABLE           = $1000
TEXT            = $2000
TEXT_MAX        = $B700-TEXT
                * = $0800
                jmp     main
                .include "neoext.inc"

main            stz     reverse
                stz     filebuf
                lda     #1
                jsr     cmd_arg
                jsr     take_arg
                lda     #2
                jsr     cmd_arg
                jsr     take_arg
                lda     filebuf
                bne     _stat
                jsr     fail
                #println "Usage: SORT [/R] file"
                rts
_stat           #setparam 0, filebuf
                #api    3,16
                lda     DError
                beq     +
                jsr     fail
                #println "File not found"
                rts
+               lda     DParams+2               ; taille > 40 Ko ?
                ora     DParams+3
                bne     _big
                lda     DParams+1
                cmp     #>TEXT_MAX
                bcc     _load
                bne     _big
                lda     DParams
                cmp     #<TEXT_MAX
                bcc     _load
_big            jsr     fail
                #println "File too large (37 KB max)"
                rts
_load           lda     DParams                 ; fin du texte -> ptr3
                clc
                adc     #<TEXT
                sta     ptr3
                lda     DParams+1
                adc     #>TEXT
                sta     ptr3+1
                #setparam 0, filebuf
                #setparam 2, TEXT
                #api    3,2
                lda     DError
                beq     +
                #println "Read error"
                rts
+               jsr     split_lines
                jsr     shell_sort
                jsr     output
                rts

take_arg        lda     argbuf
                beq     _r
                cmp     #2
                bne     _file
                lda     argbuf+1
                cmp     #'/'
                bne     _file
                lda     argbuf+2
                and     #$DF
                cmp     #'R'
                bne     _r
                lda     #1
                sta     reverse
                rts
_file           lda     filebuf
                bne     _r
                ldx     argbuf
-               lda     argbuf,x
                sta     filebuf,x
                dex
                bpl     -
_r              rts

; split_lines : remplace CR/LF par 0, table des débuts de ligne (nlines)
split_lines     stz     nlines
                stz     nlines+1
                lda     #<TEXT
                sta     ptr
                lda     #>TEXT
                sta     ptr+1
                lda     #<TABLE
                sta     ptr2
                lda     #>TABLE
                sta     ptr2+1
_line           lda     ptr                     ; fin du texte ?
                cmp     ptr3
                lda     ptr+1
                sbc     ptr3+1
                bcs     _done
                lda     nlines+1                ; 2 048 lignes max
                cmp     #8
                bcs     _done
                lda     ptr                     ; table[n] = ptr
                sta     (ptr2)
                ldy     #1
                lda     ptr+1
                sta     (ptr2),y
                inc     ptr2
                inc     ptr2
                inc     nlines
                bne     +
                inc     nlines+1
+               ldy     #0
_scan           lda     ptr                     ; cherche CR ou LF ou fin
                cmp     ptr3
                lda     ptr+1
                sbc     ptr3+1
                bcs     _done
                lda     (ptr)
                cmp     #CR
                beq     _eol
                cmp     #10
                beq     _eol
                inc     ptr
                bne     _scan
                inc     ptr+1
                bra     _scan
_eol            lda     #0
                sta     (ptr)
                inc     ptr
                bne     +
                inc     ptr+1
+               lda     ptr                     ; LF après CR ?
                cmp     ptr3
                lda     ptr+1
                sbc     ptr3+1
                bcs     _line
                lda     (ptr)
                cmp     #10
                bne     _line
                lda     #0
                sta     (ptr)
                inc     ptr
                bne     _line
                inc     ptr+1
                bra     _line
_done           rts

; shell_sort : tri de la table (pas 1 750, 701, 301, 132, 57, 23, 10, 4, 1)
shell_sort      ldx     #0
_gap            lda     gaps,x
                sta     gap
                lda     gaps+1,x
                sta     gap+1
                ora     gap
                beq     _end
                stx     tmp
                ; for i = gap ; i < n ; i++
                lda     gap
                sta     i
                lda     gap+1
                sta     i+1
_i              lda     i
                cmp     nlines
                lda     i+1
                sbc     nlines+1
                bcs     _nextgap
                ; j = i ; while j >= gap and t[j-gap] > t[j] : swap ; j -= gap
                lda     i
                sta     j
                lda     i+1
                sta     j+1
_j              lda     j
                cmp     gap
                lda     j+1
                sbc     gap+1
                bcc     _nexti
                jsr     compare_jgap            ; C=1 si t[j-gap] > t[j]
                bcc     _nexti
                jsr     swap_jgap
                lda     j
                sec
                sbc     gap
                sta     j
                lda     j+1
                sbc     gap+1
                sta     j+1
                bra     _j
_nexti          inc     i
                bne     _i
                inc     i+1
                bra     _i
_nextgap        ldx     tmp
                inx
                inx
                bra     _gap
_end            rts
gaps            .word   1750, 701, 301, 132, 57, 23, 10, 4, 1, 0

; entry_addr : A/Y = index (bas/haut) -> ptr = adresse de l'entrée de table
entry_addr      asl     a
                sta     ptr
                tya
                rol     a
                clc
                adc     #>TABLE
                sta     ptr+1
                rts
; load_jgap : ptr2 = t[j-gap], ptr3sv... -> ptr2 = ligne j-gap, ptr = entrée
lines_jgap      lda     j
                sec
                sbc     gap
                pha
                lda     j+1
                sbc     gap+1
                tay
                pla
                jsr     entry_addr
                lda     ptr                     ; sauve l'adresse d'entrée
                sta     ea
                lda     ptr+1
                sta     ea+1
                lda     (ptr)
                sta     ptr2
                ldy     #1
                lda     (ptr),y
                sta     ptr2+1
                lda     j
                ldy     j+1
                jsr     entry_addr
                lda     ptr
                sta     eb
                lda     ptr+1
                sta     eb+1
                lda     (ptr)
                sta     ptr3
                ldy     #1
                lda     (ptr),y
                sta     ptr3+1
                rts
; compare_jgap : C=1 si ligne(j-gap) > ligne(j) (ordre voulu : croissant,
; ou décroissant avec /R)
compare_jgap    jsr     lines_jgap
                ldy     #0
_cmp            lda     (ptr2),y
                jsr     fold
                sta     tmp+1
                lda     (ptr3),y
                jsr     fold
                cmp     tmp+1
                bne     _diff
                lda     tmp+1
                beq     _equal                  ; fin des deux lignes
                iny
                bne     _cmp
                inc     ptr2+1
                inc     ptr3+1
                bra     _cmp
_diff           ; C=1 si (ptr3) >= (ptr2) ici (cmp b,a) ; on veut a > b
                bcs     _le                     ; b >= a -> a <= b
                lda     reverse
                bne     _no
_yes            sec
                rts
_le             lda     reverse
                beq     _no
                bra     _yes
_equal
_no             clc
                rts
fold            cmp     #'a'
                bcc     _r
                cmp     #'z'+1
                bcs     _r
                and     #$DF
_r              rts
; swap_jgap : échange les entrées ea et eb
swap_jgap       ldy     #1
-               lda     (ea),y
                pha
                lda     (eb),y
                sta     (ea),y
                pla
                sta     (eb),y
                dey
                bpl     -
                rts

; output : lignes dans l'ordre de la table
output          lda     #<TABLE
                sta     ptr2
                lda     #>TABLE
                sta     ptr2+1
                lda     nlines
                sta     i
                lda     nlines+1
                sta     i+1
_next           lda     i
                ora     i+1
                beq     _done
                lda     (ptr2)
                sta     ptr
                ldy     #1
                lda     (ptr2),y
                sta     ptr+1
                ldy     #0
-               lda     (ptr),y
                beq     +
                jsr     putc
                iny
                bne     -
                inc     ptr+1
                bra     -
+               jsr     newline
                inc     ptr2
                inc     ptr2
                lda     i
                bne     +
                dec     i+1
+               dec     i
                bra     _next
_done           rts

argbuf          .fill   122
filebuf         .fill   122
