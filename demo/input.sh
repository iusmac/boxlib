#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

if input=$(input \
    title='Example input box' \
    text='Please, press Enter to continue, or ESC exit' \
    value='Hello ')
then
    text \
        title='Input result' \
        text="Your input is ${#input} characters long. The input was:\n$input"
fi
