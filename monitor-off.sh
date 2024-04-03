#!/bin/bash

# Copyright 2016-2024 Jeremy Hansen <jebrhansen -at- gmail.com>
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

# This script will use dbus to turn off your monitor when running KDE/Plasma5.
# My monitors love to randomly flip on, and this will allow me to turn them off
# whether I'm at the computer or I log in via ssh on my phone.

# This needed massive reworking after Slackware's move to Plasma5 and will need
# other reworking for other DEs/WMs (hopefully just the dbus command).

# -----------------------------------------------------------------------------

sleep 2

# If we don't have the right environment variables set (usually due to remote
# logins), set them.
for i in DISPLAY XAUTHORITY DBUS_SESSION_BUS_ADDRESS; do
 if [ -z "${!i}" ]; then
   # Get all PIDs of the logged in user, then get the environment variables of
   # those PIDs, make each variable have it's own line, get the first instance
   # of the variable, and then extract the contents of the variable. Then we
   # set the variable in the script and export it.
   export "$i=$(ps -u "$UID" -o pid= | xargs -I {} cat /proc/{}/environ 2> /dev/null | tr '\00' '\n' | grep -m1 ^$i= | cut -d= -f2-)"
 fi
done

dbus-send --session --print-reply --dest=org.kde.kglobalaccel /component/org_kde_powerdevil org.kde.kglobalaccel.Component.invokeShortcut string:'Turn Off Screen'
