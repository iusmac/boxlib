#!/usr/bin/env bash
# vim: set fdm=marker:

# @hide
declare -A __TIMEPICKER

# Sets up a new time picker box. Corresponds to the --timebox argument in Dialog.
# In Whiptail, this feature is emulated using an input field with validation.
# Also performs the actual drawing of the time picker box.
function timepicker() { # {{{
    if [ $# -eq 1 ] && [ "$1" = 'help' ]; then
        __timepicker_help
        return 0
    fi

    # Clean up the old time picker box
    __TIMEPICKER=(
        ['timeFormat']='%H:%M:%S'
        ['forceInputBox']='false'
    )

    local -a l_box_args
    local l_param l_value
    while [ $# -gt 0 ]; do
        if [ "$1" = '--time-format' ]; then
            __TIMEPICKER['timeFormat']="${2?}"
            shift 2
            continue
        fi
        l_param="${1%%=*}"
        l_value="${1#*=}"
        case "$l_param" in
            hour|minute|second|timeFormat) __TIMEPICKER["$l_param"]="$l_value";;
            forceInputBox) __assert_bool "$l_value" && __TIMEPICKER["$l_param"]="${__BOOLS["$l_value"]?}";;
            *) l_box_args+=("$1")
        esac
        local l_code=$?
        if [ $l_code -gt 0 ]; then
            exit $l_code
        fi
        shift
    done

    if [ "${__TIMEPICKER['hour']:--1}" -lt 0 ]; then
        __TIMEPICKER['hour']="$(date +%H)"
    fi
    if [ "${__TIMEPICKER['minute']:--1}" -lt 0 ]; then
        __TIMEPICKER['minute']="$(date +%M)"
    fi
    if [ "${__TIMEPICKER['second']:--1}" -lt 0 ]; then
        __TIMEPICKER['second']="$(date +%S)"
    fi

    local l_time="${__TIMEPICKER['hour']?}:${__TIMEPICKER['minute']?}:${__TIMEPICKER['second']?}" \
        l_time_valid_code
    __timepicker_validate_time "$l_time"; l_time_valid_code=$?
    if [ $l_time_valid_code -gt 0 ]; then
        __panic "timepicker: Invalid time or format (expected: hour:minute:second): $l_time"
    fi

    if [ "${__TIMEPICKER['forceInputBox']?}" != 'true' ] && config isDialogRenderer >/dev/null; then
        l_box_args+=(\( --time-format "${__TIMEPICKER['timeFormat']?}" \))
        __box 'timepicker' "${l_box_args[@]}"
        __box_set_dump_callback '__timepicker_dump_callback'
        __box_draw "${__TIMEPICKER['hour']?}" "${__TIMEPICKER['minute']?}" "${__TIMEPICKER['second']?}"
    else
        __box 'input' "${l_box_args[@]}"
        __box_set_dump_callback '__timepicker_dump_callback'
        __box_set_result_validation_callback '__timepicker_input_result_validation_callback'
        __box_set_preprocess_result_callback '__timepicker_input_preprocess_result_callback'
        __box_draw "$l_time"
    fi
} # }}}

# @hide
function __timepicker_validate_time() { # {{{
    if [[ $1 =~ ^([0-9]{1,2}):([0-9]{1,2}):([0-9]{1,2})$ ]]; then
        local l_hour="${BASH_REMATCH[1]?}" l_minute="${BASH_REMATCH[2]?}" \
            l_second="${BASH_REMATCH[3]?}"
        if [ "$l_hour" -lt 0 ] || [ "$l_hour" -gt 23 ] ||
            [ "$l_minute" -lt 0 ] || [ "$l_minute" -gt 59 ] ||
            [ "$l_second" -lt 0 ] || [ "$l_second" -gt 59 ]; then
            return 1
        fi
        return 0
    fi
    return 1
}
readonly -f __timepicker_validate_time
# }}}

# @hide
function __timepicker_input_result_validation_callback() { # {{{
    if [ $? -eq 0 ]; then
        __timepicker_validate_time "${1:-}" || return "$__BOX_VALIDATION_CALLBACK_RETRY"
    fi
    return "$__BOX_VALIDATION_CALLBACK_PROPAGATE"
}
readonly -f __timepicker_input_result_validation_callback
# }}}

# @hide
function __timepicker_input_preprocess_result_callback() { # {{{
    local l_input="${1?}" l_outputFormat="${__TIMEPICKER['timeFormat']?}"
    # Format time using date from GNU coreutils or fallback to the *BSD variant
    if ! date -d"$l_input" "+$l_outputFormat"; then
        date -j -f '%H:%M:%S' "$l_input" "+$l_outputFormat"
    fi 2>/dev/null
}
readonly -f __timepicker_input_preprocess_result_callback
# }}}

# @hide
function __timepicker_dump_callback() { # {{{
    echo '_TIMEPICKER {'
        __pretty_print_array __TIMEPICKER | __treeify 2 0
    echo '}'
}
readonly -f __timepicker_dump_callback
# }}}
