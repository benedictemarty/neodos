; tbfront.asm — programme de test (Trinity T-88) : affiche la fenêtre de la
; toolbox au premier plan (34,10 Front Window), « Front window 0 » si aucune.
;   make fixtures  ->  tests/fixtures/POKER/TBFRONT.NEO
WriteCharacter  = $FFF1
WaitMessage     = $FFF4
SendMessage     = $FFF7
DParams         = $FF04
                * = $0800
                jsr     SendMessage             ; 34,10 Front Window
                .byte   34, 10
                jsr     WaitMessage
                lda     DParams
                clc
                adc     #'0'                    ; 0-8
                sta     msg_n
                ldx     #0
-               lda     msg,x
                beq     +
                jsr     WriteCharacter
                jsr     WaitMessage
                inx
                bra     -
+               rts
msg             .text   "Front window "
msg_n           .text   "?", 13, 0
