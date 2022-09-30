#!/usr/bin/env bash
# vim: set fdm=marker:

# @hide
declare -A __CALENDAR

# Sets up a new calendar box. Corresponds to the --calendar argument in Dialog.
# In Whiptail, this feature is emulated using an input field with validation.
# Also performs the actual drawing of the calendar box.
function calendar() { # {{{
    if [ $# -eq 1 ] && [ "$1" = 'help' ]; then
        __calendar_help
        return 0
    fi

    # Clean up the old calendar box
    __CALENDAR=(
        ['dateFormat']='%d/%m/%Y'
        ['forceInputBox']='false'
    )

    local -a l_box_args
    local l_param l_value
    while [ $# -gt 0 ]; do
        if [ "$1" = '--date-format' ]; then
            __CALENDAR['dateFormat']="${2?}"
            shift 2
            continue
        fi
        l_param="${1%%=*}"
        l_value="${1#*=}"
        case "$l_param" in
            day|month|year|dateFormat) __CALENDAR["$l_param"]="$l_value";;
            forceInputBox) __assert_bool "$l_value" && __CALENDAR["$l_param"]="${__BOOLS["$l_value"]?}";;
            *) l_box_args+=("$1")
        esac
        local l_code=$?
        if [ $l_code -gt 0 ]; then
            exit $l_code
        fi
        shift
    done

    if [ "${__CALENDAR['day']:-0}" -eq 0 ]; then
        __CALENDAR['day']="$(date +%d)"
    fi
    if [ "${__CALENDAR['month']:-0}" -eq 0 ]; then
        __CALENDAR['month']="$(date +%m)"
    fi
    if [ "${__CALENDAR['year']:-0}" -eq 0 ]; then
        __CALENDAR['year']="$(date +%Y)"
    fi

    local l_date="${__CALENDAR['day']?}/${__CALENDAR['month']?}/${__CALENDAR['year']?}"
    if ! __calendar_validate_date "$l_date"; then
        __panic "calendar: Invalid date or format (expected: dd/mm/yyyy): $l_date"
    fi

    if [ "${__CALENDAR['forceInputBox']?}" != 'true' ] && config isDialogRenderer >/dev/null; then
        l_box_args+=(\( --date-format "${__CALENDAR['dateFormat']?}" \))
        __box 'calendar' "${l_box_args[@]}"
        __box_set_dump_callback '__calendar_dump_callback'
        __box_draw "${__CALENDAR['day']?}" "${__CALENDAR['month']?}" "${__CALENDAR['year']?}"
    else
        __box 'input' "${l_box_args[@]}"
        __box_set_dump_callback '__calendar_dump_callback'
        __box_set_result_validation_callback '__calendar_input_result_validation_callback'
        __box_set_preprocess_result_callback '__calendar_input_preprocess_result_callback'
        __box_draw "$l_date"
    fi
} # }}}

# @hide
function __calendar_validate_date() { # {{{
    # Ensure if we get the input date in format dd/mm/yyyy or d/m/yyyy
    if ! [[ $1 =~ ^([0-9]{1,2})/([0-9]{1,2})/([0-9]{4})$ ]]; then
        return 1
    fi
    local l_outputFormat='%d/%m/%Y' \
        day="${BASH_REMATCH[1]?}" month="${BASH_REMATCH[2]?}" year="${BASH_REMATCH[3]?}"
    # Validate the input against the expected output format using date command from GNU coreutils or
    # fallback to the *BSD variant
    if ! date -d "$year-$month-$day" "+$l_outputFormat"; then
        local l_result
        if l_result="$(date -j -f "$l_outputFormat" "$1" "+$l_outputFormat")"; then
            # Canonicalize day & month from input to two-digit value format (d/m/yyyy => dd/mm/yyyy)
            printf -v day '%.2d' "${day#0}"
            printf -v month '%.2d' "${month#0}"
            # This additional check is needed for *BSD-derived implementation of the date command in
            # macOS, which is a bit lenient ;). See the following edge cases when formatting dates:
            #   1. Input: 00/04/2025 (where day is 00); Output: 31/03/2025 (March 31, 2025)
            #   2. Input: 31/04/2025 (where day is 31); Output: 01/05/2025 (May 1, 2025)
            # In the first case, the date command "underflows" the date with a nonexistent day "00"
            # to the last date of the previous month, and in the second case, it "overflows" the
            # date with a nonexistent day "31" (as April has only 30 days) to the first date of the
            # next month
            if [ "$l_result" = "$day/$month/$year" ]; then
                return 0
            fi
        fi
        return 1
    fi &>/dev/null
    return 0
}
readonly -f __calendar_validate_date
# }}}

# @hide
function __calendar_input_result_validation_callback() { # {{{
    if [ $? -eq 0 ]; then
        __calendar_validate_date "${1:-}" || return "$__BOX_VALIDATION_CALLBACK_RETRY"
    fi
    return "$__BOX_VALIDATION_CALLBACK_PROPAGATE"
}
readonly -f __calendar_input_result_validation_callback
# }}}

# @hide
function __calendar_input_preprocess_result_callback() { # {{{
    local l_input="${1?}" l_outputFormat="${__CALENDAR['dateFormat']?}" l_day l_month l_year
    IFS='/' read -r l_day l_month l_year <<< "$l_input"
    # Format using date from GNU coreutils or fallback to the *BSD variant
    if ! date -d"$l_year/$l_month/$l_day" "+$l_outputFormat"; then
        date -j -f '%d/%m/%Y' "$l_input" "+$l_outputFormat"
    fi 2>/dev/null
}
readonly -f __calendar_input_preprocess_result_callback
# }}}

# @hide
function __calendar_dump_callback() { # {{{
    echo 'CALENDAR {'
        __pretty_print_array __CALENDAR | __treeify 2 0
    echo '}'
}
readonly -f __calendar_dump_callback
# }}}
