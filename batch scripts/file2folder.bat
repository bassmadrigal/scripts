REM file2folder.bat
REM Written by Jon from theHTPC.net
REM Ensure file attribute is set to hidden.  Very important!
REM Place in folder where your media files are located.
REM Use at own risk on network shares.  Bad things have happened.
REM Run the batch file and all of your files will be moved into newly
REM created folders of the same name!
REM This script is NOT recursive.  Must be run on all directories containing
REM media files.
REM NOT recommended for TV series episodes!
REM Visit www.theHTPC.net for HTPC-related news, tips, plugins and more!

REM ---BEGIN SCRIPT---

@echo off
for %%a in (*.*) do (
md "%%~na" 2>nul
move "%%a" "%%~na"
)
pause

REM ----END SCRIPT----