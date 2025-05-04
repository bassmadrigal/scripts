#!/bin/bash
#
# Copyright 2024-2025 Jeremy Hansen <jebrhansen -at- gmail.com>
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

# Find installed packages with the SBo tag that don't exist in the SBo repo.

# This may be due to packages being removed/renamed on SBo or locally developed
# packages that were installed, but never added to SBo itself.

# -----------------------------------------------------------------------------

# Location of the SBo repo, use sbopkg location by default.
SBOREPO="${SBOREPO:-/var/lib/sbopkg/SBo/15.0}"

for i in /var/log/packages/*SBo*; do
  PRGNAM="$(basename "$i" | rev | cut -d- -f4- | rev)"

  # If the installed program doesn't exist in the SBo repo...
  if ! ls "$SBOREPO"/*/"$PRGNAM" &> /dev/null; then

    # Let's see if we can find a potential match by slapping python on the
    # front of the package name. If there are multiple potential matches, tell
    # the user.
    NUMMATCH=$(find "$SBOREPO" -name "python?-*$PRGNAM*" -type d 2> /dev/null | wc -l)
    if [ "$NUMMATCH" -gt "1" ]; then
      echo "$PRGNAM -> More than one possible match, check manually"
    elif [ "$NUMMATCH" -eq "1" ]; then
      echo "$PRGNAM -> Maybe: $(find "$SBOREPO" -name "python?-*$PRGNAM*" -type d 2> /dev/null | rev | cut -d/ -f1-2 | rev)"
    else
      echo "$PRGNAM -> No detected match"
    fi
  fi
done
