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

# Calculate subfolders sizes of certain video files, the count of those video
# files, and the average filesize of those video files to aid in determining
# which to priotize for transcoding.

# Store shopt globstar option to potentially revert
OLD_GLOBSTAR=$(shopt -p globstar)
# Then ensure that globstar is set to match all files
shopt -s globstar

# Function to determine whether to display singular or plural
# Pass the variable to the function inside the echo statement
# e.g. echo "There are $COUNT $(fileORfiles $COUNT)."
fileORfiles ()
{
    if [ "$1" -ne 1 ]; then
        echo "files";
    else
        echo "file";
    fi
}

for FOLDER in ./*; do

  TOTALCNT=0
  TOTALSIZE=0

  # Skip files. We only want to look at directories.
  if [ -f "$FOLDER" ]; then
    continue
  fi

  # Skip my temp storage folders
  # Skip the first 2 characters and grab the next 3
  if [ "${FOLDER:2:3}" == "000" ]; then
    continue
  fi

  # Get total count of files
  for FILE in "$FOLDER"/**; do

    # Skip samples
    if grep -qi "sample" <<< "$FILE"; then
      continue
    fi

    # Skip extras
    if grep -qi "Season.*Extras$" <<< "$FILE"; then
      continue
    elif grep -qi "/Extras/" <<< $FILE; then
      continue
    elif grep -qi "/Featurettes/" <<< $FILE; then
      continue
    fi

    # Only count if it's a video file
    if file -i "$FILE" | grep video &> /dev/null; then
      ((TOTALCNT+=1))
      TOTALSIZE=$((TOTALSIZE+$(du -b "$FILE" | cut -f1)))
    fi

  done
  if [ "$TOTALCNT" -ne "0" ]; then
    echo -e "$FOLDER contains \e[36m$TOTALCNT $(fileORfiles "$TOTALCNT")\e[0m totaling \e[33m$(numfmt --to=iec $TOTALSIZE)\e[0m. Average filesize is: \e[32m$(numfmt --to=iec $((TOTALSIZE/TOTALCNT)))\e[0m"
  else
    echo -e "$FOLDER \e[31mdoesn't contain video files\e[0m."
  fi

done

# Reset globstar
eval "$OLD_GLOBSTAR"
