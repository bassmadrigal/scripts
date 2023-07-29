#!/bin/bash
#
# Copyright 2017-2023 Jeremy Hansen <jebrhansen -at- gmail.com>
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

# This script will be used to generate the needed files for SlackBuilds
# based on the templates provided by SBo, however, they will be edited and
# ready for use (unlike downloading them directly from SBo).

# Changelog:
# v0.6.2 - 17 MAY 2023
#          Fix character counting for short description due to forgetting to
#          count the colon when determining total character count.
# v0.6.1 - 18 MAR 2023
#          Correct required python dependency for scripts without a setup.py,
#          escaped some missed special characters, and matched the makepkg
#          command with upstream's template.
# v0.6   - 16 MAR 2023
#          Add correction for github and pypi/python.org links that are
#          directly copied from the sites. This means no more needing to
#          correct github links to provide us with the correct filenames.
#          It also replaces hashed links on pypi/python.org, which prevents
#          my version-bump.sh script from working.
# v0.5.2 - 13 MAR 2023
#          Add new python build method for packages that don't include a
#          setup.py. Adds wheel & python3-installer dependencies to respective
#          build scripts.
# v0.5.1 - 13 MAR 2023
#          Fix infinite loop when long description is more lines than a
#          slack-desc allows
# v0.5   - 30 APR 2022
#          Add interactive mode to prompt for information instead of requiring
#          passing commandline options
# v0.4.4 - 24 APR 2022
#          Fix regex and change slack-desc function to gen_slackdesc
# v0.4.3 - 24 APR 2022
#          Add SRCVER and conf file support
# v0.4.2 - 20 APR 2022
#          Add download of source with MD5SUM generation
# v0.4.1 - 20 APR 2022
#          Add SRCNAM option
# v0.4   - 20 APR 2022
#          Add support for short and long descriptions for slack-desc
# v0.3.1 - 8 APR 2022
#          Use curly brackets on SBOUTPUT variables
# v0.3   - 7 MAR 2022
#          Bump scripts to match 15.0 templates
# v0.2   - 31 MAY 2020
#          Add automatic padding for slack-desc
# v0.1   - 13 APR 2017
#          Initial release

# "one-liner" to find count of scripts using stock commands per script type
# for i in "\./configure \\\\" "cmake \\\\" "runghc Setup configure" "meson \\.\\. \\\\" "^perl.*\\.PL" "python. setup.py install" "gem specification"; do grep "$i" ~/sbo-github/*/*/*.SlackBuild | cut -d: f1 | uniq | wc -l; done

# ===========================================================================
# User configurable settings. Add your information here, override with shell
# variables, or create a conf file (default set to $HOME/.sbgen.conf)

CONFFILE=${CONFFILE:-"$HOME/.sbgen.conf"}
[ -f ${CONFFILE} ] && source ${CONFFILE}

NAME=${NAME:-Your name}
EMAIL=${EMAIL:-Your email}
YEAR=${YEAR:-$(date +%Y)}
# Location for your SlackBuild repo
SBLOC=${SBLOC:-./slackbuilds}

# ===========================================================================

function help() {
  cat <<EOH
-- Usage:
   $(basename $0) [options] <1-$SCRIPTCNT> <program_name> <version> [category]

-- Option parameters  :
   -h                 :   This help.
   -f                 :   Force overwriting existing directory
   -p                 :   Prompt for all options
   -w <homepage>      :   Set the homepage (website)
   -d <download>      :   Set the download location
   -m <md5sum>        :   Set the md5sum
   -D <download64>    :   Set the 64bit download
   -M <md5sum64>      :   Set the 64bit md5sum
   -r <dependencies>  :   Set the REQUIRES for required dependencies
                          (Multiples REQUIRES need to be enclosed in quotes)
   -s <description>   :   Set the short description (use quotations)
   -l                 :   Prompt later for long description
   -S <srcnam>        :   Set optional SRCNAM variable
   -V <srcver>        :   Set optional SRCVER variable

-- Description:
   This script requires passing at least the number corresponding to script
   type (see below), the program name and the program version.
   You can optionally pass the homepage, download, md5sum, x86_64-download,
   x86_64-md5sum and any required dependencies.

   If you want it placed in a certain subfolder under your SlackBuilds
   directory, pass that "category". They don't have to correspond with SBo's
   categories as this is only local.

-- Script types:
EOH
script_types
}

