#!/usr/bin/env bash
# vim: set fdm=marker:

# @hide
declare -A __INPUT

# Sets up a new input box. Corresponds to the --inputbox & --passwordbox arguments in Dialog/Whiptail.
# Also performs the actual drawing of the input box.
function input() { # {{{
    if [ $# -eq 1 ] && [ "$1" = 'help' ]; then
        __input_help
        return 0
    fi

    # Clean up the old input box
    __INPUT=(
        ['type']='input'
        ['value']=''
    )

    local -a l_box_args
    local l_param l_value
    while [ $# -gt 0 ]; do
        l_param="${1%%=*}"
        l_value="${1#*=}"
        case "$l_param" in
            type) __input_get_type "$l_value";;
            value) __INPUT["$l_param"]="$l_value";;
            *) l_box_args+=("$1")
        esac
        local l_code=$?
        if [ $l_code -gt 0 ]; then
            exit $l_code
        fi
        shift
    done

    __box "${__INPUT['type']?}" "${l_box_args[@]}"
    __box_set_dump_callback '__input_dump_callback'
    __box_draw "${__INPUT['value']?}"
} # }}}

# Helper to get the type of the input box with validation.
# @hide
function __input_get_type() { # {{{
    local -A l_input_types=(['text']='input' ['password']='password')
    local l_value="${1?}"
    if [ ! "${l_input_types["$l_value"]+xyz}" ]; then
        __panic "input: Unrecognized input type: $l_value. Possible types: ${!l_input_types[*]}"
    fi
    __INPUT['type']="${l_input_types["$l_value"]}"
}
readonly -f __input_get_type
# }}}

# @hide
function __input_dump_callback() { # {{{
    echo 'INPUT {'
        __pretty_print_array __INPUT | __treeify 2 0
    echo '}'
}
readonly -f __input_dump_callback
# }}}
