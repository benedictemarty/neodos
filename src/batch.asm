; batch.asm — exécution des fichiers .BAT (AUTOEXEC.BAT au démarrage)
;
; Le fichier est chargé en entier dans batbuf (768 octets maximum) puis exécuté
; ligne par ligne. Les paramètres %0-%9 sont remplacés par les mots de la
; ligne de commande qui a lancé le script (batargs). Un programme .NEO lancé
; depuis un batch rend la main au batch s'il se termine par RTS (et s'il n'a
; pas écrasé $C000-$FBFF) ; un .BAT lancé sans CALL remplace le script
; courant (comme MS-DOS) ; CALL empile le script courant (BAT_DEPTH niveaux)
; et le recharge à la fin de l'appelé. Les lignes « :label » sont des cibles
; de GOTO.

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
; run_batch : namebuf = nom du fichier (stat déjà fait : taille en DParams),
; linebuf = ligne de commande (%0-%9). Ne revient pas.
; ---------------------------------------------------------------------------
run_batch       ldx     namebuf                 ; batname = namebuf (tronqué)
                cpx     #BAT_NAME_SIZE-1
                bcc     +
                ldx     #BAT_NAME_SIZE-1
+               stx     batname
-               lda     namebuf,x
                sta     batname,x
                dex
                bne     -
                ldx     linebuf                 ; batargs = linebuf (tronqué)
                cpx     #BAT_ARGS_SIZE-1
                bcc     +
                ldx     #BAT_ARGS_SIZE-1
+               stx     batargs
                cpx     #0                      ; (STX ne positionne pas Z)
                beq     +
-               lda     linebuf,x
                sta     batargs,x
                dex
                bne     -
+               jsr     batch_load
                bcc     +
                jmp     batch_end
+               stz     bptr
                stz     bptr+1
                lda     #1
                sta     bat_active
                jmp     batch_next

; batch_load : charge le fichier batname dans batbuf (taille via File Stat) ;
; C=1 si impossible (message affiché)
batch_load      ldx     batname
-               lda     batname,x
                sta     namebuf,x
                dex
                bpl     -
                jsr     stat_namebuf
                beq     +
                jsr     err_api
                sec
                rts
+               lda     DParams+2               ; taille > 65535 ?
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
_big            jsr     errlvl1
                #println "Batch file too large (max 768 bytes)"
                sec
                rts
_load           jsr     p0_namebuf
                #setparam 2, batbuf
                #api    3,2
                lda     DError
                beq     +
                jsr     err_api
                sec
                rts
+               clc
                rts

; ---------------------------------------------------------------------------
; batch_next : ligne suivante du script (boucle principale du batch)
; ---------------------------------------------------------------------------
batch_next      ldx     #$ff                    ; boucle de haut niveau : pile
                txs                             ; propre (CALL/GOTO y sautent)
                cli
                jsr     check_cad               ; Ctrl+Alt+Suppr : sort d'un
                lda     bptr                    ; script en boucle ; fin du tampon ?
                cmp     blen
                lda     bptr+1
                sbc     blen+1
                bcs     batch_end
                jsr     batch_getline           ; -> linebuf (paramètres remplacés)
                lda     linebuf
                beq     batch_next
                lda     linebuf+1
                cmp     #':'                    ; « :label » : ignorée
                beq     batch_next
                cmp     #'@'                    ; « @ » en tête : pas d'écho
                bne     _echo
                ldy     #2                      ; décale la ligne d'un caractère
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
                beq     batch_next
                jsr     execute_line
                jmp     batch_next

; ---------------------------------------------------------------------------
; batch_end : fin du script courant : retour à l'appelant (CALL) ou à l'invite
; ---------------------------------------------------------------------------
batch_end       lda     batdepth
                beq     _prompt
                dec     batdepth
                jsr     level_addr              ; ptr -> niveau à restaurer
                ldy     #0
-               lda     (ptr),y                 ; batname
                sta     batname,y
                iny
                cpy     #BAT_NAME_SIZE
                bne     -
                ldx     #0
-               lda     (ptr),y                 ; batargs
                sta     batargs,x
                iny
                inx
                cpx     #BAT_ARGS_SIZE
                bne     -
                lda     (ptr),y                 ; bptr
                sta     bptr
                iny
                lda     (ptr),y
                sta     bptr+1
                jsr     batch_load              ; recharge l'appelant
                bcs     _prompt
                jmp     batch_next
_prompt         stz     bat_active
                stz     batdepth
                stz     echo_off
                jmp     mainloop

