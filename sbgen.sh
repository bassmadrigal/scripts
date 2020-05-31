#!/bin/bash
#
# Copyright 2017-2020 Jeremy Hansen <jebrhansen -at- gmail.com>
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
# v0.1 - Initial release

# ===========================================================================
# User configurable settings. Add your information here or override when
# running the script.
NAME=${NAME:-Your name}
EMAIL=${EMAIL:-Your email}
YEAR=${YEAR:-$(date +%Y)}
# Location for your SlackBuild repo
SBLOC=${SBLOC:-./slackbuilds}

# ===========================================================================

function help() {
  cat <<EOH
-- Usage:
   $(basename $0) [options] <1-7> <program_name> <version> [category]

-- Option parameters:
   -h :    This help.
   -f :    Force overwriting existing directory
   -w :    Set the homepage (website)
   -d :    Set the download location
   -m :    Set the md5sum
   -D :    Set the 64bit download
   -M :    Set the 64bit md5sum
   -r :    Set the REQUIRES for required dependencies
             (Multiples REQUIRES need to be enclosed in quotes)

-- Description:
   This script requires passing at least the number corresponding to script
   type (see below), the program name and the program version.
   You can optionally pass the homepage, download, md5sum, x86_64-download,
   x86_64-md5sum and any required dependencies.

   If you want it placed in a certain subfolder under your SlackBuilds
   directory, pass that "category". They don't have to correspond with SBo's
   categories as this is only local.

-- Script types:
   1 : AutoTools (./configure && make && make install)
   2 : Python (python setup.py install)
   3 : CMake (mkdir build && cd build && cmake ..)
   4 : Perl (perl Makefile.PL)
   5 : Haskell (runghc Setup Configure)
   6 : RubyGem (gem specification && gem install)
   7 : Other (Used for manually specifying "build" process)

   (This list is sorted based on the frequency in SBo's 14.2 repo.)

EOH
}

# Option parsing:
while getopts "hfw:d:m:D:M:r:" OPTION
do
  case $OPTION in
    h ) help; exit
        ;;
    f ) FORCE=yes
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
    * ) help; exit
        ;;
  esac
done
shift $(($OPTIND - 1))

# Display the help and exit if nothing is passed
if [ $# -eq 0 ]; then
  help
  exit 1
fi

# Error out if three arguments aren't passed
if [ -z $1 ] || [ -z $2 ] || [ -z $3 ]; then
  echo -e "\n\tERROR: You must pass the script type, program name, and version.\n"
  help
  exit
elif ! [[ $1 =~ [1-7] ]]; then
  echo -e "\n\tERROR: Invalid script type\n"; help; exit
fi

# Set the program name and version
PRGNAM=$2
VERSION=$3
CATEGORY="$4"
SBOUTPUT="${SBLOC}/${CATEGORY}/${PRGNAM}"

function SBintro() {
  # Let's not overwrite an existing folder unless it is forced
  if [ -e $SBOUTPUT ] && [ "${FORCE:-no}" != "yes" ]; then
    echo "$SBOUTPUT already exists. To overwrite, use $(basename $0) -f"
    exit 1
  fi

  mkdir -p $SBOUTPUT

  # Let's create the copyright header
  cat << EOF > $SBOUTPUT/$PRGNAM.SlackBuild
#!/bin/sh

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

  cat << EOF >> $SBOUTPUT/$PRGNAM.SlackBuild
PRGNAM=\${PRGNAM:-$PRGNAM}
VERSION=\${VERSION:-$VERSION}
BUILD=\${BUILD:-1}
TAG=\${TAG:-_SBo}

if [ -z "\$ARCH" ]; then
  case "\$( uname -m )" in
    i?86) ARCH=i586 ;;
    arm*) ARCH=arm ;;
    *) ARCH=\$( uname -m ) ;;
  esac
fi

CWD=\$(pwd)
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

function SBextract() {
  cat << EOF >> $SBOUTPUT/$PRGNAM.SlackBuild
rm -rf \$PRGNAM-\$VERSION
tar xvf \$CWD/\$PRGNAM-\$VERSION.tar.gz
cd \$PRGNAM-\$VERSION
chown -R root:root .
find -L . \\
 \\( -perm 777 -o -perm 775 -o -perm 750 -o -perm 711 -o -perm 555 \\
  -o -perm 511 \\) -exec chmod 755 {} \\; -o \\
 \\( -perm 666 -o -perm 664 -o -perm 640 -o -perm 600 -o -perm 444 \\
  -o -perm 440 -o -perm 400 \\) -exec chmod 644 {} \\;

EOF
}

