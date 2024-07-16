#!/bin/bash

# Copyright 2020-2024 Jeremy Hansen <jebrhansen -at- gmail.com>
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
  echo "$(basename "$0") <version>"
  exit 1
else
  NEWVER="$1"
fi

# Check if name is set in ~/.version-bump and if not, prompt for it
if [ -e ~/.version-bump ]; then
  source ~/.version-bump
fi

if [ -n "$NAME" ] && [ ! -e ~/.version-bump ]; then
  echo "Your name is not set, so $(basename) can't check the copyright"
  read -erp "for your info. Please type your name: " NAME
  echo "NAME=\"$NAME\"" > ~/.version-bump
fi

# Let's set some colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m' # Reset color

# Set the program name based on the directory you're in
PRGNAM=$(basename "$PWD")

# Source the .info file or error out if it doesn't exist
if [ -f "$PRGNAM".info ]; then
  . "$PRGNAM".info
else
  echo "Please be in the directory of the .SlackBuild and .info files"
  exit 1
fi

# Check if we're in a git repo
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  ISGIT=yes
  # Set the default branch
  DEF_BRANCH=master
  CUR_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  # Check if we're in the default branch. If so, offer to change it
  if [ "$DEF_BRANCH" == "$CUR_BRANCH" ]; then
    echo -e "${YELLOW}WARNING:${RESET} You are currently on your default branch, $DEF_BRANCH."
    git branch
    read -erp "Do you want to switch to or create a new branch? Y/n " answer
    if ! /usr/bin/grep -qi "n" <<< "$answer"; then
      read -erp "Enter name of new/existing branch: " newbranch
      git checkout -B "$newbranch"
      CUR_BRANCH=$newbranch
    else
      read -erp "Do you want to continue working on $DEF_BRANCH? y/N " answer
      if ! /usr/bin/grep -qi "y" <<< "$answer"; then
        exit 1
      fi
    fi
  fi
else
  ISGIT=no
fi

# Change the version in the .info and .SlackBuild
if [ "$VERSION" != "$NEWVER" ]; then
  echo -e "Changing $PRGNAM's version from ${YELLOW}$VERSION${RESET} to ${GREEN}$NEWVER${RESET}."
  # Need to escape any periods in the variables to prevent them from
  # being treated as wildcards.
  sed -i "s|${VERSION//\./\\.}|${NEWVER//\./\\.}|g" "$PRGNAM".info "$PRGNAM".SlackBuild
else
  echo -e "${RED}ERROR${RESET}: Looks like you're trying to change it to the same version."
  echo "Old version: $VERSION  | New version: $NEWVER"
  read -erp "Would you like to continue? y/N " answer
  if ! /usr/bin/grep -qi "y" <<< "$answer"; then
    exit 1
  fi
fi

# Reset the build number since version was changed
BUILDNUM=$(grep ^BUILD "$PRGNAM".SlackBuild | awk -F[-\}] '{print $2}')
if [ "$BUILDNUM" != "1" ]; then
  echo -e "Resetting the build number from ${YELLOW}$BUILDNUM${RESET} to ${GREEN}1${RESET}."
  sed -i "s|\${BUILD:-.*}|\${BUILD:-1}|" "$PRGNAM".SlackBuild
fi

# Source the updated .info so we can check the downloads
. "$PRGNAM".info

# Time to download files if they aren't already available and generate
# MD5SUMs. Supports both single and multiple downloads.
echo "Checking downloads and generating MD5SUMs."
NEWMD5=""
# Check for 32bit/universal download and update md5sum
if [ "$DOWNLOAD" ] && [ "$DOWNLOAD" != "UNSUPPORTED" ]; then

  # Loop through the download list
  for i in $DOWNLOAD; do
    # Download if the file doesn't already exist
    if [ ! -f "$(basename "$i")" ]; then
      if ! wget "$i"; then
        echo -e "${RED}ERROR${RESET}: Download for $i failed. Please check link and update manually."
        exit 1
      else
        echo -e "${GREEN}Success${RESET}: Downloaded $(basename "$i")."
      fi
    else
      echo -e "${YELLOW}NOTICE${RESET}: File $(basename "$i") already exists. Won't redownload."
    fi
    # If it's the first file, set the variable, otherwise, add to it
    if [ -z "$NEWMD5" ]; then
      NEWMD5="$(md5sum "$(basename "$i")" | cut -d" " -f1)"
    else
      NEWMD5="$NEWMD5 $(md5sum "$(basename "$i")" | cut -d" " -f1)"
    fi
  done
