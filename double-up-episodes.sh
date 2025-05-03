#!/bin/bash
#
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

# If there are two episodes named as one (but otherwise in order), rename them
# to contain the proper episode numbers (ie S01E01 would become S01E01-E02,
# S01E02 would become S01E03-E04, etc)

DIR="$1"
CWD=$(pwd)
cd "$DIR"

COUNT=1
FIRST=1
SECOND=2

# Store files in a temp dir to prevent catching the wrong episodes and not
# overwrite the originals
mkdir -p temp

# Figure out how many files to set our counter
NUMFILES=$(ls *S??E* | wc -l)

# Loop through until we reach the total number of files
for (( COUNTER=1; COUNTER<=$NUMFILES; COUNTER+=1 )); do

  # Set the base episode number and pad to 2 spaces
  BASE_EP=$(printf "%02d" $COUNTER)
  # Find the corresponding file
  FILENAME=$(ls *S??E"$BASE_EP"*)
  # Calculate what the first episode number should be and pad to 2 spaces
  FIRST_EP=$(printf "%02d" $FIRST)
  # Calculate what the second episode number should be and pad to 2 spaces
  SEC_EP=$(printf "%02d" $SECOND)
  # Set the new episode filename
  NEWNAME=$(echo $FILENAME | sed "s/E${BASE_EP}/E${FIRST_EP}-E${SEC_EP}/")

  # Actually rename and move the file to a temp dir
  mv "$FILENAME" temp/"$NEWNAME"

  # Increase the counters
  FIRST=$(( $FIRST + 2 ))
  SECOND=$(( $SECOND + 2 ))
done

# Move the files out of the temp dir and rm the dir
mv temp/* .
rmdir temp

# Switch back to the original directory
cd "$CWD"
