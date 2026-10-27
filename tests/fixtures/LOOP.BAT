@ECHO OFF
IF %1==A GOTO a
ECHO not a
GOTO :end
:a
ECHO label a
:end
ECHO done
GOTO nowhere
ECHO never
