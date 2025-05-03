#!/bin/bash
#
# Copyright 2024 Jeremy Hansen <jebrhansen -at- gmail.com>
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

# Edit mkv track info without remuxing. Can support editing multiple tracks on
# the same line. Track can be referenced either as a number (starting from 0)
# or character and number. If using character and number, the first character
# in track can be (v)ideo, (a)udio, (s)ubtitle, or (b)utton (whatever "button"
# is), followed by track number (starting from 1).

# The below changes the first subtitle track to be the default and the second
# track to be marked as "forced" for forced subtitles (subtitles for spoken
# languages other than the expected).

# I have this mainly to remember it so I don't have to teach myself how to use
# it next time I need to do it. Maybe others will find a use for it.

# -----------------------------------------------------------------------------

for i in *.mkv; do
  mkvpropedit "$i" \
  --edit track:s1 --set flag-default=1 --set language=eng \
  --edit track:s2 --set flag-forced=1
done
