; EDIT.asm — commande externe NeoDOS : EDIT fichier — éditeur de texte plein
; écran (53x30 : 1 ligne d'état, 28 lignes de texte, 1 ligne d'aide).
; Texte en mémoire ($2000-$B5FF, lignes terminées par CR ; CR/LF converti au
; chargement, réécrit à la sauvegarde). Touches : flèches, Début/Fin,
; PgUp/PgDn, caractères (insertion), Retour arrière, Suppr, Entrée,
; Échap = menu (S sauver, X sauver et quitter, Q quitter sans sauver).
;   make examples  ->  storage/BIN/EDIT.NEO
ptr             = $80
sptr            = $82
cnt             = $84
cur             = $86           ; position du curseur (pointeur dans le texte)
tend            = $88           ; fin du texte (exclue)
top             = $8A           ; première ligne affichée
lstart          = $8C           ; début de la ligne du curseur
tmp             = $8E
row             = $90           ; ligne d'écran du curseur (0-27)
col             = $91
dirty           = $92
key             = $93
ptr2            = $94
wantcol         = $96           ; colonne souhaitée (déplacements verticaux)
TEXT            = $2000
TEXT_END        = $B600         ; limite (les CR/LF de sauvegarde ont besoin de marge)
ROWS            = 28
COLS            = 53
CC_LEFT         = 1
CC_RIGHT        = 4
CC_PGDN         = 6
CC_END          = 7
CC_BS           = 8
CC_PGUP         = 18
CC_DOWN         = 19
CC_HOME         = 20
CC_UP           = 23
CC_REV          = 24
CC_DEL          = 26
CC_ESC          = 27
                * = $0800
                jmp     main
                .include "neoext.inc"

main            lda     #1
                jsr     cmd_arg
                lda     argbuf
                bne     +
                jsr     fail
                #println "Usage: EDIT file"
                rts
+               ldx     argbuf
-               lda     argbuf,x
                sta     filebuf,x
                dex
                bpl     -
                jsr     load_file
                bcs     _exit
                stz     dirty
                lda     #<TEXT
                sta     cur
                sta     top
                sta     lstart
                lda     #>TEXT
                sta     cur+1
                sta     top+1
                sta     lstart+1
                stz     col
                stz     wantcol
                #api    2,12                    ; CLS
_loop           jsr     draw_all
                jsr     getkey
                sta     key
                jsr     handle_key
                bcc     _loop
_exit           #api    2,12
                rts

; ---------------------------------------------------------------------------
; Fichier
; ---------------------------------------------------------------------------
; load_file : charge filebuf en TEXT (CR/LF -> CR) ; fichier absent = vide
load_file       lda     #<TEXT
                sta     tend
                lda     #>TEXT
                sta     tend+1
                #setparam 0, filebuf
                #api    3,16
                lda     DError
                bne     _new                    ; nouveau fichier
                lda     DParams+2
                ora     DParams+3
                bne     _big
                lda     DParams+1
                cmp     #>(TEXT_END-TEXT-256)
                bcs     _big
                #setparam 0, filebuf
                #setparam 2, TEXT
                #api    3,2
                lda     DError
                bne     _big
                ; tend = TEXT + taille, puis compaction CR/LF -> CR
                #setparam 0, filebuf
                #api    3,16
                lda     DParams
                clc
                adc     #<TEXT
                sta     tend
                lda     DParams+1
                adc     #>TEXT
                sta     tend+1
                jsr     strip_lf
_new            clc
                rts
_big            jsr     fail
                #println "File too large or unreadable"
                sec
                rts

; strip_lf : CR LF -> CR, LF seul -> CR (source ptr, destination ptr2)
strip_lf        lda     #<TEXT
                sta     ptr
                sta     ptr2
                lda     #>TEXT
                sta     ptr+1
                sta     ptr2+1
                stz     tmp                     ; dernier caractère = CR ?
