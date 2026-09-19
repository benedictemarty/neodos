; commands.asm — commandes internes de NeoDOS

; ---------------------------------------------------------------------------
; Table des commandes : pstring du nom, adresse ; terminée par un 0
; ---------------------------------------------------------------------------
cmdtable        .ptext  "DIR"
                .word   cmd_dir
                .ptext  "CD"
                .word   cmd_cd
                .ptext  "CHDIR"
                .word   cmd_cd
                .ptext  "MD"
                .word   cmd_md
                .ptext  "MKDIR"
                .word   cmd_md
                .ptext  "RD"
                .word   cmd_rd
                .ptext  "RMDIR"
                .word   cmd_rd
                .ptext  "DEL"
                .word   cmd_del
                .ptext  "ERASE"
                .word   cmd_del
                .ptext  "REN"
                .word   cmd_ren
                .ptext  "RENAME"
                .word   cmd_ren
                .ptext  "COPY"
                .word   cmd_copy
                .ptext  "TYPE"
                .word   cmd_type
                .ptext  "CLS"
                .word   cmd_cls
                .ptext  "VER"
                .word   cmd_ver
                .ptext  "VOL"
                .word   cmd_vol
                .ptext  "ECHO"
                .word   cmd_echo
                .ptext  "REM"
                .word   cmd_rem
                .ptext  "PAUSE"
                .word   cmd_pause
                .ptext  "DATE"
                .word   cmd_date
                .ptext  "TIME"
                .word   cmd_time
                .ptext  "MEM"
                .word   cmd_mem
                .ptext  "HELP"
                .word   cmd_help
                .ptext  "EXIT"
                .word   cmd_exit
                .ptext  "BASIC"
                .word   cmd_exit
                .byte   0

; ---------------------------------------------------------------------------
; DIR [chemin] : liste un répertoire au format DOS
; ---------------------------------------------------------------------------
cmd_dir         #setptr ptr, arg1
                jsr     to_apipath
                lda     arg1
                bne     +
                lda     #1                      ; sans argument : « . »
                sta     arg1
                lda     #'.'
                sta     arg1+1
+               #setparam 0, arg1
                #api    3,17                    ; Open Directory
                lda     DError
                beq     +
                jmp     err_api
+               #print  " Volume in drive "
                #api    3,26
                lda     DParams
                clc
                adc     #'A'
                jsr     putc
                #print  " is "
                jsr     print_volname
                jsr     newline
                #print  " Directory of "
                jsr     build_prompt            ; « A:\chemin> »
                dec     promptbuf               ; sans le « > »
                lda     arg1                    ; chemin demandé (sauf « . »)
                cmp     #1
                bne     _witharg
                lda     arg1+1
                cmp     #'.'
                bne     _witharg
                #setptr ptr, promptbuf
                jsr     putpstr
                bra     _hdr
_witharg        lda     arg1+1                  ; chemin absolu : « A: » + chemin
                cmp     #'/'
                bne     _relative
                lda     #2
                sta     promptbuf
                #setptr ptr, promptbuf
                jsr     putpstr
                bra     _showarg
_relative       #setptr ptr, promptbuf
                jsr     putpstr
                ldx     promptbuf               ; racine : pas de second « \ »
                lda     promptbuf,x
                cmp     #'\'
                beq     _showarg
                lda     #'\'
                jsr     putc
_showarg        #setptr ptr, arg1
                jsr     putpstr_dos
_hdr            jsr     newline
                jsr     newline
                stz     nfiles
                stz     nfiles+1
                stz     ndirs
                stz     ndirs+1
                stz     total
                stz     total+1
                stz     total+2
                stz     total+3
_entry          lda     #100
                sta     namebuf
                #setparam 0, namebuf
                #api    3,18                    ; Read Directory
                lda     DError
                bne     _end
                #setptr ptr, namebuf
                ldx     #16
                jsr     putpstr_pad
                lda     DParams+6
                and     #ATTR_DIR
                beq     _file
                #print  "     <DIR>"
                inc     ndirs
                bne     +
                inc     ndirs+1
+               jsr     newline
                bra     _entry
_file           lda     DParams+2               ; taille -> num et total
                sta     num
                clc
                adc     total
                sta     total
                lda     DParams+3
                sta     num+1
                adc     total+1
                sta     total+1
                lda     DParams+4
                sta     num+2
                adc     total+2
                sta     total+2
                lda     DParams+5
                sta     num+3
                adc     total+3
                sta     total+3
                ldx     #10
                jsr     print32
                jsr     newline
                inc     nfiles
                bne     _entry
                inc     nfiles+1
                bra     _entry
