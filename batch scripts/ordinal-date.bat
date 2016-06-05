:: Copyright 2009 Jeremy Hansen <jebrhansen -at- gmail.com>
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
:: This was created to generate the ordinal date (known as the julian date in
:: the military), which could then be used for backups of an Access database 
:: that liked to crash frequently and dump a lot of needed data. This currently
:: just outputs the ordinal date and the HHMM (24hr format).

@echo off
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
If /i %LeapYr% EQU 0 SET /a ORD=%ORD%+1
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
 
:: To remove the leading 0 on the day if it exists so it can add the numbers
IF %Day:~0,1% EQU 0 SET Day=%Day:~1%
 
SET /a ORD=%ORD%+%DAY%

ECHO Day: %ORD% ^| Time: %HHMM%