_loop           lda     ptr
                cmp     tend
                lda     ptr+1
                sbc     tend+1
                bcs     _done
                lda     (ptr)
                cmp     #10
                bne     _keep
                lda     tmp                     ; LF après CR : ignoré
                bne     _skip
                lda     #CR                     ; LF seul : CR
_keep           sta     (ptr2)
                inc     ptr2
                bne     +
                inc     ptr2+1
+               cmp     #CR
                beq     +
                stz     tmp
                bra     _skip
+               lda     #1
                sta     tmp
_skip           inc     ptr
                bne     _loop
                inc     ptr+1
                bra     _loop
_done           lda     ptr2
                sta     tend
                lda     ptr2+1
                sta     tend+1
                rts

; save_file : écrit le texte avec CR/LF (expansion en place vers le haut,
; puis compaction) ; C=1 si erreur
save_file       ; compte les CR -> cnt16
                stz     cnt16
                stz     cnt16+1
                lda     #<TEXT
                sta     ptr
                lda     #>TEXT
                sta     ptr+1
_count          lda     ptr
                cmp     tend
                lda     ptr+1
                sbc     tend+1
                bcs     _expand
                lda     (ptr)
                cmp     #CR
                bne     +
                inc     cnt16
                bne     +
                inc     cnt16+1
+               inc     ptr
                bne     _count
                inc     ptr+1
                bra     _count
_expand         ; ptr2 = tend + cnt16 (nouvelle fin) ; recopie à reculons
                lda     tend
                clc
                adc     cnt16
                sta     ptr2
                lda     tend+1
                adc     cnt16+1
                sta     ptr2+1
                lda     ptr2                    ; sauvegarde de la taille finale
                sec
                sbc     #<TEXT
                sta     size16
                lda     ptr2+1
                sbc     #>TEXT
                sta     size16+1
                lda     tend
                sta     ptr
                lda     tend+1
                sta     ptr+1
_back           lda     ptr                     ; ptr == TEXT ? fini
                cmp     #<TEXT
                bne     +
                lda     ptr+1
                cmp     #>TEXT
                beq     _store
+               jsr     dec_ptr
                jsr     dec_ptr2
                lda     (ptr)
                cmp     #CR
                bne     +
                lda     #10
                sta     (ptr2)
                jsr     dec_ptr2
                lda     #CR
+               sta     (ptr2)
                bra     _back
_store          #setparam 0, filebuf
                #setparam 2, TEXT
                lda     size16
                sta     DParams+4
                lda     size16+1
                sta     DParams+5
                #api    3,3
                lda     DError
                pha
                ; recompacte (tend inchangé : on repart de la taille étendue)
                lda     size16
                clc
                adc     #<TEXT
                sta     tend
                lda     size16+1
                adc     #>TEXT
                sta     tend+1
                jsr     strip_lf
                pla
                beq     _ok
                sec
                rts
_ok             stz     dirty
                clc
                rts
dec_ptr         lda     ptr
                bne     +
                dec     ptr+1
+               dec     ptr
                rts
dec_ptr2        lda     ptr2
                bne     +
                dec     ptr2+1
+               dec     ptr2
                rts

; ---------------------------------------------------------------------------
; Affichage
; ---------------------------------------------------------------------------
; draw_all : ligne d'état, ROWS lignes depuis top, ligne d'aide, curseur
draw_all        jsr     find_lstart
                jsr     adjust_top
                ; ligne d'état
                ldx     #0
                ldy     #0
                jsr     set_cursor
                #print  "EDIT "
                lda     #<filebuf
                sta     ptr
                lda     #>filebuf
                sta     ptr+1
                jsr     putpstr
                lda     dirty
                beq     +
                lda     #'*'
                jsr     putc
+               jsr     pad_line
                ; texte
                lda     top
                sta     ptr
                lda     top+1
                sta     ptr+1
                lda     #1
                sta     tmp                     ; rangée