_end            #api    3,19                    ; Close Directory
                lda     nfiles
                ldy     nfiles+1
                ldx     #9
                jsr     print16
                #print  " file(s) "
                lda     total
                sta     num
                lda     total+1
                sta     num+1
                lda     total+2
                sta     num+2
                lda     total+3
                sta     num+3
                ldx     #10
                jsr     print32
                #println " bytes"
                lda     ndirs
                ldy     ndirs+1
                ldx     #9
                jsr     print16
                #println " dir(s)"
                rts

; print_volname : nom du volume courant
print_volname   #api    3,26                    ; Parameter:0 = volume courant
                lda     #32
                sta     namebuf
                #setparam 1, namebuf
                #api    3,24
                lda     DError
                bne     _unk
                #setptr ptr, namebuf
                jmp     putpstr
_unk            #print  "?"
                rts

; ---------------------------------------------------------------------------
; CD [chemin] : change ou affiche le répertoire courant
; ---------------------------------------------------------------------------
cmd_cd          lda     arg1
                bne     _chdir
                jsr     build_prompt
                dec     promptbuf
                #setptr ptr, promptbuf
                jsr     putpstr
                jmp     newline
_chdir          #setptr ptr, arg1
                jsr     to_apipath
                #setparam 0, arg1
                #api    3,15
                lda     DError
                beq     _ok
                #println "Invalid directory"
_ok             rts

; ---------------------------------------------------------------------------
; MD chemin : crée un répertoire
; ---------------------------------------------------------------------------
cmd_md          lda     arg1
                beq     _syntax
                #setptr ptr, arg1
                jsr     to_apipath
                #setparam 0, arg1
                #api    3,14
                lda     DError
                beq     _ok
                #println "Unable to create directory"
_ok             rts
_syntax         jmp     err_syntax

; ---------------------------------------------------------------------------
; RD chemin : supprime un répertoire vide
; ---------------------------------------------------------------------------
cmd_rd          lda     arg1
                beq     _syntax
                #setptr ptr, arg1
                jsr     to_apipath
                #setparam 0, arg1
                #api    3,16                    ; doit être un répertoire
                lda     DError
                bne     _bad
                lda     DParams+4
                and     #ATTR_DIR
                beq     _bad
                #setparam 0, arg1
                #api    3,13
                lda     DError
                beq     _ok
_bad            #println "Invalid path, not directory, or directory not empty"
_ok             rts
_syntax         jmp     err_syntax

; ---------------------------------------------------------------------------
; DEL fichier : supprime un fichier (pas un répertoire)
; ---------------------------------------------------------------------------
cmd_del         lda     arg1
                beq     _syntax
                #setptr ptr, arg1
                jsr     to_apipath
                #setparam 0, arg1
                #api    3,16
                lda     DError
                bne     _nf
                lda     DParams+4
                and     #ATTR_DIR
                bne     _denied
                #setparam 0, arg1
                #api    3,13
                lda     DError
                beq     _ok
_nf             jmp     err_notfound
_denied         jmp     err_denied
_ok             rts
_syntax         jmp     err_syntax

; ---------------------------------------------------------------------------
; REN ancien nouveau
; ---------------------------------------------------------------------------
cmd_ren         lda     arg1
                beq     _syntax
                lda     arg2
                beq     _syntax
                #setptr ptr, arg1
                jsr     to_apipath
                #setptr ptr, arg2
                jsr     to_apipath
                #setparam 0, arg1
                #setparam 2, arg2
                #api    3,12
                lda     DError
                beq     _ok
                #println "Duplicate file name or file not found"
_ok             rts
_syntax         jmp     err_syntax

; ---------------------------------------------------------------------------
; COPY source destination
; ---------------------------------------------------------------------------
cmd_copy        lda     arg1
                beq     _syntax
                lda     arg2
                beq     _syntax
                #setptr ptr, arg1
                jsr     to_apipath
                #setptr ptr, arg2
                jsr     to_apipath
                #setparam 0, arg1
                #api    3,16                    ; la source doit exister
                lda     DError
                bne     _nf
                #setparam 0, arg1
                #setparam 2, arg2
                #api    3,20
                lda     DError
                bne     _err
                #println "        1 file(s) copied"
                rts
_nf             jmp     err_notfound
_err            jmp     err_api
_syntax         jmp     err_syntax

; ---------------------------------------------------------------------------
; TYPE fichier : affiche un fichier texte
; ---------------------------------------------------------------------------
cmd_type        lda     arg1
                bne     +
                jmp     err_syntax
