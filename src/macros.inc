; macros.inc — macros 64tass pour NeoDOS

; Appel API : groupe, fonction. KSendMessage attend la fin de la commande
; précédente avant d'envoyer ; KWaitMessage attend la réponse. Les paramètres
; doivent avoir été écrits AVANT (aucune commande n'est en cours à ce moment :
; putc attend la fin de chaque écriture console).
api             .macro
                jsr     SendMessage
                .byte   \1, \2
                jsr     WaitMessage
                .endm

; Affiche un texte inline (terminé par 0)
print           .macro
                jsr     puts
                .null   \1
                .endm

; Affiche un texte inline suivi d'un retour chariot
println         .macro
                jsr     puts
                .text   \1
                .byte   CR, 0
                .endm

; Charge un pointeur 16 bits dans les paramètres API (offset)
setparam        .macro                  ; \1 = offset paramètre, \2 = adresse
                lda     #<\2
                sta     DParams+\1
                lda     #>\2
                sta     DParams+\1+1
                .endm

; Charge une adresse dans un pointeur page zéro
setptr          .macro                  ; \1 = pointeur ZP, \2 = adresse
                lda     #<\2
                sta     \1
                lda     #>\2
                sta     \1+1
                .endm