_row            ldx     #0
                ldy     tmp
                jsr     set_cursor
                stz     tmp+1                   ; colonne
_ch             lda     ptr
                cmp     tend
                lda     ptr+1
                sbc     tend+1
                bcs     _eol                    ; fin du texte
                lda     (ptr)
                cmp     #CR
                beq     _eolcr
                ldx     tmp+1
                cpx     #COLS-1
                bcs     _skipc                  ; ligne trop longue : coupée
                jsr     putc
                inc     tmp+1
_skipc          inc     ptr
                bne     _ch
                inc     ptr+1
                bra     _ch
_eolcr          inc     ptr
                bne     _eol
                inc     ptr+1
_eol            jsr     pad_line
                inc     tmp
                lda     tmp
                cmp     #ROWS+1
                bcc     _row
                ; aide
                ldx     #0
                ldy     #ROWS+1
                jsr     set_cursor
                #print  "Esc=menu  Ln "
                jsr     cur_line_no
                jsr     pad_line
                ; curseur : rangée row+1, colonne col
                lda     col
                cmp     #COLS-1
                bcc     +
                lda     #COLS-1
+               tax
                ldy     row
                iny
                jsr     set_cursor
                lda     #CC_REV
                jmp     putc

; pad_line : espaces jusqu'à la fin de la ligne (colonne tmp+1 -> COLS)
pad_line        #api    2,13                    ; Cursor Position -> P0 = x
                lda     DParams
                cmp     #COLS-1
                bcs     _last
                sta     tmp+1
_sp             lda     #' '
                jsr     putc
                inc     tmp+1
                lda     tmp+1
                cmp     #COLS-1
                bcc     _sp
_last           rts

; set_cursor : X = colonne, Y = rangée
set_cursor      stx     DParams
                sty     DParams+1
                #api    2,7
                rts

; cur_line_no : numéro de la ligne du curseur (1-based)
cur_line_no     lda     #1
                sta     cnt16
                stz     cnt16+1
                lda     #<TEXT
                sta     ptr
                lda     #>TEXT
                sta     ptr+1
_loop           lda     ptr
                cmp     lstart
                lda     ptr+1
                sbc     lstart+1
                bcs     _done
                lda     (ptr)
                cmp     #CR
                bne     +
                inc     cnt16
                bne     +
                inc     cnt16+1
+               inc     ptr
                bne     _loop
                inc     ptr+1
                bra     _loop
_done           lda     cnt16
                ldy     cnt16+1
                jmp     print16

; find_lstart : lstart = début de la ligne contenant cur ; col = cur - lstart
find_lstart     lda     cur
                sta     lstart
                lda     cur+1
                sta     lstart+1
                stz     col
_loop           lda     lstart                  ; == TEXT ?
                cmp     #<TEXT
                bne     +
                lda     lstart+1
                cmp     #>TEXT
                beq     _done
+               lda     lstart                  ; caractère précédent = CR ?
                bne     +
                dec     lstart+1
+               dec     lstart
                lda     (lstart)
                cmp     #CR
                bne     +
                inc     lstart
                bne     _done
                inc     lstart+1
                bra     _done
+               inc     col
                bra     _loop
_done           rts

; adjust_top : row = rangée de lstart depuis top ; fait défiler si hors écran
adjust_top      ; lstart < top ? -> top = lstart
                lda     lstart
                cmp     top
                lda     lstart+1
                sbc     top+1
                bcs     _count
                lda     lstart
                sta     top
                lda     lstart+1
                sta     top+1
_count          ; row = nombre de CR entre top et lstart
                stz     row
                lda     top
                sta     ptr
                lda     top+1
                sta     ptr+1
_loop           lda     ptr
                cmp     lstart
                lda     ptr+1
                sbc     lstart+1
                bcs     _check
                lda     (ptr)
                cmp     #CR
                bne     +
                inc     row
