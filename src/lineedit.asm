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
; la ligne), Entrée, Tab (complétion du nom de fichier sous le curseur : plus
; long préfixe commun des entrées du répertoire), F8 (DOSKEY : rappelle la
; commande la plus récente de l'historique qui commence par le texte tapé ;
; F8 à nouveau remonte plus loin).
;
; Suggestion automatique : quand le curseur est en fin de ligne, la suite de
; la commande la plus récente de l'historique qui commence par la ligne est
; affichée en gris après le curseur (show_sugg, avant chaque attente de
; touche ; hide_sugg l'efface dès qu'une touche arrive). Droite ou Fin en fin
; de ligne l'acceptent (_accept) ; toute autre touche la recalcule.

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
                stz     f8len
                stz     sglen
                lda     hcount
                sta     hcur
_key            jsr     show_sugg
                jsr     getkey
                pha
                jsr     hide_sugg
                pla
                cmp     #KEY_F8                 ; toute autre touche termine
                beq     +                       ; la recherche F8
                stz     f8len
+               ldx     #0
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
                jsr     ins_char
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
                bcs     _accept
                jsr     cur_right
                jmp     _key
_accept         lda     sglen                   ; fin de ligne : accepte la
                beq     _jkey                   ; suggestion s'il y en a une
                lda     sgidx
                jsr     hist_entry
                ldy     llen
-               iny
                lda     (ptr2),y
                phy
                jsr     ins_char
                ply
                tya
                cmp     (ptr2)
                bne     -
                stz     sglen
                jmp     _key
_home           lda     lpos
                beq     _jkey
                jsr     cur_left
                bra     _home
_end            lda     lpos
                cmp     llen
                bcs     _accept
                jsr     cur_right
                bra     _end
_esc            jsr     clear_line
                jmp     _key
_up             lda     hcur
                beq     _jkey
                dec     hcur
                bra     _recall
_jkey4          jmp     _key
_down           lda     hcur
                cmp     hcount
                bcs     _jkey4
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
; F8 : recherche dans l'historique, de la plus récente à la plus ancienne
; (avant hcur), une commande dont les f8len premiers caractères sont ceux
; de la ligne ; la première fois, le préfixe est la ligne jusqu'au curseur.
_f8             lda     f8len
                bne     +
                lda     lpos
                sta     f8len
+               lda     hcur
                sta     idx
_f8next         lda     idx
                beq     _jkey2                  ; plus rien : ligne inchangée
                dec     idx
                lda     idx
                jsr     hist_entry              ; ptr2 -> entrée
                lda     (ptr2)
                cmp     f8len
                bcc     _f8next                 ; trop courte
                ldy     f8len
-               beq     +                       ; préfixe entier comparé
                lda     (ptr2),y
                cmp     linebuf,y
                bne     _f8next
                dey
                bra     -
+               lda     idx
                sta     hcur
                bra     _recall
