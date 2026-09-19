; shell.asm — boucle principale : invite, lecture, analyse, exécution

; ---------------------------------------------------------------------------
; Point d'entrée
; ---------------------------------------------------------------------------
start           cld
                sei
                ldx     #$ff
                txs
                stz     echo_off
                stz     bat_active
                lda     #$ff                    ; ferme tout ce qui traîne
                sta     DParams
                #api    3,5
                #api    3,19
                jsr     newline
                #println "NeoDOS version " .. VERSION
                #println "(C) 2026 bmarty - Neo6502 disk operating system"
                jsr     newline
                jsr     run_autoexec

; ---------------------------------------------------------------------------
; Boucle de l'interpréteur
; ---------------------------------------------------------------------------
mainloop        ldx     #$ff                    ; pile propre après un programme
                txs
                cli
                stz     bat_active
                jsr     show_prompt
                jsr     read_command            ; ligne -> linebuf (sans l'invite)
                jsr     execute_line
                bra     mainloop

; ---------------------------------------------------------------------------
; show_prompt : « A:\CHEMIN> » ; mémorise sa longueur dans promptlen
; ---------------------------------------------------------------------------
show_prompt     jsr     build_prompt
                #setptr ptr, promptbuf
                jsr     putpstr
                rts

; build_prompt : construit promptbuf (chaîne à préfixe de longueur)
build_prompt    #api    3,26                    ; volume courant
                lda     DParams
                clc
                adc     #'A'
                sta     promptbuf+1
                lda     #':'
                sta     promptbuf+2
                lda     #80
                sta     cwdbuf                  ; longueur maximale du tampon
                #setparam 0, cwdbuf
                lda     #80
                sta     DParams+2
                #api    3,23
                ldy     #1
                ldx     #3
_copy           cpy     cwdbuf
                beq     +
                bcs     _end
+               lda     cwdbuf,y
                cmp     #'/'
                bne     +
                lda     #'\'
+               sta     promptbuf,x
                inx
                iny
                bra     _copy
_end            lda     cwdbuf                  ; cwd vide -> « \ »
                bne     +
                lda     #'\'
                sta     promptbuf,x
                inx
+               lda     #'>'
                sta     promptbuf,x
                stx     promptbuf               ; longueur
                rts

; ---------------------------------------------------------------------------
; read_command : lit la ligne d'écran (elle contient l'invite), la recopie
; dans linebuf sans l'invite.
; ---------------------------------------------------------------------------
read_command    ldx     #<screenline
                ldy     #>screenline
                jsr     ReadLine
                ; la ligne d'écran commence par l'invite : on la saute
                lda     screenline
                sec
                sbc     promptbuf
                bcc     _empty
                sta     linebuf
                beq     _done
                sta     cnt
                ldy     #1
                ldx     promptbuf
                inx
_copy           lda     screenline,x
                sta     linebuf,y
                inx
                iny
                dec     cnt
                bne     _copy
_done           rts
_empty          stz     linebuf
                rts

; ---------------------------------------------------------------------------
; execute_line : analyse linebuf et exécute la commande
; ---------------------------------------------------------------------------
execute_line    jsr     parse_line
                lda     cmdbuf
                beq     _done                   ; ligne vide
                ; « X: » : changement de lecteur
                cmp     #2
                bne     _lookup
                lda     cmdbuf+2
                cmp     #':'
                bne     _lookup
                jmp     cmd_drive
_lookup         #setptr ptr, cmdtable
_next           lda     (ptr)                   ; longueur du nom (0 = fin)
                beq     _notfound
                cmp     cmdbuf
                bne     _skip
                ; comparer les caractères
                tay
_cmp            lda     (ptr),y
                cmp     cmdbuf,y
                bne     _skip
                dey
                bne     _cmp
                ; trouvé : adresse après le nom
                lda     (ptr)
                clc
                adc     #1
                tay
                lda     (ptr),y
                sta     ptr2
                iny
                lda     (ptr),y
                sta     ptr2+1
                jmp     (ptr2)
_skip           lda     (ptr)                   ; entrée suivante : nom + 2
                clc
                adc     #3
                adc     ptr
                sta     ptr
                bcc     _next
                inc     ptr+1
                bra     _next
_notfound       jmp     run_program
_done           rts

