#!/usr/bin/env bash
# vim: set fdm=marker:

# @hide
declare -A __INFO

# Sets up a new info box. Corresponds to the --infobox argument in Dialog/Whiptail.
# Also performs the actual drawing of the info box.
function info() { # {{{
    if [ $# -eq 1 ] && [ "$1" = 'help' ]; then
        __info_help
        return 0
    fi

    # Clean up the old info box
    __INFO=()

    local -a l_box_args
    if ! config isDialogRenderer >/dev/null; then
        case "$TERM" in
            # whiptail fails to render info box in an xterm (i.e., gnome-terminal). So, we'll use
            # 'linux' terminfo instead to render boxes, which fully supports ncurses.
            # Ref: https://bugs.launchpad.net/ubuntu/+source/newt/+bug/604212
            xterm*|*-256color) l_box_args+=('term=linux');;
            screen) l_box_args+=('term=linux');; # Same issue with 'screen' terminfo...
        esac
    else
        case "$TERM" in
            # On some distro, Dialog suffers the same issue as whiptail when rendering in Tmux
            tmux-256color) l_box_args+=('term=linux');;
        esac
    fi

    local l_param l_value l_code
    while [ $# -gt 0 ]; do
        l_param="${1%%=*}"
        l_value="${1#*=}"
        case "$l_param" in
            clear) __assert_bool "$l_value" && __INFO["$l_param"]="${__BOOLS["$l_value"]?}";;
            timeout) : Ignored;;
            sleep) [ ${__INFO['clear']+xyz} ] || __INFO['clear']='true';&
            *) l_box_args+=("$1")
        esac
        l_code=$?
        if [ $l_code -gt 0 ]; then
            exit $l_code
        fi
        shift
    done

    __box 'info' "${l_box_args[@]}"
    __box_set_dump_callback '__info_dump_callback'
    __box_draw; l_code=$?

    if [ "${__INFO['clear']:-}" = 'true' ]; then
        clear
    fi

    return $l_code
} # }}}

# @hide
function __info_dump_callback() { # {{{
    echo 'INFO {'
        __pretty_print_array __INFO | __treeify 2 0
    echo '}'
}
readonly -f __info_dump_callback
# }}}
