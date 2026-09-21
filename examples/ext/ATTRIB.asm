; ATTRIB.asm — commande externe NeoDOS : ATTRIB [+R -R +H -H +S -S +A -A]
; [fichier|motif|répertoire] — affiche (colonnes A S H R puis le chemin) ou
; modifie les attributs des fichiers correspondants (un répertoire : son
; contenu ; sans argument : « * »). Le bit répertoire n'est jamais touché.
; Résident jusqu'à la 0.13.0 (cmd_attrib), externalisé en 0.14.0 (ADR-003).
;   make examples  ->  storage/BIN/ATTRIB.NEO
ptr             = $80
sptr            = $82
cnt             = $84
tmp             = $85
mstar_p         = $86
mstar_n         = $87
attr_set        = $88
attr_clr        = $89
lptr            = $8A           ; écriture dans la liste des noms (2)
count           = $8C           ; noms collectés (16 bits)
argn            = $8E           ; numéro du mot en cours
oidx            = $8F           ; build_path : longueur produite
LIST            = $2000         ; noms collectés (pstrings consécutives)
LIST_END        = $B000
                * = $0800
                jmp     main
                .include "neoext.inc"
                .include "glob.inc"

main            stz     attr_set
                stz     attr_clr
                stz     pathbuf
                stz     argn
_word           inc     argn
                lda     argn
                jsr     cmd_arg
                lda     argbuf
                beq     _parsed
                cmp     #2
                bne     _path
                lda     argbuf+1
                cmp     #'+'
                beq     _plus
                cmp     #'-'
                bne     _path
                lda     argbuf+2
                jsr     attr_bit
                beq     _bad
                ora     attr_clr
                sta     attr_clr
                bra     _word
_plus           lda     argbuf+2
                jsr     attr_bit
                beq     _bad
                ora     attr_set
                sta     attr_set
                bra     _word
_bad            jsr     fail
                #println "Invalid parameter"
                rts
_path           lda     pathbuf                 ; premier chemin seulement
                bne     _word
                ldx     argbuf
-               lda     argbuf,x
                sta     pathbuf,x
                dex
                bpl     -
                bra     _word
_parsed         lda     pathbuf
                bne     +
                lda     #1                      ; sans fichier : « * »
                sta     pathbuf
                lda     #'*'
                sta     pathbuf+1
+               ldx     pathbuf                 ; argbuf = pathbuf (split_path)
-               lda     pathbuf,x
                sta     argbuf,x
                dex
                bpl     -
                lda     #<argbuf
                sta     ptr
                lda     #>argbuf
                sta     ptr+1
                jsr     has_wild
                bcs     _wild
                #setparam 0, argbuf             ; un répertoire : son contenu
                jsr     stat_path
                lda     DError
                bne     _wild
                lda     DParams+4
                and     #ATTR_DIR
                beq     _wild
                ldx     argbuf
                lda     #'/'
                inx
                sta     argbuf,x
                lda     #'*'
                inx
                sta     argbuf,x
                stx     argbuf
_wild           jsr     split_path
                jsr     collect
                bcc     +
                rts
+                lda     count
                ora     count+1
                bne     +
                jsr     fail
                #println "File not found"
                rts
+               lda     #<LIST
                sta     ptr
                lda     #>LIST
                sta     ptr+1
_each           lda     count
                ora     count+1
                bne     +
                rts
+               jsr     build_path              ; namebuf = dirbuf/nom
                jsr     next_name
                #setparam 0, namebuf
                #api    3,16
                lda     DError
                bne     _each
                lda     attr_set
                ora     attr_clr
                bne     _change
                ; affichage : A S H R  chemin
                lda     DParams+4
                sta     tmp
                and     #ATTR_ARCHIVE
                ldx     #'A'
                jsr     attr_show
                lda     tmp
                and     #ATTR_SYSTEM
                ldx     #'S'
                jsr     attr_show
                lda     tmp
                and     #ATTR_HIDDEN
                ldx     #'H'
                jsr     attr_show
                lda     tmp
                and     #ATTR_READONLY
                ldx     #'R'
                jsr     attr_show
                lda     #' '
                jsr     putc
                jsr     put_namebuf
                jsr     newline
                jmp     _each
_change         lda     DParams+4
                and     #ATTR_DIR               ; jamais le bit répertoire
                sta     tmp
                lda     DParams+4
                ora     attr_set
                sta     cnt
                lda     attr_clr
                eor     #$ff
                and     cnt
                and     #~ATTR_DIR
                ora     tmp
                sta     DParams+2
                #setparam 0, namebuf
                #api    3,21
                lda     DError
                bne     +
                jmp     _each
