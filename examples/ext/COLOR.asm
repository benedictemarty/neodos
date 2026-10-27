; COLOR.asm — commande externe NeoDOS : COLOR [fe] — couleurs de la console,
; syntaxe DOS : deux chiffres hexadécimaux, fond puis encre (COLOR 1F = encre
; blanc brillant sur fond bleu) ; COLOR seul = 07 (défaut du firmware). Les
; couleurs sont envoyées par les codes de contrôle $90+fond / $80+encre puis
; l'écran est effacé (CLS les conserve). Pour les retrouver à chaque
; démarrage : mettre COLOR dans AUTOEXEC.BAT. Fond = encre : refusé
; (ERRORLEVEL 1), comme DOS.
;   make examples  ->  storage/BIN/COLOR.NEO
ptr             = $80
sptr            = $82
cnt             = $84
paper           = $85
ink             = $86
                * = $0800
                jmp     main
                .include "neoext.inc"

main            lda     #1
                jsr     cmd_arg
                lda     argbuf
                bne     +
                stz     paper                   ; défaut : 07
                lda     #7
                sta     ink
                bra     _apply
+               cmp     #2
                bne     _usage
                lda     argbuf+1
                jsr     hexdigit
                bcs     _usage
                sta     paper
                lda     argbuf+2
                jsr     hexdigit
                bcs     _usage
                sta     ink
                cmp     paper
                beq     _same
_apply          lda     paper
                ora     #$90
                jsr     ctrl
                lda     ink
                ora     #$80
                jsr     ctrl
                #api    2,12                    ; Clear Screen
                rts
_same           #println "Same foreground and background color."
                jmp     fail
_usage          #println "Usage: COLOR [fe]  (hex: f=background e=foreground)"
                #println "COLOR 1F = bright white on blue; COLOR = 07."
                jmp     fail

; ctrl : envoie un code de contrôle directement à la console
ctrl            jsr     WriteCharacter
                jsr     WaitMessage
                rts

; hexdigit : A = '0'-'9', 'A'-'F', 'a'-'f' -> 0-15, C=0 ; sinon C=1
hexdigit        cmp     #'a'
                bcc     +
                cmp     #'z'+1
                bcs     +
                and     #$DF                    ; majuscule
+
                cmp     #'0'
                bcc     _bad
                cmp     #'9'+1
                bcc     _num
                cmp     #'A'
                bcc     _bad
                cmp     #'F'+1
                bcs     _bad
                sbc     #'A'-11                 ; C=0 ici : A-'A'+10
                clc
                rts
_num            sbc     #'0'-1                  ; C=0 ici : A-'0'
                clc
                rts
_bad            sec
                rts
argbuf          .fill   122
