; data.asm — tampons de NeoDOS (non initialisés, en fin d'image)

canary_lo       .fill   1               ; sentinelle basse (début des données)
digitbuf        .fill   10              ; chiffres de print32
echo_off        .fill   1               ; 1 = ECHO OFF (batch)
bat_active      .fill   1               ; 1 = un batch est en cours
promptbuf       .fill   92              ; invite « A:\chemin> » (pstring)
cwdbuf          .fill   82              ; répertoire courant (pstring)
linebuf         .fill   201             ; ligne de commande sans l'invite (200 max)
cmdbuf          .fill   17              ; mot de commande en majuscules
arg1            .fill   129             ; premier argument
arg2            .fill   129             ; second argument
argrest         .fill   201             ; reste de la ligne après la commande (200 max)
namebuf         .fill   129             ; nom de fichier de travail
iobuf           .fill   256             ; tampon de lecture (TYPE)
batbuf          .fill   BATBUF_SIZE     ; fichier batch en cours
dirbuf          .fill   129             ; jokers : partie répertoire
patbuf          .fill   129             ; jokers : motif
newname         .fill   129             ; REN : nom résultant
listbuf         .fill   LISTBUF_SIZE    ; jokers : noms collectés
errorlevel      .fill   1               ; 0 = dernière commande réussie
batname         .fill   BAT_NAME_SIZE   ; chemin du batch courant
batargs         .fill   BAT_ARGS_SIZE   ; ligne de commande du batch courant
batdepth        .fill   1               ; niveaux CALL empilés
batstack        .fill   BAT_LEVEL_SIZE*BAT_DEPTH ; niveaux sauvegardés (nom, args, bptr)
outbuf          .fill   OUTBUF_SIZE     ; redirection : caractères en attente
outlen          .fill   1               ; nombre de caractères dans outbuf
pathbuf         .fill   PATH_SIZE+1     ; PATH
promptfmt       .fill   PROMPT_SIZE+1   ; format de l'invite
cwdpath         .fill   84              ; « A:\chemin » (DIR, CD)
runword         .fill   129             ; run_program : nom tel que tapé
promptskip      .fill   1               ; longueur de la dernière ligne de l'invite
dpsave          .fill   9               ; sauvegarde DParams/DError pendant redir_flush
hcount          .fill   1               ; historique : nombre d'entrées
hused           .fill   1               ; historique : octets utilisés
histbuf         .fill   HIST_SIZE       ; historique : pstrings consécutives
canary_hi       .fill   1               ; sentinelle haute (fin des données)
dataend
