; console.asm — sortie console : caractères, chaînes, nombres décimaux

; ---------------------------------------------------------------------------
; putc : écrit A sur la console et attend la fin de la commande (ainsi aucun
; appel API n'est en cours quand l'appelant prépare des paramètres).
; Préserve A, X, Y.
; ---------------------------------------------------------------------------
putc            bit     redir
                bmi     +
                jsr     WriteCharacter
                jsr     WaitMessage
                rts
+               jmp     redir_put

newline         pha
                lda     #CR
                jsr     putc
                pla
                rts

space           pha
                lda     #' '
                jsr     putc
                pla
                rts

; ---------------------------------------------------------------------------
; puts : affiche le texte inline (terminé par 0) qui suit le JSR.
; Utilise ptr. Préserve X, Y.
; ---------------------------------------------------------------------------
puts            pla
                sta     sptr
                pla
                sta     sptr+1
                phy
                ldy     #0
_next           inc     sptr                     ; pré-incrément : l'adresse de
                bne     +                       ; retour pointe l'octet avant
                inc     sptr+1                   ; le texte
+               lda     (sptr),y
                beq     _done
                jsr     putc
                bra     _next
_done           ply
                lda     sptr+1                   ; sptr = terminateur ; RTS
                pha                             ; reprend à sptr+1
                lda     sptr
                pha
                rts

; ---------------------------------------------------------------------------
; putpstr : affiche la chaîne à préfixe de longueur pointée par ptr.
; ---------------------------------------------------------------------------
putpstr         phy
                lda     (ptr)
                beq     _done
                sta     cnt
                ldy     #1
_loop           lda     (ptr),y
                jsr     putc
                iny
                dec     cnt
                bne     _loop
_done           ply
                rts

; putpstr_dos : comme putpstr, en affichant « / » comme « \ »
putpstr_dos     phy
                lda     (ptr)
                beq     _done
                sta     cnt
                ldy     #1
_loop           lda     (ptr),y
                cmp     #'/'
                bne     +
                lda     #'\'
+               jsr     putc
                iny
                dec     cnt
                bne     _loop
_done           ply
                rts

; ---------------------------------------------------------------------------
; putpstr_pad : comme putpstr puis complète avec des espaces jusqu'à X
; colonnes (si la chaîne est plus longue, un seul espace).
; ---------------------------------------------------------------------------
putpstr_pad     stx     tmp
                jsr     putpstr
                lda     (ptr)
                cmp     tmp
                bcs     _one
                sec
                lda     tmp
                sbc     (ptr)
                tax
_loop           jsr     space
                dex
                bne     _loop
                rts
_one            jsr     space
                rts

; ---------------------------------------------------------------------------
; spaces : affiche X espaces (X = 0 : aucun)
; ---------------------------------------------------------------------------
spaces          cpx     #0
                beq     _done
_loop           jsr     space
                dex
                bne     _loop
_done           rts

; ---------------------------------------------------------------------------
; print32 : affiche num (32 bits) en décimal, cadré à droite sur X colonnes
; (X = 0 : sans cadrage). Détruit num.
; Méthode : soustractions successives des puissances de 10 (table).
; ---------------------------------------------------------------------------
print32         stx     tmp                     ; largeur demandée
                ldx     #0                      ; X = nombre de chiffres produits
                stz     flag                    ; flag = un chiffre non nul vu
                ldy     #0                      ; Y = index puissance de 10
_power          lda     #0
                sta     digitbuf,x              ; compte de soustractions
_sub            ; num >= pow10[y] ?
                lda     num
                cmp     pow10+0,y
                lda     num+1
                sbc     pow10+1,y
                lda     num+2
                sbc     pow10+2,y
                lda     num+3
                sbc     pow10+3,y
                bcc     _nextpow
                lda     num                     ; num -= pow10[y]
                sbc     pow10+0,y
                sta     num
                lda     num+1
                sbc     pow10+1,y
                sta     num+1
                lda     num+2
                sbc     pow10+2,y
                sta     num+2
                lda     num+3
                sbc     pow10+3,y
                sta     num+3
                inc     digitbuf,x
                bra     _sub
_nextpow        inx
                iny
                iny
                iny
                iny
                cpy     #40                     ; 10 puissances (10^9 .. 10^0)
                bne     _power
                ; supprimer les zéros de tête (garder le dernier chiffre)
                ldx     #0
_lead           lda     digitbuf,x
                bne     _found
                inx
                cpx     #9
                bne     _lead
_found          stx     idx                     ; idx = premier chiffre utile
                lda     #10
                sec
                sbc     idx                     ; nombre de chiffres à afficher
                sta     cnt
                lda     tmp                     ; cadrage
                beq     _print
                sec
                sbc     cnt
                bcc     _print
                beq     _print
                tax
                jsr     spaces
_print          ldx     idx
_digit          lda     digitbuf,x
                ora     #'0'
                jsr     putc
                inx
                cpx     #10
                bne     _digit
                rts

; print16 : affiche A (bas) / Y (haut) 16 bits, cadré sur X colonnes
print16         sta     num
                sty     num+1
                stz     num+2
                stz     num+3
                jmp     print32

; print8 : affiche A (8 bits) en décimal sans cadrage
print8          ldx     #0
                jmp     print8_pad

; print2 : affiche A (0-99) sur deux chiffres avec zéro de tête
print2          ldx     #0
-               cmp     #10
                bcc     +
                sbc     #10
                inx
                bra     -
+               pha
                txa
                ora     #'0'
                jsr     putc
                pla
                ora     #'0'
                jsr     putc
                rts

pow10           .dword  1000000000, 100000000, 10000000, 1000000, 100000
                .dword  10000, 1000, 100, 10, 1

; print8_pad : affiche A (8 bits) en décimal cadré sur X colonnes
print8_pad      sta     num
                stz     num+1
                stz     num+2
                stz     num+3
                jmp     print32