# Set script count so I don't need to remember to change the prompt range
# in the many places it is used within the script
SCRIPTCNT=8
script_types ()
{
  echo -e "   1 : AutoTools (./configure && make && make install)
   2 : Python (python setup.py install)
   3 : CMake (mkdir build && cd build && cmake ..)
   4 : Perl (perl Makefile.PL)
   5 : Haskell (runghc Setup Configure)
   6 : RubyGem (gem specification && gem install)
   7 : Meson (mkdir build && cd build && meson ..)
   8 : Other (Used for manually specifying \"build\" process)

   (This list is sorted based on the frequency in SBo's 15.0 repo.)\n"
}

# Option parsing:
while getopts "hfpw:d:m:D:M:r:s:lS:V:" OPTION
do
  case $OPTION in
    h ) help; exit
        ;;
    f ) FORCE=yes
        ;;
    p ) PROMPT=yes
        ;;
    w ) HOMEPAGE=$OPTARG
        ;;
    d ) DOWNLOAD=$OPTARG
        ;;
    m ) MD5SUM=$OPTARG
        ;;
    D ) DOWNLOAD64=$OPTARG
        ;;
    M ) MD5SUM64=$OPTARG
        ;;
    r ) REQUIRES=$OPTARG
        ;;
    s ) SHORTDESC="$OPTARG"
        ;;
    l ) LONGDESC=yes
        ;;
    S ) SETSRCNAM="$OPTARG"
        ;;
    V ) SETSRCVER="$OPTARG"
        ;;
    * ) help; exit
        ;;
  esac
done
shift $(($OPTIND - 1))