+               inc     ptr
                bne     _loop
                inc     ptr+1
                bra     _loop
_check          lda     row
                cmp     #ROWS
                bcc     _ok
                ; trop bas : top avance d'une ligne, on recompte
                jsr     top_next_line
                bra     _count
_ok             rts

; top_next_line : top = début de la ligne suivante
top_next_line   lda     top
                sta     ptr
                lda     top+1
                sta     ptr+1
-               lda     ptr
                cmp     tend
                lda     ptr+1
                sbc     tend+1
                bcs     _done
                lda     (ptr)
                inc     ptr
                bne     +
                inc     ptr+1
+               cmp     #CR
                bne     -
_done           lda     ptr
                sta     top
                lda     ptr+1
                sta     top+1
                rts

; ---------------------------------------------------------------------------
; Touches
; ---------------------------------------------------------------------------
; handle_key : C=1 pour quitter
handle_key      lda     key
                cmp     #CC_ESC
                bne     +
                jmp     menu
+               cmp     #CC_LEFT
                beq     _left
                cmp     #CC_RIGHT
                beq     _right
                cmp     #CC_UP
                beq     _up
                cmp     #CC_DOWN
                beq     _down
                cmp     #CC_HOME
                beq     _home
                cmp     #CC_END
                beq     _end
                cmp     #CC_PGUP
                beq     _pgup
                cmp     #CC_PGDN
                beq     _pgdn
                cmp     #CC_BS
                beq     _bs
                cmp     #CC_DEL
                beq     _del
                cmp     #CR
                beq     _ins
                cmp     #9
                beq     _tab
                cmp     #' '
                bcc     _none
                cmp     #127
                bcs     _none
_ins            jsr     insert_char
                jsr     find_lstart
                lda     col
                sta     wantcol
_none           clc
                rts
_tab            lda     #' '
                sta     key
                bra     _ins
_left           jsr     cur_dec
                bra     _setcol
_right          jsr     cur_inc
                bra     _setcol
_home           jsr     find_lstart
                lda     lstart
                sta     cur
                lda     lstart+1
                sta     cur+1
                bra     _setcol
_end            jsr     goto_eol
_setcol         jsr     find_lstart
                lda     col
                sta     wantcol
                clc
                rts
_up             jsr     line_up
                clc
                rts
_down           jsr     line_down
                clc
                rts
_pgup           ldx     #ROWS-1
-               phx
                jsr     line_up
                plx
                dex
                bne     -
                clc
                rts
_pgdn           ldx     #ROWS-1
-               phx
                jsr     line_down
                plx
                dex
                bne     -
                clc
                rts
_bs             lda     cur                     ; au début : rien
                cmp     #<TEXT
                bne     +
                lda     cur+1
                cmp     #>TEXT
                beq     _none
+               jsr     cur_dec
                jsr     delete_char
                bra     _setcol
_del            jsr     delete_char
                bra     _setcol

cur_dec         lda     cur
                cmp     #<TEXT
                bne     +
                lda     cur+1
                cmp     #>TEXT
                beq     _r
+               lda     cur
                bne     +
                dec     cur+1
+               dec     cur
_r              rts
cur_inc         lda     cur
                cmp     tend
                lda     cur+1
                sbc     tend+1
                bcs     _r
                inc     cur
                bne     _r
                inc     cur+1
_r              rts
; goto_eol : cur = CR de fin de ligne (ou fin du texte)
goto_eol        lda     cur
                cmp     tend
                lda     cur+1
                sbc     tend+1
                bcs     _r
                lda     (cur)
                cmp     #CR
                beq     _r
                inc     cur
                bne     goto_eol
                inc     cur+1
                bra     goto_eol
_r              rts
; line_up : ligne précédente, colonne wantcol
line_up         jsr     find_lstart
                lda     lstart                  ; première ligne ?
                cmp     #<TEXT
                bne     +
                lda     lstart+1
                cmp     #>TEXT
                beq     _r
