:: Copyright 2010 Jeremy Hansen <jebrhansen -at- gmail.com>
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
:: This was created to help sort incoming scans of AMC Form 77s into longterm
:: and shortterm folders stored on the network

@echo off
SETLOCAL EnableDelayedExpansion
set _pre=U:\TR\TRO\TROA\Mission Files\FY10
 
set _filename=
set _ord=
 
for %%f in (*.pdf) do (
  set _filename=%%f
  set _ord=!_filename:~9,3!
  set _ltf=!_filename:~12,1!
  set _mission=!_filename:~0,12!
  set _extra=
  set _SorL=
  if !_ltf! == a set _SorL=LTF
  if !_ltf! == . set _SorL=STF
  set _count=0
  set _extra=
  set _fullpath=!_pre!\!_SorL!\!_ord!\!_mission!\
  if defined _SorL (
    if NOT EXIST "!_fullpath!" (
      md "!_fullpath!"
    )
    call :WhileLoop
    copy !_filename! "!_fullpath!!_mission!!_extra!.pdf"
  )
)
 
:WhileLoop
if exist "!_fullpath!!_mission!!_extra!.pdf" (
  set /a _count = !_count! + 1
  set _extra=-!_count!
  goto WhileLoop
)