# Display the help and exit if nothing is passed except -p
if [ $# -eq 0 ] && [ "$PROMPT" != "yes" ]; then
  help
  exit 1
fi

# If PROMPT is set and script type, PRGNAM, and VERSION aren't passed, prompt
# for them and CATEGORY
if [ "$PROMPT" == "yes" ] && [ -z $1 ] || [ -z $2 ] || [ -z $3 ]; then
  # While loop to ensure proper category is set
  while true; do
    echo "Available script types:"
    script_types
    read -erp "Please select script type from list [1-$SCRIPTCNT]: " SCRIPTNUM
    # Check that it's a valid script number
    if ! [[ $SCRIPTNUM =~ ^[1-$SCRIPTCNT]$ ]]; then
      echo -e "\n============================================="
      echo "ERROR: Invalid script type! Please try again."
      echo -e "=============================================\n"
    else
      break
    fi
  done

  # Ensure PRGNAM is set
  while true; do
    read -erp "Please provide program name (PRGNAM): " PRGNAM
    if [ -n "${PRGNAM}" ]; then
      break
    else
      echo -e "\nERROR: PRGNAM cannot be blank! Please try again.\n"
    fi
  done
  # Ensure VERSION is set
  while true; do
    read -erp "Please provide version: " VERSION
    if [ -n "${VERSION}" ]; then
      break
    else
      echo -e "\nERROR: VERSION cannot be blank! Please try again.\n"
    fi
  done
  # CATEGORY is optional, so don't check
  read -erp "Please provide script category (optional): " CATEGORY

# If PROMPT is not set, error out if three arguments aren't passed
elif [ -z $1 ] || [ -z $2 ] || [ -z $3 ]; then
  echo -e "\n\tERROR: You must pass the script type, program name, and version.\n"
  help
  exit
# If more than 4 arguments are passed, error out.
elif [ "$#" -gt "4" ]; then
  echo -e "\n\tERROR: Too many arguments were passed. Please check command and try again.\n"
  help
  exit
else
  # Set the program name and version
  SCRIPTNUM=$1
  PRGNAM=$2
  VERSION=$3
  CATEGORY="$4"
fi

# Set SBOUTPUT
SBOUTPUT="${SBLOC}/${CATEGORY}/${PRGNAM}"

# Let's not overwrite an existing folder unless it is forced
if [ -e $SBOUTPUT ] && [ "$PROMPT" == "yes" ]; then
  read -erp "$SBOUTPUT already exists. Would you like to overwrite it? y/N " answer
  # If it's a yes, set FORCE
  if /usr/bin/grep -qi "y" <<< "$answer"; then
    FORCE=yes
  else
   echo "Please adjust parameters and try again."
   exit 1
  fi
elif [ -e $SBOUTPUT ] && [ "${FORCE:-no}" != "yes" ]; then
  echo "$SBOUTPUT already exists. To overwrite, use $(basename $0) -f"
  exit 1
fi

# If the script type isn't valid, error out.
if ! [[ $SCRIPTNUM =~ ^[1-$SCRIPTCNT]$ ]]; then
  echo -e "\n\tERROR: Invalid script type\n"
  help
  exit
fi

# Prompt for remaining options
if [ "$PROMPT" == "yes" ]; then

  # Regex to check for valid webaddress and file location. Separate http from
  # ftp as homepages shouldn't be ftp sites, but downloads can be.
  # Thanks to https://stackoverflow.com/a/3184819/2251996 for the regex
  REGEX='://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'
  WEBEX='(https?)'
  DOWNEX='(https?|ftp)'

  # Prompt for homepage
  while true; do
    read -erp "Please enter homepage: " HOMEPAGE
    # If a homepage was entered, check regex for proper format. If it is not
    # seen as valid, prompt them to enter the same homepage a second time to
    # override the regex. If no homepage was entered, exit the loop and move on
    if [ -n "${HOMEPAGE}" ]; then
      # If website was detected as invalid, but the user enters it a second
      # time, override the regex and save the homepage
      if [ "$ORIGLINK" == "$HOMEPAGE" ]; then
        break
      # If homepage is set, verify it is a valid address with regex
      elif [[ ! ${HOMEPAGE} =~ ${WEBEX}${REGEX} ]]; then
        echo -e "\nERROR: Homepage doesn't seem to be a valid website. Please try again."
        echo -e "If it is valid, enter the same site again to override."
        ORIGLINK="$HOMEPAGE"
      # Otherwise keep the homepage entered and move on
      else
        break
      fi
    # If no homepage was entered, exit the loop
    else
      break
    fi
  done

  # Prompt for 32bit/universal download
  while true; do
    echo -e "\nPlease enter 32bit or universal source link."
    read -erp "If 32bit is unsupported, leave blank: " DOWNLOAD
    # If a download was entered, check regex for proper format. If it is not
    # seen as valid, prompt them to enter the same download a second time to
    # override the regex. If no download was entered, assume 32bit is
    # unsupported.
    if [ -n "${DOWNLOAD}" ]; then
      # If website was detected as invalid, but the user enters it a second
      # time, override the regex and save the homepage
      # Also break if UNSUPPORTED
      if [ "$ORIGLINK" == "$DOWNLOAD" ] || [ "$DOWNLOAD" == "UNSUPPORTED" ]; then
        break
      # If homepage is set, verify it is a valid address with regex
      elif [[ ! ${DOWNLOAD} =~ ${DOWNEX}${REGEX} ]]; then
        echo -e "\nERROR: Download doesn't seem to be a valid link. Please try again."
        echo -e "If it is valid, enter the same link again to override."
        ORIGLINK="$DOWNLOAD"
      # Otherwise keep the homepage entered and move on
      else
        break
      fi
    # If nothing was entered, assume 32bit is not supported
    else
      DOWNLOAD="UNSUPPORTED"
      break
    fi
  done

  # Prompt for 32bit/universal md5sum
  if [ -n "$DOWNLOAD" ] && [ "$DOWNLOAD" != "UNSUPPORTED" ]; then
    echo -e "\nEnter md5sum for 32bit/universal source."
    read -erp "Leave blank to have it auto-generated: " MD5SUM
  fi

  # Prompt for 64bit download
  while true; do
    echo -e "\nPlease enter 64bit source link. Leave blank if previous link was universal."
    read -erp "If 64bit is unsupported, please type \"UNSUPPORTED\": " DOWNLOAD64
    # If a download was entered, check regex for proper format. If it is not
    # seen as valid, prompt them to enter the same download a second time to
    # override the regex. If 64bit is unsupported, prompt user to enter that.
    # If no download is entered, assume the script does not require a special
    # download for 64bit.
    if [ -n "${DOWNLOAD64}" ]; then
      # If website was detected as invalid, but the user enters it a second
      # time, override the regex and save the homepage
      # Also break if UNSUPPORTED
      if [ "$ORIGLINK" == "$DOWNLOAD64" ] || [ "$DOWNLOAD" == "UNSUPPORTED" ]; then
        break
      # If homepage is set, verify it is a valid address with regex
      elif [[ ! ${DOWNLOAD64} =~ ${DOWNEX}${REGEX} ]] || [ ! "$DOWNLOAD64" == "UNSUPPORTED" ] ; then
        echo -e "\nERROR: Download doesn't seem to be a valid link. Please try again."
        echo -e "If it is valid, enter the same link again to override."
        ORIGLINK="$DOWNLOAD64"
      # Otherwise keep the homepage entered and move on
      else
        break
      fi
    # If nothing was entered, exit the loop
    else
      break
    fi
  done

  # Prompt for 64bit md5sum
  if [ -n "$DOWNLOAD64" ] && [ "$DOWNLOAD64" != "UNSUPPORTED" ]; then
    echo -e "\nEnter md5sum for 64bit source."
    read -erp "Leave blank to have it auto-generated: " MD5SUM64
  fi

  # Enter any dependencies
  read -erp "Please enter any required dependencies (otherwise leave blank): " REQUIRES

  # Prompt for SRCNAM -- needed for perl SlackBuilds
  if [ "$SCRIPTNUM" -ne "4" ]; then
    read -erp "Set separate source name (SRCNAM) variable (otherwise leave blank): " SETSRCNAM
  else
    echo -e "\nPerl scripts set SRCNAM automatically by removing the \"perl-\" from the PRGNAM."
    echo "Leaving this to the defaults would have SRCNAM be \"$(printf $PRGNAM | cut -d- -f2-)\"."
    read -erp "Leave blank unless you want to override: " SETSRCNAM
    SRCorPRG="SRCNAM"
  fi

  # Prompt for SRCVER
  read -erp "Set separate source version (SRCVER) variable (otherwise leave blank): " SETSRCVER

  # Try and keep the short description within the length of the handy ruler
  while true; do

    # Prep some variables for our sanity checks and make sure they didn't add
    # a closing parenthesis that shouldn't be there
    if [ -n "$SHORTDESC" ]; then
      SHORTLENGTH="$(( ${#PRGNAM} + ${#SHORTDESC} ))"
      OPENPAREN="${SHORTDESC//[^(]}"
      CLOSEPAREN="${SHORTDESC//[^)]}"
      # If there are fewer opening parenthesis than closing and the last character
      # is a closing parenthesis, remove it
      if [ "${#OPENPAREN}" -lt "${#CLOSEPAREN}" ] && [ "${SHORTDESC: -1}" == ")" ]; then
        SHORTDESC="${SHORTDESC:: -1}"
      fi
    fi

    # If not already set, prompt for short description in slack-desc
    if [ -z "$SHORTDESC" ] && [ -z "$LOOP" ]; then
      read -erp "Set short description for slack-desc (otherwise leave blank): " SHORTDESC
      LOOP=yes
    # If it is set, check and see if it is too long for the slack-desc
    elif [ "$SHORTLENGTH" -gt "67" ]; then
      echo "Short description is too long."
      # Display the "handy ruler" to better show size requirements
      echo "|-----handy-ruler------------------------------------------------------|"
      echo ": $PRGNAM ($SHORTDESC)"
      echo "Please try again (leave off the closing parenthesis)"
      read -erp ": $PRGNAM (" SHORTDESC

    # Otherwise exit the loop
    else
      unset LOOP
      break
    fi
  done

  # Prompt to see if they'd like to add a long description later
  echo -e "\nWould you like to enter the long description for slack-desc?"
  read -erp "If yes, this will be prompted for later: y/N " answer
  # If it's a yes, set LONGDESC
  if /usr/bin/grep -qi "y" <<< "$answer"; then
    LONGDESC=yes
  fi

  # Give us a blank line
  echo
fi

# Set up SRCNAM if used
if [ -n "$SETSRCNAM" ] && [ "$SCRIPTNUM" -ne "4" ]; then
  SRCorPRG="SRCNAM"
# Perl scripts are unique in determining SRCNAM automatically.
# If a user manually set SRCNAM, ask them if they're sure they want to use it
elif [ -n "$SETSRCNAM" ] && [ "$SCRIPTNUM" -eq "4" ]; then
  echo "Perl scripts set SRCNAM automatically by removing the \"perl-\" from the PRGNAM."
  echo "You manually specified $SETSRCNAM when the script would set it to $(printf $PRGNAM | cut -d- -f2-)."
  read -erp "Would you like to keep your manually set name? y/N " answer
  # If it's a yes, set SRCorPRG
  if /usr/bin/grep -qi "y" <<< "$answer"; then
    SRCorPRG="SRCNAM"
  else
    SETSRCNAM=
    SRCorPRG="PRGNAM"
  fi
# If SETSRCNAM is not set for perl scripts, default to auto-setting it
elif [ -z $SETSRCNAM ] && [ "$SCRIPTNUM" -eq "4" ]; then
  SRCorPRG="SRCNAM"
# Otherwise assume they don't need SRCNAM
else
  SRCorPRG="PRGNAM"
fi

# Set up SRCVER if used
if [ -n "$SETSRCVER" ]; then
  SRCorVER="SRCVER"
else
  SRCorVER="VERSION"
fi

function SBintro() {

  mkdir -p $SBOUTPUT

  # Let's create the copyright header
  cat << EOF > ${SBOUTPUT}/$PRGNAM.SlackBuild
#!/bin/bash

# Slackware build script for $PRGNAM

# Copyright $YEAR $NAME $EMAIL
# All rights reserved.
#
# Redistribution and use of this script, with or without modification, is
# permitted provided that the following conditions are met:
#
# 1. Redistributions of this script must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
#  THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED
#  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO
#  EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
#  OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
#  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
#  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
#  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
EOF

  # Now we'll set up the section for variables, extracting the source, and
  # changing permissions.

  cat << EOF >> ${SBOUTPUT}/$PRGNAM.SlackBuild
cd \$(dirname \$0) ; CWD=\$(pwd)

PRGNAM=$PRGNAM
VERSION=\${VERSION:-$VERSION}
EOF

  # Add SRCNAM and SRCVER if set
  if [ -n "$SETSRCNAM" ]; then
    echo "SRCNAM=\${SRCNAM:-$SETSRCNAM}" >> ${SBOUTPUT}/$PRGNAM.SlackBuild
  fi
  if [ -n "$SETSRCVER" ]; then
    echo "SRCVER=\${SRCVER:-$SETSRCVER}" >> ${SBOUTPUT}/$PRGNAM.SlackBuild
  fi

  # Resume some more
  cat << EOF >> ${SBOUTPUT}/$PRGNAM.SlackBuild
BUILD=\${BUILD:-1}
TAG=\${TAG:-_SBo}
PKGTYPE=\${PKGTYPE:-tgz}

EOF

# Add SRCNAM for perl scripts per the perl template
if [ "$SCRIPTNUM" -eq "4" ] && [ -z "$SETSRCNAM" ]; then
  echo -e "SRCNAM=\"\$(printf \$PRGNAM | cut -d- -f2-)\"\n" >> ${SBOUTPUT}/$PRGNAM.SlackBuild
fi

  # Resume the rest
  cat << EOF >> ${SBOUTPUT}/$PRGNAM.SlackBuild
if [ -z "\$ARCH" ]; then
  case "\$( uname -m )" in
    i?86) ARCH=i586 ;;
    arm*) ARCH=arm ;;
       *) ARCH=\$( uname -m ) ;;
  esac
