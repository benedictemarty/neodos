; walk.inc — parcours récursif d'une arborescence pour les commandes externes
; (XCOPY /S, DELTREE). Le firmware n'a qu'un répertoire ouvert à la fois :
; chaque niveau est ré-énuméré en sautant les sous-répertoires déjà visités
; (pile skip[depth]). Le programme fournit trois crochets :
;   hook_file  : pathbuf = répertoire courant, namebuf = fichier (1re visite)
;   hook_enter : pathbuf = répertoire dans lequel on vient de descendre,
;                subdir = son nom
;   hook_leave : pathbuf = répertoire que l'on va quitter (vide de fichiers)
; Variables page zéro attendues : ptr, cnt, depth, n, found. Tampons :
; pathbuf (129), namebuf (102), subdir (102), skip (WALK_DEPTH).
WALK_DEPTH      = 8

; walk : parcourt pathbuf (déjà un répertoire) ; C=1 si trop profond
walk            stz     depth
                stz     skip
_level          jsr     walk_level
                lda     found
                beq     _up
                ldx     depth
                inc     skip,x
                cpx     #WALK_DEPTH-1
                bcs     _level                  ; trop profond : ignoré
                jsr     path_push
                inc     depth
                ldx     depth
                stz     skip,x
                jsr     hook_enter
                bra     _level
_up             jsr     hook_leave
                lda     depth
                beq     _done
                jsr     path_pop
                dec     depth
                bra     _level
_done           clc
                rts

; walk_level : passe 1 (fichiers, première visite seulement) puis passe 2 :
; found = 1 et subdir = prochain sous-répertoire à visiter
walk_level      stz     found
                ldx     depth
                lda     skip,x
                bne     _dirs
                jsr     open_level
_f              jsr     read_entry
                bcs     _fend
                lda     DParams+6
                and     #1
                bne     _f
                jsr     hook_file
                bra     _f
_fend           #api    3,19
_dirs           stz     n
                jsr     open_level
_d              jsr     read_entry
                bcs     _dend
                lda     DParams+6
                and     #1
                beq     _d
                ldx     depth
                lda     n
                cmp     skip,x
                bcc     _seen
                bne     _d
                lda     #1
                sta     found
                ldx     namebuf
-               lda     namebuf,x
                sta     subdir,x
                dex
                bpl     -
_seen           inc     n
                bra     _d
_dend           #api    3,19
                rts

open_level      #setparam 0, pathbuf
                #api    3,17
                rts
read_entry      lda     #100
                sta     namebuf
                #setparam 0, namebuf
                #api    3,18
                lda     DError
                bne     _end
                clc
                rts
_end            sec
                rts

; path_push : pathbuf += « / » + subdir ; path_pop : retire le dernier élément
path_push       ldx     pathbuf
                lda     #'/'
                inx
                sta     pathbuf,x
                ldy     #1
-               cpy     subdir
                beq     +
                bcs     _end
+               lda     subdir,y
                inx
                sta     pathbuf,x
                iny
                bra     -
_end            stx     pathbuf
                rts
path_pop        ldx     pathbuf
-               lda     pathbuf,x
                cmp     #'/'
                beq     +
                dex
                bne     -
+               dex
                stx     pathbuf
                rts

; join : (ptr) = pstring A + « / » + pstring B, avec A = pathbuf-like en
; (ptr2) et B = namebuf ; résultat dans (ptr). Utilisé pour « rép/fichier ».
join            ldx     #0
                ldy     #1
-               tya
                cmp     (ptr2)
                beq     +
                bcs     _slash
+               lda     (ptr2),y
                jsr     _put
                iny
                bra     -
_slash          lda     #'/'
                jsr     _put
                ldy     #1
-               cpy     namebuf
                beq     +
                bcs     _end
+               lda     namebuf,y
                jsr     _put
                iny
                bra     -
_end            txa
                sta     (ptr)
                rts
_put            inx                             ; (ptr)[X] = A, Y préservé
                sty     cnt
                pha
                txa
                tay
                pla
                sta     (ptr),y
                ldy     cnt
                rts
