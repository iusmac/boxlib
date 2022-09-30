#!/usr/bin/env bash

# @hide
declare -A __BOOLS=(['true']='true' ['1']='true' ['false']='false' ['0']='false')
# @hide
readonly -a \
    __ALPHA_CHARSET=({a..z}) \
    __ALPHANUM0_CHARSET=({0..9} {a..z}) \
    __ALPHANUM1_CHARSET=({1..9} 0 {a..z})

function __panic() {
    printf "Panic: %s\nStacktrace:\n" "${1?}"
    local i l_stack_depth="$((${#FUNCNAME[@]} - 1))"
    for ((i = 1; i <= l_stack_depth; ++i)); do
        printf "    at %s() at line %d in file %s\n" \
            "${FUNCNAME[i]}" ${BASH_LINENO[i-1]} "${BASH_SOURCE[i]}"
    done
    exit 1
} >&2

function __assert_bool() {
    case "${1?}" in
        1|0|true|false) return 0
    esac
    __panic "${FUNCNAME[1]}: Invalid boolean value: $1. Expected: ${!__BOOLS[*]}"
}

function __set_shell_exit_code() {
    return "${1?}"
}

function __create_temp_file() {
    mktemp -t 'boxlib.XXXXXX' 2>/dev/null || mktemp
}

function __create_fifo_file() {
    local l_temp; l_temp="$(__create_temp_file)"
    rm "$l_temp"
    mkfifo -m 0600 "$l_temp"
    echo "$l_temp"
}

function __trim_decimals() {
    local l_value="${1?}"
    l_value="${l_value//,/.}"
    echo "${l_value%%.*}"
}

function __scale_value() {
    local l_scale="${1?}"
    local l_value="${2?}"
    if [ "${l_scale: -1}" = '%' ]; then
        l_scale="${l_scale::-1}"
    fi
    l_scale="$(__trim_decimals "$l_scale")" || return $?
    l_value="$(__trim_decimals "$l_value")" || return $?
    echo $((l_value * l_scale / 100))
}

function __treeify() {
    local l_depth=$((${1?} - 1)) l_line l_prefix
    local -i l_use_guide_lines="${2:-1}"
    if [ $l_depth -gt 0 ]; then
        local l_guide_line=' '
        if [ $l_use_guide_lines -eq 1 ]; then
            l_guide_line='│'
        fi
        printf -v l_prefix "$l_guide_line %.0s" $(seq $l_depth)
    fi
    while IFS= read -r -d$'\n' l_line; do
        printf '%s' "$l_prefix"
        if [ $l_use_guide_lines -eq 1 ]; then
            if [ -n "$l_line" ] && [ "${l_line::1}" != ' ' ]; then
                printf '├─'
            else
                printf '│'
            fi
        fi
        printf "%s\n" "$l_line"
    done
}

function __find_default_editor() {
    if command -v sensible-editor >/dev/null; then
        echo 'sensible-editor'
    elif [ -n "${EDITOR:-}" ]; then
        echo "$EDITOR"
    elif [ -n "${VISUAL:-}" ]; then
        echo "$VISUAL"
    elif command -v nano >/dev/null; then
        echo 'nano'
    elif command -v nano-tiny >/dev/null; then
        echo 'nano-tiny'
    else
        echo 'vi'
    fi
}

function __whiptail_to_dialog_code() {
    case "${1?}" in
        0) return "${DIALOG_OK:-0}";;
        1) return "${DIALOG_CANCEL:-1}";;
        255) return "${DIALOG_ESC:-255}";;
    esac
    return "${1?}"
}

# Count the number of lines in a string with 'wc' command.
# Takes into the account both the literal '\n' and newline byte (0x0a).
function __count_lines() {
    wc -l <<< "${1//\\n/$'\n'}"
}

# Pretty print indexed and associative arrays.
# $1 - array reference name
function __pretty_print_array() {
    local -n l_array_ref="${1?}"
    local l_fmt_str
    if [ ${#l_array_ref[@]} -gt 0 ]; then
        printf -v l_fmt_str '"%s"="%%s"\n' "${!l_array_ref[@]}"
        # shellcheck disable=2059
        printf "$l_fmt_str" "${l_array_ref[@]}"
    fi
}