_jkey2          jmp     _key
; Tab : le mot sous le curseur (depuis l'espace précédent) + « * » est un
; motif ; les entrées du répertoire qui y correspondent sont collectées dans
; listbuf, et leur plus long préfixe commun est inséré au-delà de ce qui est
; déjà tapé. Aucune correspondance (ou répertoire inexistant) : rien.
_tab            ldx     lpos                    ; X = début du mot (index de
-               beq     +                       ; l'espace précédent, 0 = début)
                lda     linebuf,x
                cmp     #' '
                beq     +
                dex
                bra     -
+               ldy     #0                      ; arg1 = mot + « * »
-               cpx     lpos
                beq     +
                lda     linebuf+1,x
                iny
                sta     arg1,y
                inx
                bra     -
+               iny
                lda     #'*'
                sta     arg1,y
                sty     arg1
                jsr     ptr_arg1
                jsr     to_apipath
                jsr     split_path              ; dirbuf + patbuf
                lda     #1                      ; fichiers et répertoires
                sta     flag
                jsr     collect_open
                bne     _jkey2
                jsr     collect_loop
                lda     lcount
                beq     _jkey2
                ; cnt = longueur du préfixe commun (sans tenir compte de la casse)
                jsr     list_first
                lda     listbuf
                sta     cnt
_tcmp           jsr     list_next               ; ptr2 -> entrée suivante
                bcs     _tins
                lda     (ptr2)
                cmp     cnt
                bcs     +
                sta     cnt                     ; entrée plus courte
+               ldy     #1
-               cpy     cnt
                beq     +
                bcs     _tcmp                   ; Y > cnt : entrée conforme
+               lda     (ptr2),y
                jsr     upper
                sta     tmp
                lda     listbuf,y
                jsr     upper
                cmp     tmp
                bne     +
                iny
                bra     -
+               dey                             ; divergence en Y : préfixe = Y-1
                sty     cnt
                bra     _tcmp
_tins           ldy     patbuf                  ; déjà tapé : patbuf sans « * »
                dey
-               cpy     cnt
                bcs     _tdir
                iny
                lda     listbuf,y
                jsr     ins_char
                bra     -
_tdir           lda     lcount                  ; correspondance unique et
                cmp     #1                      ; répertoire : « \ » ajouté
                bne     _jkey3
                jsr     list_first              ; ptr2 -> l'entrée
                jsr     ptr_namebuf
                jsr     build_path              ; namebuf = dirbuf/nom
                jsr     stat_namebuf
                bne     _jkey3
                lda     DParams+4
                and     #ATTR_DIR
                beq     _jkey3
                lda     #'\'
                jsr     ins_char
_jkey3          jmp     _key

keytab          .byte   CR, CC_BACKSPACE, CC_DELETE, CC_LEFT, CC_RIGHT, CC_HOME
                .byte   CC_END, CC_UP, CC_DOWN, CC_ESC, CC_TAB, KEY_F8, 0
handlers        .word   _enter, _bs, _del, _left, _right, _home
                .word   _end, _up, _down, _esc, _tab, _f8

; ins_char : insère A dans linebuf au curseur (écran compris) ; rien si la
; ligne est pleine (200)
ins_char        ldx     llen
                cpx     #200
                bcs     _full
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
_full           rts

; show_sugg : curseur en fin de ligne non vide -> cherche, de la plus
; récente à la plus ancienne, une entrée de l'historique plus longue qui
; commence par la ligne ; affiche la suite en gris (sglen caractères) et
; ramène le curseur (cur_left, via un lpos temporaire) ; sglen = 0 sinon.
show_sugg       stz     sglen
                lda     lpos
                cmp     llen
                bne     _rts
                lda     llen
                beq     _rts
                lda     hcount
                sta     idx
_next           lda     idx
                beq     _rts
                dec     idx
                lda     idx
                jsr     hist_entry              ; ptr2 -> entrée
                lda     (ptr2)
                cmp     llen
                beq     _next                   ; pas plus longue
                bcc     _next
                ldy     llen
-               lda     (ptr2),y
                cmp     linebuf,y
                bne     _next
                dey
                bne     -
                lda     idx
                sta     sgidx
                lda     (ptr2)
                sec
                sbc     llen
                sta     sglen
                jsr     column                  ; borne à la fin de la ligne
                sta     tmp                     ; d'écran : une suggestion qui
                lda     #SCREEN_COLS-1          ; passerait à la ligne ferait
                sec                             ; défiler l'écran (résidus)
                sbc     tmp
                beq     _none                   ; curseur au bord : rien
                bcc     _none
                cmp     sglen
                bcs     +
                sta     sglen                   ; tronque à la place restante
+               lda     #7                      ; encre courante (2,18 Read
                sta     DParams                 ; Ink/Paper ; 7 si absente)
                #api    2,18
                lda     DParams
                ora     #$80
                sta     sgink
                lda     #INK_GHOST
                jsr     putc
                lda     llen                    ; fin de l'affichage = llen+sglen
                clc                             ; (sglen a pu être borné à la
                adc     sglen                   ; ligne d'écran)
                sta     cnt
                ldy     llen
-               iny
                lda     (ptr2),y
                phy
                jsr     putc
                ply
                cpy     cnt
                bne     -
                lda     sgink
                jsr     putc
                bra     sugg_back
_none           stz     sglen
_rts            rts
sugg_rts        rts

; hide_sugg : efface la suggestion affichée (espaces, puis retour du
; curseur) ; sglen est conservé pour _accept
hide_sugg       lda     sglen
                beq     sugg_rts
                sta     cnt
-               lda     #' '
                jsr     putc
                dec     cnt
                bne     -
; sugg_back : ramène le curseur de sglen positions (cur_left avec un lpos
; temporaire : les passages de ligne sont calculés, sans dépendre de
; l'indicateur « ligne prolongée » de la console, faux après un défilement)
sugg_back       lda     llen
                clc
                adc     sglen
                sta     lpos
-               jsr     cur_left
                lda     lpos
                cmp     llen
                bne     -
                rts

; check_cad : Ctrl+Alt+Suppr enfoncés ? -> redémarrage à chaud de NeoDOS
; (ne revient pas) ; sinon retour sans effet. Appelé par toutes les attentes
; clavier et entre deux lignes de script.
check_cad       lda     #KEY_DELETE
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
+               rts

; wait_key : attend une touche (A = code) ; Ctrl+Alt+Suppr pendant l'attente
; redémarre NeoDOS
wait_key        jsr     check_cad
                #api    2,1
                lda     DParams
                beq     wait_key
                rts

; getkey : wait_key avec le curseur inversé pendant l'attente
getkey          lda     #CC_REVERSE
                jsr     putc
                jsr     wait_key
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