fi

if [ ! -z "\${PRINT_PACKAGE_NAME}" ]; then
  echo "\$PRGNAM-\$VERSION-\$ARCH-\$BUILD\$TAG.\$PKGTYPE"
  exit 0
fi

TMP=\${TMP:-/tmp/SBo}
PKG=\$TMP/package-\$PRGNAM
OUTPUT=\${OUTPUT:-/tmp}

if [ "\$ARCH" = "i586" ]; then
  SLKCFLAGS="-O2 -march=i586 -mtune=i686"
  LIBDIRSUFFIX=""
elif [ "\$ARCH" = "i686" ]; then
  SLKCFLAGS="-O2 -march=i686 -mtune=i686"
  LIBDIRSUFFIX=""
elif [ "\$ARCH" = "x86_64" ]; then
  SLKCFLAGS="-O2 -fPIC"
  LIBDIRSUFFIX="64"
else
  SLKCFLAGS="-O2"
  LIBDIRSUFFIX=""
fi

set -e

rm -rf \$PKG
mkdir -p \$TMP \$PKG \$OUTPUT
cd \$TMP
EOF
}

# Extract section with optional SRCNAM and SRCVER support
function SBextract() {
  cat << EOF >> ${SBOUTPUT}/$PRGNAM.SlackBuild
rm -rf \$${SRCorPRG}-\$${SRCorVER}
tar xvf \$CWD/\$${SRCorPRG}-\$${SRCorVER}.tar.gz
cd \$${SRCorPRG}-\$${SRCorVER}
chown -R root:root .
find -L . \\
 \\( -perm 777 -o -perm 775 -o -perm 750 -o -perm 711 -o -perm 555 \\
  -o -perm 511 \\) -exec chmod 755 {} \\; -o \\
 \\( -perm 666 -o -perm 664 -o -perm 640 -o -perm 600 -o -perm 444 \\
  -o -perm 440 -o -perm 400 \\) -exec chmod 644 {} \\;

EOF
}

