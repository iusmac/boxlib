#!/usr/bin/env bash
# vim: set fdm=marker:

# @hide
declare -A __RANGEBOX

# Sets up a new range box. Corresponds to the --rangebox argument in Dialog.
# In Whiptail, this feature is emulated using an input field with validation.
# Also performs the actual drawing of the range box.
function range() { # {{{
    if [ $# -eq 1 ] && [ "$1" = 'help' ]; then
        __range_help
        return 0
    fi

    # Clean up the old range box
    __RANGEBOX=(
        ['min']=0
        ['max']=0
    )

    local -a l_box_args
    local -n l_min=__RANGEBOX['min'] l_max=__RANGEBOX['max'] l_def=__RANGEBOX['default']
    local l_param l_text=''
    while [ $# -gt 0 ]; do
        l_param="${1%%=*}"
        value="${1#*=}"
        case "$l_param" in
            min|max|default) __RANGEBOX["$l_param"]="$(__trim_decimals "$value")";;
            text) l_text="$value";;
            *) l_box_args+=("$1")
        esac
        local l_code=$?
        if [ $l_code -gt 0 ]; then
            exit $l_code
        fi
        shift
    done

    # Default equals to min when unset
    if [ ! ${l_def+xyz} ]; then
        l_def=${l_min?}
    fi

    # Check if all are valid numbers
    local l_type
    for l_type in min max default; do
        if ! __range_is_number "${__RANGEBOX[$l_type]?}"; then
            __panic "range: Invalid '$l_type' value: '${__RANGEBOX[$l_type]?}'"
        fi
    done

    if config isDialogRenderer >/dev/null; then
        __box 'range' text="$l_text" "${l_box_args[@]}"
        __box_set_dump_callback '__range_dump_callback'
        __box_draw "${l_min?}" "${l_max?}" "${l_def?}"
    else
        # Clamp the range values as in Dialog
        [ "${l_max?}" -lt "${l_min?}" ] && l_max=${l_min?}
        [ "${l_def?}" -gt "${l_max?}" ] && l_def=${l_max?}
        [ "${l_def?}" -lt "${l_min?}" ] && l_def=${l_min?}

        # Show the current range limits hint in the box's text region
        if [ -n "$l_text" ]; then
            l_text+="\n"
        fi
        l_text+="min: ${l_min?}; max: ${l_max?}"

        __box 'input' text="$l_text" "${l_box_args[@]}"
        __box_set_dump_callback '__range_dump_callback'
        __box_set_result_validation_callback '__range_input_result_validation_callback'
        __box_draw "${l_def?}"
    fi
} # }}}

# @hide
function __range_input_result_validation_callback() { # {{{
    if [ $? -eq 0 ]; then
        local l_min=${__RANGEBOX['min']?} l_value="${1:-}" l_max=${__RANGEBOX['max']?}
        if ! __range_is_number "$l_value" || [ "$l_value" -lt "$l_min" ] ||
            [ "$l_value" -gt "$l_max" ]; then
            return "$__BOX_VALIDATION_CALLBACK_RETRY"
        fi
    fi
    return "$__BOX_VALIDATION_CALLBACK_PROPAGATE"
}
readonly -f __range_input_result_validation_callback
# }}}

# @hide
function __range_is_number() { # {{{
    [[ $1 =~ ^-?[0-9]+$ ]]
}
readonly -f __range_is_number
# }}}

# @hide
function __range_dump_callback() { # {{{
    echo 'RANGEBOX {'
        __pretty_print_array __RANGEBOX | __treeify 2 0
    echo '}'
}
readonly -f __range_dump_callback
# }}}