; level_addr : ptr = batstack + batdepth * BAT_LEVEL_SIZE
level_addr      lda     batdepth
                asl     a
                tax
                lda     level_offsets,x
                clc
                adc     #<batstack
                sta     ptr
                lda     level_offsets+1,x
                adc     #>batstack
                sta     ptr+1
                rts

level_offsets   .word   0, BAT_LEVEL_SIZE, BAT_LEVEL_SIZE*2

; ---------------------------------------------------------------------------
; batch_getline : copie la ligne courante de batbuf dans linebuf en
; remplaçant %0-%9 par les mots de batargs ; avance bptr après la ligne.
; ---------------------------------------------------------------------------
batch_getline   stz     bx                      ; longueur de linebuf
_copy           lda     bptr                    ; fin du tampon ?
                cmp     blen
                lda     bptr+1
                sbc     blen+1
                bcs     _eol
                lda     #<batbuf
                clc
                adc     bptr
                sta     ptr
                lda     #>batbuf
                adc     bptr+1
                sta     ptr+1
                lda     (ptr)
                inc     bptr
                bne     +
                inc     bptr+1
+               cmp     #CR
                beq     _eol
                cmp     #10
                beq     _eol
                cmp     #'%'
                bne     _store
                ; %d ? (s'il reste un caractère)
                lda     bptr
                cmp     blen
                lda     bptr+1
                sbc     blen+1
                bcs     _pct
                ldy     #1
                lda     (ptr),y
                cmp     #'0'
                bcc     _pct
                cmp     #'9'+1
                bcs     _pct
                inc     bptr                    ; consomme le chiffre
                bne     +
                inc     bptr+1
+               and     #$0f
                jsr     insert_arg
                bra     _copy
_pct            lda     #'%'
_store          ldx     bx
                cpx     #200
                bcs     _copy                   ; ligne trop longue : tronquée
                inx
                sta     linebuf,x
                stx     bx
                bra     _copy
_eol            lda     bx
                sta     linebuf
                rts

; insert_arg : ajoute à linebuf le mot n° A (0 = premier) de batargs
insert_arg      sta     cnt
                ldy     #0
_skip           cpy     batargs                 ; sauter les espaces
                bcs     _done
                lda     batargs+1,y
                cmp     #' '
                bne     _word
                iny
                bra     _skip
_word           lda     cnt
                beq     _copy
                dec     cnt
-               cpy     batargs                 ; sauter ce mot
                bcs     _done
                lda     batargs+1,y
                cmp     #' '
                beq     _skip
                iny
                bra     -
_copy           cpy     batargs
                bcs     _done
                lda     batargs+1,y
                cmp     #' '
                beq     _done
                ldx     bx
                cpx     #200
                bcs     _done
                inx
                sta     linebuf,x
                stx     bx
                iny
                bra     _copy
_done           rts

; ---------------------------------------------------------------------------
; GOTO label : cherche « :label » dans batbuf et reprend après cette ligne
; ---------------------------------------------------------------------------
cmd_goto        lda     bat_active
                bne     +
                rts                             ; hors batch : ignoré (DOS)
+               lda     arg1
                beq     _syntax
                lda     arg1+1                  ; « GOTO :label » accepté
                cmp     #':'
                bne     _scan
                ldx     #0
-               lda     arg1+2,x
                sta     arg1+1,x
                inx
                cpx     arg1
                bne     -
                dec     arg1
                beq     _syntax
_scan           stz     bptr                    ; parcours depuis le début
                stz     bptr+1
_line           lda     bptr
                cmp     blen
                lda     bptr+1
                sbc     blen+1
                bcs     _notfound
                jsr     batch_getline
                lda     linebuf
                beq     _line
                lda     linebuf+1
                cmp     #':'
                bne     _line
                ; compare le label (jusqu'à un espace) avec arg1
                ldy     #1
_cmp            cpy     arg1
                beq     +
                bcs     _endlbl
+               lda     linebuf+1,y
                jsr     upper
                sta     tmp
                lda     arg1,y
                jsr     upper
                cmp     tmp
                bne     _line
                iny
                bra     _cmp
_endlbl         ; arg1 épuisé : la ligne doit finir ou continuer par un espace
                tya
                cmp     linebuf
                bcs     _found
                lda     linebuf+1,y
                cmp     #' '
                bne     _line
_found          jmp     batch_next
_notfound       jsr     errlvl1
                #println "Label not found"
                jmp     batch_end
_syntax         jmp     err_syntax

; ---------------------------------------------------------------------------
; CALL script [args] : exécute un .BAT puis revient au script appelant
; ---------------------------------------------------------------------------
cmd_call        lda     arg1
                beq     _syntax
                ; la ligne de commande de l'appelé = argrest (« script args »)
                ldx     argrest
-               lda     argrest,x
                sta     linebuf,x
                dex
                bpl     -
                lda     bat_active
                beq     _run                    ; hors batch : simple lancement
                lda     batdepth
                cmp     #BAT_DEPTH
                bcc     _push
                jsr     errlvl1
                #println "Too many nested CALLs"
                rts
_push           jsr     level_addr              ; empile le niveau courant
                ldy     #0
-               lda     batname,y
                sta     (ptr),y
                iny
                cpy     #BAT_NAME_SIZE
                bne     -
                ldx     #0
-               lda     batargs,x
                sta     (ptr),y
                iny
                inx
                cpx     #BAT_ARGS_SIZE
                bne     -
                lda     bptr
                sta     (ptr),y
                iny
                lda     bptr+1
                sta     (ptr),y
                inc     batdepth
_run            jsr     call_resolve            ; namebuf = script trouvé
                bcc     +
                lda     bat_active              ; échec : dépile
                beq     _nf
                dec     batdepth
_nf             jmp     err_notfound
+               jmp     run_batch
_syntax         jmp     err_syntax

; call_resolve : namebuf = arg1 [+ « .BAT »], tel que tapé puis en
; majuscules ; C=0 si le fichier existe (stat fait)
call_resolve    ldx     arg1
-               lda     arg1,x
                sta     namebuf,x
                dex
                bpl     -
                jsr     ptr_namebuf
                jsr     to_apipath
                jsr     call_try
                bcc     _ok
                ldx     namebuf                 ; en majuscules
-               lda     namebuf,x
                jsr     upper
                sta     namebuf,x
                dex
                bne     -
                jsr     call_try
_ok             rts

; call_try : stat namebuf, puis namebuf + « .BAT » ; C=0 si trouvé
call_try        jsr     stat_namebuf
                beq     _found
                #setptr ptr2, ext_bat
                jsr     append_ext
                jsr     stat_namebuf
                beq     _found
                lda     namebuf
                sec
                sbc     #4
                sta     namebuf
                sec
                rts
_found          clc
                rts

; ---------------------------------------------------------------------------
; SHIFT : décale les paramètres du script (%0 <- %1, %1 <- %2…) en retirant
; le premier mot de batargs ; sans effet hors d'un script ou sans paramètre.
; ---------------------------------------------------------------------------
cmd_shift       lda     bat_active
                beq     _done
                ldy     #0
_skip           cpy     batargs                 ; espaces de tête
                bcs     _empty
                lda     batargs+1,y
                cmp     #' '
                bne     _word
                iny
                bra     _skip
_word           cpy     batargs                 ; le mot
                bcs     _empty
                lda     batargs+1,y
                cmp     #' '
                beq     _move
                iny
                bra     _word
_move           ldx     #0                      ; batargs = reste (dès l'espace)
-               cpy     batargs
                bcs     _end
                lda     batargs+1,y
                inx
                sta     batargs,x
                iny
                bra     -
_end            stx     batargs
_done           rts
_empty          stz     batargs
                rts

; ---------------------------------------------------------------------------
; FOR %v IN (élément…) DO commande : pour chaque élément (un motif est
; remplacé par les fichiers correspondants, un autre mot est pris tel quel),
; la commande est exécutée avec %v (ou %%v, forme .BAT de DOS) remplacé.
; L'ensemble et le modèle sont copiés dans forset/fortpl (la commande
; réutilise argrest, arg1, listbuf…) ; les correspondances sont relues à
; chaque tour (formatch = rang) pour la même raison. Un programme .NEO dans
; DO ne revient pas dans la boucle ; pas de FOR imbriqué.
; ---------------------------------------------------------------------------
cmd_for         ldy     #0
                bra     _start
_jsyn           jmp     err_syntax
_start
                jsr     for_spaces
                lda     argrest+1,y             ; %v ou %%v
                cmp     #'%'
                bne     _jsyn
                iny
                lda     argrest+1,y
                cmp     #'%'
                bne     +
                iny
                lda     argrest+1,y
+               jsr     upper
                sta     forvar
                iny
                jsr     for_spaces
                lda     argrest+1,y             ; IN
                jsr     upper
                cmp     #'I'
                bne     _jsyn
                iny
                lda     argrest+1,y
                jsr     upper
                cmp     #'N'
                bne     _jsyn
                iny
                jsr     for_spaces
                lda     argrest+1,y             ; (ensemble)
                cmp     #'('
                bne     _jsyn
                iny
                ldx     #0
_set            cpy     argrest
                bcs     _jsyn                   ; « ) » manquante
                lda     argrest+1,y
                iny
                cmp     #')'
                beq     _setend
                cpx     #FORSET_SIZE
                bcs     _set
                inx
                sta     forset,x
                bra     _set
