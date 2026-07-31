#!/bin/bash
#
# Copyright 2023-2026 Jeremy Hansen <jebrhansen -at- gmail.com>
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

# Create a chroot from a maintained and updated Slackware stable base to allow
# easy testing of SlackBuild scripts in a clean environment. Ensure that base
# is updated every time this script is ran along with updating sbopkg and
# running sqg to update all queues. Offer to remove chroot files when exiting
# the chroot.

# Supports passing "cleanup" to remove any existing chroots and their files.

# Supports passing "update" to update the base image with slackpkg and sbopkg
# and then exiting without starting the chroot.

# TODO
# Currently empty

# -----------------------------------------------------------------------------

# --------------------------Global Settings Beginning--------------------------

# Set where you want the chroot located and the base name of the folder
CHROOT_LOCATION=/tmp/
CHROOT_TEMPLATE_BASE="chroot"


# This script defaults to 64bit Slackware. If you want a 32bit chroot, remove
# the 64 from the following variable (so it is unset).
ARCH="64"

# Set your Slackware version
VERSION=15.0

# Set the parent locations for the base install and local mirror
# NOTE: Do not add the slackware repo to the variables
SLACKWARE_BASE=/share/gothrough/sbo-build/
LOCAL_MIRROR=/share/gothrough/slackware-mirrors/

# The default rsync mirror when setting up an initial local mirror
# NOTE: Do not add the slackware repo to the variables
RSYNC_MIRROR=rsync://mirror.slackbuilds.org/slackware/

# Default to exclude source dirs, which should save time in the original sync
# and in subsequent re-syncs. Change to "no" if you want sources included.
# Options are "yes" or "no" with the unset default being "no".
# Excluding the source saves about 12GB, making the final size around 8GB,
# where the full source is around 20GB.
EXCLUDE_SOURCE="yes"

# To allow you to open GUI programs from within the chroot, you need to
# allow "remote" access to the x server. This could possibly open up
# security issues, but it is limited to non-network local connections.
# Change to "no" if you want this disabled or pass ACCESS=no to the script.
ACCESS=${ACCESS:-yes}

# Let's set some default rsync options that might get updated in later parts
# of the script.
RSYNC_OPTIONS="-a --delete"

# ---------------------------Global Settings Ending----------------------------

# --------------------------Custom Commands Beginning--------------------------
# This will allow you to add custom aliases or functions into the chroot
# Make sure you escape single quotes and variables and that all commands are on
# their own lines
custom_cmd='
# Check all listed deps in a .info to see if they are installed
alias checkdeps=". *.info; for i in \$REQUIRES; do ls /var/log/packages/*SBo* | cut -d/ -f5 | rev | cut -d- -f4- | rev | grep ^\$i$; done"
'
# ---------------------------Custom Commands Ending----------------------------

# -------------------------Derived Settings Beginning--------------------------

# Use ARCH/VERSION variables to set the SLACKWARE_REPO variable
SLACKWARE_REPO="slackware$ARCH-$VERSION"

# Add the Slackware repository to the configured locations
SLACKWARE_BASE="${SLACKWARE_BASE%/}/$SLACKWARE_REPO"
LOCAL_MIRROR="${LOCAL_MIRROR%/}/$SLACKWARE_REPO"/

# The default rsync mirror when setting up an initial local mirror
RSYNC_MIRROR="${RSYNC_MIRROR%/}/$SLACKWARE_REPO"/

# ---------------------------Derived Settings Ending---------------------------

# Simplify calling umount
safe_umount ()
{
  local umount_dir="$1"
  if mountpoint -q "$umount_dir"; then
    printf "\tUmounting %s\n" "$umount_dir"
    umount "$umount_dir" || umount -l "$umount_dir"
  fi
}

# Let's consolidate all the cleanups to a single function
cleanup_chroot ()
{
  local chroot_dir="$1"
  local action="${2:-delete}"

  safe_umount "$chroot_dir"/chroot/dev/pts
  for mnt in dev proc sys; do
    safe_umount "$chroot_dir"/chroot/"$mnt"
  done

  safe_umount "$chroot_dir"/chroot/etc/resolv.conf
  safe_umount "$chroot_dir"/chroot/var/lib/dbus/machine-id
  safe_umount "$chroot_dir"/chroot

  if [ -d "$chroot_dir" ] && [ "$action" != "keep" ] ; then
    printf "\tRemoving %s.\n" "$chroot_dir"
    rm -rf -- "$chroot_dir"
  fi

}

