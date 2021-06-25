#!/bin/bash

# Copyright 2021 Jeremy Hansen <jebrhansen -at- gmail.com>
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

# This script will take a directory and convert all video files within to the
# specified format using HandBrakeCLI and save them in the "output" directory.
# It will not save them into their respective season folders and will likely
# require further processing (I use filebot for mine). It will also calculate
# the remaining time based on how long it's taken so far and what's left and
# notify you of failed transcodes (and save the log for that failed transcode.

# If you don't want to use a pre-configured HandBrake preset, you can create
# your own in the GUI and save the name and use that (it's what I've done for
# my preset below.

# -----------------------------------------------------------------------------

SRC="$1"
DEST="$2"
EXT="${3:-mkv}"
PRESET="${4:-H.265 MKV 1080p Sub}"

function help ()
{
  cat <<EOH
-- Usage:
   "$(basename "$0") <src> <dest> [ext] [preset]"

-- Option parameters:
   <src>    - Location of the existing file(s)     <required>
   <dest>   - Location to save transcoded file(s)  <required>
   [ext]    - File format: mp4 or mkv              [optional]
   [preset] - HandBrake Preset                     [optional]

-- Description:
   This script will take a directory and convert all video files within to the
   specified format using HandBrakeCLI and save them in the "output" directory.
   It will not save them into their respective season folders and will likely
   require further processing (I use filebot for mine). It will also calculate
   the remaining time based on how long it's taken so far and what's left and
   notify you of failed transcodes (and save the log for that failed transcode.

   This script requires passing at least source and destination locations.
   File extension and preset can be pre-configured within the script, but can
   be passed if you want to override the presets.

EOH
}

# Function to calculate the amount weeks, days, hours, minutes, and seconds
# for a given amount of seconds.
calc_time()
{
  INPUT_TIME="$1"
  WEEK=$(echo "$INPUT_TIME/604800" | bc)
  DAY=$(echo "($INPUT_TIME-604800*$WEEK)/86400" | bc)
  HOUR=$(echo "(($INPUT_TIME-604800*$WEEK)-86400*$DAY)/3600" | bc)
  MIN=$(echo "((($INPUT_TIME-604800*$WEEK)-86400*$DAY)-3600*$HOUR)/60" | bc)
  SEC=$(echo "(((($INPUT_TIME-604800*$WEEK)-86400*$DAY)-3600*$HOUR)-60*$MIN)" | bc)

  OUTPUT_TIME=

  # Check if we need to add week(s) to the output.
  if [ "$WEEK" -gt 1 ]; then
    OUTPUT_TIME="${OUTPUT_TIME}${WEEK} weeks, "
  elif [ "$WEEK" -eq 1 ]; then
    OUTPUT_TIME="${OUTPUT_TIME}${WEEK} week, "
  fi
  # Check if we need to add day(s) to the output.
  if [ "$DAY" -gt 1 ]; then
    OUTPUT_TIME="${OUTPUT_TIME}${DAY} days, "
  elif [ "$DAY" -eq 1 ]; then
    OUTPUT_TIME="${OUTPUT_TIME}${DAY} day, "
  fi
  # Check if we need to add hour(s) to the output.
  if [ "$HOUR" -ge 1 ]; then
    OUTPUT_TIME="${OUTPUT_TIME}${HOUR}h:"
  fi
  # Check if we need to add minute(s) to the output.
  if [ "$MIN" -ge 1 ]; then
    OUTPUT_TIME="${OUTPUT_TIME}${MIN}m:"
  fi
  # If OUTPUT_TIME hasn't been adjusted, spell out second(s)
  # otherwise, continue the output
  if [ -z "$OUTPUT_TIME" ]; then
    if [ "$SEC" -gt 1 ]; then
      OUTPUT_TIME="${OUTPUT_TIME}${SEC} seconds"
    elif [ "$SEC" -eq 1 ]; then
      OUTPUT_TIME="${OUTPUT_TIME}${SEC} second"
    fi
  else
    OUTPUT_TIME="${OUTPUT_TIME}${SEC}s"
  fi
  echo "$OUTPUT_TIME"
  }

# Function to calculate the progress and estimated completion
progress()
{
  ELAPSED_TIME=$1
  COMPLETED=$(echo "$COUNT+$FAILED" | bc)
  PERCENT=$(echo "(100*$COMPLETED/$TOTALCNT)" | bc)
  EST_REMAIN_SEC=$(printf "%.0f" "$(echo "scale=10; $ELAPSED_TIME/($COMPLETED/$TOTALCNT)-$ELAPSED_TIME" | bc)")
  EST_REMAIN=$(calc_time "$EST_REMAIN_SEC")

  echo "====================================================="
  echo "${PERCENT}% completed. $COMPLETED of $TOTALCNT files."
  echo "Remaining Time: $EST_REMAIN"
  echo "Estimated Completion: $(date --date='+'"$EST_REMAIN_SEC"' seconds')"
  echo "====================================================="
  echo

}

# Time to check our inputs

# Check to see if they passed source and destination locations
if [ -z "$SRC" ] || [ -z "$DEST" ]; then
  echo "$(basename "$0") requires passing the source and destination directories"
  help
  exit 1
fi

# Check to see if the source directory exists
if [ ! -d "$SRC" ]; then
  echo "$SRC does not exist or you don't have permission to access it."
  help
  exit 1
fi

# Try to create the destination directory
if ! mkdir -p "$DEST"; then
  echo "Failed to create the \"$DEST\"."
  echo "Do you have proper permissions?"
  help
  exit 1
fi

# Make the extension lowercase
EXT=${EXT,,}
# Make sure the extension is either mkv or mp4
if [ "$EXT" != "mkv" ] && [ "$EXT" != "mp4" ]; then
  echo "$3 is not a valid extension. Please choose \"mp4\" or \"mkv\"."
  help
  exit 1
fi

# Make sure the HandBrake preset exists.
if ! HandBrakeCLI --preset-import-gui -z 2>&1 >/dev/null | grep -q "$PRESET"; then
  echo "\"$PRESET\" is not a valid HandBrake preset."
  sleep 3
  HandBrakeCLI --preset-import-gui -z
  exit 1
fi

# Make sure the counters are reset
SECONDS=0
COUNT=0
TOTALCNT=0
ORIGSIZE=0
NEWSIZE=0
FAILED=0
FAILED_FILES=
totalFrames=0

# Store shopt globstar option to potentially revert
OLD_GLOBSTAR=$(shopt -p globstar)
# Then ensure that globstar is set to match all files
shopt -s globstar

# Get total count of files
echo "Finding total filecount. Please wait..."
for FILE in "$SRC"/**; do

  # Only count if it's a video file
  if file -i "$FILE" | grep video &> /dev/null; then
    ((TOTALCNT+=1))
    ORIGSIZE=$((ORIGSIZE+$(du -b "$FILE" | cut -f1)))
  fi

done
echo "Found $TOTALCNT file(s) totalling $(numfmt --to=iec $ORIGSIZE). Starting the transcoding..."
sleep 4

# Save the source location for easy future reference
# (I kept forgetting which source I used when I went to delete)
realpath "$SRC" > "$DEST"/000-SOURCE.txt

# Time to start looping through the directory and convert files
for FILE in "$SRC"/**; do

  # Don't try and convert a directory
  if [ -d "$FILE" ]; then
    continue
  fi

  # Don't try and convert if the file isn't a video
  if ! file -i "$FILE" | grep video &> /dev/null; then
    continue
  fi

  # Get just the filename without extension
  filename=$(basename "${FILE%.*}")

  # Count frames so we can determine an average FPS.
  totalFrames=$((totalFrames+$(mediainfo --Inform='Video;%FrameCount%' "$FILE")))

  # Set pipefail to ensure HandBrakeCLI failing works
  # This will allow a failure of HandBrakeCLI to propagate through the pipe
  # and allow the if statement to catch a failure of the HandBrakeCLI command
  # so it can run the else section if needed
  set -o pipefail

  # Time to actually start transcoding. If it completes successfully, rm the
  # log and update the counter
  if HandBrakeCLI --preset-import-gui -Z "$PRESET" -i "$FILE" -o "$DEST"/"$filename"."$EXT" 2>&1 | tee "$DEST"/temp.log; then
    ((COUNT+=1))
    rm "$DEST"/temp.log
    NEWSIZE=$((NEWSIZE+$(du -b "$DEST"/"$filename"."$EXT" | cut -f1)))

  # If it fails, try and run HandBrake a second time. Many times this will succeed
  # when the first one failed.
  else

    # Sometimes handbrake just needs to be run a second time if the first time fails
    if HandBrakeCLI --preset-import-gui -Z "$PRESET" -i "$FILE" -o "$DEST"/"$filename"."$EXT" 2>&1 | tee "$DEST"/temp.log; then
      ((COUNT+=1))
      rm "$DEST"/temp.log
      NEWSIZE=$((NEWSIZE+$(du -b "$DEST"/"$filename"."$EXT" | cut -f1)))
      echo "$FILE failed on the first run, but succeeded on the second run." >> "$DEST"/fail.log

    # If it fails the second time, update the fail count, save the filename to the fail log,
    # save the HandBrakeCLI log, and echo the HandBrakeCLI command to the fail log
    # so you can easily attempt to rerun the transcoding manually
    else
      ((FAILED+=1))
      FAILED_FILES="${FAILED_FILES}\n${FILE}"
      {
        echo "======$FILE======"
        cat "$DEST"/temp.log
        echo -e "\n======$FILE======"
        echo "HandBrakeCLI --preset-import-gui -Z \"$PRESET\" -i \"$FILE\" -o \"$DEST\"/\"$filename\".\"$EXT\""
      } >> "$DEST"/fail.log
      rm "$DEST"/temp.log
    fi
  fi

  # Only show progress if we haven't reached the end
  if ((COUNT+FAILED < TOTALCNT)); then
    progress $SECONDS
  fi

done

# Reset globstar
eval "$OLD_GLOBSTAR"

# Calculate the total time it took to transcode the files
TOTALTIME=$(calc_time $SECONDS)

if [ "$COUNT" -ge 1 ]; then
  echo "The script finished converting $COUNT file(s) from \"$(basename "$SRC")\"."
  echo "It completed it in $TOTALTIME averaging $(echo "scale=2; $totalFrames/$SECONDS" | bc)fps."
  echo "Intial size: $(numfmt --to=iec $ORIGSIZE)"
  echo "Transcoded size: $(numfmt --to=iec $NEWSIZE)"
  echo "Reduced total size by $(echo "100-(100*$NEWSIZE/$ORIGSIZE)" | bc)%, saving $(numfmt --to=iec $((ORIGSIZE-NEWSIZE)))."
# elif [ "$COUNT" -eq 1 ]; then
#   echo"The script finished converting $COUNT file in $TOTALTIME"
fi

# If anything failed, notify which file(s) and the location for the log
if [ "$FAILED" -ge 1 ]; then
  echo -e "The following $FAILED file(s) failed to encode:$FAILED_FILES"
  echo "Please see $DEST/fail.log for more details."
  exit 2
fi

if [ "$COUNT" -eq 0 ]; then
  echo "The script did not convert any files."
  exit 1
fi
