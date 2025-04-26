#!/usr/bin/env bash
# vim: set fdm=marker:

# @hide
declare -A __PROGRAM

# Sets up a new program box that will display the output of a command. Corresponds to the --prgbox,
# --programbox & --progressbox arguments in Dialog.
# In Whiptail, the program feature is emulated using an info & text box (--msgbox).
# Also performs the actual drawing of the program box.
function program() { # {{{
    if [ $# -eq 1 ] && [ "$1" = 'program' ]; then
        __program_help
        return 0
    fi

    # Clean up the old program box
    __PROGRAM=(
        ['hideOk']='false'
    )

    local -a l_box_args l_box_size=(0 0)
    local l_param l_value l_code l_text='' l_callback=''
    while [ $# -gt 0 ]; do
        l_param="${1%%=*}"
        l_value="${1#*=}"
        case "$l_param" in
            text) l_text="$l_value";;
            text+) l_text+="$l_value";;
            callback) l_callback="$l_value";;
            command) __PROGRAM["$l_param"]="$l_value";;
            hideOk) __assert_bool "$l_value" && __PROGRAM["$l_param"]="${__BOOLS["$l_value"]?}";;
            *)
                [ "$l_param" = 'height' ] && l_box_size[0]="$l_value"
                [ "$l_param" = 'width' ] && l_box_size[1]="$l_value"
                l_box_args+=("$1")
        esac
        l_code=$?
        if [ $l_code -gt 0 ]; then
            exit $l_code
        fi
        shift
    done

    local l_type
    if config isDialogRenderer >/dev/null; then
        if [ "${__PROGRAM['hideOk']?}" = 'true' ]; then
            l_type='progprogress'
        elif [ ${__PROGRAM['command']+xyz} ]; then
            l_type='progcommand'
        else
            l_type='progstdin'
        fi
    else
        # In Whiptail, we'll use info box to immediately display the command's output instead of
        # just buffering it. After the command exited, the buffered output will be displayed again
        # in the text box (--msgbox), allowing the user to press the OK button
        l_type='message'
        function run_info_box() {
            # The user provided the text that is located under the title (in Dialog), so need a copy
            # of it since we'll be scrolling the text separately
            local l_header="$l_text"
            if [ -n "$l_header" ]; then
                # Visually separate the header from the command output
                l_header+=$'\n\n'
                l_text=''
            fi

            # Draw the info box now as we don't know when the first command's output will be printed
            info text="${l_header?}" "${l_box_args[@]}"

            # Compute the size of the box needed to determine the scrollable area of the text
            local l_header_height=0
            __box_compute_size 'info' "${l_box_size[0]}" "${l_box_size[1]}" "${l_header?}" l_box_size
            if [ -n "${l_header?}" ]; then
                l_header_height="$(__count_lines "${l_header?}")"
            fi

            local l_max_line_width=$((l_box_size[1] - 4)) # 4 is to exclude left & right borders
            if [ $l_max_line_width -lt 0 ]; then
                l_max_line_width=0
            fi

            # Exclude the header height and the fixed box height (borders + title)
            local l_scroll_height=$((l_box_size[0] - l_header_height - 6))
            if [ $l_scroll_height -le 0 ]; then
                # Always display at least one line when box height should auto-size or too small
                l_scroll_height=1
            fi
            # Save globally for debug dump
            __PROGRAM['scroll-height']=$l_scroll_height
            __PROGRAM['max-line-width']=$l_max_line_width

            # Display in the info box all the data from stdin. Note that, instead of reading line by
            # line, we try to read bytes every 50ms (continuing until EOF is reached). This allows
            # to display multiple lines at once
            local l_rc l_buf l_last_chunk='' l_lf
            while IFS= read -r -d '' -t .05 l_buf; l_rc=$?; [ $l_rc -eq 0 ] ||
                [ -n "$l_buf" ] || # It may exit with code 1 when EOF is reached but have the last chunk of data
                [ $l_rc -gt 128 ]; do
                if [ -z "$l_buf" ]; then # No data = timed out
                    continue
                fi

                l_buf="${l_buf//$'\r'/$'\n'}"

                l_lf=${l_buf: -1}
                if [ "$l_lf" != $'\n' ]; then
                    # When the new buffered data doesn't end with a new line, then we probably read
                    # more lines, such as "line1\nline2\nline3". To line up with Dialog behavior, we
                    # strip off the last incomplete chunk (line3) and merge it later, so that we
                    # avoid displaying incomplete lines
                    l_last_chunk="${l_buf##*$'\n'}"
                    if [ "$l_last_chunk" != "$l_buf" ]; then
                        l_buf="${l_buf::-${#l_last_chunk}}"
                        # Update the LF as the line that was before the last incomplete line chunk
                        # is now the last line
                        l_lf=$'\n'
                    else
                        # There's no incomplete line chunks; it's a one-liner, so buf will be
                        # appended to the existing text as-is
                        l_last_chunk=''
                    fi
                else
                    # Remove the trailing line feed char as the here string (<<<) will add one later
                    l_buf="${l_buf::-1}"
                fi

                # Merge the new buffered lines with the old text but limit it to the scrollable area
                local l_line l_text_old="$l_text"
                l_text=''
                while IFS= read -r l_line; do
                    # Whiptail's info box wraps text to a new line, but Dialog's program box limits
                    # the lines to the box width
                    l_text+="${l_line:0:l_max_line_width}"
                    l_text+=$'\n'
                done < <(tail -$l_scroll_height <<< "${l_text_old}${l_buf}")

                if [ "$l_lf" = $'\n' ]; then
                    # Redraw only when have a new line
                    info text="${l_header}${l_text}" "${l_box_args[@]}"
                fi

                if [ -n "$l_last_chunk" ]; then
                    l_text+="$l_last_chunk"
                    l_last_chunk='' # consumed
                fi
            done

            # Reassemble the last outputted text to be displayed again in the text box
            l_text="${l_header}${l_text}"
        }

        # Start an alternate buffer for the info boxes, so that we can clear them all after the
        # command exits
        tput smcup

        if [ ${__PROGRAM['command']+xyz} ]; then
            # HACK: to avoid escaping and improper argument splitting hell that occur when using
            # sh -c "<command>", we use process substitution to create a temp shell script file
            # containing the command(s) that can be executed as-is
            run_info_box < <(sh <(printf -- '%s' "${__PROGRAM['command']?}") 2>&1)
        else
            run_info_box
        fi

        # Early exit with the info box code when shouldn't display the text box with an OK button
        if [ "${__PROGRAM['hideOk']?}" = 'true' ]; then
            local l_code="${DIALOG_OK:-0}"
            # Process the user callback, if present
            if [ -n "$l_callback" ]; then
                info text="$l_text" callback="$l_callback" "${l_box_args[@]}"; l_code=$?
            fi
            # Normally, the text box would reuse the alternate buffer, but since it won't be
            # displayed, the alternate buffer needs to be removed explicitly
            tput rmcup
            return "$l_code"
        fi
    fi

    __box "$l_type" text="$l_text" callback="$l_callback" "${l_box_args[@]}"
    __box_set_dump_callback '__program_dump_callback'
    if config isDialogRenderer >/dev/null && [ ${__PROGRAM['command']+xyz} ]; then
        if [ "${__PROGRAM['hideOk']?}" = 'true' ]; then
            # When should hide the OK button, we'll be using a progressbox that displays the piped
            # output of a command, so need to execute the command and provide the output via stdin
            __box_draw < <(sh <(printf -- '%s' "${__PROGRAM['command']?}") 2>&1)
        else
            # Note that we need to escape the double quotes for the sprintf() used to pass the
            # command to sh -c "<command>"
            __box_draw "${__PROGRAM['command']//\"/\\\"}"
        fi
    else
        __box_draw
    fi
} # }}}

# @hide
function __program_dump_callback() { # {{{
    echo 'PROGRAM {'
        __pretty_print_array __PROGRAM | __treeify 2 0
    echo '}'
}
readonly -f __program_dump_callback
# }}}
