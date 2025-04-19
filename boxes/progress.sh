#!/usr/bin/env bash
# vim: set fdm=marker:

# @hide
declare -A __PROGRESS
# @hide
declare -a __PROGRESS_ENTRIES

# Public constants to use as entry state in the mixedprogress
readonly PROGRESS_SUCCEEDED_STATE=0 \
    PROGRESS_FAILED_STATE=1 \
    PROGRESS_PASSED_STATE=2 \
    PROGRESS_COMPLETED_STATE=3 \
    PROGRESS_CHECKED_STATE=4 \
    PROGRESS_DONE_STATE=5 \
    PROGRESS_SKIPPED_STATE=6 \
    PROGRESS_IN_PROGRESS_STATE=7 \
    PROGRESS_BLANK_STATE=8 \
    PROGRESS_N_A_STATE=9 # N/A state

# Sets up a new progress box. Corresponds to the --gauge & --mixedgauge arguments in Dialog/Whiptail.
# In Whiptail, the mixed progress is simulated using a normal progress.
# Also performs the actual drawing of the progress box.
# Adjustments can be done via progressSet().
function progress() { # {{{
    if [ $# -eq 1 ] && [ "$1" = 'help' ]; then
        __progress_help
        return 0
    fi

    # Clean up the old progress box
    __progress_clean_up
    __PROGRESS=(
        ['value']=0
        ['total']=0
        ['current-value']=0
        ['sleep']=0
        ['mixed']=0
    )

    local -a l_box_args l_common_args
    local l_param l_value
    while [ $# -gt 0 ]; do
        l_param="${1%%=*}"
        l_value="${1#*=}"
        case "$l_param" in
            loop|timeout) : Ignored;;
            entry|state|value|total) l_common_args+=("$1");;
            sleep) __PROGRESS["$l_param"]="$l_value";;
            *) l_box_args+=("$1")
        esac
        local l_code=$?
        if [ $l_code -gt 0 ]; then
            exit $l_code
        fi
        shift
    done

    if [ ${l_common_args[@]+xyz} ]; then
        __progress_set "${l_common_args[@]}"
    fi
    __progress_compute

    if config isDialogRenderer >/dev/null && [ "${__PROGRESS['mixed']?}" -eq 1 ]; then
        __box 'mixedprogress' "${l_box_args[@]}"
        __progress_compute_max_box_content_dimens
        __box_set_dump_callback '__progress_dump_callback'
        __box_draw "${__PROGRESS['current-value']?}" "${__PROGRESS_ENTRIES[@]}"
    else
        __box 'progress' "${l_box_args[@]}"
        __progress_compute_max_box_content_dimens
        __box_set_dump_callback '__progress_dump_callback'
        __progress_draw
    fi
} # }}}

# @hide
function __progress_draw() { # {{{
    local l_text="${__BOX['text']?}"
    if [ ${__PROGRESS['text']+xyz} ]; then
        l_text="${__PROGRESS['text']}"
    fi
    # We may have entries at this point, so prepend them unconditionally to the existing text
    if [ "${__PROGRESS['mixed']?}" -eq 1 ] && ! config isDialogRenderer >/dev/null &&
        __progress_generate_entries; then
        l_text="${__PROGRESS['entries']?}\n$l_text"
    fi
    __BOX['text']="$l_text"

    __progress_close_fifo_fd

    # We need a FIFO file that will be used as a stdin for Whiptail/Dialog to update the
    # progress box, such as percentage or text inside the box
    __PROGRESS['fifo-file']="$(__create_fifo_file)" || exit $?
    local l_fifo="${__PROGRESS['fifo-file']}"

    if ! config isDialogRenderer >/dev/null; then {
        # Whiptail is a newt-based terminal app that relies on S-Lang C library to interact with
        # the terminal. Upon start, it calls SLang_init_tty() to prepare the TTY for
        # single-character input. This also erases all control keys, including the interrupt
        # character (Ctrl+c). As a result, the progress box (and the user script) cannot receive
        # SIGINT signals. To workaround, we send something to the FIFO file in a background
        # process, which causes it to halt & wait until Whiptail opens the file in read mode.
        # Then, we sleep for 100ms to allow Whiptail to set its terminal settings, then restore
        # the interrupt character
        printf $'\0' > "$l_fifo" && sleep .1 && [ -p "$l_fifo" ] && stty intr $'\cC' 2>/dev/null
    } <&0 &
    fi

    # Note that, we launch the progress box as a background process, so that the user script can
    # continue and perform progress updates as needed
    {
        trap '__progress_clean_up' EXIT
        __box_draw "${__PROGRESS['current-value']?}" < "$l_fifo"
    } & __PROGRESS['pid']=$!

    local l_fd
    exec {l_fd}>"$l_fifo"
    __PROGRESS['fd']=$l_fd
}
readonly -f __progress_draw
# }}}

