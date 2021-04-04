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

# If an srt file exists in the folder with the same name as the mp4, you can
# optionally add the subtitles into the resulting mkv file.

# You can optionally delete the original mp4 (and srt if used).

# -----------------------------------------------------------------------------

# Set up the functions

# Help function
function display_help() {
  cat <<EOH
-- Usage:
   $(basename $0) [options] [location]

-- Option parameters:
   -h :    This help.
   -s :    Add subtitle of same name to resulting mkv
   -d :    Delete the original mp4 after conversion (and remove srt if -s is used)

-- Description:
   This script is used to convert mp4 files to mkv files. It doesn't
   transcode, it just switches the container keeping the existing codecs and
   streams as is. It can support mp4 files in the current directory or
   subdirectories, or you can pass a directory to the script and it will check
   for mp4 files in that directory or subdirectories.

   If an srt file exists in the folder with the same name as the mp4, you can
   optionally add the subtitles into the resulting mkv file.

   You can optionally delete the original mp4 (and srt if used).

EOH
}

# The actual workhorse. Grabs the filename and removes the extension, then
# runs it through ffmpeg to store it in an mkv container
# Optionally add subtitles to the mkv and remove the original mp4 and srt
convertmp42mkv()
{
for fullfile in *.mp4; do
  filename=$(basename "$fullfile")
  filename="${filename%.*}"
  echo -e "\e[1A\e[KConverting $fullfile to mkv"

  # Only continue if it completes the conversion
  if ffmpeg -stats -hide_banner -loglevel quiet -i "$fullfile" -vcodec copy -acodec copy "$filename".mkv; then

    # Check if we should add subs (if they exist)
    if [ "$ADDSUBS" == "yes" ] && [ -f "$filename".srt ]; then

      # Only continue if it successfully adds the subtitles
      if mkvmerge -o "${filename}"-with-sub.mkv "$fullfile" --language "0:eng" --track-name "0:eng" "$filename".srt; then
        mv "$filename"-with-sub.mkv "$filename".mkv

        # Check if we should delete the subtitle file
        if [ "$DELETE" == "yes" ]; then
          rm -f "$filename".srt
        fi
      fi
    fi

    # Check if we should delete the original mp4
    if [ "$DELETE" == "yes" ]; then
      rm -f "$fullfile"
    fi
  fi
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

# Option parsing:
while getopts "dhs" OPTION
do
  case $OPTION in

    d )     DELETE=yes
            ;;

    h )     display_help
            exit ;;

    s )     ADDSUBS=yes
            ;;

    * )     display_help
            exit ;;

  esac
done
shift $(($OPTIND - 1))

# Make sure we end up back where we started
CWD=$(pwd)

# Allow setting a separate directory from the one we're in
PREFIX=
if [ -n "$1" ]; then
  cd "$1"
  location="$1"
else
  location="current"
fi

# Check for files in the main directory
if ls ./*.mp4 >/dev/null 2>&1; then

  echo -e "Converting files in $location directory.\n"
  convertmp42mkv

# If no files in the main directory, check for files in subdirectories
elif ls */*.mp4 >/dev/null 2>&1; then

  loopthrufolders

# If files still can't be found, exit the script with an error
else

  echo "No mp4 files found in $location directory or its subdirectories"
  # If a directory was passed to the script, change back to that directory.
  if [ -n "$1" ]; then
    cd "$CWD"
  fi
  exit 1

fi

# Make sure we end up back where we started
cd "$CWD"
