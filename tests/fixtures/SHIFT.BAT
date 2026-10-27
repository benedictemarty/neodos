@ECHO OFF
:LOOP
IF "%1"=="" GOTO END
ECHO arg=%1 next=%2
SHIFT
GOTO LOOP
:END
ECHO done %0
