@ECHO OFF
ECHO %0 got %1 and %2 [%3] 100%
IF "%1"=="A" ECHO first is A
IF NOT %1==A ECHO first is not A
IF EXIST %2 ECHO %2 exists
IF NOT EXIST %2 ECHO %2 missing
IF %1 == A ECHO spaced compare
