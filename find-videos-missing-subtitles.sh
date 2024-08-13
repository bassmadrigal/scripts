#!/bin/bash
#
# Copyright 2024 Jeremy Hansen <jebrhansen -at- gmail.com>
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

# Search through subfolders to find files that don't have subtitles embedded.
# Once I start using it more, I'll probably need to limit what video files it
# searches since many don't support embedded subtitles.

if [ -n "$1" ]; then
  SRC="$1"
else
  SRC="$(pwd)"
fi

# Store shopt globstar option to potentially revert
OLD_GLOBSTAR=$(shopt -p globstar)
# Then ensure that globstar is set to match all files
shopt -s globstar

totalCOUNT=0
# Get total count of files
echo "Finding total filecount. Please wait..."
for FILE in "$SRC"/**; do

  if file -i "$FILE" | grep -q -e video; then
    ((totalCOUNT+=1))
  fi
  printf "\r%.0f files" "$totalCOUNT"
done

printf "\rFound %.0f files\n" "$totalCOUNT"

currCOUNT=0
noSubCOUNT=0
for FILE in "$SRC"/**; do

  if file -i "$FILE" | grep -q -e video; then
    if ! mediainfo "$FILE" | grep -q ^Text; then
      printf "\r%s\n" "$FILE"
      ((noSubCOUNT+=1))
    fi

  ((currCOUNT+=1))
  printf "\r$((100*currCOUNT/totalCOUNT))%% complete"
  fi
done

printf "\rThere were %.0f files without subtitles.\n" "$noSubCOUNT"

# Reset globstar
eval "$OLD_GLOBSTAR"
