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

# With my workflow, git branches can sometimes pile up. At some point, I'd
# like to prune them from my computer and server. I typically hand jam a for
# loop, but in the past 5 days, I've generated 23 branches for updates to SBo.
# I've been meaning to make this for a while, but finally decided to do it.

# Set the default branch to make sure it's never deleted
DEF_BRANCH=master

# Exit the script if we're not in a git repo
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "ERROR: $(pwd) is not a working git repo."
  exit 1
fi

# Let's set some colors
YELLOW='\033[0;33m'
RESET='\033[0m' # Reset color

# Check if we are in the default branch and if not, switch
# We don't want to be in a branch that is trying to be deleted
if [ "$(git rev-parse --abbrev-ref HEAD)" != "$DEF_BRANCH" ]; then
  echo -e "${YELLOW}NOTE:${RESET} Switching to default branch, $DEF_BRANCH, to prevent deletion issues."
  git checkout "$DEF_BRANCH"
fi

# Find out if we should remove all or some
echo "The following are all the branches except your default branch, $DEF_BRANCH:"
git branch --format="%(refname:short)" | grep -v "$DEF_BRANCH"
read -erp "Are there any of these branches that should NOT be deleted? y/N " answer
if /usr/bin/grep -qi "y" <<< "$answer"; then
  read -erp "Please enter branches you'd like to keep separated by a space: " KEEP_BRANCH
fi

# Store all saved (HALLELUJAH!) branches in one variable
KEEP_BRANCH="$DEF_BRANCH $KEEP_BRANCH"

# Work through all the branches
for CUR_BRANCH in $(git for-each-ref --format='%(refname:short)' refs/heads/); do

  # Find out if the branch matches ones we want to keep
  for SKIP_BRANCH in $KEEP_BRANCH; do
    if [ "$CUR_BRANCH" == "$SKIP_BRANCH" ]; then
      # Pass the skip variable since this for loop is nested in another
      SKIP=yes
      continue
    fi
  done

  # Skip branches we want to keep
  if [ "$SKIP" == "yes" ]; then
    unset SKIP
    continue
  fi

  # Now to delete the branch locally
  git branch -D "$CUR_BRANCH"
  # Check if the branch is on the server and, if so, delete it too. Without
  # this check, the output of the command is really ugly if there isn't a
  # remote branch to delete.
  # This is also much, much faster than the oft suggested `git ls-remote` to
  # see if there is a remote branch.
  if git branch -a | grep -q remotes/origin/"$CUR_BRANCH"$; then
    git push -f origin :"$CUR_BRANCH"
  fi

done