# 2179 autotools scripts
function SBautotools() {
  cat << EOF >> ${SBOUTPUT}/$PRGNAM.SlackBuild
CFLAGS="\$SLKCFLAGS" \\
CXXFLAGS="\$SLKCFLAGS" \\
./configure \\
  --prefix=/usr \\
  --libdir=/usr/lib\${LIBDIRSUFFIX} \\
  --sysconfdir=/etc \\
  --localstatedir=/var \\
  --mandir=/usr/man \\
  --docdir=/usr/doc/\$PRGNAM-\$VERSION \\
  --disable-static \\
  --build=\$ARCH-slackware-linux

make
make install DESTDIR=\$PKG

rm -f \$PKG/{,usr/}lib\${LIBDIRSUFFIX}/*.la

EOF
}

# 848 python scripts
function SBpython () {
  # This will automatically add python3 support. Please remove it if you don't want it.
  cat << EOF >> ${SBOUTPUT}/$PRGNAM.SlackBuild
# For python2
python2 setup.py install --root=\$PKG

# For python3
python3 setup.py install --root=\$PKG

# For no setup.py (requires python3-build as dependency)
python3 -m build --wheel --no-isolation
python3 -m installer --destdir=\$PKG dist/*.whl

EOF
}

#578 cmake scripts
function SBcmake () {
  cat << EOF >> ${SBOUTPUT}/$PRGNAM.SlackBuild
mkdir -p build
cd build
  cmake \\
    -DCMAKE_C_FLAGS:STRING="\$SLKCFLAGS" \\
    -DCMAKE_CXX_FLAGS:STRING="\$SLKCFLAGS" \\
    -DCMAKE_INSTALL_PREFIX=/usr \\
    -DLIB_SUFFIX=\${LIBDIRSUFFIX} \\
    -DMAN_INSTALL_DIR=/usr/man \\
    -DCMAKE_BUILD_TYPE=Release ..
  make
  make install/strip DESTDIR=\$PKG
cd ..

rm -f \$PKG/{,usr/}lib\${LIBDIRSUFFIX}/*.la

EOF
}

# 58 meson scripts
function SBmeson () {
  cat << EOF >> ${SBOUTPUT}/$PRGNAM.SlackBuild
mkdir build
cd build
  CFLAGS="\$SLKCFLAGS" \\
  CXXFLAGS="\$SLKCFLAGS" \\
  meson .. \\
    --buildtype=release \\
    --infodir=/usr/info \\
    --libdir=/usr/lib\${LIBDIRSUFFIX} \\
    --localstatedir=/var \\
    --mandir=/usr/man \\
    --prefix=/usr \\
    --sysconfdir=/etc \\
    -Dstrip=true
  "\${NINJA:=ninja}"
  DESTDIR=\$PKG \$NINJA install
cd ..

rm -f \$PKG/{,usr/}lib\${LIBDIRSUFFIX}/*.la

EOF
}

# 551 perl scripts
function SBperl () {
  cat << EOF >> ${SBOUTPUT}/$PRGNAM.SlackBuild
# Build method #1 (preferred)
perl Makefile.PL \\
  PREFIX=/usr \\
  INSTALLDIRS=vendor \\
  INSTALLVENDORMAN1DIR=/usr/man/man1 \\
  INSTALLVENDORMAN3DIR=/usr/man/man3
make
make test
make install DESTDIR=\$PKG

# Build method #2
# requires perl-Module-Build or perl-Module-Build-Tiny
perl Build.PL \\
  --installdirs vendor \\
  --config installvendorman1dir=/usr/man/man1 \\
  --config installvendorman3dir=/usr/man/man3
./Build
./Build test
./Build install \\
  --destdir \$PKG

EOF
}

# 328 haskell scripts
function SBhaskell () {
  cat << EOF >> ${SBOUTPUT}/$PRGNAM.SlackBuild
CFLAGS="\$SLKCFLAGS" \\
CXXFLAGS="\$SLKCFLAGS" \\
runghc Setup configure \\
  --prefix=/usr \\
  --libdir=/usr/lib\${LIBDIRSUFFIX} \\
  --libsubdir=ghc-\${GHC_VERSION}/\$SRCNAM-$VERSION \\
  --enable-shared \\
  --enable-library-profiling \\
  --docdir=/usr/doc/\$PRGNAM-\$VERSION

runghc Setup build
runghc Setup haddock
runghc Setup copy --destdir=\$PKG
runghc Setup register --gen-pkg-config

PKGCONFD=/usr/lib\${LIBDIRSUFFIX}/ghc-\${GHC_VERSION}/package.conf.d
PKGID=\$( grep -E "^id: " \$SRCNAM-\$VERSION.conf | cut -d" " -f2 )
mkdir -p \$PKG/\$PKGCONFD
mv \$SRCNAM-\$VERSION.conf \$PKG/\$PKGCONFD/\$PKGID.conf

EOF
}

# 91 ruby scripts
function SBruby () {
  cat << EOF >> ${SBOUTPUT}/$PRGNAM.SlackBuild

DESTDIR=\$( ruby -r rbconfig -e '
include RbConfig
printf("%s/%s/gems/%s\n",
        CONFIG["libdir"],
        CONFIG["RUBY_INSTALL_NAME"],
        CONFIG["ruby_version"]
      )
')

gem specification \$CWD/\$SRCNAM-\$VERSION.gem | \\
        ruby -r yaml -r rbconfig -e '
c = RbConfig::CONFIG
path = sprintf("%s/%s/gems/%s",
        c["libdir"],
        c["RUBY_INSTALL_NAME"],
        c["ruby_version"])
sys_gemspecs = Dir.glob(path + "/specifications/**/*.gemspec").map {|g| gs = Gem::Specification.load(g); gs.name }
obj = Gem::Specification.from_yaml(\$stdin)
obj.dependencies.each {|dep|
        if not(dep.type == :runtime)
                next
        end
        if not(sys_gemspecs.include?(dep.name))
                \$stderr.write("WARNING: #{dep.name} gem not found\n")
                sleep 0.5
        end

}'

gem install \\
        --local \\
        --no-update-sources \\
        --ignore-dependencies \\
        --backtrace \\
        --install-dir \$PKG/\$DESTDIR \\
        --bindir \$PKG/usr/bin \\
        \$CWD/\$SRCNAM-\$VERSION.gem

find \$PKG -print0 | xargs -0 file | grep -e "executable" -e "shared object" | grep ELF \\
  | cut -f 1 -d : | xargs strip --strip-unneeded 2> /dev/null || true

mkdir -p \$PKG/usr/doc/\$PRGNAM-\$VERSION
tar -x -O --file=\$CWD/\$SRCNAM-\$VERSION.gem data.tar.gz \\
  | tar -xz -C \$PKG/usr/doc/\$PRGNAM-\$VERSION --file=- \\
  <documentation>
cat \$CWD/\$PRGNAM.SlackBuild > \$PKG/usr/doc/\$PRGNAM-\$VERSION/\$PRGNAM.SlackBuild

EOF
}

