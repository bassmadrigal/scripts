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

SAVESTATS="${SAVESTATS:-yes}"
STATLOC="${STATLOC:-$HOME/.transcode-stats}"

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

   If global stats are enabled (SAVESTATS=yes), then they will be displayed at
   the bottom of the help output or when transcoding is complete. Save file
   defaults to ~/.transcode-stats, but can be moved to a global location if
   being used for multiple users.

EOH
  # Check if stats are enabled and print
  print_global_stats
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

  # Let's save the ETA info to a file so it can be checked remotely, then display the file.
  {
    echo "==============================================================================="
    echo "${PERCENT}% completed. $COMPLETED of $TOTALCNT files."
    echo "Remaining Time: $EST_REMAIN"
    echo "Estimated Completion: $(date --date='+'"$EST_REMAIN_SEC"' seconds')"
    echo "==============================================================================="
    echo
  } > "$DEST"/000-ETA
  cat "$DEST"/000-ETA

}

print_global_stats()
{
  if [ "$SAVESTATS" == "yes" ] && [ "$PERMRUNS" -gt "0" ]; then
    echo -e "\n==============================Global stats=============================="
    echo "This script has converted $PERMCNT total files over the course of $PERMRUNS runs."
    echo "It has run a total of $(calc_time "$PERMSECS") averaging $(echo "scale=2; $PERMFRAMES/$PERMSECS" | bc)fps."
    echo "Initial total size: $(numfmt --to=iec "$PERMORIG")"
    echo "Transcoded total size: $(numfmt --to=iec "$PERMNEW")"
    echo "Reduced the total size by $(echo "100-(100*$PERMNEW/$PERMORIG)" | bc)%, saving $(numfmt --to=iec $((PERMORIG-PERMNEW))) total space."
    echo "Average intial filesize of $(numfmt --to=iec $((PERMORIG/PERMCNT))) reduced to $(numfmt --to=iec $((PERMNEW/PERMCNT))) after transcoding."
    echo "========================================================================"
  elif [ "$SAVESTATS" == "yes" ] && [ "$PERMRUNS" -eq "0" ]; then
    echo "No stats are available yet. Please check $STATLOC or transcode some files."
  fi
}

# Get global stats going if set
if [ "$SAVESTATS" == "yes" ]; then
  if [ ! -f "$STATLOC" ]; then
    echo -n "Stats have been enabled, but $STATLOC does not exist. Would you like to create it? Y/n "
    read -r answer
    # If anything other than n, create the file
    if ! /usr/bin/grep -qi "n" <<< "$answer"; then
      {
        echo "PERMCNT=\"0\""
        echo "PERMORIG=\"0\""
        echo "PERMNEW=\"0\""
        echo "PERMRUNS=\"0\""
        echo "PERMSECS=\"0\""
        echo "PERMFRAMES=\"0\""
      } > "$STATLOC"
      source "$STATLOC"
    else
      echo "Please disable stats, change stat location, or create file."
      exit 1
    fi
  else
    source "$STATLOC"
  fi
fi

# Time to check our inputs

# Check to see if they passed source and destination locations
if [ -z "$SRC" ] || [ -z "$DEST" ]; then
  echo -e "\n!!ERROR!!\n$(basename "$0") requires passing the source and destination directories\n"
  help
  exit 1
fi

# Check to see if the source directory exists
if [ ! -d "$SRC" ]; then
  echo -e "\n!!ERROR!!\n$SRC does not exist or you don't have permission to access it.\n"
  help
  exit 1
fi

# Try to create the destination directory
if ! mkdir -p "$DEST"; then
  echo -e "\n!!ERROR!!\nFailed to create the \"$DEST\"."
  echo -e "Do you have proper permissions?\n"
  help
  exit 1
fi

# Make the extension lowercase
EXT=${EXT,,}
# Make sure the extension is either mkv or mp4
if [ "$EXT" != "mkv" ] && [ "$EXT" != "mp4" ]; then
  echo -e "\n!!ERROR!!\n$3 is not a valid extension. Please choose \"mp4\" or \"mkv\".\n"
  help
  exit 1
fi

