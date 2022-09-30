#!/usr/bin/env bash
# vim: set fdm=marker:

# @hide
declare -A __PAUSE
# @hide
readonly -a __PAUSE_BAR_CHARSET=(
    # characters used to fill the 'remaining' value of the bar (range 0-9)
    '░' '░' '░' '░' '░' '░' '░' '░' '░' '░'
    # characters used to fill the background track of the bar (range 10-19)
    '▓' '▓' '▓' '▓' '▓' '▓' '▓' '▓' '▓' '▓'
)

# Sets up a new pause box. Corresponds to the --pause argument in Dialog.
# In whpitail, this feature is emulated using a menu box.
# Also performs the actual drawing of the pause box.
function pause() { # {{{
    if [ $# -eq 1 ] && [ "$1" = 'help' ]; then
        __pause_help
        return 0
    fi

    # Clean up the old pause box
    __PAUSE=(
        ['remaining']=0
    )

    local -a l_box_args
    local l_param l_value l_loop='false' l_code
    while [ $# -gt 0 ]; do
        l_param="${1%%=*}"
        l_value="${1#*=}"
        case "$l_param" in
            timeout) : Ignored;;
            seconds) __PAUSE['seconds']="$(__trim_decimals "$l_value")";;
            loop) __assert_bool "$l_value" && l_loop="${__BOOLS["$l_value"]?}";;
            *) l_box_args+=("$1")
        esac
        l_code=$?
        if [ $l_code -gt 0 ]; then
            exit $l_code
        fi
        shift
    done

    if [ ! ${__PAUSE['seconds']+xyz} ]; then
        __panic "pause: Missing 'seconds' option."
    fi
    if ! [ "${__PAUSE['seconds']?}" -ge 0 ]; then
        __panic "pause: Invalid seconds value: ${__PAUSE['seconds']?}"
    fi

    if config isDialogRenderer >/dev/null; then
        __box 'pause' loop="$l_loop" "${l_box_args[@]}"
        __box_set_dump_callback '__pause_dump_callback'
        __box_draw "${__PAUSE['seconds']?}"
    else
        l_box_args+=(\( --notags \))
        local l_rc l_offset=10 l_bar l_ifs_copy="$IFS" l_seconds=${__PAUSE['seconds']?}
        while :; do
            for ((__PAUSE['remaining'] = l_seconds; __PAUSE['remaining'] >= 0; __PAUSE['remaining']--)); do
                __box 'menu' timeout=1 "${l_box_args[@]}"
                __box_set_dump_callback '__pause_dump_callback'
                __box_set_result_validation_callback '__pause_menu_result_validation_callback'
                __box_set_capture_renderer_code_callback '__pause_menu_capture_renderer_code_callback'
                # The box will exit with code 255 on timeout, but the pause box is an exception
                __box_set_default_renderer_code_on_timeout "${DIALOG_OK:-0}"

                # Build a bar/meter indicating how many seconds remain until the end of the pause.
                # To do so, we use the sliding window technique with a fixed size of 10 characters,
                # (1 character every 10%). The 0-9 range in the charset represent the 'remaining'
                # percentage, while the 10-19 range represent "empty" blocks needed to fill the
                # 'background' track of the bar, as we slide to the right
                if [ "$l_seconds" -gt 0 ]; then
                    l_offset=$((10 - __PAUSE['remaining'] * 10 / l_seconds))
                fi
                IFS='' l_bar="${__PAUSE_BAR_CHARSET[*]:l_offset:10}" IFS="$l_ifs_copy"

                # The menu tag is set to an empty string to propagate nothing to the user's callback
                # when selected directly or via OK button. The menu item will display the actual
                # bar/meter and the remaining seconds
                __box_draw 0 '' "$l_bar ${__PAUSE['remaining']?} "; l_rc=$?

                if [ "${__PAUSE['renderer-code']?}" -gt 128 ] && [ "${__PAUSE['renderer-code']?}" -lt 255 ]; then
                    # Killed on timeout
                    continue
                fi
                break
            done
            # Prevent the menu box from looping, if needed
            if [ "${__PAUSE['remaining']?}" -lt 0 ]; then # Timed out
                if [ "$l_loop" != 'true' ]; then
                    break
                fi
            elif [ "${__PAUSE['renderer-code']?}" -gt 0 ] || [ "$l_loop" != 'true' ]; then
                break
            fi
        done
        return $l_rc
    fi
} # }}}

# @hide
function __pause_menu_result_validation_callback() { # {{{
    local l_code=$?
    if [ $l_code -gt 128 ] && [ $l_code -lt 255 ]; then # Killed on timeout
        if [ "${__PAUSE['remaining']?}" -gt 0 ]; then
            # The pause hasn't yet ended, so we must not propagate the result to the user's callback
            return "$__BOX_VALIDATION_CALLBACK_BREAK"
        fi
    fi
    # We propagate the box exit code when menu entry was selected, an OK/Cancel/ESC button was
    # pressed, or we reached the end of the pause
    return "$__BOX_VALIDATION_CALLBACK_PROPAGATE"
}
readonly -f __pause_menu_result_validation_callback
# }}}

# @hide
function __pause_menu_capture_renderer_code_callback() { # {{{
    __PAUSE['renderer-code']="${1?}"
}
readonly -f __pause_menu_capture_renderer_code_callback
# }}}

# @hide
function __pause_dump_callback() { # {{{
    echo 'PAUSE {'
        __pretty_print_array __PAUSE | __treeify 2 0
    echo '}'
}
readonly -f __pause_dump_callback
# }}}
