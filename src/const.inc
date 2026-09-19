; const.inc — constantes NeoDOS : adresses du noyau, bloc de contrôle API, page zéro
; NeoDOS occupe $C000-$FBFF (le noyau 6502 est en $FC00-$FFFF, l'API en $FF00-$FF0F).
; La zone $0800-$DFFF est laissée aux programmes lancés depuis l'invite.

NEODOS_BASE     = $C000
NEODOS_TOP      = $FC00
PROG_BASE       = $0800         ; zone programme (comme NeoBASIC)
PROG_TOP        = NEODOS_BASE

; Vecteurs du noyau (kernel/neo6502.inc)
ReadLine        = $FFEB
ReadCharacter   = $FFEE
WriteCharacter  = $FFF1
WaitMessage     = $FFF4
SendMessage     = $FFF7

; Bloc de contrôle de l'API
ControlPort     = $FF00
DCommand        = ControlPort+0
DFunction       = ControlPort+1
DError          = ControlPort+2
DStatus         = ControlPort+3
DParams         = ControlPort+4
DExec           = ControlPort+8 ; après un Load File (3,2) : RTS ou JMP exec

; Page zéro NeoDOS : $80-$AF (le noyau F-61 utilise $E0-$EF et $FC-$FF)
ptr             = $80           ; pointeur générique (2)
ptr2            = $82           ; second pointeur (2)
tmp             = $84
cnt             = $85
idx             = $86
flag            = $87
num             = $88           ; nombre 32 bits (4) pour l'affichage décimal
total           = $8C           ; total 32 bits (4) — DIR
nfiles          = $90           ; compteurs 16 bits — DIR
ndirs           = $92
bptr            = $94           ; pointeur de lecture du fichier batch (2)
blen            = $96           ; taille du fichier batch (2)
sptr            = $98           ; pointeur interne de puts (2)
mstar_p         = $9A           ; match_glob : position du dernier « * » (motif)
mstar_n         = $9B           ; match_glob : position correspondante (nom)
lptr            = $9C           ; jokers : pointeur d'écriture dans listbuf (2)
lcount          = $9E           ; jokers : nombre de noms collectés
dirflags        = $9F           ; DIR : bit 0 = /P, bit 1 = /W
dirlines        = $A0           ; DIR /P : lignes affichées depuis la pause
dircol          = $A1           ; DIR /W : colonne courante (0-3)
sp_s            = $A2           ; apply_pattern : début/longueur partie source
sp_l            = $A3
pp_s            = $A4           ; apply_pattern : début/longueur partie motif
pp_l            = $A5
oidx            = $A6           ; apply_pattern : index d'écriture
wflag           = $A7           ; jokers présents dans l'argument
errsave         = $A8           ; code d'erreur API sauvegardé avant affichage
lidx            = $A9           ; jokers : noms restants dans listbuf
negate          = $AA           ; IF NOT
bx              = $AB           ; batch : longueur de la ligne en cours d'expansion
by              = $AC           ; batch : index de lecture dans la ligne source
cond            = $AD           ; IF : condition vraie
preverr         = $AE           ; ERRORLEVEL de la commande précédente (lu par IF)
redir           = $AF           ; sortie redirigée vers CH_OUT (bit 7 = active)
opfn            = $B0           ; COPY/MOVE : fonction API (20 copie, 12 renomme)
attr_set        = $B1           ; ATTRIB : bits à mettre / à retirer
attr_clr        = $B2
lpos            = $B3           ; éditeur de ligne : curseur
llen            = $B4           ; éditeur de ligne : longueur
hcur            = $B5           ; historique : entrée en cours de rappel

; Codes d'erreur de l'API fichiers (firmware filesystem.h)
ERR_OK          = 0
ERR_EOF         = 2
ERR_NO_FILE     = $11
ERR_NO_PATH     = $12
ERR_INVALID_DRIVE = $13
ERR_DENIED      = $21
ERR_EXIST       = $22

; Attributs de fichier (3,16 / 3,18)
ATTR_DIR        = $01
ATTR_SYSTEM     = $02
ATTR_ARCHIVE    = $04
ATTR_READONLY   = $08
ATTR_HIDDEN     = $10

; Console
CR              = 13
KEY_DELETE      = $4C           ; code HID de Suppr (Key Status 1,2)
MOD_CTRL        = $11           ; bits Ctrl gauche/droit (Parameter:1 de 1,2)
MOD_ALT         = $44           ; bits Alt / AltGr
SCREEN_COLS     = 53

; Canaux fichiers utilisés par NeoDOS
CH_IO           = 0             ; TYPE, COPY manuel
CH_BAT          = 7             ; lecture d'un fichier batch
CH_OUT          = 1             ; redirection de la sortie (>, >>)

BATBUF_SIZE     = 1024          ; taille maximale d'un fichier .BAT
LISTBUF_SIZE    = 1024          ; noms collectés par les jokers (pstrings)
DIR_PAGE_LINES  = 28            ; DIR /P : lignes par page (écran de 30)
BAT_NAME_SIZE   = 64            ; chemin d'un fichier batch (pstring)
BAT_ARGS_SIZE   = 96            ; ligne de commande d'un batch (pstring, %0-%9)
BAT_DEPTH       = 3             ; niveaux de CALL
BAT_LEVEL_SIZE  = BAT_NAME_SIZE + BAT_ARGS_SIZE + 2
OUTBUF_SIZE     = 128           ; tampon de la redirection
HIST_SIZE       = 200           ; historique de commandes (octets, pstrings)
PATH_SIZE       = 128           ; PATH (pstring, entrées séparées par « ; »)
PROMPT_SIZE     = 48            ; format de PROMPT (pstring)
