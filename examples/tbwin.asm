; tbwin.asm — programme de test (Trinity T-88) : ouvre une fenêtre de la
; toolbox (32,1 InitGraf, 34,1 New Window) puis rend la main sans la fermer.
; NeoDOS doit appeler 32,19 Toolbox Reset au retour : le programme suivant
; ne doit pas en hériter (TBFRONT affiche alors « Front window 0 »).
; Avec -D SMASH=1 (TBWINX) : écrase aussi $B800-$FBFF avant de rendre la
; main, pour le chemin où NeoDOS est rechargé depuis le disque.
;   make fixtures  ->  tests/fixtures/POKER/TBWIN.NEO, TBWINX.NEO
WaitMessage     = $FFF4
SendMessage     = $FFF7
DParams         = $FF04
                .weak
SMASH           = 0                     ; -D SMASH=1 : TBWINX
                .endweak
                * = $0800
                jsr     SendMessage             ; 32,1 InitGraf
                .byte   32, 1
                jsr     WaitMessage
                lda     #<rect                  ; 34,1 New Window : cadre,
                sta     DParams                 ; titre, barre de titre
                lda     #>rect
                sta     DParams+1
                lda     #<title
                sta     DParams+2
                lda     #>title
                sta     DParams+3
                lda     #1
                sta     DParams+4
                jsr     SendMessage
                .byte   34, 1
                jsr     WaitMessage
                .if     SMASH
                lda     #$B8
                sta     $81
                stz     $80
                ldy     #0
                lda     #0
-               sta     ($80),y
                iny
                bne     -
                inc     $81
                lda     $81
                cmp     #$FC
                bne     -
                .endif
                rts
rect            .word   20, 60, 150, 150
title           .ptext  "Win"