+
                #setptr ptr, arg1
                jsr     to_apipath
                lda     #CH_IO
                sta     DParams
                #setparam 1, arg1
                stz     DParams+3               ; lecture seule
                #api    3,4
                lda     DError
                bne     _nf
                stz     flag                    ; dernier caractère = CR ?
_block          lda     #CH_IO
                sta     DParams
                #setparam 1, iobuf
                stz     DParams+3
                lda     #1
                sta     DParams+4               ; 256 octets
                #api    3,8
                lda     DError
                bne     _close
                lda     DParams+3               ; octets lus (bas)
                ora     DParams+4
                beq     _close
                lda     DParams+3
                sta     cnt
                ldx     #0
_char           lda     iobuf,x
                cmp     #10                     ; LF : saut sauf après CR
                bne     _notlf
                lda     flag
                bne     _skip
                lda     #CR
_notlf          cmp     #CR
                beq     _cr
                cmp     #9                      ; tabulation -> espace
                bne     +
                lda     #' '
+               cmp     #32
                bcc     _skip                   ; autres codes de contrôle
                stz     flag
                jsr     putc
                bra     _skip
_cr             jsr     putc
                lda     #1
                sta     flag
_skip           inx
                dec     cnt
                bne     _char
                bra     _block                  ; jusqu'à une lecture vide
_close          lda     #CH_IO
                sta     DParams
                #api    3,5
                lda     flag
                bne     _ok
                jsr     newline
_ok             rts
_nf             jmp     err_notfound
_syntax         jmp     err_syntax

; ---------------------------------------------------------------------------
; CLS
; ---------------------------------------------------------------------------
cmd_cls         #api    2,12
                rts

; ---------------------------------------------------------------------------
; VER : version de NeoDOS et du firmware
; ---------------------------------------------------------------------------
cmd_ver         jsr     newline
                #println "NeoDOS version " .. VERSION
                #print  "Neo6502 firmware "
                #api    1,11
                lda     DParams
                jsr     print8
                lda     #'.'
                jsr     putc
                lda     DParams+1
                jsr     print8
                lda     #'.'
                jsr     putc
                lda     DParams+2
                jsr     print8
                jsr     newline
                jmp     newline

; ---------------------------------------------------------------------------
; VOL : volume courant
; ---------------------------------------------------------------------------
cmd_vol         #print  " Volume in drive "
                #api    3,26
                lda     DParams
                clc
                adc     #'A'
                jsr     putc
                #print  " is "
                jsr     print_volname
                jmp     newline

; ---------------------------------------------------------------------------
; ECHO [ON|OFF|texte]
; ---------------------------------------------------------------------------
cmd_echo        lda     argrest
                bne     _text
                #print  "ECHO is "
                lda     echo_off
                bne     _off
                #println "on"
                rts
_off            #println "off"
                rts
_text           cmp     #1                      ; « ECHO. » : ligne vide
                bne     +
                lda     argrest+1
                cmp     #'.'
                bne     _print
                jmp     newline
+               cmp     #2                      ; ON / OFF ?
                beq     _on2
                cmp     #3
                bne     _print
                lda     argrest+1
                jsr     upper
                cmp     #'O'
                bne     _print
                lda     argrest+2
                jsr     upper
                cmp     #'F'
                bne     _print
                lda     argrest+3
                jsr     upper
                cmp     #'F'
                bne     _print
                lda     #1
                sta     echo_off
                rts
_on2            lda     argrest+1
                jsr     upper
                cmp     #'O'
                bne     _print
                lda     argrest+2
                jsr     upper
                cmp     #'N'
                bne     _print
                stz     echo_off
                rts
_print          #setptr ptr, argrest
                jsr     putpstr
                jmp     newline

; REM : commentaire
cmd_rem         rts

; PAUSE : attend une touche
cmd_pause       #println "Press any key to continue . . ."
_wait           #api    2,1
                lda     DParams
                beq     _wait
                rts

; ---------------------------------------------------------------------------
; DATE [aaaa-mm-jj] / TIME [hh:mm[:ss]]
; ---------------------------------------------------------------------------
cmd_date        lda     arg1
                bne     _set
                #print  "Current date is "
                #api    1,20
                lda     DParams
                ldy     DParams+1
                ldx     #0
                jsr     print16                 ; année
                lda     #'-'
                jsr     putc
                lda     DParams+2
                jsr     print2
                lda     #'-'
                jsr     putc
                lda     DParams+3
                jsr     print2
                jmp     newline
