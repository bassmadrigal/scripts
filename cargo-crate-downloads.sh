#!/bin/bash

# Copyright 2026  Jeremy Hansen <jebrhansen -at- gmail.com>
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

# This script will parse the Cargo.lock file and generate a DOWNLOAD list to
# add to the .info, a crate.list of all crates (that will be used in the
# SlackBuild), and the required code to add to the SlackBuild to use local
# sources.

# -----------------------------------------------------------------------------

# Source the .info file to get the required info
. $(basename "$PWD").info

# Get the filename of the first DOWNLOAD so we can check if it's already there.
# If it isn't, download it.
SRCFILE=$(echo ${DOWNLOAD%% *} | rev | cut -d/ -f1 | rev)
if [ ! -f "$SRCFILE" ]; then
  wget ${DOWNLOAD%% *}
fi

tar -xf $SRCFILE

# Since PRGNAM doesn't always match the SRCNAM
cd $(echo $SRCFILE | rev| cut -d- -f2- | rev)-$VERSION

# Run some python code to parse the Cargo.lock and generate a list of URLS
# for each required crate.
URLS=$(python3 <<'EOP'
import tomli

with open("Cargo.lock", "rb") as f:
    data = tomli.load(f)

urls = set()

for pkg in data["package"]:
    src = pkg.get("source", "")
    if "crates.io" in src:
        name = pkg["name"]
        version = pkg["version"]
        urls.add(f"https://static.crates.io/crates/{name}/{name}-{version}.crate")

for url in sorted(urls):
    print(url)

EOP
)

cd ..

# Display download links with spacing and backslashes
# (Make sure to remove the last on and add an end quote)
URLCNT=$(echo "$URLS" | wc -l)
COUNT=0
for i in $URLS; do
  ((COUNT++))
  if [ "$COUNT" -lt "$URLCNT" ]; then
    echo "          $i \\"
  else
    echo "          $i\""
  fi
done

# Display the names and versions of each crate to add to the
# SlackBuild for proper sourcing
echo "Creating crate.list to be parsed by the SlackBuild."
for URL in $URLS; do
  FILE="${URL##*/}"
  CRATENAM=$(basename "$(dirname "$URL")")
  CRATEVER="${FILE#${CRATENAM}-}"
  CRATEVER="${CRATEVER%.crate}"
  echo "$CRATENAM $CRATEVER"
done > crate.list

echo "Ensure the following is in the SlackBuild after you cd into the source"
echo "directory but before the chown command so it can process the crates."
echo "+------------------------------cut below------------------------------+"
cat <<'EOL'

# Prepare the crates for offline usage
mkdir -p vendor .cargo
echo "[patch.crates-io]" >> Cargo.toml

while read -r CRATENAME CRATEVER; do
  mkdir -p "vendor/${CRATENAME}-${CRATEVER}"
  tar xf "$CWD/${CRATENAME}-${CRATEVER}.crate" \
    --strip-components=1 \
    -C "vendor/${CRATENAME}-${CRATEVER}/"
  echo "$CRATENAME = { path = \"vendor/${CRATENAME}-${CRATEVER}\" }" >> Cargo.toml
done < "$CWD/crate.list"

# Create a config.toml that forces using local versions in vendor/
cat <<'EOF' > .cargo/config.toml

[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "vendor"
EOF
export CARGO_NET_OFFLINE=true
EOL
echo "+------------------------------cut above------------------------------+"

rm -r $(echo $SRCFILE | rev| cut -d- -f2- | rev)-$VERSION
