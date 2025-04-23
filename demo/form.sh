#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

# This demo box is part of the main menu, so we'll use it's menu entry title for all boxes
config title="$1"

function form_handler() {
    text title='Registration form result' text="$(cat <<- EOL
		First Name       = ${1:-<unset>}
		Last Name        = ${2:-<unset>}
		Address          = ${3:-<unset>}
		Contact Number   = ${4:-<unset>}
		Birth Date       = ${5:-<unset>}
		Gender           = ${6:-<unset>}
		Place Of Birth   = ${7:-<unset>}
		Nationality      = ${8:-<unset>}
		Username         = ${9:-<unset>}
		Email            = ${10:-<unset>}
		Password         = ${11:-<unset>}
		Confirm Password = ${12:-<unset>}
		EOL
    )"
}

form \
    text="Please, complete the registration form or press ESC to exit.\n" \
    text+="Hint: Use up/down arrows (or control/N, control/P) to move between fields." \
    columns=2 \
    fieldWidth=15 \
    fieldMaxLength=30 \
    callback='form_handler()'

formField title='First Name'
formField title='Last Name'

formField title='Address'
formField title='Contact Number'

formField title='Birth Date' maxlength=10
formField title='Gender' maxlength=10

formField title='Place Of Birth'
formField title='Nationality'

formField title='Username' value="$USER"
formField title='E-Mail'

formField type='hidden' title='Password'
formField type='hidden' title='Confirm Password'

formDraw