_set            #api    1,20                    ; lit l'heure courante
                #setptr ptr, arg1
                ldy     #1
                jsr     parse_num               ; année
                bcs     _bad
                lda     num
                sta     DParams
                lda     num+1
                sta     DParams+1
                iny
                jsr     parse_num
                bcs     _bad
                lda     num
                sta     DParams+2
                iny
                jsr     parse_num
                bcs     _bad
                lda     num
                sta     DParams+3
                #api    1,21
                lda     DError
                bne     _bad
                rts
_bad            #println "Invalid date"
                rts

cmd_time        lda     arg1
                bne     _set
                #print  "Current time is "
                #api    1,20
                lda     DParams+4
                jsr     print2
                lda     #':'
                jsr     putc
                lda     DParams+5
                jsr     print2
                lda     #':'
                jsr     putc
                lda     DParams+6
                jsr     print2
                jmp     newline
_set            #api    1,20
                #setptr ptr, arg1
                ldy     #1
                jsr     parse_num
                bcs     _bad
                lda     num
                sta     DParams+4
                iny
                jsr     parse_num
                bcs     _bad
                lda     num
                sta     DParams+5
                stz     DParams+6
                iny
                jsr     parse_num               ; secondes facultatives
                bcs     +
                lda     num
                sta     DParams+6
+               #api    1,21
                lda     DError
                bne     _bad
                rts
_bad            #println "Invalid time"
                rts

; parse_num : lit un entier décimal dans la pstring (ptr) à partir de Y ;
; s'arrête sur un caractère non numérique (Y pointe dessus). Résultat dans
; num (16 bits). C=1 si aucun chiffre lu.
parse_num       stz     num
                stz     num+1
                stz     flag
_loop           tya
                cmp     (ptr)                   ; Y > longueur ?
                beq     +
                bcs     _end
+               lda     (ptr),y
                cmp     #'0'
                bcc     _end
                cmp     #'9'+1
                bcs     _end
                and     #$0f
                sta     tmp
                ; num = num*10 + tmp  (num*8 + num*2)
                asl     num
                rol     num+1                   ; *2
                lda     num
                sta     total
                lda     num+1
                sta     total+1
                asl     num
                rol     num+1
                asl     num
                rol     num+1                   ; *8
                clc
                lda     num
                adc     total
                sta     num
                lda     num+1
                adc     total+1
                sta     num+1
                lda     num
                clc
                adc     tmp
                sta     num
                bcc     +
                inc     num+1
+               inc     flag
                iny
                bra     _loop
_end            lda     flag
                beq     _none
                clc
                rts
_none           sec
                rts

; ---------------------------------------------------------------------------
; MEM : mémoire disponible pour les programmes
; ---------------------------------------------------------------------------
cmd_mem         jsr     newline
                lda     #<(PROG_TOP-PROG_BASE)
                ldy     #>(PROG_TOP-PROG_BASE)
                ldx     #8
                jsr     print16
                #println " bytes free for programs ($0800-$D7FF)"
                lda     #<(NEODOS_TOP-NEODOS_BASE)
                ldy     #>(NEODOS_TOP-NEODOS_BASE)
                ldx     #8
                jsr     print16
                #println " bytes reserved for NeoDOS ($D800-$FBFF)"
                jmp     newline

; ---------------------------------------------------------------------------
; HELP
; ---------------------------------------------------------------------------
cmd_help        jsr     newline
                #println "DIR [path]        List directory"
                #println "CD [path]         Change/show directory"
                #println "MD RD path        Make/remove directory"
                #println "DEL file          Delete a file"
                #println "REN old new       Rename a file"
                #println "COPY src dst      Copy a file"
                #println "TYPE file         Display a text file"
                #println "X:                Change drive"
                #println "CLS VER VOL MEM   Screen, versions, volume, memory"
                #println "DATE TIME         Show/set date and time"
                #println "ECHO PAUSE REM    Batch commands (.BAT)"
                #println "EXIT              Return to NeoBASIC"
                #println "name[.NEO]        Run a program"
                jmp     newline

; ---------------------------------------------------------------------------
; EXIT : retour à NeoBASIC (recharge BASIC en $0800)
; ---------------------------------------------------------------------------
cmd_exit        #api    1,3
                jmp     (0)

; ---------------------------------------------------------------------------
; X: : changement de lecteur (cmdbuf = « X: »)
; ---------------------------------------------------------------------------
cmd_drive       lda     cmdbuf+1
                sec
                sbc     #'A'
                cmp     #4
                bcs     _bad
                sta     DParams
                #api    3,25
                lda     DError
                beq     _ok
_bad            #println "Invalid drive specification"
_ok             rts
