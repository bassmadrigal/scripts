#!/bin/bash
#
# Copyright 2020 Jeremy Hansen <jebrhansen -at- gmail.com>
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

# This script is used to convert mp4 files to mkv files. It doesn't
# transcode, it just switches the container keeping the existing codecs and
# streams as is. It can support mp4 files in the current directory or
# subdirectories, or you can pass a directory to the script and it will check
# for mp4 files in that directory or subdirectories.

# -----------------------------------------------------------------------------

# Set up the functions

# The actual workhorse. Grabs the filename and removes the extension, then
# runs it through ffmpeg to store it in an mkv container
convertmp42mkv()
{
for fullfile in *.mp4; do
  filename=$(basename "$fullfile")
  filename="${filename%.*}"
  echo -e "\e[1A\e[KConverting $fullfile to mkv"
  ffmpeg -stats -hide_banner -loglevel quiet -i "$fullfile" -vcodec copy -acodec copy "$filename".mkv
done
echo
}

# If the mp4s exist in subdirectories, let's loop through those and convert
# all the files within them
loopthrufolders()
{
  for i in */; do
    if ls "$i"/*.mp4 >/dev/null 2>&1; then
      echo -e "Entering Directory $i\n"
      cd "$i"
      convertmp42mkv
      cd ..
    else
      echo "No mp4 files in $PREFIX/$i."
    fi
  done
}

# Now onto the rest of the script

# Make sure we end up back where we started
CWD=$(pwd)

# Allow setting a separate directory from the one we're in
PREFIX=
if [ -n "$1" ]; then
  cd "$1"
fi

# Check for files in the main directory
if ls ./*.mp4 >/dev/null 2>&1; then

  echo -e "Converting files in current directory.\n"
  convertmp42mkv

# If no files in the main directory, check for files in subdirectories
elif ls */*.mp4 >/dev/null 2>&1; then

  loopthrufolders

# If files still can't be found, exit the script with an error
else

  if [ -n "$1" ]; then
    echo "No mp4 files found in $1 directory or its subdirectories"
    cd "$CWD"
  else
    echo "No mp4 files found in current directory or subdirectories"
  fi
  exit 1

fi

# Make sure we end up back where we started
cd "$CWD"
