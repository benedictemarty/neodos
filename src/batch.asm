; batch.asm — exécution des fichiers .BAT (AUTOEXEC.BAT au démarrage)
;
; Le fichier est chargé en entier dans batbuf (1 Ko maximum) puis exécuté
; ligne par ligne. Un programme .NEO lancé depuis un batch rend la main au
; batch s'il se termine par RTS (et s'il n'a pas écrasé $D000-$FBFF) ; un
; .BAT lancé depuis un .BAT le remplace (comme MS-DOS sans CALL).

; ---------------------------------------------------------------------------
; run_autoexec : exécute AUTOEXEC.BAT s'il existe dans le répertoire courant
; ---------------------------------------------------------------------------
run_autoexec    ldx     #0
-               lda     autoexec_name,x
                sta     namebuf,x
                inx
                cpx     #13
                bne     -
                jsr     stat_namebuf
                bne     _none
                jmp     run_batch
_none           rts

autoexec_name   .ptext  "AUTOEXEC.BAT"

; ---------------------------------------------------------------------------
; run_batch : namebuf = nom du fichier (stat déjà fait : taille en DParams)
; ---------------------------------------------------------------------------
run_batch       lda     DParams+2               ; taille > 65535 ?
                ora     DParams+3
                bne     _big
                lda     DParams
                sta     blen
                lda     DParams+1
                sta     blen+1
                cmp     #>BATBUF_SIZE           ; taille > 1024 ?
                bcc     _load
                bne     _big
                lda     blen
                beq     _load
_big            jmp     batch_toobig
_load           #setparam 0, namebuf
                #setparam 2, batbuf
                #api    3,2
                lda     DError
                beq     +
                jsr     err_api
                jmp     mainloop
+               stz     bptr
                stz     bptr+1
                lda     #1
                sta     bat_active
batch_next
_line           ; fin du tampon ?
                lda     bptr
                cmp     blen
                lda     bptr+1
                sbc     blen+1
                bcs     _end
                ; copie la ligne dans linebuf
                lda     #<batbuf
                clc
                adc     bptr
                sta     ptr
                lda     #>batbuf
                adc     bptr+1
                sta     ptr+1
                ldx     #0
                ldy     #0
_copy           lda     bptr                    ; fin du tampon ?
                cmp     blen
                lda     bptr+1
                sbc     blen+1
                bcs     _eol
                lda     (ptr),y
                inc     bptr
                bne     +
                inc     bptr+1
+               cmp     #CR
                beq     _eol
                cmp     #10
                beq     _eol
                cpx     #200
                beq     _copy                   ; ligne trop longue : tronquée
                inx
                sta     linebuf,x
                iny
                bra     _copy
_eol            stx     linebuf
                ; ligne vide ?
                cpx     #0
                beq     _line
                ; « @ » en tête : pas d'écho
                lda     linebuf+1
                cmp     #'@'
                bne     _echo
                ; décale la ligne d'un caractère
                ldy     #2
-               lda     linebuf,y
                sta     linebuf-1,y
                iny
                cpy     linebuf
                beq     -
                bcc     -
                dec     linebuf
                bra     _exec
_echo           lda     echo_off
                bne     _exec
                jsr     show_prompt
                #setptr ptr, linebuf
                jsr     putpstr
                jsr     newline
_exec           lda     linebuf
                beq     _line
                jsr     execute_line
                jmp     _line
_end            stz     bat_active
                stz     echo_off
                jmp     mainloop
batch_toobig    #println "Batch file too large (max 1024 bytes)"
                jmp     mainloop
