; lineedit.asm — éditeur de ligne de NeoDOS avec historique (DOSKEY simplifié)
;
; Remplace le ReadLine du noyau (qui renvoyait toute la ligne d'écran). La
; ligne est tenue dans linebuf (pstring, 200 caractères max) avec un curseur
; (lpos) ; l'écran est tenu en miroir par les codes de contrôle de la console
; du firmware : insertion (5), suppression (26), retour arrière (8), gauche
; (1), droite (4), haut/bas (23/19) pour les retours à la ligne.
;
; Touches : caractères imprimables (insertion), Retour arrière, Suppr,
; Gauche/Droite, Début/Fin (Home/End), Haut/Bas (historique), Échap (efface
; la ligne), Entrée.

CC_LEFT         = 1
CC_RIGHT        = 4
CC_INSERT       = 5
CC_END          = 7
CC_BACKSPACE    = 8
CC_DOWN         = 19
CC_HOME         = 20
CC_UP           = 23
CC_REVERSE      = 24
CC_DELETE       = 26
CC_ESC          = 27

; ---------------------------------------------------------------------------
; readline_ed : lit une ligne dans linebuf
; ---------------------------------------------------------------------------
readline_ed     stz     llen
                stz     lpos
                lda     hcount
                sta     hcur
_key            jsr     getkey
                ldx     #0
-               ldy     keytab,x
                beq     _print
                cmp     keytab,x
                beq     _dispatch
                inx
                bra     -
_dispatch       txa
                asl     a
                tax
                jmp     (handlers,x)
_print          cmp     #' '
                bcc     _key                    ; autres codes de contrôle
                cmp     #127
                bcs     _key
                ; insertion d'un caractère
                ldx     llen
                cpx     #200
                bcs     _key
                sta     tmp
                cpx     lpos                    ; décale la fin de ligne
                beq     _ins
-               lda     linebuf,x               ; linebuf+1+(x-1) -> +1+x
                sta     linebuf+1,x
                dex
                cpx     lpos
                bne     -
                lda     #CC_INSERT              ; écran : insère un espace
                jsr     putc
_ins            ldx     lpos
                lda     tmp
                sta     linebuf+1,x
                jsr     putc
                inc     lpos
                inc     llen
                jmp     _key
_jkey           jmp     _key
_bs             lda     lpos
                beq     _jkey
                dec     lpos
                jsr     del_at                  ; retire linebuf[lpos]
                lda     #CC_BACKSPACE
                jsr     putc
                jmp     _key
_del            lda     lpos
                cmp     llen
                bcs     _jkey
                jsr     del_at
                lda     #CC_DELETE
                jsr     putc
                jmp     _key
_left           lda     lpos
                beq     _jkey
                jsr     cur_left
                jmp     _key
_right          lda     lpos
                cmp     llen
                bcs     _jkey
                jsr     cur_right
                jmp     _key
_home           lda     lpos
                beq     _jkey
                jsr     cur_left
                bra     _home
_end            lda     lpos
                cmp     llen
                bcs     _jkey
                jsr     cur_right
                bra     _end
_esc            jsr     clear_line
                jmp     _key
_up             lda     hcur
                beq     _jkey
                dec     hcur
                bra     _recall
_down           lda     hcur
                cmp     hcount
                bcs     _jkey
                inc     hcur
                lda     hcur
                cmp     hcount                  ; après la dernière : ligne vide
                bne     _recall
                jsr     clear_line
                jmp     _key
_recall         jsr     clear_line
                lda     hcur
                jsr     hist_entry              ; ptr2 -> pstring
                lda     (ptr2)
                sta     llen
                sta     lpos
                bne     +
                jmp     _key
+               tay
-               lda     (ptr2),y                ; copie (à l'envers)
                sta     linebuf,y
                dey
                bne     -
                ldy     #1
-               lda     linebuf,y               ; affiche
                jsr     putc
                iny
                cpy     llen
                beq     -
                bcc     -
                jmp     _key
_enter          lda     lpos                    ; curseur en fin de ligne
                cmp     llen
                bcs     +
                jsr     cur_right
                bra     _enter
+               lda     llen
                sta     linebuf
                jsr     newline
                jmp     hist_add

keytab          .byte   CR, CC_BACKSPACE, CC_DELETE, CC_LEFT, CC_RIGHT, CC_HOME
                .byte   CC_END, CC_UP, CC_DOWN, CC_ESC, 0
handlers        .word   _enter, _bs, _del, _left, _right, _home
                .word   _end, _up, _down, _esc

; getkey : attend une touche (curseur inversé pendant l'attente) ;
; Ctrl+Alt+Suppr pendant l'attente : redémarrage à chaud de NeoDOS
getkey          lda     #CC_REVERSE
                jsr     putc
-               lda     #KEY_DELETE
                sta     DParams
                #api    1,2                     ; état de Suppr + modificateurs
                lda     DParams
                beq     +
                lda     DParams+1
                bit     #MOD_CTRL
                beq     +
                bit     #MOD_ALT
                beq     +
                jmp     warm_restart
+               #api    2,1
                lda     DParams
                beq     -
                pha
                lda     #CC_REVERSE
                jsr     putc
                pla
                rts

; del_at : retire le caractère linebuf[lpos] (llen--)
del_at          ldx     lpos
-               cpx     llen
                bcs     +
                lda     linebuf+2,x
                sta     linebuf+1,x
                inx
                bra     -
+               dec     llen
                rts

; cur_left / cur_right : déplacent le curseur (lpos et écran) d'un caractère,
; en gérant le passage d'une ligne d'écran à l'autre (colonne = promptskip +
; lpos modulo SCREEN_COLS).
cur_left        jsr     column                  ; colonne avant le déplacement
                bne     +
                lda     #CC_UP                  ; colonne 0 : ligne précédente
                jsr     putc
+               lda     #CC_LEFT
                jsr     putc
                dec     lpos
                rts
cur_right       inc     lpos
                lda     #CC_RIGHT
                jsr     putc
                jsr     column                  ; colonne après le déplacement
                bne     +
                lda     #CC_DOWN                ; retour en colonne 0 : ligne
                jsr     putc                    ; suivante
+               rts

; column : A = (promptskip + lpos) mod SCREEN_COLS
column          lda     promptskip
                clc
                adc     lpos
-               cmp     #SCREEN_COLS
                bcc     +
                sbc     #SCREEN_COLS
                bra     -
+               rts

; clear_line : efface la ligne (écran et tampon)
clear_line      lda     lpos
                cmp     llen
                bcs     _erase
                jsr     cur_right
                bra     clear_line
_erase          lda     llen
                beq     _done
                lda     #CC_BACKSPACE
                jsr     putc
                dec     llen
                dec     lpos
                bra     _erase
_done           rts

; ---------------------------------------------------------------------------
; Historique : pstrings consécutives dans histbuf (hused octets, hcount
; entrées) ; la plus ancienne est retirée quand la place manque.
; ---------------------------------------------------------------------------
hist_add        lda     linebuf
                beq     _done
                lda     hcount                  ; identique à la dernière ?
                beq     _room
                dec     a
                jsr     hist_entry
                ldy     linebuf
-               lda     (ptr2),y
                cmp     linebuf,y
                bne     _room
                dey
                bpl     -
                rts
_room           lda     hused                   ; hused + len + 1 > taille ?
                sec
                adc     linebuf
                bcs     _drop
                cmp     #HIST_SIZE
                beq     _append
                bcc     _append
_drop           lda     #0                      ; retire la première entrée
                jsr     hist_entry
                lda     (ptr2)
                sec
                adc     #0
                sta     tmp                     ; taille de l'entrée
                ldy     #0
-               tya
                clc
                adc     tmp
                cmp     hused
                bcs     +
                tax
                lda     histbuf,x
                sta     histbuf,y
                iny
                bra     -
+               lda     hused
                sec
                sbc     tmp
                sta     hused
                dec     hcount
                bra     _room
_append         ldx     hused
                ldy     #0
-               lda     linebuf,y
                sta     histbuf,x
                inx
                iny
                cpy     linebuf
                beq     -
                bcc     -
                stx     hused
                inc     hcount
_done           rts

; hist_entry : ptr2 -> entrée n° A (0 = la plus ancienne)
hist_entry      tax
                #setptr ptr2, histbuf
_loop           cpx     #0
                beq     _done
                lda     (ptr2)
                sec
                adc     ptr2
                sta     ptr2
                bcc     +
                inc     ptr2+1
+               dex
                bra     _loop
_done           rts