+               pha
                jsr     put_namebuf
                #print  ": "
                pla
                jsr     err_api
                jmp     _each

; collect : ouvre dirbuf, copie dans LIST les fichiers (pas les répertoires)
; dont le nom correspond à patbuf ; count = nombre ; C=1 si erreur (affichée)
collect         stz     count
                stz     count+1
                lda     #<LIST
                sta     lptr
                lda     #>LIST
                sta     lptr+1
                #setparam 0, dirbuf
                #api    3,17
                lda     DError
                beq     _next
                jsr     err_api
                sec
                rts
_next           lda     #100
                sta     namebuf
                #setparam 0, namebuf
                #api    3,18
                lda     DError
                bne     _end
                lda     DParams+6
                and     #ATTR_DIR
                bne     _next
                jsr     match_glob
                bcc     _next
                lda     lptr+1                  ; place ? (LIST_END - 128)
                cmp     #>(LIST_END-128)
                bcs     _full
                ldy     namebuf
-               lda     namebuf,y
                sta     (lptr),y
                dey
                bpl     -
                lda     namebuf
                sec
                adc     lptr
                sta     lptr
                bcc     +
                inc     lptr+1
+               inc     count
                bne     _next
                inc     count+1
                bra     _next
_full           #api    3,19
                jsr     fail
                #println "Too many files"
                sec
                rts
_end            #api    3,19
                clc
                rts

; build_path : namebuf = dirbuf + « / » + pstring (ptr) (dirbuf « . » : nom
; seul ; dirbuf finissant par « / » : pas de doublon)
build_path      stz     oidx
                lda     dirbuf
                cmp     #1
                bne     _copydir
                lda     dirbuf+1
                cmp     #'.'
                beq     _name
_copydir        ldy     #1
-               lda     dirbuf,y
                jsr     app_char
                iny
                cpy     dirbuf
                beq     -
                bcc     -
                ldy     dirbuf
                lda     dirbuf,y
                cmp     #'/'
                beq     _name
                lda     #'/'
                jsr     app_char
_name           ldy     #1
_loop           tya
                cmp     (ptr)
                beq     +
                bcs     _end
+               lda     (ptr),y
                jsr     app_char
                iny
                bra     _loop
_end            lda     oidx
                sta     namebuf
                rts
app_char        phy
                inc     oidx
                ldy     oidx
                sta     namebuf,y
                ply
                rts

; next_name : ptr -> pstring suivante de LIST ; count--
next_name       lda     (ptr)
                sec
                adc     ptr
                sta     ptr
                bcc     +
                inc     ptr+1
+               lda     count
                bne     +
                dec     count+1
+               dec     count
                rts

; put_namebuf : affiche namebuf avec des « \ »
put_namebuf     ldy     #1
-               cpy     namebuf
                beq     +
                bcs     _done
+               lda     namebuf,y
                cmp     #'/'
                bne     +
                lda     #'\'
+               jsr     putc
                iny
                bra     -
_done           rts

; attr_bit : A = lettre -> masque (0 si inconnue)
attr_bit        jsr     upper
                ldx     #ATTR_READONLY
                cmp     #'R'
                beq     _ok
                ldx     #ATTR_HIDDEN
                cmp     #'H'
                beq     _ok
                ldx     #ATTR_SYSTEM
                cmp     #'S'
                beq     _ok
                ldx     #ATTR_ARCHIVE
                cmp     #'A'
                beq     _ok
                lda     #0
                rts
_ok             txa
                rts

; attr_show : affiche X si A != 0, sinon un espace
attr_show       cmp     #0
                bne     +
                ldx     #' '
+               txa
                jmp     putc

; err_api : message selon le code d'erreur API dans A
err_api         cmp     #$11
                beq     _nf
                cmp     #$12
                beq     _path
                cmp     #$21
                beq     _denied
                pha
                #print  "Error "
                pla
                jsr     print8
                jmp     newline
_nf             jsr     fail
                #println "File not found"
                rts
_path           jsr     fail
                #println "Path not found"
                rts
_denied         jsr     fail
                #println "Access denied"
                rts

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

ATTR_DIR        = $01
ATTR_SYSTEM     = $02
ATTR_ARCHIVE    = $04
ATTR_READONLY   = $08
ATTR_HIDDEN     = $10

argbuf          .fill   130
pathbuf         .fill   130
dirbuf          .fill   130
patbuf          .fill   130
namebuf         .fill   232
