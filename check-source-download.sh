#!/bin/bash
#
# Copyright 2023-2024 Jeremy Hansen <jebrhansen -at- gmail.com>
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

# This was extracted and tweaked from my sbgen.sh script, which was added in
# v0.6 in MAR 2023.

# This will take copy/pasted URLs from github and provide direct URLs that can
# download the correct filename with or without using content-disposition. It
# will also take hashed URLs from pythonhosted and pypi so all that is needed
# to update versions is to change the version number.

# You can either add this function into your script, add it to your environment
# or pass the url to the script.

function check_download()
{
  TESTURL="$1"
  DOMAIN="$(echo "$TESTURL" | cut -d"/" -f 3)"

  # Let's first prep github addresses
  if [ "$DOMAIN" == "github.com" ]; then
    OWNER=$(echo "$TESTURL" | cut -d"/" -f4)
    PROJECT=$(echo "$TESTURL" | cut -d"/" -f5)

    # Check for release urls, which don't need modification
    if [ "$(echo "$TESTURL" | cut -d"/" -f6)" == "releases" ]; then
      NEWURL="$TESTURL"
    # Catch tag versions
    elif [ "$(echo "$TESTURL" | cut -d"/" -f7-8)" == "refs/tags" ]; then
      # Extract the version from the URL to get the right tag and use that
      # to get the right version to include in the filename
      TAGVER=$(basename "$TESTURL" | rev | cut -d. -f3- | rev)
      NEWURL="https://$DOMAIN/$OWNER/$PROJECT/archive/refs/tags/$TAGVER/$PROJECT-${TAGVER//v/ }.tar.gz"
    # Check for commit ID
    # Need to check for 41 chars since the url includes a newline that isn't stripped
    elif [ "$(echo "$TESTURL" | cut -d"/" -f7 | cut -d"." -f1 | wc -m)" -eq 41 ]; then
      COMMITID=$(echo "$TESTURL" | cut -d"/" -f7 | cut -d"." -f1)
      NEWURL="https://$DOMAIN/$OWNER/$PROJECT/archive/${COMMITID:0:7}/$PROJECT-$COMMITID.tar.gz"
    # Just return the url if it doesn't match the above
    else
      NEWURL="$TESTURL"
    fi

  # If we're using a hashed python.org link, switch to a proper versioned link
  elif [ "$DOMAIN" == "files.pythonhosted.org" ] || [ "$DOMAIN" == "pypi.python.org" ]; then
    # Check if we're using a hashed url by seeing if the parent folder is
    # 61 characters (the length of the hash)
    if [ "$(echo "$TESTURL" | cut -d"/" -f7 | wc -c)" == "61" ]; then
      PROJECT="$(echo "$TESTURL" | cut -d"/" -f8 | cut -d- -f1)"
      VERSION="$(echo "$TESTURL" | cut -d"/" -f8 | cut -d- -f2 | rev | cut -d"." -f3- )"
      NEWURL="https://files.pythonhosted.org/packages/source/${PROJECT::1}/${PROJECT}/${PROJECT}-${VERSION}.tar.gz"
    else
      NEWURL="$TESTURL"
    fi

  # Anything else, just ignore it.
  # Can add future catches if needed
  else
    NEWURL="$TESTURL"
  fi

  # Return our correct URL
  echo "$NEWURL"
}

check_download "$1"