function SBautotools() {
  cat << EOF >> $SBOUTPUT/$PRGNAM.SlackBuild
CFLAGS="\$SLKCFLAGS" \\
CXXFLAGS="\$SLKCFLAGS" \\
./configure \\
  --prefix=/usr \\
  --libdir=/usr/lib\${LIBDIRSUFFIX} \\
  --sysconfdir=/etc \\
  --localstatedir=/var \\
  --mandir=/usr/man \\
  --docdir=/usr/doc/\$PRGNAM-\$VERSION \\
  --build=\$ARCH-slackware-linux

make
make install DESTDIR=\$PKG

EOF
}

function SBpython () {
  # This will automatically add python3 support. Please remove it if you don't want it.
  cat << EOF >> $SBOUTPUT/$PRGNAM.SlackBuild
python setup.py install --root=\$PKG

# Install python3 if detected. Override with PYTHON3=no.
if $(python3 -c 'import sys' 2>/dev/null) && [ "\${PYTHON3:-yes}" == "yes" ]; then
  python3 setup.py install --root=\$PKG
fi

EOF
}

function SBcmake () {
  cat << EOF >> $SBOUTPUT/$PRGNAM.SlackBuild
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
  make install DESTDIR=\$PKG
cd ..

EOF
}

function SBperl () {
  cat << EOF >> $SBOUTPUT/$PRGNAM.SlackBuild
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

function SBhaskell () {
  cat << EOF >> $SBOUTPUT/$PRGNAM.SlackBuild
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

function SBruby () {
  cat << EOF >> $SBOUTPUT/$PRGNAM.SlackBuild

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
obj = Gem::Specification.from_yaml($stdin)
obj.dependencies.each {|dep|
        if not(dep.type == :runtime)
                next
        end
        if not(sys_gemspecs.include?(dep.name))
                $stderr.write("WARNING: #{dep.name} gem not found\n")
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
  cat << EOF >> $SBOUTPUT/$PRGNAM.SlackBuild
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
  cat << EOF >> $SBOUTPUT/$PRGNAM.SlackBuild
mkdir -p \$PKG/install
cat \$CWD/slack-desc > \$PKG/install/slack-desc
cat \$CWD/doinst.sh > \$PKG/install/doinst.sh

cd \$PKG
/sbin/makepkg -l y -c n \$OUTPUT/\$PRGNAM-\$VERSION-\$ARCH-\$BUILD\$TAG.\${PKGTYPE:-tgz}
EOF

echo "${SBOUTPUT}/${PRGNAM}.SlackBuild was created"
}

function info() {
  cat << EOF > $SBOUTPUT/$PRGNAM.info
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

echo "${SBOUTPUT}/${PRGNAM}.info was created"
}

function slack-desc() {
  # Get PRGNAM's character count so we can pad the handy ruler
  PADNUM=${#PRGNAM}
  PADDING=$(printf "%*s%s" $PADNUM)

  cat << EOF > $SBOUTPUT/slack-desc
# HOW TO EDIT THIS FILE:
# The "handy ruler" below makes it easier to edit a package description.
# Line up the first '|' above the ':' following the base package name, and
# the '|' on the right side marks the last column you can put a character in.
# You must make exactly 11 lines for the formatting to be correct.  It's also
# customary to leave one space after the ':' except on otherwise blank lines.

$PADDING|-----handy-ruler------------------------------------------------------|
$PRGNAM: $PRGNAM (short description of app)
$PRGNAM:
$PRGNAM:
$PRGNAM:
$PRGNAM:
$PRGNAM:
$PRGNAM:
$PRGNAM:
$PRGNAM:
$PRGNAM:
$PRGNAM:
EOF

  echo "${SBOUTPUT}/slack-desc was created"

  # Let's cheat and copy the use the slack-desc for the base README
  tail -n 11 $SBOUTPUT/slack-desc | sed "s/$PRGNAM://g" > $SBOUTPUT/README

  echo "${SBOUTPUT}/README was created"
}

function other() {
  echo -e "# Use this for manually creating package\n" >> $SBOUTPUT/$PRGNAM.SlackBuild
}

SBintro
case $1 in
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
  7 ) SBextract; other; SBstrip_docs
      ;;
  * ) echo -e "\n\tERROR: Invalid script type\n"; help; exit
esac
SBclosing
info
slack-desc
