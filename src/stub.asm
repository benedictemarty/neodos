; stub.asm — stub de retour des programmes (comment NeoDOS « survit »)
;
; Un programme lancé par NeoDOS peut écraser $C000-$FBFF (pile C de llvm-mos
; en $F600, programme de 60 Ko…). Comme le firmware recharge NeoBASIC depuis
; la flash à chaque 1,3, NeoDOS se recharge depuis le disque : avant le
; lancement, ce stub est copié en $0100 (bas de la page pile, que la pile
; matérielle n'atteint qu'au-delà de 240 octets) et son adresse est poussée
; comme adresse de retour. Au RTS du programme, le stub vérifie NeoDOS
; (somme de contrôle du code, sentinelles des données) : intact → reprise
; normale (batch en cours, invite) ; sinon → rechargement de
; /boot/neodos.neo puis /neodos.neo (3,2 + $FF08) ; en dernier recours,
; retour à NeoBASIC (1,3).

; EXIT emprunte aussi ce stub (stub_exit) : 1,3 charge l'image résidente
; par-dessus $B800-$FBFF, donc l'appel et le jmp (0) qui suit ne peuvent pas
; s'exécuter depuis le code de NeoDOS lui-même (au retour de WaitMessage, le
; CPU reprendrait dans la nouvelle image, à une adresse quelconque).

; install_stub : copie le stub en $0100 et y inscrit la somme de contrôle du
; code ($C000..codeend-1), calculée par la routine du stub lui-même.
install_stub    ldx     #0                      ; (stub_len > 128 : pas de bpl)
-               lda     stub_image,x
                sta     STUB_BASE,x
                inx
                cpx     #stub_len
                bne     -
                jsr     STUB_BASE+(sum_code-stub_start)
                lda     $82
                sta     STUB_BASE+(stub_sum-stub_start)
                lda     $83
                sta     STUB_BASE+(stub_sum-stub_start)+1
                rts

; --- image du stub (assemblée pour $0100, copiée à chaque lancement) -------
stub_image
                .logical STUB_BASE
stub_start      ldx     #$ff
                txs
                ; sentinelles des données
                lda     canary_lo
                cmp     #CANARY
                bne     _reload
                lda     canary_hi
                cmp     #CANARY
                bne     _reload
                jsr     sum_code                ; somme de contrôle du code
                lda     $82
                cmp     stub_sum
                bne     _reload
                lda     $83
                cmp     stub_sum+1
                bne     _reload
                jmp     neodos_back             ; NeoDOS intact : reprise
_reload         ldx     #0                      ; recharge depuis le disque
_try            lda     stub_names,x
                sta     $FF04
                lda     stub_names+1,x
                sta     $FF05
                stz     $FF06
                stz     $FF07
                lda     #2                      ; 3,2 Load File
                sta     $FF01
                lda     #3
                sta     $FF00
-               lda     $FF00
                bne     -
                lda     $FF02
                beq     _go
                inx
                inx
                cpx     #4
                bne     _try
_exit           lda     #3                      ; échec : environnement résident
                sta     $FF01                   ; (1,3) — aussi le chemin de EXIT
                lda     #1
                sta     $FF00
-               lda     $FF00
                bne     -
                jmp     (0)
_go             jmp     $FF08                   ; JMP exec de NeoDOS rechargé
; sum_code : somme 16 bits de sum_start..codeend-1 -> $82/$83 (page zéro
; NeoDOS : ptr et ptr2, libres à ce moment). Commence après l'en-tête
; (jmp/signature/version/pointeurs) : hdr_errlvl (base+16) est écrit par les
; programmes et ne doit pas fausser la somme.
sum_start       = NEODOS_BASE+17
sum_code        lda     #<sum_start
                sta     $80
                lda     #>sum_start
                sta     $81
                stz     $82
                stz     $83
                ldy     #0
_sum            lda     ($80),y
                clc
                adc     $82
                sta     $82
                bcc     +
                inc     $83
+               inc     $80
                bne     +
                inc     $81
+               lda     $80
                cmp     #<codeend
                bne     _sum
                lda     $81
                cmp     #>codeend
                bne     _sum
                rts
stub_sum        .word   0
stub_names      .word   name_boot, name_root
name_boot       .ptext  "/boot/neodos.neo"
name_root       .ptext  "/neodos.neo"
stub_end
                .here
stub_len        = stub_end-stub_start
stub_exit       = stub_start._exit          ; entrée de EXIT (1,3 + jmp (0))
