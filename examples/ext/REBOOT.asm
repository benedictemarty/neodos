; REBOOT.asm — commande externe NeoDOS : REBOOT — reset matériel complet
; (fonction 1,7 : le RP2040 redémarre par son watchdog, le 65C02 avec lui).
; Complément froid de Ctrl+Alt+Suppr (redémarrage à chaud de NeoDOS seul).
; Sur la carte, 1,7 ne revient jamais ; si elle revient (émulateur sans
; reset matériel), message et ERRORLEVEL 1.
;   make examples  ->  storage/BIN/REBOOT.NEO
ptr             = $80
sptr            = $82
cnt             = $84
                * = $0800
                jmp     main
                .include "neoext.inc"

main            lda     #1
                jsr     cmd_arg                 ; un argument (/? ou autre) : usage
                lda     argbuf
                beq     _go
                #println "Usage: REBOOT"
                #println "Hardware reset (Ctrl+Alt+Del: NeoDOS only)."
                jmp     fail
_go             #api    1,7                     ; System Reset (ne revient pas)
                #println "Hardware reset not available."
                jmp     fail
argbuf          .fill   122