# Check that we're root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

# Provide an easy cleanup for older tmp files and exit
if [ "$1" == "cleanup" ]; then

  for i in "$CHROOT_LOCATION"/"$CHROOT_TEMPLATE_BASE".*; do
    if [ -d "$i" ]; then
      found="yes"
      echo "Found $i"
      cleanup_chroot "$i"
    else
      found="no"
      echo "No chroots to clean up."
      exit 2
    fi
  done
  if [ "$found" == "yes" ]; then
    echo "Cleanup complete"
  fi
  exit
fi

# If EXCLUDE_SOURCE was set to "yes" include options for rsync to skip the
# source dirs of the main distro and in subfolders (which includes extra/,
# patches/, pasture/, and testing/.
if [ "$EXCLUDE_SOURCE" == "yes" ]; then
  RSYNC_OPTIONS="$RSYNC_OPTIONS --exclude=source/ --exclude=*/source/"
fi

# Check for the local mirror
if [ ! -d "$LOCAL_MIRROR" ] || [ ! -f "$LOCAL_MIRROR/ChangeLog.txt" ]; then
  echo "It seems you do not have a local Slackware mirror."
  read -erp "Would you like to set it up? (Warning this will take some time and requires internet) Y/n " answer
  if /usr/bin/grep -qi "n" <<< "$answer"; then
    exit 1
  fi

  # Sync everything into a temporary folder. Later, if rsync succeeds, move it
  # over to the actual mirror directory.
  TMP_MIRROR="${LOCAL_MIRROR%/}.partial.$$"
  mkdir -p "$TMP_MIRROR"

  echo "Syncing mirror..."

  if rsync $RSYNC_OPTIONS -- "$RSYNC_MIRROR/" "$TMP_MIRROR"; then

    # Make sure we're syncing into an empty directory
    if [ -d "$LOCAL_MIRROR" ]; then
      rm -rf -- "$LOCAL_MIRROR"
    fi

    mv "$TMP_MIRROR" "${LOCAL_MIRROR%/}"

    echo "Please set up a crontab to keep this mirror up-to-date."
    echo "As root, run \`crontab -e\` and add the following line to run a daily 3AM sync:"
    echo "0 3 * * * rsync $RSYNC_OPTIONS -- \"$RSYNC_MIRROR/\" \"$LOCAL_MIRROR\""

  else
    echo "rsync failed or did not complete. Please try manually."
    echo "rsync $RSYNC_OPTIONS -- \"$RSYNC_MIRROR\" \"$LOCAL_MIRROR\""
    rm -rf -- "$TMP_MIRROR"
  fi
fi

