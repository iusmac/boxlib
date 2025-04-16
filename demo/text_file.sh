#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

# This demo box is part of the main menu, so we'll use it's menu entry title for all boxes
config title="$1"

# Display the contents of the current file in the text box. We keep the
# scrollbar enabled if the terminal height is too small to fit the contents
text file="$ROOT/${BASH_SOURCE[0]##*/}" scrollbar='true'
