; big.asm — programme de test : image chargée en $B000 et longue de $1100
; octets, donc recouvrant le début de NeoDOS ($B800…) PENDANT le chargement
; (comme legacy.neo, $A000-$FBE6). Le lancement doit survivre : la séquence
; 3,2 + JMP exec s'exécute depuis le stub en $0100 (stub_run), puis le RTS
; final ramène au stub qui recharge NeoDOS depuis /boot/neodos.neo.
;   make fixtures  ->  tests/fixtures/BIG.NEO
WriteCharacter  = $FFF1
WaitMessage     = $FFF4
                * = $B000
                ldx     #0
-               lda     msg,x
                beq     +
                jsr     WriteCharacter
                jsr     WaitMessage
                inx
                bra     -
+               rts
msg             .text   "Big program loaded over NeoDOS...", 13, 0
                .fill   $C100-*, $EA            ; remplissage jusqu'à $C100