_setend         stx     forset
                jsr     for_spaces
                lda     argrest+1,y             ; DO
                jsr     upper
                cmp     #'D'
                bne     _jsyn
                iny
                lda     argrest+1,y
                jsr     upper
                cmp     #'O'
                bne     _jsyn
                iny
                jsr     for_spaces
                ldx     #0
_tpl            cpy     argrest
                bcs     _tplend
                lda     argrest+1,y
                iny
                cpx     #FORTPL_SIZE
                bcs     _tpl
                inx
                sta     fortpl,x
                bra     _tpl
_tplend         stx     fortpl
                txa
                bne     +
                jmp     err_syntax
+               stz     foritem
_item           lda     foritem                 ; arg1 = élément n° foritem
                jsr     for_item
                lda     arg1
                beq     _done
                inc     foritem
                jsr     ptr_arg1
                jsr     to_apipath
                jsr     has_wild
                bcs     _wild
                ldx     arg1                    ; mot : tel quel
-               lda     arg1,x
                sta     namebuf,x
                dex
                bpl     -
                jsr     for_exec
                bra     _item
_wild           stz     formatch
_match          lda     foritem                 ; arg1 relu (écrasé par la
                dec     a                       ; commande)
                jsr     for_item
                jsr     ptr_arg1
                jsr     to_apipath
                jsr     split_path
                lda     #0                      ; fichiers seulement
                jsr     collect_matches
                bcs     _item
                lda     formatch
                cmp     lcount
                bcs     _item                   ; épuisé
                jsr     list_first
                ldx     formatch
                inx
