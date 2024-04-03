#!/bin/bash
#
# By Jeremy Hansen <jebrhansen -at- gmail.com> circa 2020
#
# Feel free to use and abuse this "one-liner"

# KDE4 loves to screw up my panels after reawaking the monitors. This resets
# plasma-desktop and reverts the changes using git.

killall plasma-desktop
(
  cd ~/.kde
  git checkout share/config/plasma-desktoprc
  git checkout share/config/plasma-desktop-appletsrc
)
plasma-desktop > /dev/null 2>&1
