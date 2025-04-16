#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

# Display the contents of the current file in the text box. We keep the
# scrollbar enabled if the terminal height is too small to fit the contents
text \
    title='Example text box' \
    file="$ROOT/${BASH_SOURCE[0]##*/}" \
    scrollbar='true'
