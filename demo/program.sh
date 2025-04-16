#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

# This demo box is part of the main menu, so we'll use it's menu entry title for all boxes
config title="$1"

{
    echo 1+2=$((1+2)); sleep .3
    echo 'Example message printed to stderr' >&2; sleep .3
    for i in {1..20}; do
        echo "Example long scrolling output (line $i)"; sleep .05
    done
    printf 'Done'
} 2>&1 | program \
    text='Display the output of a command using a pipe' \
    width=75% \
    height=75%

# The same can be achieved using 'command' option
# program width=75% height=75% command="$(cat << EOL
#   echo 1+2=\$((1+2)); sleep .3
#   echo 'Example message printed to stderr' >&2; sleep .3
#   for i in \$(seq 1  20); do
#       echo "Example long scrolling output (line \$i)"; sleep .05
#   done
#   printf 'Done'
# EOL
# )"
