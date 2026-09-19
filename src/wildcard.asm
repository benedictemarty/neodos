; wildcard.asm — jokers DOS : correspondance « * » / « ? », découpage
; répertoire/motif, collecte des entrées d'un répertoire, substitution REN

; ---------------------------------------------------------------------------
; has_wild : C=1 si la pstring (ptr) contient « * » ou « ? »
; ---------------------------------------------------------------------------
has_wild        lda     (ptr)
                beq     _no
                tay
_loop           lda     (ptr),y
                cmp     #'*'
                beq     _yes
                cmp     #'?'
                beq     _yes
                dey
                bne     _loop
_no             clc
                rts
_yes            sec
                rts

; ---------------------------------------------------------------------------
; match_glob : C=1 si namebuf correspond au motif patbuf.
; « ? » = un caractère, « * » = une suite quelconque ; insensible à la casse.
; « *.* » est ramené à « * » (en DOS tout nom a une extension implicite).
; Retour arrière sur le dernier « * » (algorithme classique sans récursion).
; ---------------------------------------------------------------------------
match_glob      lda     patbuf                  ; « *.* » -> tout
                cmp     #3
                bne     _start
                lda     patbuf+1
                cmp     #'*'
                bne     _start
                lda     patbuf+2
                cmp     #'.'
                bne     _start
                lda     patbuf+3
                cmp     #'*'
                bne     _start
                bra     _ok
_start          ldx     #1                      ; X = index motif
                ldy     #1                      ; Y = index nom
                stz     mstar_p
                stz     mstar_n
_loop           tya                             ; nom épuisé ?
                cmp     namebuf
                beq     _more
                bcs     _nameend
_more           txa                             ; motif épuisé ?
                cmp     patbuf
                beq     _pchar
                bcs     _backtrack
_pchar          lda     patbuf,x
                cmp     #'*'
                beq     _star
                cmp     #'?'
                beq     _adv
                jsr     upper
                sta     tmp
                lda     namebuf,y
                jsr     upper
                cmp     tmp
                bne     _backtrack
_adv            inx
                iny
                bra     _loop
_star           inx                             ; mémorise la position
                stx     mstar_p
                sty     mstar_n
                bra     _loop
_backtrack      lda     mstar_p                 ; pas d'étoile : échec
                beq     _fail
                ldx     mstar_p                 ; l'étoile absorbe un
                inc     mstar_n                 ; caractère de plus
                ldy     mstar_n
                bra     _loop
_nameend        txa                             ; reste du motif : que des « * »
                cmp     patbuf
                beq     +
                bcs     _ok
+               lda     patbuf,x
                cmp     #'*'
                bne     _fail
                inx
                bra     _nameend
_ok             sec
                rts
_fail           clc
                rts