fi

NEWMD5x64=""
# Check for 32bit/universal download and update md5sum
if [ "$DOWNLOAD_x86_64" ] && [ "$DOWNLOAD_x86_64" != "UNSUPPORTED" ]; then

  # Loop through the download list
  for i in $DOWNLOAD_x86_64; do
    # Download if the file doesn't already exist
    if [ ! -f "$(basename "$i")" ]; then
      if ! wget "$i"; then
        echo -e "${RED}ERROR${RESET}: Download for $i failed. Please check link and update manually."
        exit 1
      else
        echo -e "${GREEN}Success${RESET}: Downloaded $(basename "$i")."
      fi
    else
      echo -e "${YELLOW}NOTICE${RESET}: File already exists. Won't redownload."
    fi
    # If it's the first file, set the variable, otherwise, add to it
    if [ -z "$NEWMD5x64" ]; then
      NEWMD5x64="$(md5sum "$(basename "$i")" | cut -d" " -f1)"
    else
      NEWMD5x64="$NEWMD5x64 $(md5sum "$(basename "$i")" | cut -d" " -f1)"
    fi
  done
fi

# Couldn't figure out how to keep the newlines in the updated DOWNLOAD
# and MD5SUM variables, so we will brute force it by combining multiple
# spaces into one to process later. Not so easy peasy, but it works.
{
  echo "PRGNAM=\"$PRGNAM\""
  echo "VERSION=\"$VERSION\""
  echo "HOMEPAGE=\"$HOMEPAGE\""
  echo "DOWNLOAD=\"$(echo "$DOWNLOAD" | tr -s ' ')\""
  echo "MD5SUM=\"$(echo "$NEWMD5" | tr -s ' ')\""
  echo "DOWNLOAD_x86_64=\"$(echo "$DOWNLOAD_x86_64" | tr -s ' ')\""
  echo "MD5SUM_x86_64=\"$(echo "$NEWMD5x64" | tr -s ' ')\""
  echo "REQUIRES=\"$REQUIRES\""
  echo "MAINTAINER=\"$MAINTAINER\""
  echo "EMAIL=\"$EMAIL\""
} > "$PRGNAM".info

# Time to match SBo's .info template
# Manually add a newline and the right number of spaces for the
# variables that need it by swapping the spaces between downloads with
# newlines and the right number of padded spaces for the .info.
sed -Ei '/DOWNLOAD=/s| | \\\n          |g' "$PRGNAM".info
sed -Ei '/MD5SUM=/s| | \\\n        |g' "$PRGNAM".info
sed -Ei '/DOWNLOAD_x86_64=/s| | \\\n                 |g' "$PRGNAM".info
sed -Ei '/MD5SUM_x86_64=/s| | \\\n               |g' "$PRGNAM".info

# Check if the Copyright year contains the current year
COPYRIGHT=$(grep Copyright "$PRGNAM".SlackBuild | tail -n1)
if ! grep -q "$(date +"%Y")" <<< "$COPYRIGHT"; then
  echo -e "\n=============================${YELLOW}YEAR WARNING${RESET}==============================="
  echo -e "Copyright on $PRGNAM.SlackBuild does not seem contain this year's date.\n"
  echo -e "\t$COPYRIGHT\n"
  echo "Please check and consider updating."
  echo -e "=============================${YELLOW}YEAR WARNING${RESET}===============================\n"
  WARN=yes
fi