# Performs adjustments on the current progress box.
function progressSet() { # {{{
    if [ $# -eq 1 ] && [ "$1" = 'help' ]; then
        __progress_set_help
        return 0
    fi

    __progress_assert_displaying

    __progress_set "$@"
    __progress_compute
    if [ "${__PROGRESS['force-redraw']:-0}" -eq 1 ]; then
        __PROGRESS['force-redraw']=0
        __progress_draw
    else
        __progress_refresh
    fi

    if [ "${__PROGRESS['current-value']?}" -ge 100 ]; then
        if [ "${__PROGRESS['sleep']?}" = 0 ]; then
            # Allow for the last frame to be drawn before exiting the box
            sleep .1
        fi
        __progress_exit
    fi
} # }}}

# Manually causes the progress box to exit.
function progressExit() { # {{{
    if [ $# -gt 0 ]; then
        if [ $# -eq 1 ] && [ "$1" = 'help' ]; then
            __progress_exit_help
            return 0
        fi
        __panic "progressExit: Unrecognized argument(s): $*."
    fi
    __progress_exit
}
# }}}

# Function to gracefully exit the progress box and perform post-activities, such as cleanup.
# @hide
function __progress_exit() { # {{{
    __progress_assert_displaying

    # Save values before clean up
    local l_sleep="${__PROGRESS['sleep']?}"
    local -i l_pid="${__PROGRESS['pid']?}"

    __progress_clean_up

    # Wait for the progress box to terminate before exiting the script, as it should remove the
    # alternate buffer to cleanup the screen, and restore TTY input settings
    wait $l_pid 2>/dev/null

    if [ "$l_sleep" != 0 ]; then
        sleep "$l_sleep" || exit $?
    fi
}
readonly -f __progress_exit
# }}}

# Function to set common progress options.
# @hide
function __progress_set() { # {{{
    local -a l_entries l_states
    local l_param l_value l_new_text
    while [ $# -gt 0 ]; do
        l_param="${1%%=*}"
        l_value="${1#*=}"
        case "$l_param" in
            entry) l_entries+=("$l_value");;
            state) l_states+=("$l_value");;
            text) l_new_text="$l_value";;
            value|total) __PROGRESS["$l_param"]="$(__trim_decimals "$l_value")";;
            *) __panic "${FUNCNAME[1]}: Unrecognized argument: $1"
        esac
        local l_code=$?
        if [ $l_code -gt 0 ]; then
            exit $l_code
        fi
        shift
    done

    if [ ${l_new_text+xyz} ]; then
        local l_old_text="${__PROGRESS['text']-${__BOX['text']?}}"
        __PROGRESS['text']="$l_new_text"
        # Nor Dialog nor Whiptail auto resize to fit the new text, so redraw is needed
        if [ "$l_old_text" != "$l_new_text" ] && __progress_compute_max_box_content_dimens; then
            __PROGRESS['force-redraw']=1
        fi
    fi

    if [ ${#l_entries[@]} -ne ${#l_states[@]} ]; then
        __panic "${FUNCNAME[1]}: Entry and state count mismatch (${#l_entries[@]} != ${#l_states[@]})."
    fi

    if [ ${l_entries[@]+xyz} ]; then
        local l_entry l_state_idx=0 l_entry_idx l_state l_batch_size=2 \
            l_old_total_entries=${#__PROGRESS_ENTRIES[@]}
        for l_entry in "${l_entries[@]}"; do
            # Search for the entry index
            local i l_total=${#__PROGRESS_ENTRIES[@]}
            for ((i = 0; i < l_total; i += l_batch_size)); do
                if [ "$l_entry" = "${__PROGRESS_ENTRIES[i]}" ]; then
                    l_entry_idx=$i
                    break
                fi
            done
            l_state="${l_states[l_state_idx++]}"
            # Update the existing entry pair or add a new one
            if [ ${l_entry_idx+xyz} ]; then
                __PROGRESS_ENTRIES[l_entry_idx+1]="$l_state"
                unset l_entry_idx
            else
                __PROGRESS_ENTRIES+=("$l_entry" "$l_state")
            fi
        done
        # Need to redraw the progress box if it's already displayed and the entry count has changed.
        # This is needed for Whiptail, because the entries are prepended to the existing text inside
        # the progress box, which requires the box to be resized
        if [ ${__PROGRESS['fd']+xyz} ] && [ "$l_old_total_entries" -ne ${#__PROGRESS_ENTRIES[@]} ]; then
            __PROGRESS['force-redraw']=1
        fi
        __PROGRESS['mixed']=1
    fi

    # Dialog's mixed progress box will still be redrawn, so no need to force it further
    if [ "${__PROGRESS['mixed']?}" -eq 1 ] && config isDialogRenderer >/dev/null; then
        __PROGRESS['force-redraw']=0
    fi
}
readonly -f __progress_set
# }}}

# Generates the string of entries like in Dialog's mixed progress box.
# Each entry is separated by new line.
# Exits with 1 when no entries has been added, 0 otherwise.
# @hide
function __progress_generate_entries() { # {{{
    local i l_total l_entry l_state batch_size=2
    __PROGRESS['entries']=''
    for ((i = 0, l_total = ${#__PROGRESS_ENTRIES[@]}; i < l_total; i += batch_size)); do
        l_entry="${__PROGRESS_ENTRIES[i]}"
        l_state="${__PROGRESS_ENTRIES[i+1]}"

        # Interpret the special entry values to line up with Dialog, otherwise use the string as-is.
        case "$l_state" in
            -*) l_state="${l_state:1}%" ;; # Suffix with a % sign when it starts with a leading '-'
            "$PROGRESS_SUCCEEDED_STATE") l_state='Succeeded';;
            "$PROGRESS_FAILED_STATE") l_state='Failed';;
            "$PROGRESS_PASSED_STATE") l_state='Passed';;
            "$PROGRESS_COMPLETED_STATE") l_state='Completed';;
            "$PROGRESS_CHECKED_STATE") l_state='Checked';;
            "$PROGRESS_DONE_STATE") l_state='Done';;
            "$PROGRESS_SKIPPED_STATE") l_state='Skipped';;
            "$PROGRESS_IN_PROGRESS_STATE") l_state='In Progress';;
            "$PROGRESS_BLANK_STATE")
                # For the blank state omit drawing the entry and show an empty line instead
                __PROGRESS['entries']+="\n"
                continue
                ;;
            "$PROGRESS_N_A_STATE") l_state='N/A';;
        esac

        __PROGRESS['entries']+="$l_entry [ $l_state ]"
        __PROGRESS['entries']+="\n"
    done
    [ $i -gt 0 ]; return $?
}
# }}}

