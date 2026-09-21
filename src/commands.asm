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
                .ptext  "MOVE"
                .word   cmd_move
                .ptext  "FOR"
                .word   cmd_for
                .ptext  "SHIFT"
                .word   cmd_shift
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
                .ptext  "IF"
                .word   cmd_if
                .ptext  "GOTO"
                .word   cmd_goto
                .ptext  "CALL"
                .word   cmd_call
                .ptext  "PAUSE"
                .word   cmd_pause
                .ptext  "DATE"
                .word   cmd_date
                .ptext  "TIME"
                .word   cmd_time
                .ptext  "MEM"
                .word   cmd_mem
                .ptext  "PATH"
                .word   cmd_path
                .ptext  "PROMPT"
                .word   cmd_prompt
                .ptext  "HELP"
                .word   cmd_help
                .ptext  "EXIT"
                .word   cmd_exit
                .ptext  "BASIC"
                .word   cmd_exit
                .byte   0

; ---------------------------------------------------------------------------
; DIR [chemin][motif] [/P] [/W] : liste un répertoire au format DOS
; ---------------------------------------------------------------------------
cmd_dir         jsr     dir_parse_args          ; arg1 = chemin, dirflags
                jsr     ptr_arg1
                jsr     to_apipath
                lda     arg1
                bne     _witharg
                lda     #1                      ; sans argument : « . », « * »
                sta     dirbuf
                lda     #'.'
                sta     dirbuf+1
                bra     _all
_witharg        jsr     has_wild
                bcs     _split
                jsr     p0_arg1               ; un répertoire existant ?
                #api    3,16
                lda     DError
                bne     _split
                lda     DParams+4
                and     #ATTR_DIR
                beq     _split
                ldx     arg1                    ; dirbuf = arg1
-               lda     arg1,x
                sta     dirbuf,x
                dex
                bpl     -
_all            lda     #1                      ; patbuf = « * »
                sta     patbuf
                lda     #'*'
                sta     patbuf+1
                bra     _open
_split          jsr     split_path
_open           #setparam 0, dirbuf
                #api    3,17                    ; Open Directory
                lda     DError
                beq     +
                jmp     err_api
+               stz     dirlines
                stz     dircol
                #print  " Volume in drive "
                stz     DParams                 ; sans 3,26 (Trinity) : A
                #api    3,26
                lda     DParams
                clc
                adc     #'A'
                jsr     putc
                jsr     print_volname
                jsr     dir_newline
                #print  " Directory of "
                jsr     build_cwdpath           ; « A:\chemin »
                lda     dirbuf                  ; répertoire demandé (sauf « . »)
                cmp     #1
                bne     _withdir
                lda     dirbuf+1
                cmp     #'.'
                bne     _withdir
                #setptr ptr, cwdpath
                jsr     putpstr
                bra     _hdr
_withdir        lda     dirbuf+1                ; chemin absolu : « A: » + chemin
                cmp     #'/'
                bne     _relative
                lda     #2
                sta     cwdpath
                #setptr ptr, cwdpath
                jsr     putpstr
                bra     _showdir
_relative       #setptr ptr, cwdpath
                jsr     putpstr
                ldx     cwdpath                 ; racine : pas de second « \ »
                lda     cwdpath,x
                cmp     #'\'
                beq     _showdir
                lda     #'\'
                jsr     putc
_showdir        #setptr ptr, dirbuf
                jsr     putpstr_dos
_hdr            jsr     dir_newline
                jsr     dir_newline
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
                jsr     p0_namebuf
                #api    3,18                    ; Read Directory
                lda     DError
                beq     +
                jmp     _end
+               jsr     match_glob
                bcs     +
                jmp     _entry
+               lda     dirflags
                and     #2
                bne     _wide
                jsr     ptr_namebuf
                ldx     #16
                jsr     putpstr_pad
                lda     DParams+6
                and     #ATTR_DIR
                beq     _file
                #print  "     <DIR>"
                jsr     dir_newline
                inc     ndirs
                bne     _entry
                inc     ndirs+1
                bra     _entry
