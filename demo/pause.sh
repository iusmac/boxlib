#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

pause \
    title='Example pause box' \
    text='Continue?' \
    seconds=3