# Refresh the text and % value in the progress box.
# If it's a mixedprogress, this also refreshes the entries.
# @hide
function __progress_refresh() { # {{{
    local l_text="${__BOX['text']?}"
    if [ ${__PROGRESS['text']+xyz} ]; then
        l_text="${__PROGRESS['text']}"
    fi

    if [ "${__PROGRESS['mixed']?}" -eq 1 ] && config isDialogRenderer >/dev/null; then
        # The progress could have started with no entries, but they can be added later using
        # progressSet, so need to align the box type
        __BOX['type']='mixedprogress'
        __BOX['text']="$l_text"
        __box_draw "${__PROGRESS['current-value']?}" "${__PROGRESS_ENTRIES[@]}"
    else
        if [ "${__PROGRESS['mixed']?}" -eq 1 ] && ! config isDialogRenderer >/dev/null &&
            __progress_generate_entries; then
            l_text="${__PROGRESS['entries']?}\n$l_text"
        fi
        printf "XXX\n%d\n%s\nXXX\n" \
            "${__PROGRESS['current-value']?}" "$l_text" >&"${__PROGRESS['fd']?}" || exit $?
    fi
}
readonly -f __progress_refresh
# }}}

# Compute the current progress value.
# @hide
function __progress_compute() { # {{{
    local l_value="${__PROGRESS['value']?}"

    # Calculate the % basing on total value, if supplied
    if [ "${__PROGRESS['total']?}" -gt 0 ]; then
        l_value=$((l_value * 100 / __PROGRESS['total']))
    fi

    __PROGRESS['current-value']="$l_value"
}
readonly -f __progress_compute
# }}}