_file           jsr     dir_addsize
                ldx     #10
                jsr     print32
                jsr     dir_newline
                bra     _entry
_wide           lda     DParams+6               ; /W : [DIR] ou NOM, 4 colonnes
                and     #ATTR_DIR
                beq     _wfile
                inc     ndirs
                bne     +
                inc     ndirs+1
+               lda     #'['
                jsr     putc
                jsr     ptr_namebuf
                jsr     putpstr
                lda     #']'
                jsr     putc
                lda     namebuf
                inc     a
                inc     a
                bra     _wpad
_wfile          jsr     dir_addsize
                jsr     ptr_namebuf
                jsr     putpstr
                lda     namebuf
_wpad           cmp     #13                     ; complète à 13 colonnes
                bcs     _wnext
                sta     tmp
                lda     #13
                sec
                sbc     tmp
                tax
                jsr     spaces
_wnext          inc     dircol
                lda     dircol
                cmp     #4
                bcc     _next
                stz     dircol
                jsr     dir_newline
_next           jmp     _entry
_end            #api    3,19                    ; Close Directory
                lda     dircol
                beq     +
                jsr     dir_newline
+               lda     nfiles
                ora     nfiles+1
                ora     ndirs
                ora     ndirs+1
                bne     _totals
                jmp     err_notfound
_totals         lda     nfiles
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
                #print  " bytes"
                jsr     dir_newline
                lda     ndirs
                ldy     ndirs+1
                ldx     #9
                jsr     print16
                #print  " dir(s)"
                jmp     dir_newline

; dir_addsize : taille de l'entrée (DParams+2..5) -> num, ajoutée à total ;
; compte un fichier
dir_addsize     lda     DParams+2
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
                inc     nfiles
                bne     +
                inc     nfiles+1
+               rts

; dir_newline : retour chariot ; avec /P, pause toutes les DIR_PAGE_LINES
dir_newline     jsr     newline
                lda     dirflags
                and     #1
                beq     _done
                inc     dirlines
                lda     dirlines
                cmp     #DIR_PAGE_LINES
                bcc     _done
                stz     dirlines
                #print  "Press any key to continue . . ."
-               #api    2,1
                lda     DParams
                beq     -
                jmp     newline
_done           rts

; dir_parse_args : mots de argrest -> arg1 (premier mot qui n'est pas un
; commutateur) et dirflags (/P = 1, /W = 2). Un commutateur est un mot de
; deux caractères commençant par « / ».
dir_parse_args  stz     dirflags
                stz     arg1
                ldy     #0
_word           jsr     ptr_arg2               ; mot suivant -> arg2
                jsr     get_word
                lda     arg2
                beq     _done
                cmp     #2
                bne     _path
                lda     arg2+1
                cmp     #'/'
                bne     _path
                lda     arg2+2
                jsr     upper
                cmp     #'P'
                bne     +
                lda     dirflags
                ora     #1
                sta     dirflags
                bra     _word
+               cmp     #'W'
                bne     _word                   ; commutateur inconnu : ignoré
                lda     dirflags
                ora     #2
                sta     dirflags
                bra     _word
_path           lda     arg1                    ; premier chemin seulement
                bne     _word
                ldx     arg2
-               lda     arg2,x
                sta     arg1,x
                dex
                bpl     -
                bra     _word
_done           stz     arg2
                rts


