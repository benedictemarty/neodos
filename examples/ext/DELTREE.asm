; DELTREE.asm — commande externe NeoDOS : DELTREE répertoire — supprime un
; répertoire et tout son contenu (confirmation Y/N). Parcours walk.inc :
; fichiers effacés à la première visite, répertoire effacé en le quittant.
;   make examples  ->  storage/BIN/DELTREE.NEO
ptr             = $80
sptr            = $82
cnt             = $84
depth           = $85
n               = $86
found           = $87
ptr2            = $88
                * = $0800
                jmp     main
                .include "neoext.inc"
                .include "walk.inc"

main            lda     #1
                jsr     cmd_arg
                lda     argbuf
                bne     +
                #println "Usage: DELTREE directory"
                rts
+               ldx     argbuf                  ; pathbuf = argument
-               lda     argbuf,x
                sta     pathbuf,x
                dex
                bpl     -
                #setparam 0, pathbuf
                #api    3,16
                lda     DError
                bne     _bad
                lda     DParams+4
                and     #1
                bne     _ask
_bad            #println "Invalid path"
                rts
_ask            #print  "Delete directory "
                lda     #<pathbuf
                sta     ptr
                lda     #>pathbuf
                sta     ptr+1
                jsr     putpstr
                #print  " and all its subdirectories? (Y/N) "
-               jsr     getkey
                and     #$DF
                cmp     #'N'
                beq     _no
                cmp     #'Y'
                bne     -
                jsr     putc
                jsr     newline
                jmp     walk
_no             jsr     putc
                jmp     newline

; hook_file : efface pathbuf/namebuf
hook_file       lda     #<pathbuf
                sta     ptr2
                lda     #>pathbuf
                sta     ptr2+1
                lda     #<fullbuf
                sta     ptr
                lda     #>fullbuf
                sta     ptr+1
                jsr     join
                #setparam 0, fullbuf
                #api    3,13
                lda     DError
                beq     +
                jsr     report_err
+               rts
hook_enter      rts
; hook_leave : le répertoire (vide) est effacé
hook_leave      #setparam 0, pathbuf
                #api    3,13
                lda     DError
                beq     +
                lda     #<pathbuf
                sta     ptr
                lda     #>pathbuf
                sta     ptr+1
                jsr     putpstr
                #println ": cannot remove"
+               rts
report_err      lda     #<fullbuf
                sta     ptr
                lda     #>fullbuf
                sta     ptr+1
                jsr     putpstr
                #println ": cannot delete"
                rts

argbuf          .fill   122
pathbuf         .fill   129
namebuf         .fill   102
subdir          .fill   102
fullbuf         .fill   232
skip            .fill   WALK_DEPTH
