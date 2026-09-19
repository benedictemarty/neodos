; const.inc — constantes NeoDOS : adresses du noyau, bloc de contrôle API, page zéro
; NeoDOS occupe $D800-$FBFF (le noyau 6502 est en $FC00-$FFFF, l'API en $FF00-$FF0F).
; La zone $0800-$DFFF est laissée aux programmes lancés depuis l'invite.

NEODOS_BASE     = $D800
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

; Page zéro NeoDOS : $80-$9F (le noyau F-61 utilise $E0-$EF et $FC-$FF)
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
SCREEN_COLS     = 53

; Canaux fichiers utilisés par NeoDOS
CH_IO           = 0             ; TYPE, COPY manuel
CH_BAT          = 7             ; lecture d'un fichier batch

BATBUF_SIZE     = 1024          ; taille maximale d'un fichier .BAT
