; waitkey.asm — programme de test façon jeu : lit le clavier par l'état des
; touches (Key Status 1,2) et non par la file de caractères (2,1) ; attend
; l'appui sur Entrée puis rend la main. Tout ce qui a été tapé reste dans la
; file du firmware : NeoDOS doit la vider au retour (kbd_flush, programme
; ayant tourné ≥ 2 s) au lieu d'exécuter la phrase tapée.
;   make fixtures  ->  tests/fixtures/WAITKEY.NEO
WriteCharacter  = $FFF1
WaitMessage     = $FFF4
SendMessage     = $FFF7
DParams         = $FF04
KEY_ENTER       = $28
                * = $0800
                ldx     #0
-               lda     msg,x
                beq     +
                jsr     WriteCharacter
                jsr     WaitMessage
                inx
                bra     -
+
_poll           lda     #KEY_ENTER
                sta     DParams
                jsr     SendMessage
                .byte   1, 2
                jsr     WaitMessage
                lda     DParams
                beq     _poll
                rts
msg             .text   "Type a sentence and press Enter...", 13, 0
