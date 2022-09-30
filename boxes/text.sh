#!/usr/bin/env bash
# vim: set fdm=marker:

# @hide
declare -A __TEXTBOX
# @hide
readonly __TEXT_PRESS_ENTER_MSG='Press [ENTER] to exit...'

# Sets up a new text box. Corresponds to the --msgbox, --textbox & --tailbox arguments
# in Dialog/Whiptail.
# In Whiptail, the tailbox feature is emulated using a program box.
# Also performs the actual drawing of the text box.
function text() { # {{{
    if [ $# -eq 1 ] && [ "$1" = 'help' ]; then
        __text_help
        return 0
    fi

    # Clean up the old text box
    __TEXTBOX=(
        ['type']='message'
        ['text']=''
        ['follow']='false'
        ['inBackground']='false'
    )

    local -a l_box_args l_box_size=(0 0)
    local l_param l_value l_callback=''
    while [ $# -gt 0 ]; do
        l_param="${1%%=*}"
        l_value="${1#*=}"
        case "$l_param" in
            text) __TEXTBOX["$l_param"]="$l_value";;
            callback) l_callback="$l_value";;
            file)
                __TEXTBOX['type']='text'
                __TEXTBOX["$l_param"]="$l_value"
                ;;
            follow|inBackground)
                __assert_bool "$l_value" && __TEXTBOX["$l_param"]="${__BOOLS["$l_value"]?}"
                ;;
            *)
                [ "$l_param" = 'height' ] && l_box_size[0]="$l_value"
                [ "$l_param" = 'width' ] && l_box_size[1]="$l_value"
                l_box_args+=("$1")
        esac
        local l_code=$?
        if [ $l_code -gt 0 ]; then
            exit $l_code
        fi
        shift
    done

    if [ "${__TEXTBOX['follow']?}" = 'true' ]; then
        if [ ! ${__TEXTBOX['file']+xyz } ]; then
            __panic 'text: No file specified to follow.'
        fi
        if config isDialogRenderer >/dev/null; then
            __TEXTBOX['type']='tail'
            if [ "${__TEXTBOX['inBackground']?}" = 'true' ]; then
                __TEXTBOX['type']='tailbg'
            fi
        else
            if [ "${__TEXTBOX['inBackground']?}" = 'true' ]; then
                __panic 'text: The "inBackground" option is unsupported in Whiptail.'
            fi

            # Compute the size of the program (info) box needed to determine the scrollable area of
            # the text. This is the area we want to fill with text from file, if any, otherwise tail
            # will print only last 10 lines
            __box_compute_size 'info' "${l_box_size[0]}" "${l_box_size[1]}" \
                "$__TEXT_PRESS_ENTER_MSG" l_box_size
            # Exclude the height of the press enter msg and the fixed box height (borders + title)
            local l_scroll_height=$((l_box_size[0] - 1 - 6))
            if [ $l_scroll_height -le 0 ]; then
                # Always display at least one line when box height should auto-size or too small
                l_scroll_height=1
            fi
            # Save globally for debug dump
            __TEXTBOX['scroll-height']=$l_scroll_height

            # Set up a "phantom" box with user options, but don't render it, as we simulate the tail
            # box by ourselves
            __box "${__TEXTBOX['type']?}" callback="$l_callback" "${l_box_args[@]}"
            __box_set_dump_callback '__text_dump_callback'
            __box_exec '__text_exec_tailbox' "${__TEXTBOX['file']?}" "$l_scroll_height" "${l_box_args[@]}"
            return $?
        fi
    fi

    __box "${__TEXTBOX['type']?}" text="${__TEXTBOX['file']:-${__TEXTBOX['text']?}}" \
        callback="$l_callback" "${l_box_args[@]}"
    __box_set_dump_callback '__text_dump_callback'
    __box_draw
} # }}}

# Simulate tail box with program (info) box which supports reading input from stdin. In parallel,
# we'll wait for user to press Enter or Esc key.
# Args:
# 1: the file to follow as with tail -f
# 2: the height of the scrollable area for the text
# 3...: box options to pass to the program (info) box
# Returns 0 when Enter pressed, or 255 when Esc pressed or when cannot open file for reading.
# @hide
function __text_exec_tailbox() { # {{{
    local l_file="${1?}" \
        l_scroll_height="${2?}" \
        l_rc="${DIALOG_ERROR:-255}"; shift 2
    if [ ! -r "$l_file" ]; then
        # NOTE: printing to stdout as it will be later redirected to stderr due to exit code > 0
        printf "text: Could not open file for reading: %s\n" "$l_file"
        return "$l_rc"
    fi

    # Start tail command and program box as two separate background processes. The communication
    # between the two is done using a FIFO file
    local l_fifo; l_fifo="$(__create_fifo_file)" || exit $?
    tail -n "$l_scroll_height" -f "$l_file" > "$l_fifo" & local l_tail_pid=$!
    {
        trap 'rm '"$l_fifo" EXIT
        program \
            text="$__TEXT_PRESS_ENTER_MSG" \
            hideOk='true' \
            "$@" < "$l_fifo"
    } 2>&1 & local l_program_pid=$!

    # Ensure we properly terminate on Ctrl+C or when force killed
    trap 'kill '$l_tail_pid' 2>/dev/null' EXIT

    # Wait for user to press Enter or Esc key
    local l_key
    while IFS= read -r -N 1 l_key; do
        case "$l_key" in
            # Enter key
            $'\n') l_rc=0; break;;
            # Esc key
            $'\e') l_rc="${DIALOG_ESC:-255}"; break;;
        esac
    done

    # Kill the process running the tail command, which will release the FIFO file and terminate the
    # program box
    kill $l_tail_pid 2>/dev/null

    # Wait for the program box to terminate before exiting, as it should remove the alternate
    # buffer to cleanup the screen
    wait $l_program_pid 2>/dev/null

    return "$l_rc"
}
readonly -f __text_exec_tailbox
# }}}

# @hide
function __text_dump_callback() { # {{{
    echo 'TEXT {'
        __pretty_print_array __TEXTBOX | __treeify 2 0
    echo '}'
}
readonly -f __text_dump_callback
# }}}