# Make sure the HandBrake preset exists.
if ! HandBrakeCLI --preset-import-gui -z 2>&1 >/dev/null | grep -q "$PRESET"; then
  echo -e "\n!!ERROR!!\n\"$PRESET\" is not a valid HandBrake preset.\n"
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
EXIT=
ATTEMPTS=10

# Store shopt globstar option to potentially revert
OLD_GLOBSTAR=$(shopt -p globstar)
# Then ensure that globstar is set to match all files
shopt -s globstar

# Get total count of files
echo "Finding total filecount. Please wait..."
for FILE in "$SRC"/**; do

  # Only count and check if it's a video file
  if file -i "$FILE" | grep video &> /dev/null; then
    ((TOTALCNT+=1))
    ORIGSIZE=$((ORIGSIZE+$(du -b "$FILE" | cut -f1)))
  else
    continue
  fi

  # Check for files containing non-ascii. It breaks the script (at
  # least on 14.2).
  if [[ "$FILE" = *[![:ascii:]]* ]]; then
    echo "Contains Non-ASCII: $FILE"
    # Set the exit variable so we can find and display all files containing
    # non-ascii and then exit after the loop.
    EXIT=yes
  fi

done

# If non-ascii characters were found, warn and then exit.
if [ -n "$EXIT" ]; then
  echo -e "\n!=============================================================================!"
  echo "! The above file(s) contain non-ascii characters which are not supported by   !"
  echo "! this script. Please rename the files using only ascii characters and run    !"
  echo "! the script again. Thanks!                                                   !"
  echo "!=============================================================================!"
  exit 1
fi

# If only ascii characters were found, proceed with the transcoding.
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

  # Count frames so we can determine an average transcoding FPS.
  frames=$(mediainfo --Inform='Video;%FrameCount%' "$FILE")
  # Check and make sure $frames is set and is only a number before we try and
  # add it to totalFrames. Prevents a syntax error if $frames isn't a number.
  if [ -n "${frames##*[!0-9]*}" ]; then
    totalFrames=$((totalFrames+frames))
  else
    {
      echo "==============================================================================="
      echo "Could not calculate number of frames for: $FILE"
      echo "==============================================================================="
    } >> "$DEST"/000-fail.log
  fi

  # Set pipefail to ensure HandBrakeCLI failing works
  # This will allow a failure of HandBrakeCLI to propagate through the pipe
  # and allow the if statement to catch a failure of the HandBrakeCLI command
  # so it can run the else section if needed
  set -o pipefail

  # Let's set up the encoding in a while loop. I've found that sometimes
  # HandBrake will randomly fail. Most of the time, it will successfully
  # complete the encoding on the second attempt, but I've had those fail and
  # successfully complete on the third attempt. We'll now allow for the number
  # of attempts to be configured by the user, defaulting to 5. If it fails
  # after the set number of attempts, it will log the failure and continue with
  # the rest of the queue.
  while true; do

    # Check to make sure file doesn't already exist (since we're dumping
    # everything in the same directory).
    if [ -f "$DEST"/"$filename"."$EXT" ]; then
      FILECNT=1
      while [ -f "${DEST}/${filename} - (${FILECNT}).${EXT}" ]; do
        ((FILECNT+=1))
      done
      filename="${filename} - (${FILECNT})"
    fi

    # Time to actually start transcoding. Capture the exit code for later
    # analysis (if error codes are different, then I may add future functionality
    # to adjust subsequent attempts) and increment LOOPCNT.
    HandBrakeCLI --preset-import-gui -Z "$PRESET" -i "$FILE" -o "$DEST"/"$filename"."$EXT" 2>&1 | tee "$DEST"/temp.log
    RETVAL=$?
    ((LOOPCNT+=1))

    # If it completed successfully, increase the count, remove the log, and
    # update the total encoded size variable.
    if [ "$RETVAL" -eq "0" ]; then
      ((COUNT+=1))
      rm "$DEST"/temp.log
      NEWSIZE=$((NEWSIZE+$(du -b "$DEST"/"$filename"."$EXT" | cut -f1)))

      # If this wasn't the first run, log it in 000-fail.log
      if [ "$LOOPCNT" -gt "1" ]; then
        echo "$FILE encode failed $((LOOPCNT-1)) time(s), but succeeded on run # $LOOPCNT." >> "$DEST"/000-fail.log
      fi
      # Reset LOOPCNT and exit the loop if successful
      LOOPCNT=0
      break
    else
      echo "$FILE encode failed on run # $LOOPCNT with an exit code of \"$RETVAL\"." >> "$DEST"/000-fail.log

      # If a partially transcoded file exists, delete it so the next round
      # can run without trying to duplicate it
      [ -f "$DEST"/"$filename"."$EXT" ] && rm "$DEST"/"$filename"."$EXT"

      # If we've hit our limit, update the fail count, save the filename to
      # the fail log, save the HandBrakeCLI log, and echo the HandBrakeCLI
      # command to the fail log so you can easily attempt to rerun the
      # transcoding manually
      if [ "$LOOPCNT" -eq "$ATTEMPTS" ]; then
        ((FAILED+=1))
        FAILED_FILES="${FAILED_FILES}\n${FILE}"
        {
          echo "=============$FILE failed $ATTEMPTS time(s)============="
          cat "$DEST"/temp.log
          echo "HandBrakeCLI --preset-import-gui -Z \"$PRESET\" -i \"$FILE\" -o \"$DEST\"/\"$filename\".\"$EXT\""
          echo -e "\n======================$FILE======================\n"
        } >> "$DEST"/000-fail.log
        rm "$DEST"/temp.log
        # Save all the commands separately as well to output them on script exit
        FAILEDCMD="${FAILEDCMD}\nHandBrakeCLI --preset-import-gui -Z \"$PRESET\" -i \"$FILE\" -o \"$DEST\"/\"$filename\".\"$EXT\""

        # Reset LOOPCNT and exit the loop if attempts have been reached
        LOOPCNT=0

        break
      fi
      continue
    fi
  done

  # Only show progress if we haven't reached the end
  # If we've reached the end, delete the 000-ETA file
  if ((COUNT+FAILED < TOTALCNT)); then
    progress $SECONDS
  else
    rm "$DEST"/000-ETA
  fi

done

# Reset globstar
eval "$OLD_GLOBSTAR"

# Update global stats
if [ "$SAVESTATS" == "yes" ]; then

  # Update the variables
  ((PERMCNT+=COUNT))
  ((PERMORIG+=ORIGSIZE))
  ((PERMNEW+=NEWSIZE))
  ((PERMRUNS+=1))
  ((PERMSECS+=SECONDS))
  ((PERMFRAMES+=totalFrames))

  # Update the file
  {
    echo "PERMCNT=\"$PERMCNT\""
    echo "PERMORIG=\"$PERMORIG\""
    echo "PERMNEW=\"$PERMNEW\""
    echo "PERMRUNS=\"$PERMRUNS\""
    echo "PERMSECS=\"$PERMSECS\""
    echo "PERMFRAMES=\"$PERMFRAMES\""
  } > "$STATLOC"
fi

# Calculate the total time it took to transcode the files
TOTALTIME=$(calc_time $SECONDS)

if [ "$COUNT" -ge 1 ]; then
  echo "The script finished converting $COUNT file(s) from \"$(basename "$SRC")\"."
  echo "It completed it in $TOTALTIME averaging $(echo "scale=2; $totalFrames/$SECONDS" | bc)fps."
  echo "Intial size: $(numfmt --to=iec $ORIGSIZE)"
  echo "Transcoded size: $(numfmt --to=iec $NEWSIZE)"
  echo "Reduced total size by $(echo "100-(100*$NEWSIZE/$ORIGSIZE)" | bc)%, saving $(numfmt --to=iec $((ORIGSIZE-NEWSIZE)))."
  # Check if stats are enabled and print
  print_global_stats
fi

# If anything failed, notify which file(s) and the location for the log
if [ "$FAILED" -ge 1 ]; then
  echo -e "\nThe following $FAILED file(s) failed to encode:$FAILED_FILES\n"
  echo "Please see $DEST/000-fail.log for more details."
  echo "These are the transcoding commands for the failed files to manually run: "
  echo -e "$FAILEDCMD"
  exit 2
fi

if [ "$COUNT" -eq 0 ]; then
  echo "The script did not convert any files."
  exit 1
fi
