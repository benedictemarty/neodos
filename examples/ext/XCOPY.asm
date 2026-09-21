; XCOPY.asm — commande externe NeoDOS : XCOPY source destination [/S] —
; copie les fichiers d'un répertoire vers un autre (créé au besoin) ; /S
; copie aussi les sous-répertoires (parcours walk.inc, chemin de destination
; tenu en parallèle).
;   make examples  ->  storage/BIN/XCOPY.NEO
ptr             = $80
sptr            = $82
cnt             = $84
depth           = $85
n               = $86
found           = $87
ptr2            = $88
recurse         = $8A
count           = $8B
                * = $0800
                jmp     main
                .include "neoext.inc"
                .include "walk.inc"

main            stz     recurse
                stz     pathbuf
                stz     dstpath
                stz     count
                lda     #1
                jsr     cmd_arg
                jsr     take_arg
                lda     #2
                jsr     cmd_arg
                jsr     take_arg
                lda     #3
                jsr     cmd_arg
                jsr     take_arg
                lda     dstpath
                bne     +
                jsr     fail
                #println "Usage: XCOPY source destination [/S]"
                rts
+               #setparam 0, pathbuf            ; source : un répertoire
                #api    3,16
                lda     DError
                bne     _bad
                lda     DParams+4
                and     #1
                bne     _ok
_bad            jsr     fail
                #println "Invalid source directory"
                rts
_ok             jsr     ensure_dst
                bcs     _done
                jsr     walk
                lda     count
                jsr     print8
                #println " file(s) copied"
_done           rts

; take_arg : « /S » -> recurse ; sinon pathbuf puis dstpath
take_arg        lda     argbuf
                beq     _r
                cmp     #2
                bne     _path
                lda     argbuf+1
                cmp     #'/'
                bne     _path
                lda     argbuf+2
                and     #$DF
                cmp     #'S'
                bne     _r
                lda     #1
                sta     recurse
                rts
_path           lda     pathbuf
                bne     _dst
                ldx     argbuf
-               lda     argbuf,x
                sta     pathbuf,x
                dex
                bpl     -
                rts
_dst            lda     dstpath
                bne     _r
                ldx     argbuf
-               lda     argbuf,x
                sta     dstpath,x
                dex
                bpl     -
_r              rts

; ensure_dst : crée dstpath s'il n'existe pas ; C=1 si impossible
ensure_dst      #setparam 0, dstpath
                #api    3,16
                lda     DError
                beq     _ok
                #setparam 0, dstpath
                #api    3,14
                lda     DError
                beq     _ok
                lda     #<dstpath
                sta     ptr
                lda     #>dstpath
                sta     ptr+1
                jsr     putpstr
                jsr     fail
                #println ": unable to create directory"
                sec
                rts
_ok             clc
                rts

; hook_file : copie pathbuf/namebuf -> dstpath/namebuf
hook_file       lda     #<pathbuf
                sta     ptr2
                lda     #>pathbuf
                sta     ptr2+1
                lda     #<srcfile
                sta     ptr
                lda     #>srcfile
                sta     ptr+1
                jsr     join
                lda     #<dstpath
                sta     ptr2
                lda     #>dstpath
                sta     ptr2+1
                lda     #<dstfile
                sta     ptr
                lda     #>dstfile
                sta     ptr+1
                jsr     join
                #setparam 0, srcfile
                #setparam 2, dstfile
                #api    3,20
                lda     DError
                bne     _err
                inc     count
                rts
_err            lda     #<srcfile
                sta     ptr
                lda     #>srcfile
                sta     ptr+1
                jsr     putpstr
                #println ": copy failed"
                rts

; hook_enter : sans /S, ne pas descendre : on remonte aussitôt (le parcours
; appellera hook_leave puis remontera) ; avec /S : dstpath += subdir, mkdir
hook_enter      lda     recurse
                bne     +
                ldx     depth                   ; marque tout le niveau comme vu
                lda     #$7F
                sta     skip,x
                rts
+               ldx     dstpath
                lda     #'/'
                inx
                sta     dstpath,x
                ldy     #1
-               cpy     subdir
                beq     +
                bcs     _mk
+               lda     subdir,y
                inx
                sta     dstpath,x
                iny
                bra     -
_mk             stx     dstpath
                jmp     ensure_dst
hook_leave      lda     depth
                beq     _r
                lda     recurse
                beq     _r
                ldx     dstpath                 ; retire le dernier élément
-               lda     dstpath,x
                cmp     #'/'
                beq     +
                dex
                bne     -
+               dex
                stx     dstpath
_r              rts

; print8 : A en décimal
print8          ldx     #0
                sec
-               sbc     #100
                bcc     +
                inx
                bra     -
+               adc     #100
                pha
                txa
                beq     +
                ora     #'0'
                jsr     putc
+               pla
                ldx     #0
                sec
-               sbc     #10
                bcc     +
                inx
                bra     -
+               adc     #10
                pha
                txa
                beq     +
                ora     #'0'
                jsr     putc
+               pla
                ora     #'0'
                jmp     putc

argbuf          .fill   122
pathbuf         .fill   129
dstpath         .fill   129
namebuf         .fill   102
subdir          .fill   102
srcfile         .fill   232
dstfile         .fill   232
skip            .fill   WALK_DEPTH
