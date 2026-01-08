@echo off
powershell.exe ./src/setup.ps1
echo  ^> Setup is Complete
echo  ^> Setup files well self remove...
pause > nul
rmdir /s /q "./src"
(goto) 2>nul & del /q "%~f0"