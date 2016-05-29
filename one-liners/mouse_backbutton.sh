#!/bin/bash
#
# By Jeremy Hansen <jebrhansen -at- gmail.com> circa 2013
#
# Feel free to use and abuse this "one-liner"
#
# Used to find my mouse id and set the correct button map
# I need buttons 8 and 9 swapped so my back button doesn't act
# as a forward button.

id=$(xinput --list --id-only 'Microsoft Microsoft Optical Mouse with Tilt Wheel')
xinput set-button-map $id 1 2 3 4 5 6 7 9 8
