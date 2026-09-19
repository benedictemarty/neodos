; data.asm — tampons de NeoDOS (non initialisés, en fin d'image)

digitbuf        .fill   10              ; chiffres de print32
echo_off        .fill   1               ; 1 = ECHO OFF (batch)
bat_active      .fill   1               ; 1 = un batch est en cours
promptbuf       .fill   96              ; invite « A:\chemin> » (pstring)
cwdbuf          .fill   96              ; répertoire courant (pstring)
screenline      .fill   256             ; ligne d'écran lue (pstring)
linebuf         .fill   256             ; ligne de commande sans l'invite
cmdbuf          .fill   17              ; mot de commande en majuscules
arg1            .fill   129             ; premier argument
arg2            .fill   129             ; second argument
argrest         .fill   256             ; reste de la ligne après la commande
namebuf         .fill   129             ; nom de fichier de travail
iobuf           .fill   256             ; tampon de lecture (TYPE)
batbuf          .fill   BATBUF_SIZE     ; fichier batch en cours
dirbuf          .fill   129             ; jokers : partie répertoire
patbuf          .fill   129             ; jokers : motif
newname         .fill   129             ; REN : nom résultant
listbuf         .fill   LISTBUF_SIZE    ; jokers : noms collectés
dataend