# Check for base install
if [ ! -d "$SLACKWARE_BASE" ] || [ ! -f "$SLACKWARE_BASE"/etc/slackware-version ]; then
  echo "It seems the base Slackware install is not present."
  read -erp "Would you like to create it? Y/n " answer
  if /usr/bin/grep -qi "n" <<< "$answer"; then
    exit 1
  fi

  # Check that a single mirror is selected for slackpkg
  slackpkg_mirror=$(grep -vE '^[[:space:]]*(#|$)' /etc/slackpkg/mirrors)
  if [ "$(echo "$slackpkg_mirror" | wc -l)" -ne "1" ]; then
    echo "slackpkg does not have a mirror set properly."
    echo "Please check /etc/slackpkg/mirrors and try again."
    exit 2
  elif ! echo "$slackpkg_mirror" | grep -q -- "-$VERSION/"; then
    echo "The selected mirror does not match the Slackware version for this script."
    exit 3
  fi

  mkdir -p "$SLACKWARE_BASE"

  # Get a list of packages in patches/ and use those instead of installing
  # the original packages. This should prevent needing to upgrade all patched
  # packages when actually creating the chroot.
  declare -A PATCHES
  for pkg in "$LOCAL_MIRROR"/patches/packages/*.t?z; do
    basepkg=$(basename "$pkg")
    pkgname=$(echo "$basepkg" | rev | cut -d- -f4- | rev)
    PATCHES["$pkgname"]="$pkg"
  done

  # Loop through all the packages and install patched when available or
  # original when no patched versions exist.
  for pkg in "$LOCAL_MIRROR"/slackware"${ARCH}"/*/*.t?z; do

    basepkg=$(basename "$pkg")
    pkgname=$(echo "$basepkg" | rev | cut -d- -f4- | rev)

    # Use patched package if available
    if [ -n "${PATCHES[$pkgname]}" ]; then
      install_pkg="${PATCHES[$pkgname]}"
      unset "PATCHES[$pkgname]"
    else
      install_pkg="$pkg"
    fi
    if ! ROOT="$SLACKWARE_BASE" installpkg "$install_pkg"; then
      echo "installpkg failed for: $install_pkg"
      exit 2
    fi

  done

  # Catch any added packages to stable in patches/
  for i in "$LOCAL_MIRROR"/patches/packages/*.t?z; do
    package=$(echo "$i" | rev | cut -d/ -f1 | cut -d. -f2 | rev)
    if [ ! -f "$SLACKWARE_BASE"/var/log/packages/"$package" ]; then
      ROOT="$SLACKWARE_BASE" installpkg "$i"
    fi
  done
fi

# Check if the local mirror is up-to-date and if not, prompt to update it
REMOTE_CHANGELOG="https://mirror.slackbuilds.org/slackware/$SLACKWARE_REPO/ChangeLog.txt"
status=$(curl -s -o /dev/null -w '%{http_code}' \
              -z "$LOCAL_MIRROR/ChangeLog.txt" \
              "$REMOTE_CHANGELOG")

if [ "$status" == "304" ]; then
  echo "Slackware mirror up-to-date"
elif [ "$status" == "200" ]; then
  read -erp "Local Slackware mirror out of date. Would you like to update it? Y/n " answer
  if ! /usr/bin/grep -qi "n" <<< "$answer"; then
    if ! rsync $RSYNC_OPTIONS --delay-updates -- "$RSYNC_MIRROR/" "$LOCAL_MIRROR"; then
      echo "rsync of mirror failed. You are not running the latest Slackware in this chroot!"
    fi
  fi
fi

# Track the latest updates to prevent attempting to update system
# packages and rebuilding sbopkg's queues
LAST_UPDATE_FILE="$SLACKWARE_BASE/last-base-update"
REMOTE_DATE="$(head -n1 "$LOCAL_MIRROR/ChangeLog.txt")"

# Make sure the base image is up-to-date
if [ ! -f "$LAST_UPDATE_FILE" ] || \
   [ "$REMOTE_DATE" != "$(cat "$LAST_UPDATE_FILE")" ]; then

  for i in "$LOCAL_MIRROR"/patches/packages/*.t?z; do
    if [ ! -e "$SLACKWARE_BASE"/var/lib/pkgtools/packages/"$(basename "${i%.*}")" ]; then
      ROOT="$SLACKWARE_BASE" upgradepkg --install-new "$i"
    fi
  done

  echo "Slackware has been updated with local mirror."
  echo "$REMOTE_DATE" > "$LAST_UPDATE_FILE"
else
  echo "Slackware is up-to-date with the local mirror."
fi

# Set up directories for the chroot
echo "Creating required directories for the overlay"
TMPDIR=$(mktemp -d "$CHROOT_LOCATION"/"$CHROOT_TEMPLATE_BASE".XXXXX)
mkdir "$TMPDIR"/{changes,tmp,chroot}

# Catch unplanned exits and default to keeping the data
trap 'cleanup_chroot "$TMPDIR" keep' EXIT INT TERM

# Mount the overlayfs
echo "Mounting the overlay"
mount -t overlay overlay -olowerdir="$SLACKWARE_BASE",upperdir="$TMPDIR"/changes,workdir="$TMPDIR"/tmp "$TMPDIR"/chroot

# Bind mount the pertinent system dirs
echo "Binding required directories"
mkdir -p "$TMPDIR"/changes/{dev,proc,sys}
for i in dev proc sys; do
  mount -o bind /$i "$TMPDIR"/chroot/$i
done

# Mount /dev/pts for sudo
mkdir -p "$TMPDIR"/changes/dev/pts
mount -o bind /dev/pts "$TMPDIR"/chroot/dev/pts

# Give the chroot internet
echo "Setting up internet"
mount -o bind /etc/resolv.conf "$TMPDIR"/chroot/etc/resolv.conf
chroot "$TMPDIR"/chroot /bin/bash -c "/usr/sbin/update-ca-certificates --fresh > /dev/null"

# Setting up DBUS binding required for certain apps
echo "Binding DBUS to local machine"
touch "$TMPDIR"/chroot/var/lib/dbus/machine-id
mount -o bind /var/lib/dbus/machine-id "$TMPDIR"/chroot/var/lib/dbus/machine-id

# Update sbopkg (if installed) and queues
# Do it in the chroot to prevent GPG errors, but copy files back to the
# base image so we only need to do it during updates.
if [ -e "$SLACKWARE_BASE"/usr/sbin/sbopkg ]; then
  echo "Checking for SBo updates for sbopkg"
  # Get the latest changelog date from server
  SERVDATE="$(wget -qO- "https://slackbuilds.org/slackbuilds/$VERSION/ChangeLog.txt" | head -n1)"
  if [ -z "$SERVDATE" ]; then
    echo "Upstream address did not provide a changelog."
    echo "Please validate internet is working and address is correct"
    echo "This will continue in 5 seconds. Ctrl+C if you'd like to exit."
    sleep 5
  fi
  # Get latest changelog date on local copy
  LOCALDATE="$(head -n1 "$SLACKWARE_BASE/var/lib/sbopkg/SBo/$VERSION/ChangeLog.txt" 2> /dev/null)"
  # If they don't match, update sbopkg and run sqg. Copy updates back to base image.
  if [ "$SERVDATE" != "$LOCALDATE" ]; then
    chroot "$TMPDIR"/chroot /bin/bash -c "/usr/sbin/sbopkg -r; /usr/sbin/sqg -a"
    rsync -a --delete "$TMPDIR"/chroot/var/lib/sbopkg/ "$SLACKWARE_BASE"/var/lib/sbopkg
    rsync -a --delete "$TMPDIR"/chroot/root/.gnupg "$SLACKWARE_BASE"/root/
  else
    echo "sbopkg is up-to-date."
  fi
else
  echo "sbopkg is not installed... skipping update."
  echo "If you'd like sbopkg to be installed, download the latest version from"
  echo "https://sbopkg.org and run the following command as root:"
  echo "ROOT=$SLACKWARE_BASE installpkg sbopkg-*-noarch-1_wsr.tgz"
fi

# Only set up X server access and launch the chroot if update isn't passed
if [ "$1" != "update" ]; then
  # Checking if we can add local connection access
  if [ "$ACCESS" == "yes" ]; then
    echo "Setting up X server access"
    echo "STATUS: $(xhost +local:hosts)"
  fi

  # Set a custom PS1 script in /etc/profile.d to override the default PS1
  echo "export PS1=\"\[\033[41m\]\u\[\033[49m\]@\[\033[33m\]$(basename "$TMPDIR")\[\033[0m\]:\w\\$ \"" > \
  "$TMPDIR"/chroot/etc/profile.d/chroot_custom_options.sh

  # If custom_cmd has some in it, add it to chroot_custom_options.sh
  if [ -n "$custom_cmd" ]; then
    echo "Adding custom commands to chroot's /etc/profile.d/chroot_custom_options.sh"
    echo "$custom_cmd" >> "$TMPDIR"/chroot/etc/profile.d/chroot_custom_options.sh
  fi

  # Add any additional customizations here
  chmod +x "$TMPDIR"/chroot/etc/profile.d/chroot_custom_options.sh

  # Let's save the following in the root of the chroot structure to allow
  # the user to enter into that chroot from another prompt and/or if they
  # accidentally leave the chroot.
  # Then we'll just execute the file to actually enter the chroot.
  cat << EOH > "$TMPDIR"/start-chroot.sh
#!/bin/bash
# Time to actually chroot and do our work
# Need to type 'exit' to leave the chroot and start the cleanup
# Use custom PS1 so we know we're in the chroot
echo "Entering chroot. Please type \"exit\" to exit it."
echo "You can add files to the chroot by placing them in $TMPDIR/chroot/"
chroot "$TMPDIR"/chroot env HOME=/root bash -l
EOH

  # Start the chroot
  bash "$TMPDIR"/start-chroot.sh
fi

# Start cleanup

# Only ask to delete chroot if update isn't passed, otherwise delete without asking
if [ "$1" != "update" ]; then
  # Ask if tmp dirs should be removed
  # Could be kept to review filesystem changes
  echo -n "Would you like to remove the unneeded overlay directories? y/N "
  read -r answer
  # Turn off the trap since all further commands will run the cleanup.
  trap - EXIT INT TERM
  # If anything other than y, rm them
  if ! /usr/bin/grep -qi "y" <<< "$answer"; then
    echo "Temp overlay dirs will not be removed. They can be found at $TMPDIR."
    cleanup_chroot "$TMPDIR" "dont-delete"
  else
    cleanup_chroot "$TMPDIR"
  fi
else
  cleanup_chroot "$TMPDIR"
fi
