; textfile.inc — lecture tamponnée d'un fichier texte pour les commandes
; externes HEAD, TAIL et WC : blocs de 4 Ko en $2000 sur le canal 4 (NeoDOS
; occupe 0, 1 et 7). Le programme définit en page zéro rptr (2), rend (2),
; prevcr (1), nlines (2), tmp (1) et un tampon filebuf (pstring).
TF_CH           = 4
TF_BUF          = $2000
TF_SIZE         = $1000

; tf_args : « [/n] fichier » -> nlines (10 par défaut), filebuf ; C=1 si la
; ligne de commande est incorrecte
tf_args         lda     #10
                sta     nlines
                stz     nlines+1
                lda     #1
                jsr     cmd_arg
                lda     argbuf
                beq     _bad
                lda     argbuf+1
                cmp     #'/'
                bne     _file
                lda     argbuf                  ; « / » seul : erreur
                cmp     #2
                bcc     _bad
                stz     nlines
                ldy     #2
_digit          lda     argbuf,y
                sec
                sbc     #'0'
                cmp     #10
                bcs     _bad
                sta     tmp                     ; nlines = nlines*10 + chiffre
                lda     nlines
                ldx     nlines+1
                asl     nlines
                rol     nlines+1
                asl     nlines
                rol     nlines+1
                clc
                adc     nlines
                sta     nlines
                txa
                adc     nlines+1
                sta     nlines+1
                asl     nlines
                rol     nlines+1
                lda     nlines
                clc
                adc     tmp
                sta     nlines
                bcc     +
                inc     nlines+1
+               cpy     argbuf
                iny
                bcc     _digit
                lda     #2                      ; puis le fichier
                jsr     cmd_arg
                lda     argbuf
                beq     _bad
_file           ldx     argbuf
-               lda     argbuf,x
                sta     filebuf,x
                dex
                bpl     -
                clc
                rts
_bad            sec
                rts

; tf_open : ouvre filebuf en lecture ; C=1 (« File not found », ERRORLEVEL 1)
tf_open         lda     #TF_CH
                sta     DParams
                #setparam 1, filebuf
                stz     DParams+3
                #api    3,4
                lda     #<TF_BUF                ; tampon vide
                sta     rptr
                sta     rend
                lda     #>TF_BUF
                sta     rptr+1
                sta     rend+1
                stz     prevcr
                lda     DError
                beq     +
                jsr     fail
                #println "File not found"
                sec
                rts
+               clc
                rts

tf_close        lda     #TF_CH
                sta     DParams
                #api    3,5
                rts

; tf_byte : octet suivant -> A (C=0) ; C=1 en fin de fichier ; X, Y préservés
tf_byte         lda     rptr
                cmp     rend
                bne     _get
                lda     rptr+1
                cmp     rend+1
                bne     _get
                phx                             ; tampon épuisé : bloc suivant
                phy
                lda     #TF_CH
                sta     DParams
                #setparam 1, TF_BUF
                #setparam 3, TF_SIZE
                #api    3,8
                ldx     DParams+3               ; octets lus
                ldy     DParams+4
                lda     DError
                bne     _eof
                txa
                bne     +
                tya
                beq     _eof
+               lda     #<TF_BUF
                sta     rptr
                txa
                clc
                adc     #<TF_BUF
                sta     rend
                lda     #>TF_BUF
                sta     rptr+1
                tya
                adc     #>TF_BUF
                sta     rend+1
                ply
                plx
_get            lda     (rptr)
                inc     rptr
                bne     +
                inc     rptr+1
+               clc
                rts
_eof            ply
                plx
                sec
                rts

; tf_char : comme tf_byte, mais CR LF, LF seul et CR rendus en un seul CR
tf_char         jsr     tf_byte
                bcs     _r
                cmp     #10
                bne     _nlf
                lda     prevcr                  ; LF après CR : ignoré
                stz     prevcr
                bne     tf_char
                lda     #CR
                clc
                rts
_nlf            stz     prevcr
                cmp     #CR
                bne     _ok
                inc     prevcr
_ok             clc                             ; C=0 : caractère rendu
_r              rts

; tf_put : affiche A comme TYPE (tabulation -> espace, autres codes de
; contrôle ignorés, CR = fin de ligne)
tf_put          cmp     #CR
                beq     _out
                cmp     #9
                bne     +
                lda     #' '
+               cmp     #' '
                bcc     _r
_out            jmp     putc
_r              rts
