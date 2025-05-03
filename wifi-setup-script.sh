#!/bin/bash

# Copyright (c) 2020 Jeremy Hansen <jebrhansen+SBo -at- gmail.com>

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# REQUIRES: n/wireless_tools n/wpa_supplicant
# OPTIONAL: SBo:lshw

# This script has bashisms and won't work with just sh.
if [ "$BASH" != "/bin/bash" ] ; then
    echo "This script requires bash due to bashisms."
    echo "It does not support running it with 'sh' or other shells."
    echo "Please chmod +x $0 to execute it directly or run:"
    echo "bash $0" 1>&2
    exit 1
fi

# Check for multiple wifi devices and, if found, prompt user which one to use
readarray -t CHECKNUM < <(/sbin/iwconfig 2> /dev/null | /usr/bin/grep ESSID | cut -d' ' -f1)

# If there are more than wireless one devices, prompt the user to select which one 
if [ ${#CHECKNUM[@]} -gt 1 ]; then

  # Check if lshw is available -- if it is, provide brand and model names to user
  # Otherwise skip this part and keep them ugly
  if lshw &> /dev/null; then

    # Loop through devices and let user know the brand and product
    # Needs lshw package
    for ((i=0; i<${#CHECKNUM[@]}; i++)); do
      DEVICE="${CHECKNUM[i]}"
      LSHWINFO=$(lshw -class network | /usr/bin/grep -B 4 "logical name" | /usr/bin/grep -B 4 "$DEVICE" | head -2)
      PRODUCT=$(echo "$LSHWINFO" | head -1 | cut -d: -f2-)
      VENDOR=$(echo "$LSHWINFO" | tail -1 | cut -d: -f2-)
      CHECKNUM[i]="$DEVICE -- $VENDOR $PRODUCT"
    done
  fi

  echo "Multiple wifi devices were found. Please select the one you want: "
  select WIFIDEV in "${CHECKNUM[@]}"; do
    [[ -n "$WIFIDEV" ]] || { echo "Invalid choice. Please try again." >&2; continue; }
    WIFIDEV=$(echo "$WIFIDEV" | cut -d' ' -f1)
    break
  done

# If there's only one device, store it
elif [ ${#CHECKNUM[@]} -eq 1 ]; then
  WIFIDEV=${CHECKNUM[0]}
# If there's no wireless devices, let the user know
else
  echo "No wireless devices found. Please check hardware/drivers and try again."
  exit 1
fi

# Go until connected or the user decides to stop
while true; do

  # Check if we are already connected to a network
  # Use the broadcast address in case they're on a network without internet
  # and planning on using a local server
  BCADDR=$(/sbin/ifconfig "$WIFIDEV" | /usr/bin/grep cast | rev | cut -d' ' -f1 | rev 2> /dev/null)
  echo "Checking for existing network... "
  if /bin/ping -W 1 -bc1 "$BCADDR" &>/dev/null; then

  # Check for internet
    if /bin/ping -c1 1.1.1.1 &>/dev/null; then
      NET="the internet"
    else
      NET="a network WITHOUT internet"
    fi
    echo -e "\nYou ARE connected to $NET.\n"
    echo -n "Continuing WILL disconnect you. Do you want to continue? y/N "
    read -r EXIT

    # If anything other than y, exit the script
    ! /usr/bin/grep -qi "y" <<< "$EXIT" && exit 0 || echo -e "\nDisconnecting from network"
  else
    echo -e "Not connected to a network.\n"
  fi

  # Kill wpa_supplicant, dhcpcd, and dhclient if they're already running
  /usr/bin/killall wpa_supplicant dhcpcd dhclient 2> /dev/null

  # Null out access point address, which usually disassociates from router
  /sbin/iwconfig "$WIFIDEV" ap 00:00:00:00:00:00 2> /dev/null

  # Bring the interface down and back up for good measure
  /sbin/ifconfig "$WIFIDEV" down 2> /dev/null
  # Needs the sleep to prevent the interface from not coming back up in time
  sleep 1
  /sbin/ifconfig "$WIFIDEV" up 2> /dev/null
  
  echo "Scanning for wireless networks..."

  # Store the list and grab SSIDs and Signal rates for each network
  IWLIST=$(/sbin/iwlist "$WIFIDEV" scan)
  SSID=$(echo "$IWLIST" | /usr/bin/grep SSID | cut -d\" -f2)
  SIGNAL=$(echo "$IWLIST" | /usr/bin/grep Signal | cut -d- -f2 | cut -d' ' -f1)

  # Store the SSIDs in an array based on signal strength
  readarray -t NETLIST < <(paste <(echo "$SIGNAL") <(echo "$SSID") | tr '\t' ' ' | sort | cut -d' ' -f2-)

  # Add an extra entry to allow manually typing in the SSID
  NETLIST+=("Not listed - Manually enter SSID")

  # Display the SSID selection dialog
  COLUMNS=single
  echo -e "\n=================================\n"
  echo "Please select a wireless network: "
  select SSID in "${NETLIST[@]}"; do
    [[ -n $SSID ]] || { echo "Invalid choice. Please try again." >&2; continue; }
    break
  done

  # If the user selects "Not listed" allow them to type the network
  if [ "$SSID" == "Not listed - Manually enter SSID" ]; then
    echo -en "\nPlease enter network SSID: "
  read -r SSID
  fi

  # Type in the passphrase and hide the characters from the prompt
  # Make sure the passphrase is between 8 and 63 characters
  while true; do
    echo -en "\nPlease type in the passphrase for $SSID: "
    read -rs PASS
    if [ ${#PASS} -lt 8 ] || [ ${#PASS} -gt 63 ]; then
      echo "WPA passphrases are between 8 and 63 characters."
      echo "Your passphrase was ${#PASS} character(s). Please try again."
    else
      break
    fi
  done

  # Time to try and connect
  echo -ne "\nAttempting to connect."

  # Try and connect with wpa_supplicant
  /usr/sbin/wpa_supplicant -B -D nl80211 -i "${WIFIDEV}" -c <(echo "ctrl_interface=/var/run/wpa_supplicant"; wpa_passphrase "$SSID" "$PASS") &> /dev/null
      
  # Check if wpa_supplicant has connected once per second for 10 seconds
  # If connected, break out of the loop early and move onto the DHCP
  for (( i=0; i<10; i++ )); do
  WPASTATUS=$(wpa_cli -i wlan0 status | /usr/bin/grep wpa_state | cut -d"=" -f2)
    if [ "$WPASTATUS" == "COMPLETED" ]; then
      echo -e "\n\nConnected! Now to request an IP.\n"
      sleep 1
      break
    else
      sleep 1
      echo -n "."
    fi
  done
  
  # Fail after 10 seconds of wpa_supplicant not connecting
  if [ "$i" -eq 10 ]; then
    echo -e "FAILED!\n\nCould not connect with SSID: $SSID.\n"
    echo -n "Would you like to try again? Y/n "
    read -r TRYAGAIN
    /usr/bin/grep -qi "n" <<< "$TRYAGAIN" && exit 1
    
  # If we get an address, exit the script. If we don't, offer to try again
  else
    if dhcpcd "$WIFIDEV" &> /dev/null; then
      echo "Successfully connected to $SSID with IP $(ifconfig wlan0 | /usr/bin/grep "inet " | cut -d' ' -f10)"
      exit
    else
      echo "DHCP failed!"
      echo -n "Would you like to try again? Y/n "
      read -r TRYAGAIN
      /usr/bin/grep -qi "n" <<< "$TRYAGAIN" && break
    fi
  fi
done