-               jsr     list_next               ; ptr2 -> n° formatch
                dex
                bne     -
                inc     formatch
                jsr     ptr_namebuf
                jsr     build_path              ; namebuf = dirbuf/nom
                jsr     for_exec
                bra     _match
_done           rts
_syntax         jmp     err_syntax

; for_spaces : avance Y sur argrest (0-based) tant que c'est un espace
for_spaces      cpy     argrest
                bcs     _done
                lda     argrest+1,y
                cmp     #' '
                bne     _done
                iny
                bra     for_spaces
_done           rts

; for_item : arg1 = mot n° A de forset (pstring ; vide si absent)
for_item        sta     cnt
                stz     arg1
                ldy     #0
_skip           cpy     forset
                bcs     _done
                lda     forset+1,y
                cmp     #' '
                bne     _word
                iny
                bra     _skip
_word           lda     cnt
                beq     _copy
                dec     cnt
-               cpy     forset
                bcs     _done
                lda     forset+1,y
                cmp     #' '
                beq     _skip
                iny
                bra     -
_copy           ldx     #0
-               cpy     forset
                bcs     _end
                lda     forset+1,y
                cmp     #' '
                beq     _end
                inx
                sta     arg1,x
                iny
                cpx     #100
                bne     -
_end            stx     arg1
_done           rts

; for_exec : linebuf = fortpl avec %v / %%v remplacés par namebuf (« / »
; rendus en « \ »), puis exécution
for_exec        ldy     #0
                ldx     #0
_copy           cpy     fortpl
                bcs     _run
                lda     fortpl+1,y
                iny
                cmp     #'%'
                bne     _store
                lda     fortpl+1,y              ; « %% » : un seul compte
                cmp     #'%'
                bne     +
                iny
                lda     fortpl+1,y
+               jsr     upper
                cmp     forvar
                bne     _pct
                iny                             ; %v -> namebuf
                phy
                ldy     #1
-               cpy     namebuf
                beq     +
                bcs     _sub
+               lda     namebuf,y
                cmp     #'/'
                bne     +
                lda     #'\'
+               cpx     #200
                bcs     _sub
                inx
                sta     linebuf,x
                iny
                bra     -
_sub            ply
                bra     _copy
_pct            lda     #'%'
_store          cpx     #200
                bcs     _copy
                inx
                sta     linebuf,x
                bra     _copy
_run            stx     linebuf
                jmp     execute_line