; ---------------------------------------------------------------------------
; split_path : arg1 (chemin API, « / ») -> dirbuf + patbuf.
; « GAMES/*.TXT » -> « GAMES », « *.TXT » ; « *.TXT » -> « . », « *.TXT » ;
; « /X » -> « / », « X ».
; ---------------------------------------------------------------------------
split_path      ldx     arg1                    ; X = position du dernier « / »
                beq     _nodir
_find           lda     arg1,x
                cmp     #'/'
                beq     _found
                dex
                bne     _find
_nodir          lda     #1                      ; répertoire courant « . »
                sta     dirbuf
                lda     #'.'
                sta     dirbuf+1
                ldx     #0
                bra     _pat
_found          cpx     #1                      ; « /nom » : racine
                bne     _dir
                lda     #1
                sta     dirbuf
                lda     #'/'
                sta     dirbuf+1
                bra     _pat
_dir            txa                             ; dirbuf = arg1[1..X-1]
                pha
                dex
                stx     dirbuf
                ldy     #1
-               lda     arg1,y
                sta     dirbuf,y
                iny
                dex
                bne     -
                pla
                tax
_pat            ldy     #0                      ; patbuf = arg1[X+1..len]
_copy           inx
                cpx     arg1
                beq     +
                bcs     _end
+               lda     arg1,x
                iny
                sta     patbuf,y
                bra     _copy
_end            sty     patbuf
                rts

; ---------------------------------------------------------------------------
; collect_matches : ouvre dirbuf, collecte dans listbuf les entrées dont le
; nom correspond à patbuf. A à l'entrée : 0 = fichiers seulement, 1 = tout.
; Sortie : lcount = nombre de noms ; C=1 si erreur (message déjà affiché).
; ---------------------------------------------------------------------------
collect_matches sta     flag
                stz     lcount
                #setptr lptr, listbuf
                #setparam 0, dirbuf
                #api    3,17
                lda     DError
                beq     _next
                jsr     err_api
                sec
                rts
_next           lda     #100
                sta     namebuf
                jsr     p0_namebuf
                #api    3,18
                lda     DError
                bne     _done
                lda     flag
                bne     _test
                lda     DParams+6               ; fichiers seulement
                and     #ATTR_DIR
                bne     _next
_test           jsr     match_glob
                bcc     _next
                ; place disponible ? (lptr + len + 1 < listbuf + taille)
                lda     lptr
                clc
                adc     namebuf
                sta     ptr
                lda     lptr+1
                adc     #0
                sta     ptr+1
                inc     ptr
                bne     +
                inc     ptr+1
+               lda     ptr
                cmp     #<(listbuf+LISTBUF_SIZE)
                lda     ptr+1
                sbc     #>(listbuf+LISTBUF_SIZE)
                bcs     _full
                ldy     namebuf                 ; copie la pstring
-               lda     namebuf,y
                sta     (lptr),y
                dey
                bpl     -
                lda     ptr                     ; lptr = fin
                sta     lptr
                lda     ptr+1
                sta     lptr+1
                inc     lcount
                bne     _next
_full           #api    3,19
                jsr     errlvl1
                #println "Too many files"
                sec
                rts
_done           #api    3,19
                clc
                rts

; ---------------------------------------------------------------------------
; list_first / list_next : parcours de listbuf ; ptr2 -> pstring courante.
; list_next : C=1 quand la liste est épuisée (compteur cnt2 = lcount).
; ---------------------------------------------------------------------------
list_first      #setptr ptr2, listbuf
                lda     lcount
                sta     lidx                    ; lidx = noms restants
                rts

list_next       lda     lidx
                beq     _end
                cmp     lcount                  ; premier appel : ptr2 déjà
                beq     _first                  ; sur la première entrée
                lda     (ptr2)                  ; sinon avance après l'entrée
                sec
                adc     ptr2
                sta     ptr2
                bcc     _first
                inc     ptr2+1
_first          dec     lidx
                clc
                rts
_end            sec
                rts

; ---------------------------------------------------------------------------
; app_char : ajoute A à la pstring (ptr) ; oidx = longueur courante
; ---------------------------------------------------------------------------
app_char        phy
                inc     oidx
                ldy     oidx
                sta     (ptr),y
                ply
                rts

; ---------------------------------------------------------------------------
; build_path : (ptr) = dirbuf + « / » + pstring (ptr2)
; (dirbuf « . » : nom seul ; dirbuf finissant par « / » : pas de doublon).
; ---------------------------------------------------------------------------
build_path      stz     oidx
                lda     dirbuf
                cmp     #1
                bne     _copydir
                lda     dirbuf+1
                cmp     #'.'
                beq     _name
_copydir        ldy     #1
-               lda     dirbuf,y
                jsr     app_char
                iny
                cpy     dirbuf
                beq     -
                bcc     -
                ldy     dirbuf
                lda     dirbuf,y
                cmp     #'/'
                beq     _name
                lda     #'/'
                jsr     app_char
_name           ldy     #1
_loop           tya
                cmp     (ptr2)
                beq     +
                bcs     _end
+               lda     (ptr2),y
                jsr     app_char
                iny
                bra     _loop
_end            lda     oidx
                sta     (ptr)
                rts

; ---------------------------------------------------------------------------
; apply_pattern : newname = motif arg2 appliqué au nom (ptr2), façon DOS :
; nom et extension (dernier « . ») traités séparément ; « * » recopie le
; reste de la partie source, « ? » un caractère, le reste est littéral.
; Utilise total (source) et num (motif) comme variables de travail.
; ---------------------------------------------------------------------------
sb_l            = total                 ; longueur de la base source
se_s            = total+1               ; début / longueur de l'extension source
se_l            = total+2
pb_l            = num                   ; idem pour le motif
pe_s            = num+1
pe_l            = num+2
pdot            = num+3                 ; le motif a un « . »

apply_pattern   stz     oidx
                #setptr ptr, newname
                ; découpe de la source
                lda     (ptr2)
                tay
                beq     _sdot
-               lda     (ptr2),y
                cmp     #'.'
                beq     _sdot
                dey
                bne     -
_sdot           tya                     ; Y = position du « . » (0 : aucun)
                bne     +
                lda     (ptr2)
                sta     sb_l
                inc     a
                sta     se_s
                stz     se_l
                bra     _pattern
+               dec     a
                sta     sb_l
                iny
                sty     se_s
                lda     (ptr2)
                sec
                sbc     sb_l
                sbc     #1
                sta     se_l
_pattern        ldy     arg2
                beq     _pdot
-               lda     arg2,y
                cmp     #'.'
                beq     _pdot
                dey
                bne     -
_pdot           sty     pdot
                tya
                bne     +
                lda     arg2
                sta     pb_l
                inc     a
                sta     pe_s
                stz     pe_l
                bra     _base
+               dec     a
                sta     pb_l
                iny
                sty     pe_s
                lda     arg2
                sec
                sbc     pb_l
                sbc     #1
                sta     pe_l
_base           lda     #1
                sta     pp_s
                sta     sp_s
                lda     pb_l
                sta     pp_l
                lda     sb_l
                sta     sp_l
                jsr     apply_part
                lda     pdot
                beq     _done
                lda     #'.'
                jsr     app_char
                lda     pe_s
                sta     pp_s
                lda     pe_l
                sta     pp_l
                lda     se_s
                sta     sp_s
                lda     se_l
                sta     sp_l
                jsr     apply_part
_done           lda     oidx
                sta     (ptr)
                rts

; apply_part : applique arg2[pp_s..+pp_l] à la source (ptr2)[sp_s..+sp_l]
apply_part      stz     cnt
_loop           lda     cnt
                cmp     pp_l
                bcs     _done
                clc
                adc     pp_s
                tax
                lda     arg2,x
                cmp     #'*'
                beq     _star
                cmp     #'?'
                beq     _q
                jsr     app_char
_next           inc     cnt
                bra     _loop
_q              lda     cnt
                cmp     sp_l
                bcs     _next
                jsr     src_at
                jsr     app_char
                bra     _next
_star           lda     cnt
_sloop          cmp     sp_l
                bcs     _done
                sta     cnt
                jsr     src_at
                jsr     app_char
                lda     cnt
                inc     a
                bra     _sloop
_done           rts

; src_at : A = caractère source à l'index cnt de la partie courante
src_at          lda     cnt
                clc
                adc     sp_s
                tay
                lda     (ptr2),y
                rts
