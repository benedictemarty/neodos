; HEAD.asm — commande externe NeoDOS : HEAD [/n] fichier — affiche les n
; premières lignes du fichier (10 par défaut ; /0 : rien). Fins de ligne
; CR LF, LF ou CR ; une dernière ligne sans fin de ligne compte. Affichage
; comme TYPE ; suit la redirection « > ». ERRORLEVEL 1 si le fichier est
; absent ou la ligne de commande incorrecte.
;   make examples  ->  storage/BIN/HEAD.NEO
ptr             = $80
sptr            = $82
cnt             = $84
rptr            = $86
rend            = $88
prevcr          = $8A
nlines          = $8B           ; 16 bits : lignes demandées
count           = $8D           ; 16 bits : lignes affichées
last            = $8F
tmp             = $90
                * = $0800
                jmp     main
                .include "neoext.inc"
                .include "textfile.inc"

main            jsr     tf_args
                bcc     +
                jsr     fail
                #println "Usage: HEAD [/n] file"
                rts
+               jsr     tf_open
                bcs     _r
                stz     count
                stz     count+1
                lda     #CR
                sta     last
_line           lda     count                   ; count = nlines : fini
                cmp     nlines
                bne     _char
                lda     count+1
                cmp     nlines+1
                beq     _end
_char           jsr     tf_char
                bcs     _end
                sta     last
                jsr     tf_put
                lda     last
                cmp     #CR
                bne     _char
                inc     count
                bne     _line
                inc     count+1
                bra     _line
_end            lda     last                    ; dernière ligne sans fin
                cmp     #CR
                beq     +
                jsr     newline
+               jmp     tf_close
_r              rts

argbuf          .fill   122
filebuf         .fill   122
