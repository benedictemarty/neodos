find "e p" \FRUITS.TXT > F.TXT
echo after find
sort \FRUITS.TXT > S.TXT
if errorlevel 1 echo sort failed
echo end of script
