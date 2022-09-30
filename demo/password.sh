#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

# Force Whiptail as renderer
[ "${1:-}" = '1' ] && config rendererName='whiptail' rendererPath='whiptail'

function input_handler()  {
    # Capture the status code from the input box
    local status=$?
    if [ $status -gt 0 ]; then # ESC (#255) or Cancel (#1) button pressed
        return $status
    fi
    # Exit with zero code to loop the input box again if the password is not
    # supplied or shorter than 4 chars
    if [ $# -eq 0 ] || [ ${#1} -lt 4 ]; then
        return 0
    fi
    # Print the password and exit with a non-zero code in order to stop looping
    # the input box
    echo "$1"
    return 5
}

password="$(input \
    type='password' \
    title='Example input password box' \
    text='Please, insert at least 4 characters to continue, or press ESC exit' \
    callback='input_handler()' \
    abortOnCallbackFailure='true' \
    loop='true')"
if [ $? -eq 5 ]; then
    text title='Result' text="Your password is: $password"
fi
