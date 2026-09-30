; pages.asm — programme de test (demande Trinity du 2026-09-30, F-55) : rend la
; main en mode 1 (deux pages) avec la page de dessin 1 et la page affichée 0,
; comme BattleNeo en mode 2 ; NeoDOS doit réaligner les pages au retour.
;   make fixtures  ->  tests/fixtures/POKER/PAGES.NEO
WaitMessage     = $FFF4
SendMessage     = $FFF7
DParams         = $FF04
                * = $0800
                lda     #1
                sta     DParams
                jsr     SendMessage             ; 5,9 Set Mode : 1 (deux pages)
                .byte   5, 9
                jsr     WaitMessage
                lda     #1
                sta     DParams
                jsr     SendMessage             ; 5,11 Set Draw Page : 1
                .byte   5, 11
                jsr     WaitMessage
                stz     DParams
                jsr     SendMessage             ; 5,12 Set Display Page : 0
                .byte   5, 12
                jsr     WaitMessage
                rts