; ---------------------------------------------------------------------------
; parse_line : linebuf -> cmdbuf (mot de commande en majuscules), arg1, arg2
; (chaînes à préfixe de longueur), argrest (reste de la ligne, brut).
; Le mot de commande s'arrête sur espace, « \ », « / », « : » (après la
; 1re lettre : « A: » reste entier) — « CD\ » et « CD.. » fonctionnent.
; ---------------------------------------------------------------------------
parse_line      stz     cmdbuf
                stz     arg1
                stz     arg2
                stz     argrest
                ldy     #1
                jsr     skip_spaces
                ldx     #0
_word           jsr     at_end
                bcs     _wend                   ; Y > longueur : fin
                lda     linebuf,y
                cmp     #' '
                beq     _wend
                cmp     #'\'
                beq     _wend
                cmp     #'/'
                beq     _wend
                cmp     #'.'
                beq     _dot
                cmp     #':'
                bne     _store
                cpx     #1                      ; « X: » : on garde le « : »
                bne     _wend
                inx
                sta     cmdbuf,x
                iny
                bra     _wend
_dot            cpx     #0                      ; un mot ne peut commencer par «.»
                beq     _store
                bra     _wend
_store          jsr     upper
                inx
                sta     cmdbuf,x
                iny
                cpx     #15
                bne     _word
_wend           stx     cmdbuf
                ; reste de la ligne (brut) -> argrest
                jsr     skip_spaces
                ldx     #0
_rest           jsr     at_end
                bcs     _rend
                lda     linebuf,y
                inx
                sta     argrest,x
                iny
                bra     _rest
_rend           stx     argrest
                ; arg1 et arg2 : découpage sur les espaces
                ldy     #0
                #setptr ptr, arg1
                jsr     get_word
                #setptr ptr, arg2
                jsr     get_word
                rts

; at_end : C=1 si Y (index 1-based) dépasse la longueur de linebuf
at_end          cpy     linebuf
                beq     _in
                rts
_in             clc
                rts

; skip_spaces : avance Y dans linebuf tant que c'est un espace
skip_spaces     jsr     at_end
                bcs     _done
                lda     linebuf,y
                cmp     #' '
                bne     _done
                iny
                bra     skip_spaces
_done           rts

; get_word : copie le mot de argrest à partir de Y (index 0-based dans les
; données) dans la pstring (ptr) ; Y avance après le mot.
get_word        ldx     #0
_skip           cpy     argrest
                bcs     _end
                lda     argrest+1,y
                cmp     #' '
                bne     _copy
                iny
                bra     _skip
_copy           cpy     argrest
                bcs     _end
                lda     argrest+1,y
                cmp     #' '
                beq     _end
                sta     flag
                sty     tmp
                inx
                txa
                tay
                lda     flag
                sta     (ptr),y
                ldy     tmp
                iny
                cpx     #127
                bne     _copy
_end            txa
                sta     (ptr)
                rts

; upper : A -> majuscule
upper           cmp     #'a'
                bcc     _done
                cmp     #'z'+1
                bcs     _done
                and     #$df
_done           rts

; ---------------------------------------------------------------------------
; to_apipath : convertit « \ » en « / » dans la pstring pointée par ptr
; (les chemins DOS deviennent des chemins du firmware)
; ---------------------------------------------------------------------------
to_apipath      ldy     #0
                lda     (ptr)
                beq     _done
                tay
_loop           lda     (ptr),y
                cmp     #'\'
                bne     +
                lda     #'/'
                sta     (ptr),y
+               dey
                bne     _loop
_done           rts

; ---------------------------------------------------------------------------
; run_program : commande inconnue -> NOM.NEO ou NOM.BAT (ou nom tel quel
; s'il porte déjà l'extension). Sinon « Bad command or file name ».
; ---------------------------------------------------------------------------
run_program     jsr     first_word_raw          ; nom tel que tapé
                jsr     try_run                 ; ne revient que si absent
                jsr     first_word_raw          ; puis en majuscules (DOS)
                ldx     namebuf
                beq     _bad
-               lda     namebuf,x
                jsr     upper
                sta     namebuf,x
                dex
                bne     -
                jsr     try_run
_bad            jmp     err_badcmd

