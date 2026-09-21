; tree.asm — commande externe NeoDOS : TREE [chemin] — arborescence des
; répertoires (et fichiers avec /F). Parcours en profondeur avec une pile de
; noms (le firmware n'a qu'un répertoire ouvert à la fois : chaque niveau
; est ré-énuméré en sautant les n premiers sous-répertoires).
;   make examples  ->  storage/BIN/TREE.NEO
ptr             = $80
sptr            = $82
cnt             = $84
depth           = $85
showfiles       = $86
idx             = $87
n               = $88           ; sous-répertoire recherché au niveau courant
found           = $89
MAX_DEPTH       = 8
                * = $0800
                jmp     main
                .include "neoext.inc"

main            stz     showfiles
                stz     pathbuf
                lda     #1
                jsr     cmd_arg
                jsr     take_arg
                lda     #2
                jsr     cmd_arg
                jsr     take_arg
                lda     pathbuf
                bne     +
                lda     #1                      ; défaut : « . »
                sta     pathbuf
                lda     #'.'
                sta     pathbuf+1
+               #setparam 0, pathbuf
                jsr     stat_path
                lda     DError
                bne     _nf
                lda     DParams+4
                and     #1
                bne     _ok
_nf             jsr     fail
                #println "Invalid path"
                rts
_ok             lda     #<pathbuf
                sta     ptr
                lda     #>pathbuf
                sta     ptr+1
                jsr     putpstr
                jsr     newline
                stz     depth
                stz     skip
_level          ; énumère le répertoire courant (pathbuf), affiche les
                ; entrées, retient le (skip[depth])-ième sous-répertoire
                jsr     list_level
                lda     found
                beq     _up
                ; descendre dans le sous-répertoire trouvé (namebuf)
                ldx     depth
                inc     skip,x                  ; la prochaine fois : le suivant
                cpx     #MAX_DEPTH-1
                bcs     _level                  ; trop profond : on n'entre pas
                jsr     path_push
                inc     depth
                ldx     depth
                stz     skip,x
                bra     _level
_up             lda     depth
                beq     _done
                jsr     path_pop
                dec     depth
                bra     _level
_done           rts

; take_arg : argbuf = « /F » -> showfiles, sinon pathbuf (premier chemin)
take_arg        lda     argbuf
                beq     _r
                cmp     #2
                bne     _path
                lda     argbuf+1
                cmp     #'/'
                bne     _path
                lda     argbuf+2
                and     #$DF
                cmp     #'F'
                bne     _r
                lda     #1
                sta     showfiles
                rts
_path           lda     pathbuf
                bne     _r
                ldx     argbuf
-               lda     argbuf,x
                sta     pathbuf,x
                dex
                bpl     -
_r              rts

; list_level : ouvre pathbuf ; pour chaque entrée : affiche (indentation
; = depth) sauf celles déjà visitées ; found = 1 et namebuf = nom du
; sous-répertoire n° skip[depth]
list_level      stz     found
                lda     showfiles               ; passe 1 : les fichiers, au
                beq     _dirs                   ; premier passage seulement
                ldx     depth
                lda     skip,x
                bne     _dirs
                jsr     open_level
_f              jsr     read_entry
                bcs     _fend
                lda     DParams+6
                and     #1
                bne     _f
                jsr     indent
                lda     #'|'
                jsr     putc
                lda     #' '
                jsr     putc
                jsr     put_name
                bra     _f
_fend           #api    3,19
_dirs           stz     n                       ; passe 2 : les répertoires
                jsr     open_level
_d              jsr     read_entry
                bcs     _dend
                lda     DParams+6
                and     #1
                beq     _d
                ldx     depth
                lda     n
                cmp     skip,x
                bcc     _seen                   ; déjà visité
                bne     _d                      ; au-delà : plus tard
                jsr     indent                  ; le prochain : afficher, retenir
                lda     #'+'
                jsr     putc
                lda     #'-'
                jsr     putc
                jsr     put_name
                lda     #1
                sta     found
                ldx     namebuf                 ; copie (namebuf est réutilisé)
-               lda     namebuf,x
                sta     subdir,x
                dex
                bpl     -
_seen           inc     n
                bra     _d
_dend           #api    3,19
                rts

open_level      #setparam 0, pathbuf
                #api    3,17
                rts
; read_entry : C=1 à la fin
read_entry      lda     #100
                sta     namebuf
                #setparam 0, namebuf
                #api    3,18
                lda     DError
                bne     _end
                clc
                rts
_end            sec
                rts
put_name        lda     #<namebuf
                sta     ptr
                lda     #>namebuf
                sta     ptr+1
                jsr     putpstr
                jmp     newline

; indent : « |  » par niveau
indent          ldx     depth
                beq     _r
-               lda     #'|'
                jsr     putc
                lda     #' '
                jsr     putc
                lda     #' '
                jsr     putc
                dex
                bne     -
_r              rts

; path_push : pathbuf += « / » + subdir ; path_pop : retire le dernier élément
path_push       ldx     pathbuf
                lda     #'/'
                inx
                sta     pathbuf,x
                ldy     #1
-               cpy     subdir
                beq     +
                bcs     _end
+               lda     subdir,y
                inx
                sta     pathbuf,x
                iny
                bra     -
_end            stx     pathbuf
                rts
path_pop        ldx     pathbuf
-               lda     pathbuf,x
                cmp     #'/'
                beq     +
                dex
                bne     -
+               dex
                stx     pathbuf
                rts

argbuf          .fill   122
pathbuf         .fill   129
namebuf         .fill   102
subdir          .fill   102
skip            .fill   MAX_DEPTH
