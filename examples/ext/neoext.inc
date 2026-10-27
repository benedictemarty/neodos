; neoext.inc — base des commandes externes NeoDOS (programmes .NEO en $0800)
;
; Contrat NeoDOS (ADR-003, base $B800 depuis 0.14.0 / ADR-004) : en-tête en
; NEODOS_BASE — +3 « NEODOS », +9 version, +12 pointeur vers la ligne de
; commande (pstring), +14 vecteur putc, +16 code de retour (fail/exit_code).
; Zone libre pour le programme :
; $0800-$B7FF (ne pas écrire dans $B800-$FBFF si l'on veut revenir vite à
; l'invite ; sinon NeoDOS se recharge). Retour par RTS.

ReadCharacter   = $FFEE
WriteCharacter  = $FFF1
WaitMessage     = $FFF4
SendMessage     = $FFF7
DCommand        = $FF00
DFunction       = $FF01
DError          = $FF02
DParams         = $FF04
NEODOS_BASE     = $B800
NEODOS_SIG      = NEODOS_BASE+3
NEODOS_CMDLINE  = NEODOS_BASE+12
NEODOS_PUTC     = NEODOS_BASE+14
NEODOS_ERRLVL   = NEODOS_BASE+16 ; code de retour lu par NeoDOS (IF ERRORLEVEL), 0.16.0
CR              = 13

api             .macro
                jsr     SendMessage
                .byte   \1, \2
                jsr     WaitMessage
                .endm
print           .macro
                jsr     puts
                .null   \1
                .endm
println         .macro
                jsr     puts
                .text   \1
                .byte   CR, 0
                .endm
setparam        .macro
                lda     #<\2
                sta     DParams+\1
                lda     #>\2
                sta     DParams+\1+1
                .endm

; putc : écrit A (préservé) — par NeoDOS s'il est là (redirection « > »
; honorée), sinon directement par le noyau
putc            pha
                lda     NEODOS_SIG
                cmp     #'N'
                bne     _direct
                lda     NEODOS_SIG+1
                cmp     #'E'
                bne     _direct
                pla
                jmp     (NEODOS_PUTC)
_direct         pla
                pha
                jsr     WriteCharacter
                jsr     WaitMessage
                pla
                rts
newline         lda     #CR
                jmp     putc

; puts : texte inline terminé par 0
puts            pla
                sta     sptr
                pla
                sta     sptr+1
                phy
                ldy     #0
_next           inc     sptr
                bne     +
                inc     sptr+1
+               lda     (sptr),y
                beq     _done
                jsr     putc
                bra     _next
_done           ply
                lda     sptr+1
                pha
                lda     sptr
                pha
                rts

; putpstr : pstring pointée par ptr
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

; fail : ERRORLEVEL 1 pour NeoDOS (IF ERRORLEVEL 1 après la commande) ;
; sans NeoDOS : rien. exit_code : A -> ERRORLEVEL.
fail            lda     #1
exit_code       pha
                lda     NEODOS_SIG
                cmp     #'N'
                bne     _no
                lda     NEODOS_SIG+1
                cmp     #'E'
                bne     _no
                pla
                sta     NEODOS_ERRLVL
                rts
_no             pla
                rts

; getkey : attend une touche -> A
getkey          #api    2,1
                lda     DParams
                beq     getkey
                rts

; stat_path : Stat (3,16) du chemin déjà placé dans Parameter:0 ; sur la
; carte, FatFs répond FR_INVALID_NAME ($14) pour le répertoire d'origine
; (« . », « / ») : on le convertit en « répertoire existant » (DError = 0,
; attribut répertoire) ; Z=1 si pas d'erreur
stat_path       #api    3,16
                lda     DError
                cmp     #$14
                bne     _done
                stz     DError
                lda     #1                      ; attribut répertoire
                sta     DParams+4
                lda     #0
_done           rts

; cmd_arg : copie le mot n° A (0 = nom du programme) de la ligne de commande
; NeoDOS dans argbuf (pstring) ; argbuf vide si absent ou hors NeoDOS
cmd_arg         sta     cnt
                stz     argbuf
                lda     NEODOS_SIG
                cmp     #'N'
                bne     _done
                lda     NEODOS_SIG+1
                cmp     #'E'
                bne     _done
                lda     NEODOS_CMDLINE
                sta     ptr
                lda     NEODOS_CMDLINE+1
                sta     ptr+1
                ldy     #1
_skip           tya                             ; sauter les espaces
                cmp     (ptr)
                beq     +
                bcs     _done
+               lda     (ptr),y
                cmp     #' '
                bne     _word
                iny
                bra     _skip
_word           lda     cnt
                beq     _copy
                dec     cnt
-               tya                             ; sauter ce mot
                cmp     (ptr)
                beq     +
                bcs     _done
+               lda     (ptr),y
                cmp     #' '
                beq     _skip
                iny
                bra     -
_copy           ldx     #0
-               tya
                cmp     (ptr)
                beq     +
                bcs     _end
+               lda     (ptr),y
                cmp     #' '
                beq     _end
                cmp     #'\'
                bne     +
                lda     #'/'
+               inx
                sta     argbuf,x
                iny
                cpx     #120
                bne     -
_end            stx     argbuf
_done           rts