; try_run : namebuf = nom ; lance NOM(.NEO|.BAT) s'il existe (sans retour),
; sinon revient.
try_run         #setptr ptr, namebuf
                jsr     to_apipath
                jsr     ext_of                  ; A = 1 .NEO, 2 .BAT, 0 aucune
                cmp     #1
                beq     _neo
                cmp     #2
                beq     _bat
                ; sans extension : essayer .NEO puis .BAT
                #setptr ptr2, ext_neo
                jsr     append_ext
                jsr     stat_namebuf
                beq     _run
                lda     namebuf                 ; retirer .NEO, essayer .BAT
                sec
                sbc     #4
                sta     namebuf
                #setptr ptr2, ext_bat
                jsr     append_ext
                jsr     stat_namebuf
                beq     _runbat
                rts
_neo            jsr     stat_namebuf
                bne     _none
_run            lda     #$ff                    ; fermer fichiers et répertoire
                sta     DParams
                #api    3,5
                #api    3,19
                #setparam 0, namebuf
                stz     DParams+2               ; adresse : donnée par l'en-tête
                stz     DParams+3
                #api    3,2
                lda     DError
                bne     _loaderr
                jsr     DExec                   ; JMP exec (ou RTS)
                bra     _back
_loaderr        jsr     err_api
_back           ldx     #$ff                    ; retour : pile réinitialisée
                txs
                lda     bat_active              ; un batch reprend après le
                beq     +                       ; programme (comme MS-DOS)
                jmp     batch_next
+               jmp     mainloop
_bat            jsr     stat_namebuf
                bne     _none
_runbat         jmp     run_batch
_none           rts

; first_word_raw : premier mot de linebuf (tel que tapé) -> namebuf
first_word_raw  ldy     #1
                jsr     skip_spaces
                ldx     #0
_loop           jsr     at_end
                bcs     _end
                lda     linebuf,y
                cmp     #' '
                beq     _end
                inx
                sta     namebuf,x
                iny
                cpx     #100
                bne     _loop
_end            stx     namebuf
                rts

; ext_of : extension de namebuf (majuscules ou minuscules) :
; A = 1 « .NEO », 2 « .BAT », 0 autre/aucune
ext_of          lda     namebuf
                cmp     #5
                bcc     _none
                tax
                dex
                dex
                dex
                lda     namebuf,x               ; le « . » ?
                cmp     #'.'
                bne     _none
                lda     namebuf+1,x
                jsr     upper
                cmp     #'N'
                beq     _n
                cmp     #'B'
                bne     _none
                lda     namebuf+2,x
                jsr     upper
                cmp     #'A'
                bne     _none
                lda     namebuf+3,x
                jsr     upper
                cmp     #'T'
                bne     _none
                lda     #2
                rts
_n              lda     namebuf+2,x
                jsr     upper
                cmp     #'E'
                bne     _none
                lda     namebuf+3,x
                jsr     upper
                cmp     #'O'
                bne     _none
                lda     #1
                rts
_none           lda     #0
                rts

; append_ext : ajoute la pstring (ptr2) à namebuf
append_ext      ldx     namebuf
                ldy     #1
_loop           cpy     #5
                beq     _end
                lda     (ptr2),y
                inx
                sta     namebuf,x
                iny
                bra     _loop
_end            stx     namebuf
                rts

; stat_namebuf : File Stat sur namebuf ; Z=1 si le fichier existe (A = erreur)
stat_namebuf    #setparam 0, namebuf
                #api    3,16
                lda     DError
                rts

ext_neo         .ptext  ".NEO"
ext_bat         .ptext  ".BAT"

; ---------------------------------------------------------------------------
; Messages d'erreur DOS
; ---------------------------------------------------------------------------
err_badcmd      #println "Bad command or file name"
                rts
err_notfound    #println "File not found"
                rts
err_syntax      #println "Syntax error"
                rts
err_denied      #println "Access denied"
                rts

; err_api : message selon le code d'erreur API dans A (= DError du dernier
; appel ; à sauver dans errsave si des affichages précèdent)
err_api         cmp     #ERR_NO_FILE
                beq     err_notfound
                cmp     #ERR_NO_PATH
                beq     _path
                cmp     #ERR_INVALID_DRIVE
                beq     _drive
                cmp     #ERR_DENIED
                beq     err_denied
                cmp     #ERR_EXIST
                beq     _exist
                sta     errsave
                #print  "Error "
                lda     errsave
                jsr     print8
                jsr     newline
                rts
_path           #println "Path not found"
                rts
_drive          #println "Invalid drive specification"
                rts
_exist          #println "File already exists"
                rts