; (« has no label » quand le firmware n'a pas 3,24, comme Trinity)
print_volname   lda     caps
                and     #CAP_VOLUMES
                beq     _unk
                stz     DParams
                #api    3,26                    ; Parameter:0 = volume courant
                lda     #32
                sta     namebuf
                #setparam 1, namebuf
                #api    3,24
                lda     DError
                bne     _unk
                #print  " is "
                jsr     ptr_namebuf
                jmp     putpstr
_unk            #print  " has no label"
                rts

; ---------------------------------------------------------------------------
; CD [chemin] : change ou affiche le répertoire courant
; ---------------------------------------------------------------------------
cmd_cd          lda     arg1
                bne     _chdir
                jsr     build_cwdpath
                #setptr ptr, cwdpath
                jsr     putpstr
                jmp     newline
_chdir          jsr     ptr_arg1
                jsr     to_apipath
                jsr     p0_arg1
                #api    3,15
                lda     DError
                beq     _ok
                jsr     errlvl1
                #println "Invalid directory"
_ok             rts

; ---------------------------------------------------------------------------
; MD chemin : crée un répertoire
; ---------------------------------------------------------------------------
cmd_md          lda     arg1
                beq     _syntax
                jsr     ptr_arg1
                jsr     to_apipath
                jsr     p0_arg1
                #api    3,14
                lda     DError
                beq     _ok
                jsr     errlvl1
                #println "Unable to create directory"
_ok             rts
_syntax         jmp     err_syntax

; ---------------------------------------------------------------------------
; RD chemin : supprime un répertoire vide
; ---------------------------------------------------------------------------
cmd_rd          lda     arg1
                beq     _syntax
                jsr     ptr_arg1
                jsr     to_apipath
                jsr     p0_arg1
                #api    3,16                    ; doit être un répertoire
                lda     DError
                bne     _bad
                lda     DParams+4
                and     #ATTR_DIR
                beq     _bad
                jsr     p0_arg1
                #api    3,13
                lda     DError
                beq     _ok
_bad            jsr     errlvl1
                #println "Invalid path, not directory, or directory not empty"
_ok             rts
_syntax         jmp     err_syntax

; ---------------------------------------------------------------------------
; DEL fichier|motif : supprime des fichiers (jamais un répertoire)
; ---------------------------------------------------------------------------
cmd_del         lda     arg1
                beq     _syntax
                jsr     ptr_arg1
                jsr     to_apipath
                jsr     has_wild
                bcs     _wild
                jsr     p0_arg1
                #api    3,16
                lda     DError
                bne     _nf
                lda     DParams+4
                and     #ATTR_DIR
                bne     _denied
                jsr     p0_arg1
                #api    3,13
                lda     DError
                beq     _ok
_nf             jmp     err_notfound
_denied         jmp     err_denied
_ok             rts
_syntax         jmp     err_syntax
_wild           jsr     split_path
                lda     patbuf                  ; « * » ou « *.* » : confirmer
                cmp     #1
                bne     +
                lda     patbuf+1
                cmp     #'*'
                beq     _confirm
+               lda     patbuf
                cmp     #3
                bne     _collect
                lda     patbuf+1
                cmp     #'*'
                bne     _collect
                lda     patbuf+2
                cmp     #'.'
                bne     _collect
                lda     patbuf+3
                cmp     #'*'
                bne     _collect
_confirm        #println "All files in directory will be deleted!"
                #print  "Are you sure (Y/N)?"
                jsr     ask_yn
                bcc     _collect
                rts
_collect        lda     #0                      ; fichiers seulement
                jsr     collect_matches
                bcs     _wdone
                lda     lcount
                bne     +
                jmp     err_notfound
+               jsr     list_first
_each           jsr     list_next
                bcs     _wdone
                jsr     ptr_namebuf
                jsr     build_path
                jsr     p0_namebuf
                #api    3,13
                lda     DError
                beq     _each
                jsr     err_api
                bra     _each
_wdone          rts

; ask_yn : attend Y ou N ; C=0 pour Y (affiche la réponse et un retour)
ask_yn          #api    2,1
                lda     DParams
                beq     ask_yn
                jsr     upper
                cmp     #'Y'
                beq     _yes
                cmp     #'N'
                bne     ask_yn
                jsr     putc
                jsr     newline
                sec
                rts
_yes            jsr     putc
                jsr     newline
                clc
                rts

; ---------------------------------------------------------------------------
; REN ancien nouveau : renomme ; avec jokers, substitution façon DOS
; (REN *.TXT *.BAK, REN A?.* B?.*)
; ---------------------------------------------------------------------------
cmd_ren         lda     arg1
                beq     _syntax
                lda     arg2
                beq     _syntax
                jsr     ptr_arg1
                jsr     to_apipath
                jsr     ptr_arg2
                jsr     to_apipath
                jsr     ptr_arg1
                jsr     has_wild
                bcs     _wild
                jsr     p0_arg1
                #setparam 2, arg2
                #api    3,12
                lda     DError
                beq     _ok
_dup            jsr     errlvl1
                #println "Duplicate file name or file not found"
_ok             rts
_syntax         jmp     err_syntax
_wild           jsr     split_path
                lda     #1                      ; fichiers et répertoires
                jsr     collect_matches
                bcs     _ok
                lda     lcount
                beq     _dup
                jsr     list_first
_each           jsr     list_next
                bcs     _ok
                jsr     apply_pattern           ; newname
                lda     newname
                beq     _each
                jsr     ptr_namebuf            ; ancien chemin
                jsr     build_path
                lda     ptr2                    ; nouveau chemin -> iobuf
                pha
                lda     ptr2+1
                pha
                #setptr ptr2, newname
                #setptr ptr, iobuf
                jsr     build_path
                pla
                sta     ptr2+1
                pla
                sta     ptr2
                jsr     p0_namebuf
                #setparam 2, iobuf
                #api    3,12
                lda     DError
                beq     _each
                jsr     ptr_namebuf
                jsr     putpstr_dos
                #print  " -> "
                #setptr ptr, iobuf
                jsr     putpstr_dos
                #println ": Duplicate file name or file not found"
                jmp     _each

; ---------------------------------------------------------------------------
; COPY source|motif destination[répertoire]
; ---------------------------------------------------------------------------
cmd_copy        lda     #20                     ; Copy File
                sta     opfn
                bra     copy_move
cmd_move        lda     #12                     ; Rename
                sta     opfn
copy_move       lda     arg1
                beq     _syn
                lda     arg2
                bne     +
_syn            jmp     err_syntax
+               jsr     ptr_arg1
                jsr     to_apipath
                jsr     ptr_arg2
                jsr     to_apipath
                stz     wflag                   ; wflag = destination répertoire
                #setparam 0, arg2
                #api    3,16
                lda     DError
                bne     +
                lda     DParams+4
                and     #ATTR_DIR
                sta     wflag
+               stz     nfiles
                jsr     ptr_arg1
                jsr     has_wild
                bcs     _wild
                jsr     p0_arg1               ; la source doit exister
                #api    3,16
                lda     DError
                bne     _nf
                lda     wflag
                beq     _single
                ; destination = arg2 + « / » + nom de base de arg1
                jsr     copy_dest_name
                jsr     p0_arg1
                #setparam 2, iobuf
                bra     _one
_single         jsr     p0_arg1
                #setparam 2, arg2
_one            jsr     file_op
                lda     DError
                bne     _err
                inc     nfiles
                jmp     _count
_nf             jmp     err_notfound
_err            jmp     err_api
_wild           lda     wflag
                bne     +
                jsr     errlvl1
                #println "Destination must be a directory"
                rts
+               jsr     split_path
                lda     #0                      ; fichiers seulement
                jsr     collect_matches
                bcs     _done
                lda     lcount
                beq     _nf
                jsr     list_first
_each           jsr     list_next
                bcs     _count
                jsr     ptr_namebuf            ; source complète
                jsr     build_path
                jsr     dest_path               ; iobuf = arg2/nom
                jsr     p0_namebuf
                #setparam 2, iobuf
                jsr     file_op
                lda     DError
                bne     _cerr
                inc     nfiles
                bra     _each
_cerr           sta     errsave
                jsr     ptr_namebuf
                jsr     putpstr_dos
                #print  ": "
                lda     errsave
                jsr     err_api
                bra     _each
_count          lda     nfiles
                ldx     #9
                jsr     print8_pad
                lda     opfn
                cmp     #12
                beq     _moved
                #println " file(s) copied"
_done           rts
_moved          #println " file(s) moved"
                rts

; file_op : appel API 3,opfn (paramètres déjà en place)
file_op         jsr     WaitMessage
                lda     opfn
                sta     DFunction
                lda     #3
                sta     DCommand
                jmp     WaitMessage

; ATTRIB : commande externe BIN/ATTRIB.NEO depuis la 0.14.0 (examples/ext/ATTRIB.asm)

; copy_dest_name : iobuf = arg2 + « / » + nom de base de arg1 (après « / »)
copy_dest_name  ldx     arg1                    ; X = dernier « / » (0 : aucun)
-               lda     arg1,x
                cmp     #'/'
                beq     +
                dex
                bne     -
+               txa                             ; ptr2 -> pstring temporaire :
                clc                             ; on fabrique newname = base
                adc     #1
                tax
                ldy     #0
-               cpx     arg1
                beq     +
                bcs     ++
+               lda     arg1,x
                iny
                sta     newname,y
                inx
                bra     -
+               sty     newname
                lda     ptr2
                pha
                lda     ptr2+1
                pha
                #setptr ptr2, newname
                jsr     dest_path
                pla
                sta     ptr2+1
                pla
                sta     ptr2
                rts

; dest_path : iobuf = arg2 + « / » + pstring (ptr2) (arg2 finissant par « / »
; ou « . » traité comme build_path, via une copie de arg2 dans dirbuf)
dest_path       lda     dirbuf                  ; sauve dirbuf dans patbuf
                sta     patbuf
                tax
                beq     +
-               lda     dirbuf,x
                sta     patbuf,x
                dex
                bne     -
+               ldx     arg2                    ; dirbuf = arg2
-               lda     arg2,x
                sta     dirbuf,x
                dex
                bpl     -
                #setptr ptr, iobuf
                jsr     build_path
                ldx     patbuf                  ; restaure dirbuf
-               lda     patbuf,x
                sta     dirbuf,x
                dex
                bpl     -
                rts


; ---------------------------------------------------------------------------
; TYPE fichier : affiche un fichier texte
; ---------------------------------------------------------------------------
cmd_type        lda     arg1
                bne     +
                jmp     err_syntax
+
                jsr     ptr_arg1
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
                stz     DParams                 ; sans 3,26 (Trinity) : A
                #api    3,26
                lda     DParams
                clc
                adc     #'A'
                jsr     putc
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

; ---------------------------------------------------------------------------
; PATH [rép;rép…] : affiche ou fixe les répertoires de recherche ; « PATH ; »
; efface
; ---------------------------------------------------------------------------
cmd_path        lda     argrest
                bne     _set
                lda     pathbuf
                bne     +
                #println "No Path"
                rts
+               #print  "PATH="
                #setptr ptr, pathbuf
                jsr     putpstr_dos
                jmp     newline
_set            cmp     #1
                bne     +
                lda     argrest+1
                cmp     #';'
                bne     +
                stz     pathbuf
                rts
+               ldx     argrest
                cpx     #PATH_SIZE
                bcc     +
                ldx     #PATH_SIZE
+               stx     pathbuf
-               lda     argrest,x
                sta     pathbuf,x
                dex
                bne     -
                #setptr ptr, pathbuf
                jmp     to_apipath

; ---------------------------------------------------------------------------
; PROMPT [texte] : format de l'invite ($p$g par défaut)
; ---------------------------------------------------------------------------
cmd_prompt      ldx     argrest
                bne     +
                ldx     #4
-               lda     default_prompt,x
                sta     promptfmt,x
                dex
                bpl     -
                rts
+               cpx     #PROMPT_SIZE
                bcc     +
                ldx     #PROMPT_SIZE
+               stx     promptfmt
-               lda     argrest,x
                sta     promptfmt,x
                dex
                bne     -
                rts

; ---------------------------------------------------------------------------
; IF [NOT] EXIST fichier | a==b | ERRORLEVEL n  commande
; ---------------------------------------------------------------------------
cmd_if          stz     negate
                stz     cond
                ldy     #0
                jsr     ptr_arg2
                jsr     get_word
                lda     arg2
                beq     _jsyn
                #setptr ptr2, kw_not
                jsr     word_is
                bcc     +
                inc     negate
                jsr     ptr_arg2
                jsr     get_word
                lda     arg2
                beq     _jsyn
+               #setptr ptr2, kw_exist
                jsr     word_is
                bcc     _notexist
                jsr     ptr_arg1               ; IF EXIST fichier
                jsr     get_word
                lda     arg1
                beq     _jsyn
                sty     by
                jsr     ptr_arg1
                jsr     to_apipath
                jsr     p0_arg1
                #api    3,16
                ldy     by
                lda     DError
                bne     _jcond
                inc     cond
                bra     _jcond
_jsyn           jmp     _syntax
_jcond          jmp     _cond
_notexist       #setptr ptr2, kw_errlvl
                jsr     word_is
                bcc     _compare
                jsr     ptr_arg1               ; IF ERRORLEVEL n
                jsr     get_word
                lda     arg1
                beq     _jsyn
                sty     by
                jsr     ptr_arg1
                ldy     #1
                jsr     parse_num
                ldy     by
                bcs     _jsyn
                lda     preverr
                cmp     num
                bcc     _jcond
                inc     cond
                bra     _jcond
                bra     _jcond
_jsyn2          jmp     _syntax
_jcond2         jmp     _cond
_compare        ; « a==b » dans arg2, ou « a » « == » « b », ou « a== » « b »
                ldx     #1
_findeq         cpx     arg2
                bcs     _noeq
                lda     arg2,x
                cmp     #'='
                bne     +
                lda     arg2+1,x
                cmp     #'='
                beq     _eqat
+               inx
                bra     _findeq
_eqat           ; gauche = arg2[1..X-1] -> arg1 ; droite = arg2[X+2..] -> newname
                stx     tmp
                dex
                stx     arg1
                beq     +
-               lda     arg2,x
                sta     arg1,x
                dex
                bne     -
+               ldx     tmp
                inx
                inx                             ; X = début de la droite
                stz     newname
_right          cpx     arg2
                beq     +
                bcs     _rdone
+               lda     arg2,x
                inc     newname
                stx     tmp
                ldx     newname
                sta     newname,x
                ldx     tmp
                inx
                bra     _right
_rdone          lda     newname
                bne     _test
                #setptr ptr, newname            ; « a== b »
                jsr     get_word
                bra     _test
_noeq           ldx     arg2                    ; gauche = arg2 entier
-               lda     arg2,x
                sta     arg1,x
                dex
                bpl     -
                jsr     ptr_arg2               ; mot suivant : « == » ou « ==b »
                jsr     get_word
                lda     arg2
                cmp     #2
                bcc     _jsyn3
                lda     arg2+1
                cmp     #'='
                bne     _jsyn3
                lda     arg2+2
                cmp     #'='
                bne     _jsyn3
                lda     arg2
                cmp     #2
                bne     _eqb
                #setptr ptr, newname
                jsr     get_word
                bra     _test
_eqb            sec                             ; newname = arg2[3..]
                sbc     #2
                sta     newname
                tax
-               lda     arg2+2,x
                sta     newname,x
                dex
                bne     -
                bra     _test
_jsyn3          jmp     _syntax
_jcond3         jmp     _cond
_test           ldx     arg1                    ; arg1 == newname ? (casse exacte)
                cpx     newname
                bne     _jcond3
-               lda     arg1,x
                cmp     newname,x
                bne     _jcond3
                dex
                bpl     -
                inc     cond
_cond           lda     cond
                eor     negate
                beq     _done
                ; commande = reste de argrest à partir de Y
                ldx     #0
_skipsp         cpy     argrest
                bcs     _cmd
                lda     argrest+1,y
                cmp     #' '
                bne     _cmd
                iny
                bra     _skipsp
_cmd            cpy     argrest
                bcs     _run
                lda     argrest+1,y
                inx
                sta     linebuf,x
                iny
                bra     _cmd
_run            stx     linebuf
                txa
                beq     _jsyn3
                jmp     execute_line
_done           rts
_syntax         jmp     err_syntax

kw_not          .ptext  "NOT"
kw_exist        .ptext  "EXIST"
kw_errlvl       .ptext  "ERRORLEVEL"

; word_is : C=1 si arg2 == pstring (ptr2), sans distinction de casse ;
; préserve Y (index de get_word)
word_is         phy
                lda     (ptr2)
                cmp     arg2
                bne     _no
                tay
-               lda     (ptr2),y
                sta     tmp
                lda     arg2,y
                jsr     upper
                cmp     tmp
                bne     _no
                dey
                bne     -
                ply
                sec
                rts
_no             ply
                clc
                rts

; PAUSE : attend une touche
cmd_pause       #println "Press any key to continue . . ."
_wait           #api    2,1
                lda     DParams
                beq     _wait
                rts

; ---------------------------------------------------------------------------
; DATE [aaaa-mm-jj] / TIME [hh:mm[:ss]]
; ---------------------------------------------------------------------------
cmd_date        jsr     need_datetime
                bcc     +
                rts
+               lda     arg1
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
                jsr     ptr_arg1
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
_bad            jsr     errlvl1
                #println "Invalid date"
_none           rts

; need_datetime : C=1 (et message) si le firmware n'a pas 1,20/1,21
need_datetime   lda     caps
                and     #CAP_DATETIME
                bne     _ok
                jsr     errlvl1
                #println "Date/time not supported by this firmware"
                sec
                rts
_ok             clc
                rts

cmd_time        jsr     need_datetime
                bcc     +
                rts
+               lda     arg1
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
                jsr     ptr_arg1
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
_bad            jsr     errlvl1
                #println "Invalid time"
_none           rts

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
                #println " bytes free for programs ($0800-$B7FF)"
                lda     #<(NEODOS_TOP-NEODOS_BASE)
                ldy     #>(NEODOS_TOP-NEODOS_BASE)
                ldx     #8
                jsr     print16
                #println " bytes reserved for NeoDOS ($B800-$FBFF)"
                jmp     newline

; ---------------------------------------------------------------------------
; HELP
; ---------------------------------------------------------------------------
cmd_help        jsr     newline
                #println "DIR [path] [/P /W] List directory (wildcards)"
                #println "CD [path]         Change/show directory"
                #println "MD RD path        Make/remove directory"
                #println "DEL file|*.*      Delete files"
                #println "REN old new       Rename files (REN *.TXT *.BAK)"
                #println "COPY MOVE src dst Copy/move files (COPY *.TXT DIR)"
                #println "TYPE file         Display a text file"
                #println "X:                Change drive"
                #println "CLS VER VOL MEM   Screen, versions, volume, memory"
                #println "PATH PROMPT       Search path, prompt ($p$g)"
                #println "cmd > file        Redirect output (>> appends)"
                #println "DATE TIME         Show/set date and time"
                #println "ECHO PAUSE REM    Batch commands (.BAT, %1-%9)"
                #println "IF GOTO CALL      IF [NOT] EXIST|==|ERRORLEVEL, :label"
                #println "FOR SHIFT         FOR %f IN (set) DO cmd; SHIFT"
                #println "EXIT              Reload the resident environment"
                #println "name[.NEO]        Run a program"
                #println "BIN\: ATTRIB EDIT MORE TREE XCOPY DELTREE FIND SORT"
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
                ldx     caps                    ; sans 3,25 : seul A: existe
                bne     +
                cmp     #0
                beq     _ok
                bra     _bad
+
                sta     DParams
                #api    3,25
                lda     DError
                beq     _ok
_bad            jsr     errlvl1
                #println "Invalid drive specification"
_ok             rts
