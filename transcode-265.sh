#!/bin/bash

# Copyright 2021-2024  Jeremy Hansen <jebrhansen -at- gmail.com>
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

# --------------------------Global Settings Beginning--------------------------
DEFAULT_EXT="mkv"                     # Override using EXT=
DEFAULT_PRESET="H.265 MKV 1080p Sub"  # Override using PRESET=

SAVEFOL="${SAVEFOL:-$HOME/.transcode}"
SAVESTATS="${SAVESTATS:-yes}"
STATLOC="${STATLOC:-$SAVEFOL/transcode-stats}"
SAVEHIST="${SAVEHIST:-yes}"
HISTLOC="${HISTLOC:-$SAVEFOL/transcode-history}"

MERGESUBS="${MERGESUBS:-yes}"
# ---------------------------Global Settings Ending----------------------------

help ()
{
  cat <<EOH
-- Usage:
   "$(basename "$0") <src> <dest> [ext] [preset]"

-- Option parameters:
   <src>    - Location of the existing file(s)     <required>
   <dest>   - Location to save transcoded file(s)  <required>
   [ext]    - File format: mp4 or mkv              [optional]
   [preset] - HandBrake Preset                     [optional]

EOH

}

description ()
{
  cat <<EOH
-- Description:
   This script will take a directory and convert all video files within to the
   specified format using HandBrakeCLI and save them in the "output" directory.
   It will not save them into their respective season folders and will likely
   require further processing (I use filebot for mine). It will also calculate
   the remaining time based on how long it's taken so far and what's left and
   notify you of failed transcodes (and save the log for that failed transcode.

   This script requires passing at least source and destination locations.
   File extension and preset can be pre-configured within the script, but can
   be passed if you want to override the presets as the 3rd and 4th arguments,
   or by passing EXT= and/or PRESET= to the script.

   If global stats are enabled (SAVESTATS=yes), then they will be displayed at
   the bottom of the help output or when transcoding is complete. Save file
   defaults to ~/.transcode-stats, but can be moved to a global location if
   being used for multiple users.

   If global history is enabled (SAVEHIST=yes), then the folder locations of
   the original files will be saved. There may be future checks added to
   prevent duplicate, accidental transcodes.

   Subtitle files (srt only for now) are detected and the user is prompted on
   if they'd like merge them into the resulting mkv (doesn't currently work on
   mp4 output) if they can be matched to the correct video.

   If video files are not being included, pass DEBUG=yes to the script and it
   will save the filenames to \$DEST/non-video-files.txt with the mimetype.
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
old_progress()
{
  ELAPSED_TIME=$1
  COMPLETED=$(echo "$COUNT+$FAILED" | bc)
  PERCENT=$(echo "(100*$COMPLETED/$TOTALCNT)" | bc)
  EST_REMAIN_SEC=$(printf "%.0f" "$(echo "scale=10; $ELAPSED_TIME/($COMPLETED/$TOTALCNT)-$ELAPSED_TIME" | bc)")
  EST_REMAIN=$(calc_time "$EST_REMAIN_SEC")

  # Let's save the ETA info to a file so it can be checked remotely, then display the file.
  {
    echo "==============================================================================="
    echo "${PERCENT}% completed. $COMPLETED of $TOTALCNT $(fileORfiles "$TOTALCNT")."
    echo "Remaining Time: $EST_REMAIN"
    echo "Estimated Completion: $(date --date='+'"$EST_REMAIN_SEC"' seconds')"
    echo "==============================================================================="
    echo
  } > "$DEST"/000-ETA
  cat "$DEST"/000-ETA
}

# Let's try a new progress feature based on frame count rather than how
# much time has elapsed. This will help with directories that contain
# shorter extras than stanard episodes.
new_progress()
{
  ELAPSED_TIME=$1
  COMPLETED=$(echo "$COUNT+$FAILED" | bc)
  PERCENT=$(echo "(100*$countedFrames/$totalFrames)" | bc )
  EST_REMAIN_SEC=$(printf "%.0f" "$(echo "scale=10; $ELAPSED_TIME/($countedFrames/$totalFrames)-$ELAPSED_TIME" | bc)")
  EST_REMAIN=$(calc_time "$EST_REMAIN_SEC")

  # Let's save the ETA info to a file so it can be checked remotely, then display the file.
  {
    echo "==============================================================================="
    echo "${PERCENT}% completed. $COMPLETED of $TOTALCNT $(fileORfiles "$TOTALCNT")."
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
    echo "This script has converted $PERMCNT total $(fileORfiles "$PERMCNT") over the course of $PERMRUNS runs."
    echo "It has run a total of $(calc_time "$PERMSECS") averaging $(echo "scale=2; $PERMFRAMES/$PERMSECS" | bc)fps."
    echo "Initial total size: $(numfmt --to=iec "$PERMORIG")"
    echo "Transcoded total size: $(numfmt --to=iec "$PERMNEW")"
    echo "Reduced the total size by $(echo "100-(100*$PERMNEW/$PERMORIG)" | bc)%, saving $(numfmt --to=iec -- $((PERMORIG-PERMNEW))) total space."
    echo "Average intial filesize of $(numfmt --to=iec -- $((PERMORIG/PERMCNT))) reduced to $(numfmt --to=iec -- $((PERMNEW/PERMCNT))) after transcoding."
    echo "Added $PERMSUBS subtitle $(fileORfiles "$PERMSUBS") into videos."
    echo "========================================================================"
  elif [ "$SAVESTATS" == "yes" ] && [ "$PERMRUNS" -eq "0" ]; then
    echo "No stats are available yet. Please check $STATLOC or transcode some files."
  fi
}

final_stats()
{
  # Save the current stats to the output directory and cat the file
  # Useful to be able to see stats remotely or when 'screen' corrupts output
  {
    echo
    echo "The script finished converting $COUNT $(fileORfiles "$COUNT") from \"$(basename "$SRC")\"."
    echo "It finished at $(date) in $TOTALTIME, averaging $(echo "scale=2; $countedFrames/$SECONDS" | bc)fps."
    echo "Intial size: $(numfmt --to=iec "$ORIGSIZE")"
    echo "Transcoded size: $(numfmt --to=iec "$NEWSIZE")"
    # Use UPorDOWN set below to determine whether the size was reduced (common)
    # or increased (rare). Use the period as a delimeter so we can have the same
    # echo statement for both.
    echo "${UPorDOWN%.*} total size by $(echo "100-(100*$NEWSIZE/$ORIGSIZE)" | bc)%, ${UPorDOWN#*.} $(numfmt --to=iec -- $((ORIGSIZE-NEWSIZE)))." | sed 's|-||g'
    # Only display subs added if subs were actually added.
    if [ "$SUBSADDED" -ge "1" ]; then
      echo "Added $SUBSADDED subtitle $(fileORfiles "$SUBSADDED") into videos."
    fi
  } >> "$DEST"/000-stats
  cat "$DEST"/000-stats
}

check_dir()
{
  DIR2CHK="$1"
  REASON="$2"

  # First check if the directory exists, otherwise we'll try to create it
  if [ -d "$DIR2CHK"/ ]; then
    # If the directory exists, but is not writeable, throw an error
    if [ ! -w "$DIR2CHK" ]; then
      echo "Directory $DIR2CHK used for $REASON is not writable!"
      echo "Please check permissions and try again."
      return 1
    fi
  else
    # If it doesn't exists and we can't create the directory, throw an error
    if ! mkdir -p "$DIR2CHK"; then
      echo "Unable to create the $DIR2CHK directory used for $REASON."
      echo "Please check destination and try again."
      return 1
    fi
  fi
}

check_file()
{
  FILE2CHK="$1"
  REASON="$2"

  # First check if it exists, otherwise we'll try to create it
  if [ -f "$FILE2CHK" ]; then
    # If it exists, but is not writeable, throw an error
    # This is not catastrophic in most cases, so just set a return code
    # and let that function determine what to do
    if [ ! -w "$FILE2CHK" ]; then
      echo "$REASON is enabled, but $FILE2CHK is not writable."
      return 1
    fi
  else
    # If we can't create it, throw an error
    # This is not catastrophic in most cases, so just set a return code
    # and let that function determine what to do
    if ! touch "$FILE2CHK"; then
      echo "Unable to create $FILE2CHK."
      return 1
    fi
  fi
}

# Function to determine whether to display singular or plural
# Pass the variable to the function inside the echo statement
# e.g. echo "There are $COUNT $(fileORfiles "$COUNT")."
fileORfiles ()
{
    if [ "$1" -ne 1 ]; then
        echo "files";
    else
        echo "file";
    fi
}

# Check for required programs and error out if they aren't installed or
# are broken with an exit code of 127 (file not found, usually due to
# broken libraries after an ABI update
for i in HandBrakeCLI mediainfo ffplay; do
  if ! which $i &> /dev/null; then
    echo "ERROR: $i is not installed or within your \$PATH!"
    echo "Please correct and try again."
    MISSING=yes
  else
    ERRMSG=$($i 2>&1)
    RETVAL=$?
    if [ "$RETVAL" == "127" ]; then
      echo -e "\nERROR: $i is broken... likely because of updated libraries."
      echo "You most likely need to recompile $i to correct the issue."
      echo "It failed with the following error:"
      echo "$ERRMSG"
      BROKEN=yes
    fi
  fi
done

# If the above loop found missing or broken packages, exit
if [ "$MISSING" == "yes" ] || [ "$BROKEN" == "yes" ]; then
  exit 1
fi

# Set our variables
SRC="$1"
DEST="$2"
EXT="${3:-$DEFAULT_EXT}"
PRESET="${4:-$DEFAULT_PRESET}"

# mp4 extensions don't support our method of importing subs. They need to be
# specially added using mov_text, which is very limited. This is not currently
# supported as I prefer mkv files (but support may be added later).
# Notify the user adding subs isn't supported with the mp4 extension and
# continue with MERGESUBS disabled.
if [ "$EXT" == "mp4" ] && [ "$MERGESUBS" == "yes" ]; then
  echo "Adding subtitles to MP4 files is not currently supported."
  echo "Either Ctrl+C and change options or wait 5 seconds and the script"
  echo "will continue with using the mp4 extension without merging subs."
  sleep 5
  MERGESUBS="no"
fi

# Check that the stats/history folder exists and is writeable.
# If not, disable stats and history.
if [ "$SAVESTATS" == "yes" ] || [ "$SAVEHIST" == "yes" ]; then
  if ! check_dir "$SAVEFOL" "stats directory"; then
    if [ "$SAVESTATS" == "yes" ]; then
      echo "Disabling stats."
      SAVESTATS=no
    fi
    if [ "$SAVEHIST" == "yes" ]; then
      echo "Disabling history."
      SAVEHIST=no
    fi
    sleep 5
  fi
fi

# Check if STATLOC is writeable
if [ "$SAVESTATS" == "yes" ]; then
  if ! check_file "$STATLOC" "SAVESTATS"; then
    echo "Disabling stats."
    SAVESTATS=no
    sleep 5
  fi
fi

# Check if HISTLOC is writeable
if [ "$SAVEHIST" == "yes" ]; then
  if ! check_file "$HISTLOC" "SAVEHIST"; then
    echo "Disabling history."
    SAVEHIST=no
    sleep 5
  fi
fi

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
        echo "PERMSUBS=\"0\""
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

# If no inputs, display full help with description and stats
# Otherwise, go into the checks and display error and parameters
if [ "$#" == "0" ]; then
  help
  description
  # Check if stats are enabled and print
  print_global_stats
  exit 0
fi

# Don't display stats if they're just asking for help
if [ "$1" == "help" ] || [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  help
  description
  exit 0
fi

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
if ! check_dir "$DEST" "destination directory"; then
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
countedFrames=0
totalFrames=0
EXIT=
ATTEMPTS=10
SUBCOUNT=0
SUBSADDED=0

# Store shopt globstar option to potentially revert
OLD_GLOBSTAR=$(shopt -p globstar)
# Then ensure that globstar is set to match all files
shopt -s globstar

# Get total count of files
# Also get number of frames to better determine estimated completion
echo "Finding total filecount. Please wait..."
for FILE in "$SRC"/**; do

  # Only count and check if it's a video file
  # Catch bug in 14.2's file program wrongly detecting some mpg files as x-tga
  if file -i "$FILE" | grep -q -e video -e 'mpg\|mpeg'.*image/x-tga; then
    # Catch the .sub of sub/idx subtitles being caught as a video
    if [ "${FILE##*.}" == "sub" ]; then
      continue
    # Skip m4a files detected as video/mp4
    elif [ "${FILE##*.}" == "m4a" ]; then
      continue
    fi
    ((TOTALCNT+=1))
    ORIGSIZE=$((ORIGSIZE+$(du -b "$FILE" | cut -f1)))
  # Let's check manually for .ts files since some show up as non-video
  elif [ "${FILE##*.}" == "ts" ]; then
    ((TOTALCNT+=1))
    ORIGSIZE=$((ORIGSIZE+$(du -b "$FILE" | cut -f1)))
  # Let's check manually for .mkv files since some show up as "application/octet-stream; charset=binary"
  elif [ "${FILE##*.}" == "mkv" ]; then
    ((TOTALCNT+=1))
    ORIGSIZE=$((ORIGSIZE+$(du -b "$FILE" | cut -f1)))
  # But, if it's a subtitle, count it separately to present to the user.
  elif [ "${FILE##*.}" == "srt" ] && [ "$MERGESUBS" == "yes" ]; then
    ((SUBCOUNT+=1))
    continue
  else
    # Optionally output any non-video files for debugging
    if [ "$DEBUG" == "yes" ]; then
      echo "$FILE" >> "$DEST"/non-video-files.txt
      file -i "$FILE" >> "$DEST"/non-video-files.txt
    fi
    continue
  fi

  # Check for files containing non-ascii. It breaks the script (at least
  # on 14.2). HandBrakeCLI does not support colons, so flag those too.
  if printf -- "\r-> %s\n" "$FILE" | grep --color='auto' -P '[^\x00-\x7F]|\x3A'; then

    # Set the exit variable so we can find and display all files containing
    # non-ascii and then exit after the loop.
    EXIT=yes
  fi

  # Output our count
  printf "\r%.0f $(fileORfiles "$TOTALCNT")" "$TOTALCNT"

done

# If non-ascii characters were found, warn, delete DEST folder, and then exit.
if [ -n "$EXIT" ]; then
  echo -e "\n!=============================================================================!"
  echo "! The above filename(s) contain non-ascii or colon characters, which are not  !"
  echo "! supported by this script and/or HandBrake. Please rename the files using    !"
  echo "! only ascii characters without colons and run the script again. Thanks!      !"
  echo "!=============================================================================!"
  rmdir --ignore-fail-on-non-empty "$DEST"
  exit 1
fi

# Count total frames of all videos so we can better determine a proper
# completion estimate and show percentage complete during loop
printf "\rFound %s $(fileORfiles "$TOTALCNT"). Processing for ETA calculation...\n" "$TOTALCNT"
currCOUNT=0
for FILE in "$SRC"/**; do

# Only count and check if it's a video file
  # Catch bug in 14.2's file program wrongly detecting some mpg files as x-tga
  if ! file -i "$FILE" | grep -q -e video -e 'mpg\|mpeg'.*image/x-tga; then
    # Skip files that aren't videos, except .ts and .mkv
    if [ "${FILE##*.}" != "ts" ] && [ "${FILE##*.}" != "mkv" ]; then
      continue
    fi
  # Catch the .sub of sub/idx subtitles being caught as a video
  elif [ "${FILE##*.}" == "sub" ]; then
    continue
  # Catch .m4a being caught as video/mp4
  elif [ "${FILE##*.}" == "m4a" ]; then
    continue
  fi


  # ffprobe is faster, but won't always have the framecount available
  frames=$(ffprobe -show_streams -select_streams v:0 -hide_banner -v error -show_format -i file:/"$(realpath "$FILE")" 2> /dev/null | grep FRAMES | head -1 | cut -d'=' -f2)
  # Check and make sure $frames is set and is only a number before we try and
  # add it to totalFrames. Prevents a syntax error if $frames isn't a number.
  if [ -n "${frames##*[!0-9]*}" ]; then
    totalFrames=$((totalFrames+frames))
  else
    # Try the more robust, but much, much slower mediainfo
    frames=$(mediainfo --Inform='Video;%FrameCount%' "$FILE")
    if [ -n "${frames##*[!0-9]*}" ]; then
      totalFrames=$((totalFrames+frames))
    else
      {
        echo "Frame count could not be determined for $FILE"
      }  >> "$DEST"/000-fail.log
      frameErr="yes"
    fi
  fi
  ((currCOUNT+=1))
  printf "\r$((100*currCOUNT/TOTALCNT))%% complete"

done
printf "\rProcessing complete.\n"
unset currCOUNT

# If $frameErr is set, offer the chance to exit before continuing.
if [ "$frameErr" == "yes" ]; then
  cat "$DEST"/000-fail.log
  echo "!=============================================================================!"
  echo "! Frame count was not determined for the above files. Transcoding may fail    !"
  echo "! for those files. This script will automatically continue after 10 seconds.  !"
  echo "! If you want to stop to check/correct the files, please press Ctrl+C now.    !"
  echo "!=============================================================================!"
  sleep 10
fi

# If subs were found, present the option to try and merge them.
if [ "$SUBCOUNT" -ge "1" ]; then
  echo -e "\n!===========================================================================!"
  echo "$SUBCOUNT subtitle $(fileORfiles "$SUBCOUNT") were found for $TOTALCNT video $(fileORfiles "$TOTALCNT")."
  echo -n "Would you like to add the subtitles into the video if a match is found? Y/n "
  read -r answer
  # If anything other than n, set SUBS to yes
  if grep -qi "n" <<< "$answer"; then
    echo "Subs will not be added. If desired, please move subtitles manually once"
    echo "transcoding is finished."
  else
    echo -e "Subs will be added to files during transcoding.\n"
    SUBS="yes"
  fi
fi

# If only ascii characters were found, proceed with the transcoding.
echo "Processed $TOTALCNT $(fileORfiles "$TOTALCNT") totalling $(numfmt --to=iec $ORIGSIZE). Starting the transcoding..."
sleep 4

# Save the source location for easy future reference
# (I kept forgetting which source I used when I went to delete)
# (Append just in case we're adding to the folder.)
realpath "$SRC" >> "$DEST"/000-SOURCE.txt

# Let's add subdirectories, just in case I combined multiple folders
if [ "$(find "$SRC" -type d -mindepth 1 -printf '1'  | wc -c)" -ge "1" ]; then
  find "$SRC" -type d -maxdepth 1 | sort >> "$DEST"/000-SOURCE.txt
fi

# If history is enabled, save the folders
if [ "$SAVEHIST" == "yes" ]; then
  {
    date
    realpath "$SRC"
    echo "   $(basename "$SRC")"
    # Output subdirectories if they exist
    if [ "$(find "$SRC" -type d | wc -l)" -gt "1" ]; then
      find "$SRC" -type d | sed "s|$SRC|      |g" | tail -n+2
    fi
    realpath "$DEST"
    echo "Totalling $TOTALCNT $(fileORfiles "$TOTALCNT")."
    echo -e "=======================================\n"
  } >> "$HISTLOC"
fi

# Time to start looping through the directory and convert files
for FILE in "$SRC"/**; do

  # Don't try and convert a directory
  if [ -d "$FILE" ]; then
    continue
  fi

  # Don't try and convert if the file isn't a video
  # Catch bug in 14.2's file program wrongly detecting some mpg files as x-tga
  if ! file -i "$FILE" | grep -q -e video -e 'mpg\|mpeg'.*image/x-tga; then
    # Don't skip .ts & .mkv files (some of which don't show as video)
    if [ "${FILE##*.}" != "ts" ] && [ "${FILE##*.}" != "mkv" ]; then
      continue
    fi
  # Catch the .sub of sub/idx subtitles being caught as a video
  elif [ "${FILE##*.}" == "sub" ]; then
    continue
  # Catch .m4a being caught as video/mp4
  elif [ "${FILE##*.}" == "m4a" ]; then
    continue
  fi

  # Get just the filename without extension and current dir
  filename=$(basename "${FILE%.*}")
  fileDIR=$(realpath "$(dirname "$FILE")")

  SUBCMD=""
  SUBFILE=""
  # If we're merging subs, let's try to find the subtitle file
  if [ "$SUBS" == "yes" ]; then

    # If the file exists in the same directory with the same name, use it
    if [ -f "${FILE%.*}".srt ]; then
      SUBFILE="${FILE%.*}".srt


    # If there is a Subs/ directory, let's check in there
    elif [ -d "$fileDIR"/Subs ]; then

      # Check in a directory with the same name as the episode
      if [ "$(find "$fileDIR/Subs/$filename" -iname '*English.srt' | wc -l)" -ge "1" ]; then
        SUBFILE=$(du -b "$fileDIR/Subs/$filename/"*English.srt | sort -rn | cut -f2 | head -n1)
      fi

    # May add more entries later if needed based on other directory/subtitle
    # structures I encounter

    fi

    # If the above was successful, alter the HandBrake command to include subtitles
    # We need to store the command in an array due to bash limitations of storing
    # commands in variables.
    # See https://github.com/koalaman/shellcheck/wiki/SC2089 for more details
    if [ -n "$SUBFILE" ]; then
      SUBCMD=(--srt-lang=eng --srt-file=\""$SUBFILE"\")
      ((SUBSADDED+=1))
    fi

  fi

  # Count frames so we can determine an average transcoding FPS.
  frames=$(mediainfo --Inform='Video;%FrameCount%' "$FILE")
  # Check and make sure $frames is set and is only a number before we try and
  # add it to countedFrames. Prevents a syntax error if $frames isn't a number.
  if [ -n "${frames##*[!0-9]*}" ]; then
    countedFrames=$((countedFrames+frames))
  else
    {
      echo "==============================================================================="
      echo "Could not calculate number of frames for: $FILE"
      echo "==============================================================================="
    } >> "$DEST"/000-fail.log
    framechk=none
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
    HandBrakeCLI --preset-import-gui -Z "$PRESET" -i "$FILE" "${SUBCMD[@]}" -o "$DEST"/"$filename"."$EXT" 2>&1 | tee "$DEST"/temp.log
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
          echo "HandBrakeCLI --preset-import-gui -Z \"$PRESET\" -i \"$FILE\" " "${SUBCMD[@]}" " -o \"$DEST\"/\"$filename\".\"$EXT\""
          echo -e "\n======================$FILE======================\n"
        } >> "$DEST"/000-fail.log
        rm "$DEST"/temp.log
        # Save all the commands separately as well to output them on script exit
        FAILEDCMD="${FAILEDCMD}\nHandBrakeCLI --preset-import-gui -Z \"$PRESET\" -i \"$FILE\" \"${SUBCMD[*]}\" -o \"$DEST\"/\"$filename\".\"$EXT\""

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

    # If we have a frame count, use the new progress option
    if [ "$framechk" != "none" ]; then
      new_progress $SECONDS
    else
      old_progress $SECONDS
    fi

    # Allow progress to be seen before progressing
    sleep 5
  else
    if [ -f "$DEST"/000-ETA ]; then
      rm "$DEST"/000-ETA
    fi
  fi

done

# Reset globstar
eval "$OLD_GLOBSTAR"

# Update global stats
if [ "$SAVESTATS" == "yes" ]; then

  # Source the stats again in case multiple instances were ran simultaneously
  source "$STATLOC"

  # Update the variables
  ((PERMCNT+=COUNT))
  ((PERMORIG+=ORIGSIZE))
  ((PERMNEW+=NEWSIZE))
  ((PERMRUNS+=1))
  ((PERMSECS+=SECONDS))
  ((PERMFRAMES+=countedFrames))
  ((PERMSUBS+=SUBSADDED))

  # Update the file
  {
    echo "PERMCNT=\"$PERMCNT\""
    echo "PERMORIG=\"$PERMORIG\""
    echo "PERMNEW=\"$PERMNEW\""
    echo "PERMRUNS=\"$PERMRUNS\""
    echo "PERMSECS=\"$PERMSECS\""
    echo "PERMFRAMES=\"$PERMFRAMES\""
    echo "PERMSUBS=\"$PERMSUBS\""
  } > "$STATLOC"
fi

# Calculate the total time it took to transcode the files
TOTALTIME=$(calc_time $SECONDS)

if [ "$COUNT" -ge 1 ] && [ "$NEWSIZE" -le "$ORIGSIZE" ]; then
  # Print global stats if enabled
  print_global_stats
  # Print final stats from the transcoding
  UPorDOWN="Reduced.saving"
  final_stats
elif [ "$COUNT" -ge 1 ] && [ "$NEWSIZE" -gt "$ORIGSIZE" ]; then
  # Print global stats if enabled
  print_global_stats

  # Make sure they see that files are bigger.
  echo "====$(basename "$0") failed to transcode files smaller than the original.===="
  echo -e "File size \e[33mincreased\e[0m $(echo "(100*$NEWSIZE/$ORIGSIZE)-100" | bc)% adding $(numfmt --to=iec -- $(((ORIGSIZE-NEWSIZE)*-1)))."
  echo -e "Please consider using the original files and discarding the transcoded files."

  # Print final stats from the transcoding
  UPorDOWN="Increased.adding"
  final_stats
fi

# If anything failed, notify which file(s) and the location for the log
if [ "$FAILED" -ge 1 ]; then
  echo -e "$FAILEDCMD" >> "$DEST"/000-fail.log
  echo -e "\nThe following $FAILED $(fileORfiles "$FAILED") failed to encode:$FAILED_FILES\n"
  echo "Please see $DEST/000-fail.log for more details."
  echo "These are the transcoding commands for the failed files to manually run: "
  echo -e "$FAILEDCMD"
  exit 2
fi

if [ "$COUNT" -eq 0 ]; then
  echo "The script did not convert any files."
  exit 1
fi
