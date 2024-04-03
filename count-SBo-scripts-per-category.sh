#!/bin/bash
#
# Copyright 2022-2024 Jeremy Hansen <jebrhansen -at- gmail.com>
# All rights reserved.
#
# Redistribution and use of this script, with or without modification, is
# permitted provided that the following conditions are met:
#
# 1. Redistributions of this script must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ''AS IS'' AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
# EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Simple shell script to find count of scripts using stock commands
# per SBo script template type

REPOLOC="~/sbo-github"

CNT=1
for i in "\./configure \\\\" "cmake \\\\" "runghc Setup configure" "meson \\.\\. \\\\" "^perl.*\\.PL" "python. setup.py install" "gem specification"; do
  if [ "$CNT" -eq "1" ]; then
    SCRIPTTYPE="autotools"
  elif [ "$CNT" -eq "2" ]; then
    SCRIPTTYPE="cmake"
  elif [ "$CNT" -eq "3" ]; then
    SCRIPTTYPE="haskell"
  elif [ "$CNT" -eq "4" ]; then
    SCRIPTTYPE="meson"
  elif [ "$CNT" -eq "5" ]; then
    SCRIPTTYPE="perl"
  elif [ "$CNT" -eq "6" ]; then
    SCRIPTTYPE="python"
  elif [ "$CNT" -eq "7" ]; then
    SCRIPTTYPE="ruby"
  fi
  echo "$(grep "$i" "$REPOLOC"/*/*/*.SlackBuild | cut -d: -f1 | uniq | wc -l) - $SCRIPTTYPE"
  ((CNT+=1))
done | sort -nr