# Check if the user's name is included in the copyright
if ! grep -q "$NAME" <<< "$COPYRIGHT"; then
  echo -e "\n=============================${YELLOW}NAME WARNING${RESET}==============================="
  echo -e "Copyright on $PRGNAM.SlackBuild does not seem contain your name.\n"
  echo -e "\t$COPYRIGHT\n"
  echo "Please check and consider updating."
  echo -e "=============================${YELLOW}NAME WARNING${RESET}===============================\n"
  WARN=yes
fi

if [ "$WARN" == "yes" ]; then
  read -erp "Would you like to edit the SlackBuild before continuing? Y/n " answer
  if ! /usr/bin/grep -qi "n" <<< "$answer"; then
    $EDITOR "$PRGNAM".SlackBuild
  fi
fi

echo -e "${GREEN}Success${RESET}: $PRGNAM was updated to version $VERSION."

# Let's offer to run the SlackBuild and some tests
echo -e "\nRunning sbolint on directory"
sbolint .
read -rp $'\nWould you like try running the SlackBuild? Y/n ' answer
if ! /usr/bin/grep -qi "n" <<< "$answer"; then
  if ! sudo unshare -n sh "$PRGNAM".SlackBuild; then
    echo "$PRGNAM.SlackBuild failed to run. Please correct manually."
    exit 1
  else
    PKGNAM=$(PRINT_PACKAGE_NAME=yes sh "$PRGNAM".SlackBuild)
    echo -e "Build successful. Running sbopkglint on '$PKGNAM'.\n"
    sbopkglint /tmp/"$PKGNAM"
    read -rp $'\nWould you like try upgrading to '"$PKGNAM"'? Y/n ' answer
    if ! /usr/bin/grep -qi "n" <<< "$answer" && [ -e /tmp/"$PKGNAM" ]; then
      sudo upgradepkg --reinstall /tmp/"$PKGNAM"
      read -rp $'\nWould you like a bash shell to test the program? Y/n ' answer
      if ! /usr/bin/grep -qi "n" <<< "$answer"; then
        # We should let people know when they're in a subshell by modifying the
        # PS1 variable. There have been times I've forgotten due to trying to
        # fix things and this should solve that.
        # However, for some (unknown to me) reason, the PS1 variable is not
        # available in this script even though it's exported in the parent
        # shell. So, we'll extract it from /etc/profile and set it.
        PS1=$(grep PS1 /etc/profile | tail -2 | head -1 | cut -d\' -f2)
        # Remove the escape, question mark, and space from PS1 so we can add
        # it after we add the subshell text.
        NEWPS1="${PS1//\\\$ /} \[\e[33m\](subshell)\[\e[0m\]$ "
        echo "Type 'exit' to go back to end testing."
        env PS1="$NEWPS1" bash --norc
      fi
    fi
    CATEGORY=$(pwd | rev | cut -d/ -f2 | rev)
    echo -e "\nThe following commit has been prepared:"
    echo -e "\n\tgit commit -m \"$CATEGORY/$PRGNAM: Version bump to $VERSION\" .\n"
    if [ "$ISGIT" == "yes" ]; then
      read -rp "Would you like to commit that to the repo? Y/n " answer
      if ! /usr/bin/grep -qi "n" <<< "$answer"; then
        git commit -m "$CATEGORY/$PRGNAM: Version bump to $VERSION" .

        # If we made a commit, ask if we want to push it back to the remote repo
        DEF_REMOTE=origin
        read -rp $'\nWould you like to push that commit to your remote repo, '"\"$DEF_REMOTE\""'? Y/n ' answer
        if ! /usr/bin/grep -qi "n" <<< "$answer"; then
          git push -f origin "$CUR_BRANCH"
          if git checkout "$DEF_BRANCH"; then
            echo -e "\nReturned to default branch, \"$DEF_BRANCH\".\n"
          else
            echo -e "\n\tERROR: Unable to return to default branch, \"$DEF_BRANCH\".\n"
          fi
        fi
      fi
    else
      echo "You are not in a repo and cannot commit this change."
    fi
  fi
fi
