#!/bin/bash
#
# Copyright 2014 Jeremy Hansen <jebrhansen -at- gmail.com>
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
#
# This is a script to mute your master volume when the screen times out
# and turns off. And unmute it when the screen turns back on. You can
# also add additional commands to do additional things like pause your
# music player. This should work for any distro that uses xorg and alsa.
#
# Originally developed for Slackware 14.1 -- Might need a new one for 14.2

while true; do 

  # Grab the current status of the monitor(s)
  cur_monitor=$(xset -q | grep Monitor | cut -d' ' -f5)

  # Check to see if there's a difference from the last run
  if [[ $cur_monitor != $pre_monitor ]]
  then

    # Store the current volume
    cur_volume=$(amixer get Master | grep "Left:" | cut -d' ' -f6)

    # Checks if the monitor turned "Off" and the volume isn't muted
    if [[ "$cur_monitor" == 'Off' && "$cur_volume" != '0' ]]
    then
      pre_volume=$cur_volume

      # Mute the speakers when the monitor is turned off
      # Add/replace your own commands here (pause music, etc)
      amixer set Master 0
    fi

    # Checks if monitor turned "On" and if the volume was muted
    if [[ "$cur_monitor" == 'On' && "$cur_volume" == '0' ]]
    then

      # Set speakers to previous volume
      # Add/replace your own commands here (start music, etc)
      amixer set Master $pre_volume
    fi
    
  fi

  # Sets the "previous" monitor for the next round  
  pre_monitor=$cur_monitor

  # Wait ten seconds then run the script again
  sleep 10
  
done
