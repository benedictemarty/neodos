; HELP.asm — commande externe NeoDOS : HELP — liste des commandes.
; Sortie de NeoDOS depuis la 0.28.0 (870 octets rendus au résident) ; le
; texte est celui de la commande interne qu'elle remplace. Suit la
; redirection « > » (vecteur putc de NeoDOS).
;   make examples  ->  storage/BIN/HELP.NEO
ptr             = $80
sptr            = $82
cnt             = $84
                * = $0800
                jmp     main
                .include "neoext.inc"

main            lda     #CR
                jsr     putc
                jsr     puts
                .text   "DIR [path] [/P /W] List directory (wildcards)", CR
                .text   "CD [path]         Change/show directory", CR
                .text   "MD RD path        Make/remove directory", CR
                .text   "DEL file|*.*      Delete files", CR
                .text   "REN old new       Rename files (REN *.TXT *.BAK)", CR
                .text   "COPY MOVE src dst Copy/move files (COPY *.TXT DIR)", CR
                .text   "TYPE file         Display a text file", CR
                .text   "X:                Change drive", CR
                .text   "CLS VER VOL MEM   Screen, versions, volume, memory", CR
                .text   "PATH PROMPT MODE  Path, prompt ($p$g), video mode", CR
                .text   "cmd > file        Redirect output (>> appends)", CR
                .text   "DATE TIME         Show/set date and time", CR
                .text   "ECHO PAUSE REM    Batch commands (.BAT, %1-%9)", CR
                .text   "IF GOTO CALL      IF [NOT] EXIST|==|ERRORLEVEL, :label", CR
                .text   "FOR SHIFT         FOR %f IN (set) DO cmd; SHIFT", CR
                .text   "EXIT              Reload the resident environment", CR
                .text   "name[.NEO]        Run a program (here, then PATH)", CR
                .text   "BIN\ (PATH \BIN): ATTRIB COLOR DELTREE EDIT FIND", CR
                .text   "                  MORE REBOOT SORT TREE XCOPY", CR, 0
                lda     #CR
                jmp     putc
argbuf          = $2000                         ; exigé par neoext.inc (cmd_arg), non utilisé
