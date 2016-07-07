:: Copyright 2014 Jeremy Hansen <jebrhansen -at- gmail.com>
:: All rights reserved.
::
:: Redistribution and use of this script, with or without modification, is
:: permitted provided that the following conditions are met:
::
:: 1. Redistributions of this script must retain the above copyright
:: notice, this list of conditions and the following disclaimer.
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
:: This was created to shorten filenames. We needed to store emails on a server,
:: and this location on the server had a really large folder name. This made us
:: bump into the max depth restrictions of Windows, so I developed this script
:: to shorten the names of the filenames enough to not hit that limit. Currently,
:: it is set to 36 characters for the standard filename, plus the addtional
:: characters needed for duplicate names (e.g. email message (1).msg).

@echo off
setlocal EnableDelayedExpansion

:: Create a separate directory and move all files there. This is used to
:: determine if there are duplicate names and append unique numbers after.
md temp
move *.msg temp\

setlocal DisableDelayedExpansion
for %%f in (temp\*.msg) do (
  set _filename=%%~nf
  set _extension=%%~xf
  setlocal EnableDelayedExpansion
  :: Change the character count here (replace the 36 with your desired number)
  set _shortened=!_filename:~0,36!
  set _count=0
  set _extra=
  :: Go to the while loop to check for existing filenames.
  call :WhileLoop
  move /y "temp\!_filename!!_extension!" "!_shortened!!_extra!!_extension!"
  endlocal
)
rmdir temp
(goto) 2>nul & del "%~f0"

:WhileLoop
if exist "!_shortened!!_extra!.msg" (
  set /a _count=!_count!+1
  set _extra=-!_count!
  goto WhileLoop
)
