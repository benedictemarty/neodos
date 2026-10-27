; glob.inc — jokers DOS pour les commandes externes NeoDOS (repris de
; src/wildcard.asm) : has_wild, split_path, match_glob, upper.
;
; Le programme définit en page zéro : ptr (2), tmp, mstar_p, mstar_n, et les
; tampons argbuf (pstring, argument tel que cmd_arg le livre, « / »),
; dirbuf (129), patbuf (129), namebuf (102).

; has_wild : C=1 si la pstring (ptr) contient « * » ou « ? »
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

; split_path : argbuf (chemin API, « / ») -> dirbuf + patbuf.
; « GAMES/*.TXT » -> « GAMES », « *.TXT » ; « *.TXT » -> « . », « *.TXT » ;
; « /X » -> « / », « X ».
split_path      ldx     argbuf                  ; X = position du dernier « / »
                beq     _nodir
_find           lda     argbuf,x
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
_dir            txa                             ; dirbuf = argbuf[1..X-1]
                pha
                dex
                stx     dirbuf
                ldy     #1
-               lda     argbuf,y
                sta     dirbuf,y
                iny
                dex
                bne     -
                pla
                tax
_pat            ldy     #0                      ; patbuf = argbuf[X+1..len]
_copy           inx
                cpx     argbuf
                beq     +
                bcs     _end
+               lda     argbuf,x
                iny
                sta     patbuf,y
                bra     _copy
_end            sty     patbuf
                rts

; match_glob : C=1 si namebuf correspond au motif patbuf (« ? » un caractère,
; « * » une suite quelconque, casse ignorée ; « *.* » = tout).
match_glob      lda     patbuf
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

; upper : A -> majuscule
upper           cmp     #'a'
                bcc     _done
                cmp     #'z'+1
                bcs     _done
                and     #$df
_done           rts
