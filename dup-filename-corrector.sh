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

# -----------------------------------------------------------------------------

# When using my transcode-265.sh script, it places all transcoded files from
# a session into a single folder. To prevent overwriting files of the same
# name, it detects whether the name already exists and will append a " - (1)"
# to the end, unless that exists and it will move to a "2" and on until it has
# a unique filename. This can lead to cumbersome renaming sessions to restore
# filenames once they've been resorted back into folders.
#
# This script simplifies that process by finding the files with those at the
# end and renaming them by removing the extra bit after everything is sorted.

# -----------------------------------------------------------------------------

# If a directory is passed, use that, otherwise use the current dir
if [ -n "$1" ]; then
  SRC="$1"
else
  SRC="$(pwd)"
fi

# Store shopt globstar option to potentially revert
OLD_GLOBSTAR=$(shopt -p globstar)
# Then ensure that globstar is set so we can use ** to match all files
# regardless of whether they sit in subdirs (recursively) or in the parent dir
shopt -s globstar

COUNT=0
for FILE in "$SRC"/**; do

  # Check files for " - (#)" at the end of them, with "#" being any digit
  if echo "$FILE" | grep -Eq " - \([[:digit:]]+\)"; then
    FILENAME="$(basename "$FILE")"
    # Cut the extra fluff from the filename and add the extension back
    NEWNAME="$(echo "$FILENAME" | rev | cut -d' ' -f3- | rev ).${FILENAME##*.}"
    FILEPATH="$(dirname "$FILE")"
    # If the new filename doesn't already exist, move it
    if [ ! -f "$FILEPATH/$NEWNAME" ]; then
      if mv "$FILE" "$FILEPATH/$NEWNAME"; then
        echo "Renamed $FILE -> $FILEPATH/$NEWNAME"
      else
        echo "Failed to rename $FILE"
      fi
      ((COUNT+=1))
    fi
  fi

done

# Reset globstar
eval "$OLD_GLOBSTAR"

# Show our work
if [ "$COUNT" -eq "1" ]; then
  echo "SUCCESS: Renamed $COUNT file."
elif [ "$COUNT" -gt "1" ]; then
  echo "SUCCESS: Renamed $COUNT files."
else
  echo "NOTICE: No files found that required renaming."
  exit 1
fi
