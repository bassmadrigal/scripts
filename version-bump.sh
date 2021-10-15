#!/bin/bash

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

# Simple version bump for SlackBuilds.

# Make sure the version number is passed to the script or exit
if [ -z "$1" ]; then
  echo "Please pass the new version number as an argument."
  echo "$(basename $0) <version>"
  exit 1
else
  NEWVER="$1"
fi

# Set the program name based on the directory you're in
PRGNAM=$(basename "$PWD")

# Source the .info file or error out if it doesn't exist
if [ -f "$PRGNAM".info ]; then
  . "$PRGNAM".info
else
  echo "Please be in the directory of the .SlackBuild and .info files"
  exit 1
fi

# Change the version in the .info and .SlackBuild
if [ "$VERSION" != "$NEWVER" ]; then
  echo "Changing $PRGNAM's version from $VERSION to $NEWVER"
  sed -i "s/$VERSION/$NEWVER/g" "$PRGNAM".info "$PRGNAM".SlackBuild
else
  echo "Looks like you're trying to change it to the same version."
  echo "Old version: $VERSION  | New version: $NEWVER"
  echo "Please check and try again"
  exit 1
fi

# Reset the build number since version was changed
sed -i 's|${BUILD:-.*}|${BUILD:-1}|' "$PRGNAM".SlackBuild

# Source the updated .info so we can check the downloads
. "$PRGNAM".info

# Don't try and update md5sums for multiple downloads
case ${DOWNLOAD}${DOWNLOAD_x86_64} in
  *\ * ) echo "This does not support updating MD5 hashes for multiple downloads."
         echo "Please update MD5 hashes manually."
         exit 1;;
esac

# Check for 32bit/universal download and update md5sum
if [ "$DOWNLOAD" ] && [ "$DOWNLOAD" != "UNSUPPORTED" ]; then

  if wget "$DOWNLOAD"; then
    NEWMD5=$(md5sum $(basename "$DOWNLOAD") | cut -d" " -f1)
    sed -i "s|$MD5SUM|$NEWMD5|" "$PRGNAM".info
  else
    echo "Download failed. Please check and try again manually."
    exit 1
  fi
fi

# Check for 64bit download and update md5sum
if [ "$DOWNLOAD_x86_64" ] && [ "$DOWNLOAD_x86_64" != "UNSUPPORTED" ]; then
  if wget "$DOWNLOAD_x86_64"; then
    NEWMD5x64=$(md5sum $(basename "$DOWNLOAD_x86_64") | cut -d" " -f1)
    sed -i "s|$MD5SUM_x86_64|$NEWMD5x64|" "$PRGNAM".info
  else
    echo "Download failed. Please check and try again manually."
    exit 1
  fi
fi
