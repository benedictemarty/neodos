; CONCAT.asm — commande externe NeoDOS : concaténation de fichiers.
; COPY a+b[+c…] destination (le résident passe la main à CONCAT dès qu'un
; « + » apparaît dans la source) ou directement CONCAT a+b[+c…] destination.
; Les sources sont lues par blocs de 16 Ko et écrites bout à bout dans la
; destination, en binaire. Destination = première source : les suivantes y
; sont ajoutées (COPY LOG.TXT+NEW.TXT LOG.TXT, comme MS-DOS) ; destination =
; une autre source : refusé avant toute écriture (elle serait tronquée avant
; d'être lue). Toutes les sources doivent exister avant que la destination
; soit ouverte. Les « + » sont collés aux noms, pas de jokers.
;   make examples  ->  storage/BIN/CONCAT.NEO
ptr             = $80
sptr            = $82
cnt             = $84
idx             = $85
append          = $86
tmp             = $87
errsave         = $88
CH_SRC          = 4             ; NeoDOS utilise 0, 1 (redirection) et 7
CH_DST          = 5
BUF             = $2000
BUF_SIZE        = $4000
                * = $0800
                jmp     main
                .include "neoext.inc"

main            lda     #2                      ; destination
                jsr     cmd_arg
                ldx     argbuf
                beq     _usage
-               lda     argbuf,x
                sta     dest,x
                dex
                bpl     -
                lda     #1                      ; sources
                jsr     cmd_arg
                lda     argbuf
                bne     _scan0
_usage          jsr     fail
                #println "Usage: COPY source+source[+...] destination"
                rts
_scan0          stz     append                  ; destination = 1re source ?
                lda     #1
                sta     idx
                jsr     next_src
                jsr     stat_src
                beq     +
                jmp     _serr0
+
                jsr     is_dest
                bne     _scan
                inc     append
_scan           jsr     next_src                ; sources suivantes
                bcs     _open
                jsr     stat_src
                beq     +
                jmp     _serr0
+
                jsr     is_dest
                bne     _scan
                jsr     fail
                #println "Content of destination lost before copy"
                rts
_open           lda     #1                      ; retour à la première source
                sta     idx
                jsr     next_src
                lda     append
                beq     _new
                lda     #2                      ; lecture/écriture, puis fin
                jsr     open_dest
                bne     _derr
                lda     #CH_DST
                sta     DParams
                #api    3,10                    ; taille
                lda     #CH_DST
                sta     DParams
                #api    3,6                     ; Seek à la taille
                bra     _next
_new            lda     #3                      ; créer/tronquer
                jsr     open_dest
                bne     _derr
_src            jsr     copy_src
                bne     _serr
_next           jsr     next_src
                bcc     _src
                jsr     close_dest
                #println "        1 file(s) copied"
                rts
_serr           sta     errsave                 ; source : « nom: message »
                jsr     close_dest
                bra     +
_serr0          sta     errsave                 ; source absente : rien d'écrit
+               lda     #<name
                sta     ptr
                lda     #>name
                sta     ptr+1
                jsr     putpstr
                #print  ": "
                lda     errsave
                bra     _msg
_derr           sta     errsave
_msg            jsr     fail
                lda     errsave
                cmp     #$11
                bne     +
                #println "File not found"
                rts
+               cmp     #$12
                bne     +
                #println "Path not found"
                rts
+               cmp     #$21
                bne     +
                #println "Access denied"
                rts
+               #println "Copy error"
                rts

; next_src : source suivante (à partir de idx, jusqu'au « + ») -> name ;
; C=1 s'il n'y en a plus
next_src        ldy     idx
                cpy     argbuf
                beq     +
                bcs     _end
+               ldx     #0
_c              cpy     argbuf
                beq     +
                bcs     _eos
+               lda     argbuf,y
                iny
                cmp     #'+'
                beq     _eos
                inx
                sta     name,x
                bra     _c
_eos            stx     name
                sty     idx
                clc
                rts
_end            sec
                rts

; is_dest : Z=1 si name = dest (casse ignorée)
is_dest         ldx     name
                cpx     dest
                bne     _rts
-               lda     name,x
                jsr     upper
                sta     tmp
                lda     dest,x
                jsr     upper
                cmp     tmp
                bne     _rts
                dex
                bne     -
_rts            rts

; stat_src : la source name existe ? A = erreur, Z=1 si oui
stat_src        #setparam 0, name
                #api    3,16
                lda     DError
                rts

upper           cmp     #'a'
                bcc     +
                cmp     #'z'+1
                bcs     +
                and     #$DF
+               rts

; open_dest : ouvre dest sur CH_DST dans le mode A ; A = erreur, Z
open_dest       sta     DParams+3
                lda     #CH_DST
                sta     DParams
                #setparam 1, dest
                #api    3,4
                lda     DError
                rts

close_dest      lda     #CH_DST
                sta     DParams
                #api    3,5
                rts

; copy_src : recopie name à la suite de CH_DST ; A = erreur, Z=1 si succès
copy_src        lda     #CH_SRC
                sta     DParams
                #setparam 1, name
                stz     DParams+3               ; lecture seule
                #api    3,4
                lda     DError
                bne     _rts
_blk            lda     #CH_SRC
                sta     DParams
                #setparam 1, BUF
                #setparam 3, BUF_SIZE
                #api    3,8
                lda     DError
                bne     _eof                    ; fin de fichier
                lda     DParams+3               ; octets lus
                ldx     DParams+4
                sta     tmp
                ora     DParams+4
                beq     _eof
                lda     #CH_DST
                sta     DParams
                #setparam 1, BUF
                lda     tmp
                sta     DParams+3
                stx     DParams+4
                #api    3,9
                lda     DError
                beq     _blk
                bra     +                       ; erreur d'écriture
_eof            lda     #0
+               sta     errsave
                lda     #CH_SRC
                sta     DParams
                #api    3,5
                lda     errsave
_rts            rts

name            .fill   122
dest            .fill   122
argbuf          .fill   122
