#!/usr/bin/env bash
# vim: set fdm=marker:

# Sets up a new confirm box. Corresponds to the --yesno argument in Dialog/Whiptail.
# Also performs the actual drawing of the confirm box.
function confirm() { # {{{
    if [ $# -eq 1 ] && [ "$1" = 'help' ]; then
        __confirm_help
        return 0
    fi

    __box 'confirm' "$@"
    __box_draw
} # }}}
