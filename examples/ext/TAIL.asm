; TAIL.asm — commande externe NeoDOS : TAIL [/n] fichier — affiche les n
; dernières lignes du fichier (10 par défaut). Deux passes : la première
; compte les lignes, la seconde saute les premières — aucune limite de
; taille. Fins de ligne CR LF, LF ou CR ; une dernière ligne sans fin de
; ligne compte. Suit la redirection « > ». ERRORLEVEL 1 si le fichier est
; absent ou la ligne de commande incorrecte.
;   make examples  ->  storage/BIN/TAIL.NEO
ptr             = $80
sptr            = $82
cnt             = $84
rptr            = $86
rend            = $88
prevcr          = $8A
nlines          = $8B           ; 16 bits : lignes demandées
total           = $8D           ; 16 bits : lignes du fichier, puis à sauter
last            = $8F
tmp             = $90
                * = $0800
                jmp     main
                .include "neoext.inc"
                .include "textfile.inc"

main            jsr     tf_args
                bcc     +
                jsr     fail
                #println "Usage: TAIL [/n] file"
                rts
+               jsr     tf_open                 ; 1re passe : compter
                bcs     _r
                stz     total
                stz     total+1
                lda     #CR
                sta     last
_count          jsr     tf_char
                bcs     _counted
                sta     last
                cmp     #CR
                bne     _count
                jsr     inc_total
                bra     _count
_counted        lda     last                    ; dernière ligne sans fin
                cmp     #CR
                beq     +
                jsr     inc_total
+               jsr     tf_close
                lda     total                   ; à sauter : total - n (>= 0)
                sec
                sbc     nlines
                sta     total
                lda     total+1
                sbc     nlines+1
                sta     total+1
                bcs     +
                stz     total
                stz     total+1
+               jsr     tf_open                 ; 2e passe
                bcs     _r
_skip           lda     total
                ora     total+1
                beq     _show
                jsr     tf_char
                bcs     _end
                cmp     #CR
                bne     _skip
                lda     total
                bne     +
                dec     total+1
+               dec     total
                bra     _skip
_show           lda     #CR
                sta     last
-               jsr     tf_char
                bcs     _end
                sta     last
                jsr     tf_put
                bra     -
_end            lda     last
                cmp     #CR
                beq     +
                jsr     newline
+               jmp     tf_close
_r              rts

inc_total       inc     total
                bne     +
                inc     total+1
+               rts

argbuf          .fill   122
filebuf         .fill   122
