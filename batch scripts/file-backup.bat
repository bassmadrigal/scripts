:: Copyright 2016 Jeremy Hansen <jebrhansen -at- gmail.com>
:: All rights reserved.
::
:: Redistribution and use of this script, with or without modification, is
:: permitted provided that the following conditions are met:
::
:: 1. Redistributions of this script must retain the above copyright
::    notice, this list of conditions and the following disclaimer.
::
:: THIS SOFTWARE IS PROVIDED BY THE AUTHOR ''AS IS'' AND ANY EXPRESS OR IMPLIED
:: WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
:: MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
:: EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
:: SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
:: PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
:: OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
:: WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
:: OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
:: ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
::
:: This script will back up a local file to another location, including mapping
:: a network drive if needed adding in the backup date (ordinal) and time
:: (HHMM). Once the file is copied over, the script will remove all but the two
:: most recently modified files (configurable by changing the HOWMANY variable).

@echo off

:: Set up variables
SET BACKUP=Z:\Backup\Folder with spaces\
SET SOURCE=C:\Users\my username\folder\
SET FILE=File I want to backup.txt
SET HOWMANY=2

:: If your backup location is a network drive, add the full location below
:: If the network drive isn't mapped, map it
if not exist Z:\ (
  net use Z: \\SERVER\FOLDER$
)

:: Separate the filename from the extension so we can add the backup
:: date/time into the filename
for /F "delims=" %%a in ("%FILE%") do (
  SET FILENAME=%%~na
  SET EXT=%%~xa
)

:: Determine the ordinal date (known incorrectly as Julian date in the military)
SET Now=%Time: =0%
SET Hours=%Now:~0,2%
SET Minutes=%Now:~3,2%
SET HHMM=%hours%%minutes%
 
SET Today=%Date: =0%
SET Year=%Today:~-4%
SET Month=%Today:~-10,2%
SET Day=%Today:~-7,2%
 
SET /a LeapYr=%Year% %% 4 + %Year% %% 100 + %Year% %% 400
 
If /i %Month% GEQ 01 SET ORD=0
If /i %Month% GEQ 02 SET /a ORD=%ORD%+31
If /i %Month% GEQ 03 SET /a ORD=%ORD%+28
If /i %Month% GEQ 04 SET /a ORD=%ORD%+31
If /i %Month% GEQ 05 SET /a ORD=%ORD%+30
If /i %Month% GEQ 06 SET /a ORD=%ORD%+31
If /i %Month% GEQ 07 SET /a ORD=%ORD%+30
If /i %Month% GEQ 08 SET /a ORD=%ORD%+31
If /i %Month% GEQ 09 SET /a ORD=%ORD%+31
If /i %Month% GEQ 10 SET /a ORD=%ORD%+30
If /i %Month% GEQ 11 SET /a ORD=%ORD%+31
If /i %Month% GEQ 12 SET /a ORD=%ORD%+30

:: If it is a leap year after February, add an extra day
If /i %LeapYr% EQU 0 (
  If /i %Month% GEQ 03 SET /a ORD=%ORD%+1
)
 
:: To remove the leading 0 on the day if it exists so it can add the numbers
IF %Day:~0,1% EQU 0 SET Day=%Day:~1%
 
SET /a ORD=%ORD%+%DAY%

:: Copy the file over to the backup location
echo Copying file over...
copy "%SOURCE%%FILE%" "%BACKUP%%FILENAME%-%ORD%-%HHMM%%EXT%"

:: Get a list sorted by last modified time and delete any except for the 2 most recently modified files.
for /f "skip=%HOWMANY% eol=: delims=" %%F in ('dir /b /o-d /s "%BACKUP%%FILENAME%-*%EXT%"') do @del "%%F"