function SBstrip_docs() {
  cat << EOF >> ${SBOUTPUT}/$PRGNAM.SlackBuild
find \$PKG -print0 | xargs -0 file | grep -e "executable" -e "shared object" | grep ELF \\
  | cut -f 1 -d : | xargs strip --strip-unneeded 2> /dev/null || true

find \$PKG/usr/man -type f -exec gzip -9 {} \\;
for i in \$( find \$PKG/usr/man -type l ) ; do ln -s \$( readlink $i ).gz \$i.gz ; rm \$i ; done

rm -f \$PKG/usr/info/dir
gzip -9 \$PKG/usr/info/*.info*

find \$PKG -name perllocal.pod -o -name ".packlist" -o -name "*.bs" | xargs rm -f || true

mkdir -p \$PKG/usr/doc/\$PRGNAM-\$VERSION
cp -a \\
  <documentation> \\
  \$PKG/usr/doc/\$PRGNAM-\$VERSION
cat \$CWD/\$PRGNAM.SlackBuild > \$PKG/usr/doc/\$PRGNAM-\$VERSION/\$PRGNAM.SlackBuild

EOF
}

function SBclosing() {
  cat << EOF >> ${SBOUTPUT}/$PRGNAM.SlackBuild
mkdir -p \$PKG/install
cat \$CWD/slack-desc > \$PKG/install/slack-desc
cat \$CWD/doinst.sh > \$PKG/install/doinst.sh

cd \$PKG
/sbin/makepkg -l y -c n \$OUTPUT/\$PRGNAM-\$VERSION-\$ARCH-\$BUILD\$TAG.\$PKGTYPE
EOF

echo "Created ${SBOUTPUT}/${PRGNAM}.SlackBuild"
}

# Try to correct for weird download links (github and pypi, I'm looking at you)
function check_download() {

  TESTURL="$1"
  DOMAIN="$(echo "$TESTURL" | cut -d"/" -f 3)"

  # If SRCNAM/SRCVER are not set, set them to PRGNAM/VERSION to simplify URLs
  if [ -z "$SETSRCNAM" ]; then
    SETSRCNAM="$PRGNAM"
  fi
  if [ -z "$SETSRCVER" ]; then
    SETSRCVER="$VERSION"
  fi

  # Let's first prep github addresses
  if [ "$DOMAIN" == "github.com" ]; then
    OWNER=$(echo "$TESTURL" | cut -d"/" -f4)
    PROJECT=$(echo "$TESTURL" | cut -d"/" -f5)

    # Determine whether it's a commit or normal version
    # Need to use bash's double brackets to support regex to catch commits
    if [[ "$VERSION" =~ ^[a-fA-F0-9]{7}$ ]]; then
      NEWURL="https://$DOMAIN/$OWNER/$PROJECT/archive/$VERSION/$SETSRCNAM-$SETSRCVER.tar.gz"
    # Catch for releases, which can't use TAGVER in the else statement
    elif [[ "$(echo $TESTURL | cut -d"/" -f6)" == "releases" ]]; then
      NEWURL="$TESTURL"
    else
      # Extract the version from the URL to get the right tag
      # (many include "v" in front of the version, v1.2.3 instead of just 1.2.3)
      TAGVER=$(basename "$TESTURL" | rev | cut -d. -f3- | rev)
      NEWURL="https://$DOMAIN/$OWNER/$PROJECT/archive/refs/tags/$TAGVER/$SETSRCNAM-$SETSRCVER.tar.gz"
    fi

  # If we're using a hashed python.org link, switch to a proper versioned link
  elif [ "$DOMAIN" == "files.pythonhosted.org" ] || [ "$DOMAIN" == "pypi.python.org" ]; then
    if [ "$(echo "$TESTURL" | cut -d"/" -f7 )" == "61" ]; then
      NEWURL="https://files.pythonhosted.org/packages/source/${SETSRCNAM::1}/${SETSRCNAM}/${SETSRCNAM}-${SETSRCVER}.tar.gz"
    else
      NEWURL="$TESTURL"
    fi

  # Anything else, just ignore it.
  # Can add future catches if needed
  else
    NEWURL="$TESTURL"
  fi
  echo "$NEWURL"
}

function info() {

# Check for 32bit/universal download and update md5sum
if [ -n "$DOWNLOAD" ] && [ -z $MD5SUM ]; then

  # Make sure we're using the best download address
  DOWNLOAD="$(check_download $DOWNLOAD)"
  # Download the source and save it in the SlackBuild directory
  echo "Downloading 32bit/universal source:"
  if ! wget -qP $SBOUTPUT/ $DOWNLOAD; then
    echo "Download for $DOWNLOAD failed. Please check link and update manually."
  else
    echo "Generating MD5SUM"
    MD5SUM="$(md5sum "${SBOUTPUT}/$(basename "$DOWNLOAD")" | cut -d" " -f1)"
  fi
fi

# Check for 64bit download and update md5sum
if [ -n "$DOWNLOAD64" ] && [ -z $MD5SUM64 ]; then

  # Make sure we're using the best download address
  DOWNLOAD64="$(check_download $DOWNLOAD64)"
  # Download the source and save it in the SlackBuild directory
  echo "Downloading 64bit source:"
  if ! wget -qP $SBOUTPUT/ $DOWNLOAD64; then
    echo "64bit download for $DOWNLOAD64 failed. Please check link and update manually."
  else
    echo "Generating MD5SUM"
    MD5SUM64="$(md5sum "${SBOUTPUT}/$(basename "$DOWNLOAD64")" | cut -d" " -f1)"
  fi
fi

  cat << EOF > ${SBOUTPUT}/$PRGNAM.info
PRGNAM="$PRGNAM"
VERSION="$VERSION"
HOMEPAGE="$HOMEPAGE"
DOWNLOAD="$DOWNLOAD"
MD5SUM="$MD5SUM"
DOWNLOAD_x86_64="$DOWNLOAD64"
MD5SUM_x86_64="$MD5SUM64"
REQUIRES="$REQUIRES"
MAINTAINER="$NAME"
EMAIL="$EMAIL"
EOF

echo "Created ${SBOUTPUT}/${PRGNAM}.info"
}

function gen_slackdesc() {
  # Get PRGNAM's character count so we can pad the handy ruler
  PADNUM=${#PRGNAM}
  PADDING=$(printf "%*s%s" $PADNUM)

  # Set default short description if not set above
  SHORTDESC=${SHORTDESC:-"short description of app"}

  # Check to see if the short description made it too long
  if [ $(( ${#PRGNAM} + ${#SHORTDESC} )) -gt "67" ]; then
    echo -e "\n\t=======================================================================\n"
    echo -e "\tWARNING: The \"$SHORTDESC\" short description is too long.\n"
    echo -e "\tPlease edit slack-desc/README manually.\n"
    echo -e "\t=======================================================================\n"
    sleep 2
  fi

  # If $LONGDESC is yes, then let's prep it to be put in the slack-desc and README
  if [ "$LONGDESC" == "yes" ]; then

    # Prompt for the text
    echo "Prompting for long description in slack-desc..."
    echo "Please paste the text here followed by 'enter' and Ctrl+d: "
    # Bring in the text with fmt and shrink it to 71 characters per line, use sed to remove
    # and extra line breaks, and then use sed again to add $PRGNAM in front
    LONGDESC="$(fmt -w 71 | sed -e :a -e '/^\n*$/{$d;N;};/\n$/ba' | sed "s|^|$PRGNAM: |g")"
    # Remove the trailing space if the line is empty
    LONGDESC=$(echo "$LONGDESC" | sed "s|^$PRGNAM: $|$PRGNAM:|g")
    LINECNT=$(echo "$LONGDESC" | wc -l)

    # Give us a blank line
    echo

  # If $LONGDESC is blank, then let's add enough entries to put the HOMEPAGE
  # on the second to last line of the slack-desc (purely cosmetic placement)
  else
    until [ "$LINECNT" -eq "6" ]; do
      LONGDESC=$(echo -e "$LONGDESC\n$PRGNAM:")
      LINECNT=$(echo "$LONGDESC" | wc -l)
    done
  fi

  # Add the homepage if there's enough room
  if [ "$LINECNT" -lt "8" ] && [ -n "${HOMEPAGE}" ] && [ "${#HOMEPAGE}" -lt "62" ]; then
    LONGDESC=$(echo -e "$LONGDESC\n$PRGNAM:\n$PRGNAM: HOMEPAGE: $HOMEPAGE")
    LINECNT=$(echo "$LONGDESC" | wc -l)
  fi

  # Finish off the slack-desc if required
  until [ "$LINECNT" -eq "9" ]; do
    # Throw a warning if slack-desc ends up too long and tell them to fix it manually.
    if [ "$LINECNT" -gt "9" ]; then
      echo -e "\nWARNING: The long description was too long. slack-desc has $(($LINECNT-9)) line(s)"
      echo -e "too many. Please manually correct slack-desc before building software.\n"
      break
    fi
    LONGDESC=$(echo -e "$LONGDESC\n$PRGNAM:")
    LINECNT=$(echo "$LONGDESC" | wc -l)
  done

  cat << EOF > ${SBOUTPUT}/slack-desc
# HOW TO EDIT THIS FILE:
# The "handy ruler" below makes it easier to edit a package description.
# Line up the first '|' above the ':' following the base package name, and
# the '|' on the right side marks the last column you can put a character in.
# You must make exactly 11 lines for the formatting to be correct.  It's also
# customary to leave one space after the ':' except on otherwise blank lines.

$PADDING|-----handy-ruler------------------------------------------------------|
$PRGNAM: $PRGNAM ($SHORTDESC)
$PRGNAM:
$LONGDESC
EOF

  echo "Created ${SBOUTPUT}/slack-desc"

  # Let's cheat and copy the use the slack-desc for the base README
  tail -n 11 ${SBOUTPUT}/slack-desc | sed "s/$PRGNAM: //g" | sed "s/$PRGNAM://g" > ${SBOUTPUT}/README

  # Remove the HOMEPAGE line if it exists
  sed -i '/HOMEPAGE: /d' ${SBOUTPUT}/README

  # Delete all trailing blank lines at end of README
  # http://sed.sourceforge.net/sed1line.txt
  sed -i -e :a -e '/^\n*$/{$d;N;};/\n$/ba' ${SBOUTPUT}/README

  echo "Created ${SBOUTPUT}/README"
}

function other() {
  echo -e "# Use this for manually creating package\n" >> ${SBOUTPUT}/$PRGNAM.SlackBuild
}

SBintro
case $SCRIPTNUM in
  1 ) SBextract; SBautotools; SBstrip_docs
      ;;
  2 ) SBextract; SBpython; SBstrip_docs
      ;;
  3 ) SBextract; SBcmake; SBstrip_docs
      ;;
  4 ) SBextract; SBperl; SBstrip_docs
      ;;
  5 ) SBextract; SBhaskell; SBstrip_docs
      ;;
  6 ) SBruby
      ;;
  7 ) SBextract; SBmeson; SBstrip_docs
      ;;
  8 ) SBextract; other; SBstrip_docs
      ;;
  * ) echo -e "\n\tERROR: Invalid script type\n"; help; exit
esac
SBclosing
info
gen_slackdesc
