; CHOICE.asm — commande externe NeoDOS : CHOICE [/C[:]touches] [/N] [texte]
; (syntaxe MS-DOS 6). Affiche le texte puis « [Y,N]? » (sauf /N), attend une
; des touches proposées (YN par défaut ; majuscules et minuscules
; confondues, les autres touches sont ignorées), l'affiche et rend son rang
; dans ERRORLEVEL : 1 pour la première, 2 pour la seconde… À utiliser dans
; un script avec IF ERRORLEVEL (du plus grand au plus petit) ou
; %ERRORLEVEL%. Pas de /S ni de /T. Guillemets autour du texte retirés.
;   make examples  ->  storage/BIN/CHOICE.NEO
ptr             = $80
sptr            = $82
cnt             = $84
idx             = $85           ; position dans la ligne de commande
len             = $86           ; longueur de la ligne de commande
noshow          = $87           ; /N
                * = $0800
                jmp     main
                .include "neoext.inc"

main            lda     #2                      ; touches par défaut : YN
                sta     keys
                lda     #'Y'
                sta     keys+1
                lda     #'N'
                sta     keys+2
                stz     noshow
                stz     len
                stz     cnt                     ; caractères de texte affichés
                ldy     #1
                lda     NEODOS_SIG              ; hors NeoDOS : ligne vide
                cmp     #'N'
                beq     +
                jmp     _text
+
                lda     NEODOS_CMDLINE
                sta     ptr
                lda     NEODOS_CMDLINE+1
                sta     ptr+1
                lda     (ptr)
                sta     len
                ldy     #1
                jsr     skip_sp                 ; nom de la commande
                jsr     skip_word
_opt            jsr     skip_sp
                jsr     at_end
                bcs     _text
                lda     (ptr),y
                cmp     #'/'
                bne     _text
                iny
                jsr     at_end
                bcs     _usage
                lda     (ptr),y
                and     #$DF
                cmp     #'N'
                beq     _n
                cmp     #'C'
                bne     _usage
                iny                             ; /C[:]touches
                jsr     at_end
                bcs     _usage
                lda     (ptr),y
                cmp     #':'
                bne     +
                iny
+               ldx     #0
-               jsr     at_end
                bcs     +
                lda     (ptr),y
                cmp     #' '
                beq     +
                jsr     upper
                inx
                sta     keys,x
                iny
                cpx     #KEYS_MAX
                bne     -
+               stx     keys
                txa
                beq     _usage
                bra     _opt
_n              inc     noshow
                iny
                bra     _opt
_usage          jsr     fail
                #println "Usage: CHOICE [/C[:]keys] [/N] [text]"
                rts
                ; texte : le reste de la ligne, guillemets retirés
_text           sty     idx
_tloop          ldy     idx
                jsr     at_end
                bcs     _list
                lda     (ptr),y
                inc     idx
                cmp     #'"'
                beq     _tloop
                jsr     putc
                sta     sptr                    ; dernier caractère affiché
                inc     cnt
                bra     _tloop
_list           lda     noshow                  ; « [Y,N]? »
                bne     _wait
                lda     cnt                     ; espace après un texte
                beq     +
                lda     sptr
                cmp     #' '
                beq     +
                lda     #' '
                jsr     putc
+               lda     #'['
                jsr     putc
                ldx     #1
-               lda     keys,x
                jsr     putc
                cpx     keys
                beq     +
                lda     #','
                jsr     putc
                inx
                bra     -
+               lda     #']'
                jsr     putc
                lda     #'?'
                jsr     putc
_wait           jsr     getkey
                jsr     upper
                ldx     keys
-               cmp     keys,x
                beq     _got
                dex
                bne     -
                bra     _wait
_got            jsr     putc                    ; la touche, puis fin de ligne
                lda     #CR
                jsr     putc
                txa                             ; rang = ERRORLEVEL
                jmp     exit_code

; at_end : C=1 si Y a dépassé la ligne de commande (len)
at_end          cpy     len
                beq     +
                bcs     _end
+               clc
                rts
_end            sec
                rts
skip_sp         jsr     at_end
                bcs     +
                lda     (ptr),y
                cmp     #' '
                bne     +
                iny
                bra     skip_sp
+               rts
skip_word       jsr     at_end
                bcs     +
                lda     (ptr),y
                cmp     #' '
                beq     +
                iny
                bra     skip_word
+               rts
upper           cmp     #'a'
                bcc     +
                cmp     #'z'+1
                bcs     +
                and     #$DF
+               rts

KEYS_MAX        = 20
keys            .fill   KEYS_MAX+1
argbuf          = $2000                         ; exigé par neoext.inc (cmd_arg), non utilisé
