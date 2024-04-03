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

# Create a chroot from a maintained and updated Slackware stable base to allow
# easy testing of SlackBuild scripts in a clean environment. Ensure that base
# is updated every time this script is ran along with updating sbopkg and
# running sqg to update all queues. Offer to remove chroot files when exiting
# the chroot and, if passed "cleanup", remove any remaining chroot files.

# TODO
# Maybe add script to root of folders to allow easy secondary logins

# Check that we're root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

CHROOT_LOCATION=/tmp/
CHROOT_TEMPLATE_BASE="chroot"

# Provide an easy cleanup for older tmp files and exit
if [ "$1" == "cleanup" ]; then

  for i in "$CHROOT_LOCATION"/"$CHROOT_TEMPLATE_BASE".*; do
    if [ -d "$i" ]; then
      echo "Found $i"
    else
      echo "No chroots to clean up."
      exit 2
    fi

    for j in dev proc sys; do
      if mountpoint -q "$i"/chroot/$j; then
        printf "\tUnmounting %s/chroot/%s\n" "$i" "$j"
        umount "$i"/chroot/$j
      fi
    done

    if mountpoint -q "$i"/chroot/etc/resolv.conf; then
      printf "\tUnmounting %s/chroot/etc/resolv.conf\n" "$i"
      umount "$i"/chroot/etc/resolv.conf
    fi

    # umount overlayfs
    if mountpoint -q "$i"/chroot; then
      printf "\tUnmounting %s/chroot/%s/chroot\n" "$i" "$j"
      umount "$i"/chroot
    fi

      # Remove dirs
    if [ -d "$i" ]; then
      printf "\tRemoving %s.\n" "$i"
      rm -r "$i"
    fi
  done
  echo "Cleanup complete"
  exit
fi

# Set variables for the base image and location of the local Slacwkare mirror
VERSION=15.0
SLACKWARE_BASE=/share/gothrough/sbo-build/$VERSION
LOCAL_MIRROR=/share/gothrough/slackware-mirrors/slackware64-$VERSION/

# Track the latest updates to prevent attempting to update system
# packages and rebuilding sbopkg's queues
touch $SLACKWARE_BASE/last-base-update

# Make sure the base image is up-to-date
if [ "$(head -n1 $LOCAL_MIRROR/ChangeLog.txt)" != "$(cat $SLACKWARE_BASE/last-base-update)" ]; then
  for i in "$LOCAL_MIRROR"/patches/packages/*.t?z; do
    if [ ! -e "$SLACKWARE_BASE"/var/lib/pkgtools/packages/"$(basename "${i%.*}")" ]; then
      ROOT=$SLACKWARE_BASE upgradepkg --install-new "$i"
    fi
  done
  echo "Slackware has been updated with local mirror."
  head -n1 $LOCAL_MIRROR/ChangeLog.txt > $SLACKWARE_BASE/last-base-update
else
  echo "Slackware is up-to-date with the local mirror."
fi

# Set up directories for the chroot
echo "Creating required directories for the overlay"
TMPDIR=$(mktemp -d "$CHROOT_LOCATION"/"$CHROOT_TEMPLATE_BASE".XXXXX)
mkdir "$TMPDIR"/{changes,tmp,chroot}

# Mount the overlayfs
echo "Mounting the overlay"
mount -t overlay overlay -olowerdir="$SLACKWARE_BASE",upperdir="$TMPDIR"/changes,workdir="$TMPDIR"/tmp "$TMPDIR"/chroot

# Bind mount the pertinent system dirs
echo "Binding required directories"
mkdir -p "$TMPDIR"/changes/{dev,proc,sys}
for i in dev proc sys; do
  mount -o bind /$i "$TMPDIR"/chroot/$i
done

# Give the chroot internet
echo "Setting up internet"
mount -o bind /etc/resolv.conf "$TMPDIR"/chroot/etc/resolv.conf
chroot "$TMPDIR"/chroot /bin/bash -c "/usr/sbin/update-ca-certificates --fresh > /dev/null"

# Update sbopkg (if installed) and queues
# Do it in the chroot to prevent GPG errors, but copy files back to the
# base image so we only need to do it during updates.
if [ -e "$SLACKWARE_BASE"/usr/sbin/sbopkg ]; then
  if [ "$(wget -qO- https://git.slackbuilds.org/slackbuilds/plain/ChangeLog.txt | head -n1)" != "$(head -n1 $SLACKWARE_BASE/var/lib/sbopkg/SBo/15.0/ChangeLog.txt)" ]; then
    chroot "$TMPDIR"/chroot /bin/bash -c "/usr/sbin/sbopkg -r; /usr/sbin/sqg -a"
    rsync -a --delete "$TMPDIR"/chroot/var/lib/sbopkg/ "$SLACKWARE_BASE"/var/lib/sbopkg
    rsync -a --delete "$TMPDIR"/chroot/root/.gnupg "$SLACKWARE_BASE"/root/
  else
    echo "sbopkg is up-to-date."
  fi
fi

# Time to actually chroot and do our work
# Need to type 'exit' to leave the chroot and start the cleanup
# Use custom PS1 so we know we're in the chroot
echo "Entering chroot. Press type \"exit\" to exit it."
echo "You can add files to the chroot by placing them in $TMPDIR/chroot/"
chroot "$TMPDIR"/chroot env PS1="\[\e[41m\]\u\[\e[49m\]@\[\e[33m\]$(basename "$TMPDIR")\[\e[0m\]:\w$ " bash

# Start cleanup

# Undo bind mounts
for i in dev proc sys; do
  umount "$TMPDIR"/chroot/$i
done

umount "$TMPDIR"/chroot/etc/resolv.conf

# umount overlayfs
umount "$TMPDIR"/chroot

# Ask if tmp dirs should be removed
# Could be kept to review filesystem changes
echo -n "Would you like to remove the unneeded overlay directories? y/N "
read -r answer
# If anything other than y, rm them
if ! /usr/bin/grep -qi "y" <<< "$answer"; then
  echo "Temp overlay dirs will not be removed. They can be found at $TMPDIR."
else
  rm -r "$TMPDIR"
fi
