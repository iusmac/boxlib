#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

info \
    title='Example info box' \
    text='Wait for 2s for the screen to be cleared...' \
    sleep=2