+               lda     lstart                  ; cur = lstart - 1 (CR précédent)
                sta     cur
                lda     lstart+1
                sta     cur+1
                jsr     cur_dec
                jsr     find_lstart
                jmp     seek_col
_r              rts
; line_down : ligne suivante, colonne wantcol
line_down       jsr     goto_eol
                lda     cur
                cmp     tend
                lda     cur+1
                sbc     tend+1
                bcs     _r
                jsr     cur_inc
                jsr     find_lstart
                jmp     seek_col
_r              rts
; seek_col : depuis lstart, avance jusqu'à wantcol ou fin de ligne
seek_col        lda     lstart
                sta     cur
                lda     lstart+1
                sta     cur+1
                ldx     wantcol
                beq     _r
-               lda     cur
                cmp     tend
                lda     cur+1
                sbc     tend+1
                bcs     _r
                lda     (cur)
                cmp     #CR
                beq     _r
                inc     cur
                bne     +
                inc     cur+1
+               dex
                bne     -
_r              rts

; insert_char : insère key en cur (décale la fin du texte), cur++
insert_char     lda     tend                    ; plein ?
                cmp     #<TEXT_END
                lda     tend+1
                sbc     #>TEXT_END
                bcs     _r
                ; memmove(cur+1, cur, tend-cur) à reculons
                lda     tend
                sta     ptr
                lda     tend+1
                sta     ptr+1
_loop           lda     ptr
                cmp     cur
                lda     ptr+1
                sbc     cur+1
                bcc     _done
                beq     _done0
_mv             jsr     dec_ptr
                lda     (ptr)
                ldy     #1
                sta     (ptr),y
                bra     _loop
_done0          lda     ptr                     ; ptr+1 == cur+1 : comparer bas
                cmp     cur
                bne     _mv
_done           lda     key
                sta     (cur)
                inc     tend
                bne     +
                inc     tend+1
+               inc     cur
                bne     +
                inc     cur+1
+               lda     #1
                sta     dirty
_r              rts

; delete_char : supprime le caractère en cur (si avant la fin)
delete_char     lda     cur
                cmp     tend
                lda     cur+1
                sbc     tend+1
                bcs     _r
                lda     cur
                sta     ptr
                lda     cur+1
                sta     ptr+1
_loop           inc     ptr
                bne     +
                inc     ptr+1
+               lda     ptr
                cmp     tend
                lda     ptr+1
                sbc     tend+1
                bcs     _done
                lda     (ptr)
                sta     ptr2                    ; (ptr-1) = (ptr)
                lda     ptr
                bne     +
                dec     ptr+1
+               dec     ptr
                lda     ptr2
                sta     (ptr)
                inc     ptr
                bne     _loop
                inc     ptr+1
                bra     _loop
_done           lda     tend
                bne     +
                dec     tend+1
+               dec     tend
                lda     #1
                sta     dirty
_r              rts

; menu : Échap — S sauver, X sauver et quitter, Q quitter ; C=1 pour quitter
menu            ldx     #0
                ldy     #ROWS+1
                jsr     set_cursor
                #print  "S=save  X=save+exit  Q=quit (no save)  Esc=back"
                jsr     pad_line
_key            jsr     getkey
                and     #$DF
                cmp     #'S'
                beq     _save
                cmp     #'X'
                beq     _savex
                cmp     #'Q'
                beq     _quit
                cmp     #(CC_ESC & $DF)
                beq     _back
                cmp     #CC_ESC
                beq     _back
                bra     _key
_save           jsr     save_file
                clc
                rts
_savex          jsr     save_file
                bcs     _back
_quit           sec
                rts
_back           clc
                rts

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
cnt16           .fill   2
size16          .fill   2
argbuf          .fill   122
filebuf         .fill   122
