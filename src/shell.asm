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
                stz     batdepth
                stz     errorlevel
                stz     linebuf                 ; %0-%9 vides pour AUTOEXEC.BAT
                stz     redir
                stz     pathbuf
                stz     hcount
                stz     hused
                lda     #CANARY                 ; sentinelles de la zone données
                sta     canary_lo
                sta     canary_hi
                jsr     detect_caps
                ldx     #4                      ; PROMPT $p$g
-               lda     default_prompt,x
                sta     promptfmt,x
                dex
                bpl     -
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
                jsr     redir_close
                stz     bat_active
                jsr     show_prompt
                jsr     read_command            ; ligne -> linebuf (sans l'invite)
                jsr     execute_line
                bra     mainloop

; warm_restart : Ctrl+Alt+Suppr — redémarrage à chaud (le RP2040 n'est pas
; réinitialisé) : fichiers fermés, son coupé, écran effacé, NeoDOS relancé
warm_restart    ldx     #$ff
                txs
-               lda     #KEY_DELETE             ; attend le relâchement de Suppr
                sta     DParams                 ; (sinon redémarrages en boucle)
                #api    1,2
                lda     DParams
                bne     -
                #api    8,1                     ; Reset Sound
                #setparam 0, rootpath           ; retour à la racine, comme
                #api    3,15                    ; après un démarrage
                #api    2,12                    ; Clear Screen
                jmp     start
rootpath        .ptext  "/"


; ---------------------------------------------------------------------------
; show_prompt : « A:\CHEMIN> » ; mémorise sa longueur dans promptlen
; ---------------------------------------------------------------------------
show_prompt     jsr     build_prompt
                #setptr ptr, promptbuf
                jsr     putpstr
                rts

; build_cwdpath : cwdpath = « A:\chemin » (pstring)
build_cwdpath   stz     DParams                 ; volume courant (0 = A si le
                #api    3,26                    ; firmware ignore 3,26)
                lda     DParams
                clc
                adc     #'A'
                sta     cwdpath+1
                lda     #':'
                sta     cwdpath+2
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
+               sta     cwdpath,x
                inx
                iny
                bra     _copy
_end            lda     cwdbuf                  ; cwd vide -> « \ »
                bne     +
                lda     #'\'
                sta     cwdpath,x
                inx
+               dex
                stx     cwdpath                 ; longueur
                rts

; build_prompt : promptbuf = promptfmt interprété ($p chemin, $g >, $l <,
; $n lettre du lecteur, $d date, $t heure, $_ retour à la ligne, $$, $b |,
; $q =) ; promptskip = longueur de la dernière ligne de l'invite (ce que
; read_command doit sauter sur la ligne d'écran).
build_prompt    jsr     build_cwdpath
                stz     oidx
                stz     promptskip
                ldy     #1
_loop           cpy     promptfmt
                beq     +
                bcs     _jdone
+               lda     promptfmt,y
                iny
                cmp     #'$'
                bne     _char
                cpy     promptfmt
                beq     +
                bcs     _jdone
+               lda     promptfmt,y
                iny
                jsr     upper
                cmp     #'P'
                beq     _path
                cmp     #'G'
                bne     +
                lda     #'>'
                bra     _char
+               cmp     #'L'
                bne     +
                lda     #'<'
                bra     _char
+               cmp     #'N'
                bne     +
                lda     cwdpath+1
                bra     _char
+               cmp     #'B'
                bne     +
                lda     #'|'
                bra     _char
+               cmp     #'Q'
                bne     +
                lda     #'='
                bra     _char
+               cmp     #'$'
                beq     _char
                cmp     #'_'
                bne     +
                lda     #CR
                jsr     pr_char
                stz     promptskip              ; nouvelle ligne d'écran
                bra     _loop
+               cmp     #'D'
                beq     _date
                cmp     #'T'
                bne     _loop                   ; code inconnu : ignoré
                jmp     _time
_jdone          jmp     _done
_char           jsr     pr_char
                inc     promptskip
                bra     _loop
_jloop          jmp     _loop
_path           ldx     #1
-               cpx     cwdpath
                beq     +
                bcs     _loop
+               lda     cwdpath,x
                jsr     pr_char
                inc     promptskip
                inx
                bra     -
_date           lda     caps
                and     #CAP_DATETIME
                beq     _jloop
                phy
                #api    1,20
                lda     DParams+1               ; année : 19xx ou 20xx
                cmp     #>2000
                bne     +
                lda     DParams
                cmp     #<2000
+               bcc     _19
                lda     #'2'
                jsr     pr_char
                lda     #'0'
                jsr     pr_char
                lda     DParams
                sec
                sbc     #<2000
                bra     _yy
_19             lda     #'1'
                jsr     pr_char
                lda     #'9'
                jsr     pr_char
                lda     DParams
                sec
                sbc     #<1900
_yy             jsr     pr_2dig
                lda     #'-'
                jsr     pr_char
                lda     DParams+2
                jsr     pr_2dig
                lda     #'-'
                jsr     pr_char
                lda     DParams+3
                jsr     pr_2dig
                lda     promptskip
                clc
                adc     #10
                sta     promptskip
                ply
                bra     _jloop
_time           lda     caps
                and     #CAP_DATETIME
                bne     +
                jmp     _loop
+               phy
                #api    1,20
                lda     DParams+4
                jsr     pr_2dig
                lda     #':'
                jsr     pr_char
                lda     DParams+5
                jsr     pr_2dig
                lda     #':'
                jsr     pr_char
                lda     DParams+6
                jsr     pr_2dig
                lda     promptskip
                clc
                adc     #8
                sta     promptskip
                ply
                jmp     _loop
_done           lda     oidx
                sta     promptbuf
                rts

; pr_char : ajoute A à promptbuf (index oidx, 90 caractères max)
pr_char         phx
                ldx     oidx
                cpx     #90
                bcs     +
                inx
                sta     promptbuf,x
                stx     oidx
+               plx
                rts

; pr_2dig : ajoute A (0-99) sur deux chiffres
pr_2dig         ldx     #0
-               cmp     #10
                bcc     +
                sbc     #10
                inx
                bra     -
+               pha
                txa
                ora     #'0'
                jsr     pr_char
                pla
                ora     #'0'
                jmp     pr_char

; ---------------------------------------------------------------------------
; read_command : lit une ligne au clavier -> linebuf (éditeur de ligne avec
; historique, lineedit.asm)
; ---------------------------------------------------------------------------
read_command    jmp     readline_ed

; ---------------------------------------------------------------------------
; execute_line : analyse linebuf et exécute la commande
; ---------------------------------------------------------------------------
execute_line    jsr     redir_setup             ; « > fichier » en fin de ligne
                jsr     execute_line1
                jmp     redir_close

execute_line1   lda     errorlevel              ; IF ERRORLEVEL lit la commande
                sta     preverr                 ; précédente
                stz     errorlevel
                jsr     parse_line
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
                beq     _dot                    ; « \X », « /X » : chemin
                cmp     #'/'
                beq     _dot
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
_dot            cpx     #0                      ; un mot ne peut commencer par « . » ni « \ »
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
                cpx     #200
                bcs     _rend
                lda     linebuf,y
                inx
                sta     argrest,x
                iny
                bra     _rest
_rend           stx     argrest
                ; arg1 et arg2 : découpage sur les espaces
                ldy     #0
                jsr     ptr_arg1
                jsr     get_word
                jsr     ptr_arg2
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
                ldx     namebuf                 ; runword = copie
-               lda     namebuf,x
                sta     runword,x
                dex
                bpl     -
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
                ; puis dans chaque répertoire de PATH
                ldy     #0
_path           jsr     path_next               ; dirbuf = entrée suivante
                bcs     _bad
                sty     by
                #setptr ptr2, runword
                jsr     ptr_namebuf
                jsr     build_path
                jsr     try_run
                ldx     runword                 ; en majuscules
                beq     _bad
-               lda     runword,x
                jsr     upper
                sta     newname,x
                dex
                bpl     -
                #setptr ptr2, newname
                jsr     ptr_namebuf
                jsr     build_path
                jsr     try_run
                ldy     by
                bra     _path
_bad            jmp     err_badcmd

; path_next : entrée suivante de PATH (à partir de Y) -> dirbuf ; C=1 si
; plus d'entrée. Les entrées sont séparées par « ; ».
path_next       ldx     #0
_skip           cpy     pathbuf
                bcs     _end
                lda     pathbuf+1,y
                iny
                cmp     #';'
                beq     _skip
                cmp     #' '
                beq     _skip
                bra     _store
_copy           cpy     pathbuf
                bcs     _fin
                lda     pathbuf+1,y
                iny
                cmp     #';'
                beq     _fin
_store          inx
                sta     dirbuf,x
                cpx     #100
                bcc     _copy
_fin            stx     dirbuf
                clc
                rts
_end            stx     dirbuf
                sec
                rts

; try_run : namebuf = nom ; lance NOM(.NEO|.BAT) s'il existe (sans retour),
; sinon revient.
try_run         jsr     ptr_namebuf
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
_run            jsr     redir_flush             ; la redirection reste ouverte
                stz     DParams                 ; (un programme écrivant via
                #api    3,5                     ; $C00E y participe) ; canaux
                lda     #CH_BAT                 ; 0 et 7 et répertoire fermés
                sta     DParams
                #api    3,5
                #api    3,19
                jsr     p0_namebuf
                stz     DParams+2               ; adresse : donnée par l'en-tête
                stz     DParams+3
                #api    3,2
                lda     DError
                bne     _loaderr
                jsr     install_stub            ; stub de retour en $0100
                lda     #>(STUB_BASE-1)         ; le RTS du programme y revient
                pha
                lda     #<(STUB_BASE-1)
                pha
                jmp     DExec                   ; JMP exec (ou RTS) ; la ligne de
                                                ; commande reste dans linebuf
                                                ; (pointeur en $C00C)
_loaderr        jsr     err_api
                jmp     neodos_back
_bat            jsr     stat_namebuf
                bne     _none
_runbat         jmp     run_batch
_none           rts

; neodos_back : retour d'un programme (depuis le stub, NeoDOS intact) ou
; échec de chargement : pile réinitialisée, reprise du batch ou invite
neodos_back     ldx     #$ff
                txs
                lda     bat_active              ; un batch reprend après le
                beq     +                       ; programme (comme MS-DOS)
                jmp     batch_next
+               jmp     mainloop

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
stat_namebuf    jsr     p0_namebuf
                #api    3,16
                lda     DError
                rts

ext_neo         .ptext  ".NEO"
ext_bat         .ptext  ".BAT"

; ---------------------------------------------------------------------------
; Messages d'erreur DOS
; ---------------------------------------------------------------------------
err_badcmd      jsr     errlvl1
                #println "Bad command or file name"
                rts
err_notfound    jsr     errlvl1
                #println "File not found"
                rts
err_syntax      jsr     errlvl1
                #println "Syntax error"
                rts
err_denied      jsr     errlvl1
                #println "Access denied"
                rts

; errlvl1 : la commande a échoué (IF ERRORLEVEL 1) ; préserve A
errlvl1         pha
                lda     #1
                sta     errorlevel
                pla
                rts

; err_api : message selon le code d'erreur API dans A (= DError du dernier
; appel ; à sauver dans errsave si des affichages précèdent)
err_api         jsr     errlvl1
                cmp     #ERR_NO_FILE
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

default_prompt  .ptext  "$p$g"

; ---------------------------------------------------------------------------
; Redirection de la sortie : « commande > fichier » ou « >> fichier »
; ---------------------------------------------------------------------------
; redir_setup : cherche « > » dans linebuf ; ouvre le fichier sur CH_OUT et
; retire « > fichier » de la ligne. Sans « > » : rien.
redir_setup     ldy     #1
_find           cpy     linebuf
                beq     +
                bcs     _none
+               lda     linebuf,y
                cmp     #'>'
                beq     _found
                iny
                bra     _find
_none           rts
_found          dey                             ; la ligne s'arrête avant « > »
                sty     tmp
                iny
                iny
                lda     #3                      ; mode : créer/tronquer
                sta     flag
                cpy     linebuf
                beq     +
                bcs     _name
+               lda     linebuf,y
                cmp     #'>'
                bne     _name
                iny
                lda     #2                      ; « >> » : lecture/écriture
                sta     flag
_name           ldx     #0
_sp             cpy     linebuf
                beq     +
                bcs     _open
+               lda     linebuf,y
                cmp     #' '
                bne     _cp
                iny
                bra     _sp
_cp             cpy     linebuf
                beq     +
                bcs     _open
+               lda     linebuf,y
                cmp     #' '
                beq     _open
                inx
                sta     newname,x
                iny
                bra     _cp
_open           stx     newname
                lda     tmp
                sta     linebuf                 ; ligne tronquée
                txa
                bne     +
                jmp     _syntax
+
                #setptr ptr, newname
                jsr     to_apipath
                lda     #CH_OUT
                sta     DParams
                #setparam 1, newname
                lda     flag
                sta     DParams+3
                #api    3,4
                lda     DError
                beq     +
                cmp     #ERR_NO_FILE            ; « >> » sur un fichier absent
                bne     _err
                lda     flag
                cmp     #2
                bne     _err
                lda     #CH_OUT
                sta     DParams
                #setparam 1, newname
                lda     #3
                sta     DParams+3
                #api    3,4
                lda     DError
                bne     _err
+               lda     flag
                cmp     #2
                bne     _ok
                lda     #CH_OUT                 ; « >> » : se placer à la fin
                sta     DParams
                #api    3,10
                lda     #CH_OUT
                sta     DParams
                #api    3,6
_ok             stz     outlen
                lda     #$80                    ; bit 7 : testé par BIT dans putc
                sta     redir
                rts
_err            jmp     err_api
_syntax         stz     linebuf                 ; « > » sans nom : rien n'est exécuté
                jmp     err_syntax

; redir_close : vide le tampon et ferme le fichier de redirection
redir_close     lda     redir
                beq     _done
                jsr     redir_flush
                stz     redir
                lda     #CH_OUT
                sta     DParams
                #api    3,5
_done           rts

; redir_put : A -> outbuf (CR devient CR LF) ; préserve A, X, Y
redir_put       pha
                cmp     #CR
                bne     +
                jsr     _one
                lda     #10
+               jsr     _one
                pla
                rts
_one            phx
                ldx     outlen
                sta     outbuf,x
                inx
                stx     outlen
                cpx     #OUTBUF_SIZE
                bne     +
                jsr     redir_flush
+               plx
                rts

; redir_flush : écrit outbuf sur CH_OUT en préservant les paramètres API
; (un affichage peut survenir entre un appel API et la lecture de son résultat)
redir_flush     lda     outlen
                beq     _done
                phy
                ldy     #8
-               lda     DParams-1,y
                sta     dpsave-1,y
                dey
                bne     -
                lda     DError
                sta     dpsave+8
                lda     #CH_OUT
                sta     DParams
                #setparam 1, outbuf
                lda     outlen
                sta     DParams+3
                stz     DParams+4
                #api    3,9
                ldy     #8
-               lda     dpsave-1,y
                sta     DParams-1,y
                dey
                bne     -
                lda     dpsave+8
                sta     DError
                stz     outlen
                ply
_done           rts

; ---------------------------------------------------------------------------
; Raccourcis (taille du code) : pointeurs et paramètres API fréquents
; ---------------------------------------------------------------------------
p0_arg1         lda     #<arg1
                sta     DParams
                lda     #>arg1
                sta     DParams+1
                rts
p0_namebuf      lda     #<namebuf
                sta     DParams
                lda     #>namebuf
                sta     DParams+1
                rts
ptr_arg1        lda     #<arg1
                sta     ptr
                lda     #>arg1
                sta     ptr+1
                rts
ptr_arg2        lda     #<arg2
                sta     ptr
                lda     #>arg2
                sta     ptr+1
                rts
ptr_namebuf     lda     #<namebuf
                sta     ptr
                lda     #>namebuf
                sta     ptr+1
                rts

; detect_caps : sonde les fonctions absentes de l'amont (Trinity) : sur carte
; une fonction inconnue ne touche ni les paramètres ni l'erreur.
detect_caps     stz     caps
                lda     #$ff
                sta     DParams
                #api    3,26                    ; volume courant : 0-3 si géré
                lda     DParams
                cmp     #4
                bcs     +
                lda     #CAP_VOLUMES
                sta     caps
+               lda     #$ff
                sta     DParams+7
                #api    1,20                    ; source de l'heure : 0-2 si géré
                lda     DParams+7
                cmp     #3
                bcs     +
                lda     caps
                ora     #CAP_DATETIME
                sta     caps
+               rts
