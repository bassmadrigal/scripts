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

# Find files with non-ascii filenames and output them for review

# -----------------------------------------------------------------------------

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

COUNT=

for FILE in "$SRC"/**; do

  # Check for files containing non-ascii and colons.
  #if echo "$(realpath --relative-to="$SRC" "$FILE")" | grep --color='auto' -P '[^\x00-\x7F]|\x3A'; then
  if echo "$FILE" | grep --color='auto' -P '[^\x00-\x7F]|\x3A'; then
    # Set the exit variable so we can find and display all files containing
    # non-ascii and then exit after the loop.
    EXIT=yes
    ((COUNT+=1))
  fi

done
# Reset globstar
eval "$OLD_GLOBSTAR"

if [ "$EXIT" != "yes" ]; then
  echo "SUCCESS: No non-ascii filenames were found!"
else
  echo -e "\n!=============================================================================!"
  echo "! WARNING: The above $COUNT $(fileORfiles $COUNT) contain non-ascii characters!"
  echo "!=============================================================================!"
fi