function __progress_assert_displaying() { # {{{
    if [ ! ${__PROGRESS[@]+xyz} ] && [ ! ${__PROGRESS['fd']+xyz} ]; then
        __panic "${FUNCNAME[1]}: No progress box currently displaying."
    fi
}
readonly -f __progress_assert_displaying
# }}}

# Compute the progress box content max dimensions based on the current text's width (columns) &
# height (lines).
# Returns 0 when the current progress box content dimensions grew in size, otherwise 1 when it
# remained the same or shrunk in size compared to the previous content dimensions.
# @hide
function __progress_compute_max_box_content_dimens() { # {{{
    local l_text="${__PROGRESS['text']-${__BOX['text']?}}"
    local -i l_changed=1
    if [ "${__BOX['width']?}" = 'auto' ] || [ "${__BOX['width']?}" -eq 0 ]; then
        local IFS=$'\n' l_line
        for l_line in ${l_text//\\n/$'\n'}; do
            if [ ${#l_line} -gt "${__PROGRESS['max-text-width']-0}" ]; then
                __PROGRESS['max-text-width']=${#l_line}
                l_changed=0
            fi
        done
    fi
    if [ "${__BOX['height']?}" = 'auto' ] || [ "${__BOX['height']?}" -eq 0 ]; then
        local -i l_text_line_nr
        l_text_line_nr="$(__count_lines "$l_text")"
        if [ $l_text_line_nr -gt "${__PROGRESS['max-text-height']-0}" ]; then
            __PROGRESS['max-text-height']=$l_text_line_nr
            l_changed=0
        fi
    fi
    return $l_changed
}
readonly -f __progress_compute_max_box_content_dimens
# }}}

# Function to close the FIFO file used to update the progress box.
# After this call, the progress box will exit immediately.
# @hide
function __progress_close_fifo_fd() { # {{{
    if [ ${__PROGRESS['fd']+xyz} ]; then
        local l_fd="${__PROGRESS['fd']}"
        exec {l_fd}>&- || {
            __panic "${FUNCNAME[1]}: Failed to close the file descriptor: $l_fd (exit code: $?)."
        }
    fi
}
readonly -f __progress_close_fifo_fd
# }}}

# @hide
function __progress_clean_up() { # {{{
    __progress_close_fifo_fd

    local l_fifo_file="${__PROGRESS['fifo-file']:-}"
    if [ -p "$l_fifo_file" ]; then
        rm -f "$l_fifo_file"
    fi

    if [ "${__PROGRESS['mixed']:-0}" -eq 1 ] && config isDialogRenderer >/dev/null; then
        # Clear the screen as Dialog's mixed gauge leaves the terminal in a messed up state
        clear
    fi

    # Restore cursor visibility when exiting progress box with Ctrl+c
    tput cnorm

    __PROGRESS=()
    __PROGRESS_ENTRIES=()
}
readonly -f __progress_clean_up
# }}}

# @hide
function __progress_dump_callback() { # {{{
    echo 'PROGRESS {'
    __pretty_print_array __PROGRESS | __treeify 2 0
    echo '}'
    echo 'PROGRESS_ENTRIES {'
        local i l_batch_size=2
        for ((i = 0; i < ${#__PROGRESS_ENTRIES[@]}; i += l_batch_size)); do
            printf 'entry="%s" state="%s"\n' "${__PROGRESS_ENTRIES[i]}" "${__PROGRESS_ENTRIES[i+1]}"
        done | __treeify 2 0
    echo '}'
}
readonly -f __progress_dump_callback
# }}}
