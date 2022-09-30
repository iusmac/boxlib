#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

# Force Whiptail as renderer
[ "${1:-}" = '1' ] && config rendererName='whiptail' rendererPath='whiptail'

config headerTitle='Example project'

menu \
    title='Example main menu' \
    text='Please, select an option or press ESC to exit' \
    cancelLabel='Exit' \
    prefix='alphanum' \
    loop='true'

menuEntry \
    title='Example build list' \
    summary='Select me to show a build list' \
    callback="$ROOT/buildlist.sh"

menuEntry \
    title='Example calendar box' \
    summary='Select me to show a calendar box' \
    callback="$ROOT/calendar.sh"

menuEntry \
    title='Example check list' \
    summary='Select me to jump to a check list' \
    callback="$ROOT/checklist.sh"

menuEntry \
    title='Example confirm box' \
    summary='Select me to show a confirm box' \
    callback="$ROOT/confirm.sh"

menuEntry \
    title='Example file edit box' \
    summary='Select me to show a file edit box' \
    callback="$ROOT/edit.sh"

menuEntry \
    title='Example form box' \
    summary='Select me to show a form box' \
    callback="$ROOT/form.sh"

menuEntry \
    title='Example file selector box' \
    summary='Select me to show a file selector box' \
    callback="$ROOT/selector.sh"

menuEntry \
    title='Example info box' \
    summary='Select me to show an info box' \
    callback="$ROOT/info.sh"

menuEntry \
    title='Example input box' \
    summary='Select me to show an input box' \
    callback="$ROOT/input.sh"

menuEntry \
    title='Example input menu box' \
    summary='Select me to jump to an input menu' \
    callback="$ROOT/inputmenu.sh"

menuEntry \
    title='Example menu box' \
    summary='Select me to jump to a submenu' \
    callback="$ROOT/menu.sh"

menuEntry \
    title='Example mixed progress box' \
    summary='Select me to start a mixed progress box' \
    callback="$ROOT/mixedprogress.sh"

menuEntry \
    title='Example password box' \
    summary='Select me to show a password box' \
    callback="$ROOT/password.sh"

menuEntry \
    title='Example pause box' \
    summary='Select me to show a pause box' \
    callback="$ROOT/pause.sh"

menuEntry \
    title='Example program box' \
    summary='Select me to start a program box' \
    callback="$ROOT/program.sh"

menuEntry \
    title='Example progress box' \
    summary='Select me to start a progress box' \
    callback="$ROOT/progress.sh"

menuEntry \
    title='Example radio list' \
    summary='Select me to jump to a radio list' \
    callback="$ROOT/radiolist.sh"

menuEntry \
    title='Example range box' \
    summary='Select me to jump to a range box' \
    callback="$ROOT/range.sh"

menuEntry \
    title='Example text box' \
    summary='Select me to show a text box' \
    callback="$ROOT/text.sh"

menuEntry \
    title='Example text file box' \
    summary='Select me to show a text file box' \
    callback="$ROOT/text_file.sh"

menuEntry \
    title='Example text file follow box' \
    summary='Select me to show a text file follow box' \
    callback="$ROOT/text_file_follow.sh"

menuEntry \
    title='Example time picker box' \
    summary='Select me to show a time picker box' \
    callback="$ROOT/timepicker.sh"

menuEntry \
    title='Example treelist box' \
    summary='Select me to show a treelist box' \
    callback="$ROOT/treelist.sh"

menuDraw
