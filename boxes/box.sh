#!/usr/bin/env bash
# vim: set fdm=marker:

# @hide
readonly -A __BOX_TYPES=(
    ['buildlist']='--buildlist'
    ['calendar']='--calendar'
    ['checklist']='--checklist'
    ['confirm']='--yesno'
    ['dselect']='--dselect'
    ['edit']='--editbox'
    ['fselect']='--fselect'
    ['info']='--infobox'
    ['input']='--inputbox'
    ['inputmenu']='--inputmenu'
    ['menu']='--menu'
    ['message']='--msgbox'
    ['mixedform']='--mixedform'
    ['mixedprogress']='--mixedgauge'
    ['password']='--passwordbox'
    ['pause']='--pause'
    ['progcommand']='--prgbox'
    ['progprogress']='--progressbox'
    ['progress']='--gauge'
    ['progstdin']='--programbox'
    ['radiolist']='--radiolist'
    ['range']='--rangebox'
    ['tail']='--tailbox'
    ['tailbg']='--tailboxbg'
    ['text']='--textbox'
    ['timepicker']='--timebox'
    ['treelist']='--treeview'
)
# @hide
declare -A __BOX __BOX_CALLBACKS
# @hide
declare -a __BOX_RAW_ARGS __BOX_RAW_USER_ARGS __BOX_RAW_USER_WIDGET_ARGS __BOX_WIDGET_RAW_ARGS
# @hide
declare -a __BOX_VALIDATION_CALLBACK_RESPONSE
# @hide
readonly __BOX_VALIDATION_CALLBACK_RETRY=0 \
    __BOX_VALIDATION_CALLBACK_BREAK=1 \
    __BOX_VALIDATION_CALLBACK_PROPAGATE=2 \
    __BOX_VALIDATION_CALLBACK_SWAP_RESULT=3 \
    __BOX_VALIDATION_CALLBACK_SWAP_RESULT_AND_RETCODE=4 \
    __BOX_VALIDATION_CALLBACK_SWAP_RETCODE=5

# Sets up a box of the given type passed as first parameter and other box options.
# Requires a call __box_draw() to perform drawing of the box.
# @hide
function __box() { # {{{
    local l_type="${1?}"; shift
    if [ ! ${__BOX_TYPES["$l_type"]+xyz} ]; then
        __panic "${FUNCNAME[1]}: Undefined box type: $l_type"
    fi
    local l_prev_box_type="${__BOX['type']-}" l_depth=${__BOX['depth']-0} \
        l_debug_summary_printed=${__BOX['debug-summary-printed']:-0}

    # Clean up the old box
    __BOX=(
        ['title']=''
        ['text']=''
        ['width']=0
        ['height']=0
        ['callback']=''
        ['changeToCallbackDir']='true'
        ['abortOnCallbackFailure']='false'
        ['propagateCallbackExitCode']='true'
        ['alwaysInvokeCallback']='false'
        ['printResult']='false'
        ['abortOnRendererFailure']='false'
        ['loop']='false'
        ['hideBreadcrumb']='false'
        ['sleep']=0
        ['timeout']=0
        ['scrollbar']='false'
        ['topleft']='false'
        # Internal options
        ['type']="$l_type"
        ['depth']=$l_depth
        ['debug-summary-printed']=$l_debug_summary_printed
    )
    __BOX_CALLBACKS=()
    __BOX_RAW_ARGS=()
    __BOX_RAW_USER_ARGS=("${__CONFIG_BOX_RAW_USER_ARGS[@]}")
    __BOX_RAW_USER_WIDGET_ARGS=("${__CONFIG_BOX_RAW_USER_WIDGET_ARGS[@]}")

    # NOTE: can clear tailboxbg widget args only after widget is created
    if [ "$l_prev_box_type" != 'tailbg' ]; then
        __BOX_WIDGET_RAW_ARGS=()
    fi

    local -a l_args=("${__CONFIG_BOX_ARGS[@]}" "$@")
    local i l_total l_param l_value l_arg l_parsing_raw_args=0 l_parsing_widget_args=0
    for ((i = 0, l_total=${#l_args[@]}; i < l_total; i++)); do
        l_arg="${l_args[i]}"
        if [ $l_parsing_raw_args -eq 1 ]; then
            case "$l_arg" in
                '(') __panic "${FUNCNAME[1]}: Missing the closing round bracket ')' for the Dialog/Whiptail-specific arguments: ( ${__BOX_RAW_USER_ARGS[*]} ${__BOX_RAW_USER_WIDGET_ARGS[*]}";;
                ')') l_parsing_raw_args=0; l_parsing_widget_args=0;;
                # Prevent the user from tampering the input/output
                --output-separator|--output-fd|--input-fd) i=$((i+1));; # skip the value as well
                --separate-output);;
                # Allow ( and ) to be used as-is when escaped
                '\('|'\)') l_arg="${l_arg:1}";&
                *)
                    # Collect widget args separately to append them at the very end so Dialog can
                    # parse them correctly
                    if [ $l_parsing_widget_args -eq 1 ] || [ "$l_arg" = '--and-widget' ]; then
                        l_parsing_widget_args=1
                        __BOX_RAW_USER_WIDGET_ARGS+=("$l_arg")
                    else
                        __BOX_RAW_USER_ARGS+=("$l_arg")
                    fi
            esac
            continue
        elif [ "$l_arg" = '(' ]; then
            l_parsing_raw_args=1
            continue
        fi
        l_param="${l_arg%%=*}"
        l_value="${l_arg#*=}"
        case "$l_param" in
            # Raw value options
            title|text | \
            width|height | \
            callback | \
            yesLabel|noLabel|okLabel|cancelLabel | \
            term|sleep) __BOX["$l_param"]="$l_value";;
            # Boolean value options
            changeToCallbackDir | \
            abortOnCallbackFailure | \
            propagateCallbackExitCode | \
            alwaysInvokeCallback | \
            printResult | \
            loop | \
            abortOnRendererFailure | \
            hideBreadcrumb | \
            scrollbar | \
            topleft) __assert_bool "$l_value" && __BOX["$l_param"]="${__BOOLS["$l_value"]?}";;
            text+) __BOX['text']+="$l_value";;
            # Decimal value options
            timeout) __BOX["$l_param"]="$(__trim_decimals "$l_value")";;
            *) __panic "${FUNCNAME[1]}: Unrecognized argument: $l_arg"
        esac
        local l_code=$?
        if [ $l_code -gt 0 ]; then
            exit $l_code
        fi
    done

    if [ $l_parsing_raw_args -eq 1 ]; then
        __panic "${FUNCNAME[1]}: Missing the closing round bracket ')' for the Dialog/Whiptail-specific arguments: ( ${__BOX_RAW_USER_ARGS[*]} ${__BOX_RAW_USER_WIDGET_ARGS[*]}"
    fi
}
readonly -f __box
# }}}

# Add a callback per-option (e.g., menu entry).
# @hide
function __box_add_callback() { # {{{
    __BOX_CALLBACKS["${1?}"]="${2?}"
}
readonly -f __box_add_callback
# }}}

# Set the default exit code when the box exits due to timeout. (Whiptail-only)
# Defaults to 255 to inline with the Dialog's --timeout option.
# @hide
function __box_set_default_renderer_code_on_timeout() { # {{{
    __BOX['default-timeout-exit-code']="${1?}"
}
readonly -f __box_set_default_renderer_code_on_timeout
# }}}

# Set the callback that will validate the result(s) right after the box exits.
# The callback will receive the results as input parameters.
# The $? variable will hold the box's exit code at the time the callback is invoked.
#
# The callback should exit with one of the following constant codes:
# __BOX_VALIDATION_CALLBACK_RETRY
#   The box will be re-rendered.
#
# __BOX_VALIDATION_CALLBACK_BREAK
#   The result won't be propagated to the user's callback.
#
# __BOX_VALIDATION_CALLBACK_PROPAGATE
#   The result will be propagated to the user's callback.
#
# __BOX_VALIDATION_CALLBACK_SWAP_RESULT
#   The result stored in __BOX_VALIDATION_CALLBACK_RESPONSE array will swap the renderer result, if
#   any, and will be propagated to the user's callback.
#
# __BOX_VALIDATION_CALLBACK_SWAP_RESULT_AND_RETCODE
#   Combines the behavior of __BOX_VALIDATION_CALLBACK_SWAP_RESULT and __BOX_VALIDATION_CALLBACK_SWAP_RETCODE.
#   Note that, in this mode, the code in the response is expected to be present as the first element
#   (index 0) in the response array.
#
# __BOX_VALIDATION_CALLBACK_SWAP_RETCODE
#   The code stored in __BOX_VALIDATION_CALLBACK_RESPONSE array will swap the renderer code and
#   propagate it to the user's callback.
#
# @hide
function __box_set_result_validation_callback() { # {{{
    __BOX['result-validation-callback']="${1?}"
}
readonly -f __box_set_result_validation_callback
# }}}

# Set the callback to dump the internals of the box for debugging purpose.
# @hide
function __box_set_dump_callback() { # {{{
    __BOX['dump-callback']="${1?}"
}
readonly -f __box_set_dump_callback
# }}}

# Set the callback that will preprocess the result(s) before invoking client's callback.
# The callback will receive the results as input parameters.
# The callback should separate the results in the response using new line.
# @hide
function __box_set_preprocess_result_callback() { # {{{
    __BOX['preprocess-result-callback']="${1?}"
}
readonly -f __box_set_preprocess_result_callback
# }}}

# Set the callback that will capture the raw renderer result after box exits.
# The callback will receive the result in the standard input.
# @hide
function __box_set_capture_renderer_raw_result_callback() { # {{{
    __BOX['capture-renderer-raw-result-callback']="${1?}"
}
readonly -f __box_set_capture_renderer_raw_result_callback
# }}}

# Set the callback that will capture the renderer result(s) after box exits.
# The callback will receive the results as input parameters.
# @hide
function __box_set_capture_renderer_result_callback() { # {{{
    __BOX['capture-renderer-result-callback']="${1?}"
}
readonly -f __box_set_capture_renderer_result_callback
# }}}

# Set the callback that will capture the renderer exit code after box exits.
# @hide
function __box_set_capture_renderer_code_callback() { # {{{
    __BOX['capture-renderer-code-callback']="${1?}"
}
readonly -f __box_set_capture_renderer_code_callback
# }}}

# Builds the raw arguments to be passed to Dialog/Whiptail.
# @hide
function __box_build_args() { # {{{
    local l_type="${__BOX['type']?}"
    local -n l_text=__BOX['text']

    __BOX['backtitle']="$(__header_generate)"
    __BOX_RAW_ARGS=(
        '--backtitle' "${__BOX['backtitle']?}"
    )

    # NOTE: for Dialog, we always pass the title argument even if there's no title, as some boxes
    # (e.g., buildlist) fail to render with error "Can't make sub-window at (56,18), size (1,60)."
    # when it's entirely missing. For Whiptail, on the other hand, we add the title argument only
    # when having a non-empty title, otherwise, it will draw the title borders
    if [ -n "${__BOX['title']?}" ] || config isDialogRenderer >/dev/null; then
        __BOX_RAW_ARGS+=('--title' "${__BOX['title']?}")
    fi

    local l_button
    for l_button in 'yes' 'no' 'ok' 'cancel'; do
        if [ ${__BOX["${l_button}Label"]+xyz} ]; then
            if config isDialogRenderer >/dev/null; then
                __BOX_RAW_ARGS+=("--$l_button-label")
            else
                __BOX_RAW_ARGS+=("--$l_button-button")
            fi
            __BOX_RAW_ARGS+=("${__BOX["${l_button}Label"]?}")
        fi
    done

    if config isDialogRenderer >/dev/null && [ "${__BOX['timeout']?}" -ne 0 ]; then
        __BOX_RAW_ARGS+=('--timeout' "${__BOX['timeout']?}")
    fi

    if [ "${__BOX['scrollbar']?}" = 'true' ]; then
        if config isDialogRenderer >/dev/null; then
            __BOX_RAW_ARGS+=('--scrollbar')
        else
            __BOX_RAW_ARGS+=('--scrolltext')
        fi
    fi

    if [ "${__BOX['topleft']?}" = 'true' ]; then
        if config isDialogRenderer >/dev/null; then
            __BOX_RAW_ARGS+=('--begin' 0 0)
        else
            __BOX_RAW_ARGS+=('--topleft')
        fi
    fi

    case "$l_type" in
        checklist|buildlist) __BOX_RAW_ARGS+=('--separate-output')
    esac

    # Clean up the screen after Dialog dismissed to line up with Whiptail behavior
    if config isDialogRenderer >/dev/null; then
        case "$l_type" in
            info|mixedprogress);;
            *) __BOX_RAW_ARGS+=('--keep-tite')
        esac
    fi

    # IMPORTANT: *must* append the raw user args with dashes at the end so that they take precedence
    __BOX_RAW_ARGS+=("${__BOX_RAW_USER_ARGS[@]}")

    # Define the box arguments (e.g., --msgbox <text> <height> <width>)
    __BOX_RAW_ARGS+=("${__BOX_TYPES["$l_type"]?}")
    # NOTE: need the '--' before the text parameter as it may start with a dash. In Whiptail, this
    # will follow the getopt convention and treat all the following arguments as-is. In Dialog, this
    # will escape only the next argument
    __BOX_RAW_ARGS+=('--' "${l_text?}")

    local l_width="${__BOX['width']?}" l_height="${__BOX['height']?}"
    local -a l_box_size
    __box_compute_size "$l_type" "$l_height" "$l_width" "${l_text?}" l_box_size

    if [ "$l_type" = 'progcommand' ]; then
        local l_command="${1?}"
        __BOX_RAW_ARGS+=("$l_command" "${l_box_size[@]}")
    else
        __BOX_RAW_ARGS+=("${l_box_size[@]}" "$@")
    fi

    # Widgets should be at the very end to be correctly parsed by Dialog
    __BOX_RAW_ARGS+=("${__BOX_RAW_USER_WIDGET_ARGS[@]}")
}
readonly -f __box_build_args
# }}}

# Compute the box size (w/adjustments to fit the text) for the given box type.
# Args:
# 1: box type (e.g., menu)
# 2: box height (e.g, 25%, max (or -1), auto (or 0), 15)
# 3: box width (e.g, 25%, max (or -1), auto (or 0), 15)
# 4: box text, if any, or an empty string
# 5: array ref name to store the computed box size values in form size=(<height> <width>)
# @hide
function __box_compute_size() { # {{{
    local l_type="${1?}" l_height="${2?}" l_width="${3?}" l_text="${4?}"
    local -n l_box_size_ref="${5?}"

    case "$l_width" in
        *%) l_width="$(__scale_value "$l_width" "$(tput cols)")";;
        auto) l_width=0;;
        max) l_width=-1;;
    esac
    case "$l_height" in
        *%) l_height="$(__scale_value "$l_height" "$(tput lines)")";;
        auto) l_height=0;;
        max) l_height=-1;;
    esac

    if config isDialogRenderer >/dev/null; then
        case "$l_type" in
            fselect|dselect)
                # When maximizing with width=-1/height=-1 or auto-sizing with width=0/height=0, Dialog
                # always fails with the error: "Can't make new window at (-7,0), size (71,160)".
                # Based on testing, it seems that Dialog tries to ensure the window fits the
                # terminal. However, it doesn't consider the size of the window elements like
                # buttons, borders, padding etc.
                if [ "$l_width" -le 0 ]; then
                    l_width="$(($(tput cols) - 4))"
                fi
                if [ "$l_height" -le 0 ]; then
                    local l_lines l_size=11
                    # Ensure the box doesn't cover the backtitle displayed at the top of the screen
                    if [ -n "${__BOX['backtitle']:-}" ]; then
                        l_size=$((l_size + 4))
                    fi
                    l_lines="$(tput lines)"
                    l_height="$((l_lines - l_size < 1 ? 1 : l_lines - l_size))"
                fi
                ;;
            pause|progress)
                # When box text is supplied and height is 0 (auto-size), Dialog doesn't take into
                # the account the text height. We need at least MIN_HEIGHT rows to display 1 line,
                # so we add 1 row to the height for each new line
                if [ -n "${l_text?}" ] && [ "$l_height" -eq 0 ]; then
                    local l_text_line_nr l_min_height
                    l_text_line_nr="$(__count_lines "$l_text")"
                    case "$l_type" in
                        pause) l_min_height=7;;
                        progress) l_min_height=5;;
                    esac
                    l_height=$((l_min_height + l_text_line_nr))
                fi
        esac
        case "$l_type" in
            pause|progress)
                # When box text is supplied and width is 0 (auto-size), Dialog doesn't take into the
                # account the window elements like borders, padding, etc. As a result, the text is
                # wrapped. We'll set the box width to the width of the largest line + reserved space
                if [ -n "${l_text?}" ] && [ "$l_width" -eq 0 ]; then
                    local l_ifs_copy="$IFS" IFS=$'\n' l_line
                    for l_line in ${l_text//\\n/$'\n'}; do
                        if [ ${#l_line} -gt "$l_width" ]; then
                            l_width=${#l_line}
                        fi
                    done
                    IFS="$l_ifs_copy"
                    if [ "$l_width" -gt 0 ]; then
                        l_width=$((l_width + 4))
                        if [ "$l_width" -ge "$(tput cols)" ]; then
                            # Text exceeds the terminal width, let Dialog wrap it to avoid the
                            # "Can't make new window at (<y>,<x>), size (<h>,<w>)" error
                            l_width=0
                        fi
                    fi
                fi
                ;;
        esac
    else
        # Maximize with height and width = -1 to line up with Dialog behavior
        if [ "$l_width" -eq -1 ]; then
            l_width="$(tput cols)"
        fi
        if [ "$l_height" -eq -1 ]; then
            l_height="$(tput lines)"
        fi
        case "$l_type" in
            info|password)
                # When box text is supplied and height is 0 (auto-size), Whiptail fails for unknown
                # reason to display it unless height is at least 7 rows. We need at least 7 rows to
                # display 1 line, so we add 1 row to the height for each new line
                if [ -n "${l_text?}" ] && [ "$l_height" -eq 0 ]; then
                    local l_text_line_nr
                    l_text_line_nr="$(__count_lines "$l_text")"
                    l_height=$((6 + l_text_line_nr))
                fi
                ;;
            progress)
                # In Whiptail, the minimum progress box height without text is 6 rows. If the user
                # reserves more than this, it will make the box taller, but that space cannot be
                # filled with new text, and only the existing lines can be replaced. As workaround,
                # we'll grow the box height using empty lines excluding the initial text height and
                # the provided height of the box
                if [ "$l_height" -gt 6 ]; then
                    local i l_text_line_nr=0
                    if [ -n "${l_text?}" ]; then
                        l_text_line_nr="$(__count_lines "$l_text")"
                    fi
                    for ((i = 0; i < l_height - 6 - l_text_line_nr; i++)); do
                        l_text+=$'\n\x20' # use a space (\x20) to actually create an empty line
                    done
                    # The box height should be set to 0 (auto-size) if at least one line was reserved
                    if [ $i -gt 0 ]; then
                        l_height=0
                    fi
                fi
        esac
    fi
    l_box_size_ref[0]=$l_height
    # shellcheck disable=SC2034
    l_box_size_ref[1]=$l_width
}
readonly -f __box_compute_size
# }}}

# Performs the actual drawing of the box using the selected renderer (Dialog or Whiptail).
# Must be called after the box has been fully set up.
# @hide
function __box_draw() { # {{{
    # The tailboxbg shouldn't be drawn without a widget. The drawing is postponed until the user
    # launches another box after this one that will be converted to a widget and merged with this
    # box args. We allow draw in case the user directly added a widget via --and-widget argument
    # when created the tailboxbg
    if [ "${__BOX['type']?}" = 'tailbg' ] && [ ${#__BOX_RAW_USER_WIDGET_ARGS[@]} -eq 0 ]; then
        __box_build_args "$@"
        __BOX_WIDGET_RAW_ARGS=("${__BOX_RAW_ARGS[@]}")
        return "${DIALOG_OK:-0}"
    fi
    if [ "${__BOX['hideBreadcrumb']?}" = 'false' ]; then
        __header_breadcrumbs_push "${__BOX['title']?}"
    fi
    __box_build_args "$@"
    if [ ${#__BOX_WIDGET_RAW_ARGS[@]} -gt 0 ]; then
        __BOX_RAW_ARGS=("${__BOX_WIDGET_RAW_ARGS[@]}" '--and-widget' "${__BOX_RAW_ARGS[@]}")
    fi
    __box_exec '__box_exec_renderer' "${__CONFIG['rendererBinary']?}" \
        "${__BOX_RAW_ARGS[@]?}"; local l_rc=$?
    if [ "${__BOX['hideBreadcrumb']?}" = 'false' ]; then
        __header_breadcrumbs_pop
    fi
    return $l_rc
}
readonly -f __box_draw
# }}}

# Executes the provided renderer in a subshell and processes the result using the box options.
# Must be called after the box has been fully set up.
# @hide
function __box_exec() { # {{{
    local l_type="${__BOX['type']?}" l_title="${__BOX['title']?}"

    __BOX['depth']=$((${__BOX['depth']?}+1))

    if config debug && [ ! -s "${__CONFIG['debug']}" ] &&
        [ "${__BOX['debug-summary-printed']?}" -eq 0 ]; then
        __BOX['debug-summary-printed']=1
        __box_print_log_header >> "${__CONFIG['debug']}"
    fi
    if config debug; then {
        printf "PREPARE BOX: %s (%s)\n" "$l_type" "$l_title"
        echo 'BREADCRUMBS ['
            __pretty_print_array __BREADCRUMBS | __treeify 2 0
        echo ']'
        echo 'CONFIG {'
            __pretty_print_array __CONFIG | __treeify 2 0
        echo '}'
        echo 'CONFIG_BOX_ARGS ['
            __pretty_print_array __CONFIG_BOX_ARGS | __treeify 2 0
        echo ']'
        echo 'CONFIG_BOX_RAW_USER_ARGS ['
            __pretty_print_array __CONFIG_BOX_RAW_USER_ARGS | __treeify 2 0
        echo ']'
        echo 'BOX (common) {'
            local l_box_opt l_box_opt_val
            for l_box_opt in "${!__BOX[@]}"; do
                l_box_opt_val="${__BOX["$l_box_opt"]?}"
                printf '"%s"="%s"' "$l_box_opt" "$l_box_opt_val"
                case "$l_box_opt" in
                    callback)
                        if [ "${l_box_opt_val: -2}" = '()' ]; then # function as callback
                            printf ' : '
                            if ! declare -F "${l_box_opt_val::-2}"; then
                                printf '%s was not found\n' "$l_box_opt_val"
                            fi
                        elif [ -n "$l_box_opt_val" ]; then # file as callback
                            printf ' : '
                            ls -l "$l_box_opt_val" 2>&1
                        else
                            printf '\n'
                        fi
                        ;;
                    *) printf '\n'
                esac
            done | __treeify 2 0
        echo '}'
        if [ ${__BOX['dump-callback']+xyz} ]; then
            echo 'BOX (specific) {'
                "${__BOX['dump-callback']?}" | __treeify 2 0
            echo '}'
        fi
        echo "BOX_CALLBACKS (${#__BOX_CALLBACKS[@]} elements) {"
            local l_cb_label l_cb
            for l_cb_label in "${!__BOX_CALLBACKS[@]}"; do
                l_cb="${__BOX_CALLBACKS["$l_cb_label"]?}"
                printf '"%s"="%s" : ' "$l_cb_label" "$l_cb"
                if [ "${l_cb: -2}" = '()' ]; then
                    if ! declare -F "${l_cb::-2}"; then
                        printf '%s was not found\n' "$l_cb"
                    fi
                else
                    ls -l "$l_cb" 2>&1
                fi
            done | __treeify 2 0
        echo '}'
        echo -n 'RAW COMMAND:'; printf ' "%s"' "$@"; echo
    } | __box_log
    fi

    local l_raw_result
    local -i l_errfd l_renderer_code l_callback_code
    local -a l_result
    while :; do
        if config debug; then {
            printf "START DRAW BOX: %s (%s)\n" "$l_type" "$l_title"
        } | __box_log
        fi

        # Step 1: execute the renderer and parse the result as array
        case "$l_type" in
            # Do not capture results for boxes which are intended to display text only. By avoiding
            # command substitution ( $(cmd) ), which spawns a subshell, we reduce the box rendering
            # startup significantly. The errors will be captured by a dedicated FIFO file
            confirm|info|message|mixedprogress|pause|progcommand|progprogress|progress|progstdin| \
                tail|tailbg|text)
                exec {l_errfd}<>"$__BOXLIB_FIFO_RENDERER_ERROR"
                # NOTE: need to ensure stdin ALWAYS comes from a TTY for boxes that don't require
                # user input. Mainly this is needed for Whiptail, which is based on S-Lang C library
                # used to interact with the terminal. So, on some systems, S-Lang determines the TTY
                # by checking stderr first, and if it's not attached to a TTY, it checks stdin. In
                # our case, we always redirect stderr to a FIFO file, so only stdin is left, which
                # may be a pipe rather than a TTY, if user's program reads data from somewhere
                case "$l_type" in
                    mixedprogress|progprogress|progress|progstdin)
                        TERM="${__BOX['term']:-$TERM}" "$@";;
                    *) TERM="${__BOX['term']:-$TERM}" "$@" < /dev/tty
                esac >&2 2>&$l_errfd; l_renderer_code=$?
                ;;
            *)
                l_result=() l_raw_result=''
                local l_buf l_lf='' l_extra_lf='\n'
                # Compared to the buildlist, the checklist adds a trailing LF (bug?), so there's no
                # need for an extra LF
                case "$l_type" in checklist) l_extra_lf=''; esac
                # Read the renderer output line by line until EOF is reached. NOTE: read will exit
                # with code 1 when EOF is reached and contain the last chunk (renderer exit code)
                while IFS= read -r l_buf || ! l_renderer_code="$l_buf"; do
                    l_raw_result+="${l_lf}${l_buf}"
                    l_result+=("$l_buf")
                    l_lf=$'\n'
                done < <(TERM="${__BOX['term']:-$TERM}" "$@" 3>&1 1>&2 2>&3 < /dev/tty; printf $l_extra_lf'%d' $?)
                # Clear the result array to avoid the process results step as nothing is printed to
                # stdout when renderer exited with ESC or Ctrl+c, but the array will contain the LF
                # char, which converts to empty string
                if [ -z "$l_raw_result" ]; then
                    l_result=()
                fi
        esac
        if [ $l_renderer_code -ne "${DIALOG_EXTRA:-3}" ] &&
            [ $l_renderer_code -ne "${DIALOG_HELP:-2}" ] &&
            [ $l_renderer_code -ne "${DIALOG_OK:-0}" ] &&
            [ $l_renderer_code -ne "${DIALOG_ITEM_HELP:-4}" ] &&
            [ $l_renderer_code -ne "${DIALOG_TIMEOUT:-5}" ] && {
                # Whiptail may exit with code 1 when using unknown arguments, whereas Dialog uses
                # -1 which translates to 255 in shell
                [ $l_renderer_code -ne "${DIALOG_CANCEL:-1}" ] || ! config isDialogRenderer >/dev/null
            }; then
            # Read all the errors from the descriptor pointing to the dedicated FIFO file, if any.
            # Note that, we'll stop after 100ms to avoid the program hang due to the blocking-mode
            if [ ${l_errfd+xyz} ]; then
                IFS= read -r -d '' -t .1 l_raw_result <&$l_errfd
                exec {l_errfd}>&-
                unset l_errfd
            fi

            # Persist renderer errors in the file when in debug mode, or propagate errors to stderr
            if [ -n "$l_raw_result" ]; then
                local l_error
                printf -v l_error "renderer error: %s (%s): %s\n" "$l_type" "$l_title" "$l_raw_result"
                if config debug; then
                    echo "$l_error" | __box_log
                else
                    echo "$l_error" >&2
                fi

                # NOTE: abort only when have printable errors, otherwise we cannot distinguish the
                # case when renderer exits with ESC key (255 code) or with internal error (255 code)
                if [ "${__BOX['abortOnRendererFailure']?}" = 'true' ]; then
                    exit $l_renderer_code
                fi
            fi

            # Clear the result array to avoid the process results step as it may contain just the
            # error message
            l_result=()
        fi
        if [ ${l_errfd+xyz} ]; then
            exec {l_errfd}>&-
            unset l_errfd
        fi
        if config debug; then {
            printf "END DRAW BOX: %s (%s) code=%d\n" "$l_type" "$l_title" $l_renderer_code
            echo "BOX RAW RESULT (${#l_raw_result} bytes):"
            if [ -n "$l_raw_result" ]; then
                echo "$l_raw_result"
            fi
            echo 'result ['
                __pretty_print_array l_result | __treeify 2 0
            echo ']'
        } | __box_log
        fi

        # Step 2: process the internal callbacks, if any
        if [ ${__BOX['capture-renderer-code-callback']+xyz} ]; then
            "${__BOX['capture-renderer-code-callback']?}" $l_renderer_code
        fi

        if [ ${__BOX['capture-renderer-result-callback']+xyz} ]; then
            "${__BOX['capture-renderer-result-callback']?}" "${l_result[@]}"
        fi

        if [ ${__BOX['capture-renderer-raw-result-callback']+xyz} ]; then
            local l_code_ok=0
            if config isDialogRenderer >/dev/null && [ ${DIALOG_OK+xyz} ]; then
                l_code_ok="$DIALOG_OK"
            fi
            if [ $l_renderer_code -eq "$l_code_ok" ]; then
                "${__BOX['capture-renderer-raw-result-callback']?}" <<< "$l_raw_result"
            fi
        fi

        if [ ${__BOX['result-validation-callback']+xyz} ]; then
            __BOX_VALIDATION_CALLBACK_RESPONSE=()
            local l_validation_code
            __set_shell_exit_code $l_renderer_code
            "${__BOX['result-validation-callback']?}" "${l_result[@]}"; l_validation_code=$?
            case $l_validation_code in
                "$__BOX_VALIDATION_CALLBACK_RETRY") continue;;
                "$__BOX_VALIDATION_CALLBACK_BREAK") break;;
                "$__BOX_VALIDATION_CALLBACK_PROPAGATE") :;;
                "$__BOX_VALIDATION_CALLBACK_SWAP_RESULT")
                    l_result=("${__BOX_VALIDATION_CALLBACK_RESPONSE[@]?}")
                    ;;
                "$__BOX_VALIDATION_CALLBACK_SWAP_RESULT_AND_RETCODE")
                    l_result=("${__BOX_VALIDATION_CALLBACK_RESPONSE[@]:1}")
                    ;&
                "$__BOX_VALIDATION_CALLBACK_SWAP_RETCODE")
                    l_renderer_code=${__BOX_VALIDATION_CALLBACK_RESPONSE[0]?}
                    ;;
                *) __panic "$l_type: Unhandled validation callback code: $l_validation_code"
            esac
            if config debug; then {
                echo 'RESULT-VALIDATION-CALLBACK {'; {
                    echo "validation_code=$l_validation_code"
                    echo "renderer_code=$l_renderer_code"
                    echo 'result ['
                        __pretty_print_array l_result | __treeify 2 0
                    echo ']'
                } | __treeify 2 0
                echo '}'
            } | __box_log
            fi
        fi

        if [ "${__BOX['sleep']?}" != 0 ]; then
            if config debug; then {
                echo 'SLEEPING:' "${__BOX['sleep']?}"; echo
            } | __box_log
            fi
            sleep "${__BOX['sleep']?}" || exit $?
        fi

        if [ "${__BOX['timeout']}" -gt 0 ] && ! config isDialogRenderer >/dev/null &&
            # Killed or crashed on timeout
            [ ${l_renderer_code?} -gt 128 ] && [ ${l_renderer_code?} -lt 255 ]; then
            # Unless overridden, we exit with code 255 on timeout to line up with the Dialog's
            # --timeout option
            local l_override_code="${DIALOG_TIMEOUT+5}"
            __set_shell_exit_code \
                "${__BOX['default-timeout-exit-code']:-${l_override_code:-255}}"; l_renderer_code=$?
        fi

        # Now that the renderer code is known, ensure it's the same code Dialog would return
        if ! config isDialogRenderer >/dev/null; then
            __whiptail_to_dialog_code $l_renderer_code; l_renderer_code=$?
        fi

        # Step 3: print the result to stdout, if required, or if no callbacks added to handle it
        if [ "${__BOX['printResult']?}" = 'true' ] || {
            [ -z "${__BOX['callback']?}" ] && [ ${#__BOX_CALLBACKS[@]} -eq 0 ]
        } && [ ${#l_result[@]} -gt 0 ]; then
            # Send the preprocessed result instead, if possible
            if [ ${__BOX['preprocess-result-callback']+xyz} ]; then
                __set_shell_exit_code $l_renderer_code
                "${__BOX['preprocess-result-callback']}" "${l_result[@]}"
            else
                printf "%s\n" "${l_result[@]}"
            fi
        fi

        # Step 4: send the per-result callbacks, if any
        if [ ${#__BOX_CALLBACKS[@]} -gt 0 ]; then
            local -i i l_n_results=${#l_result[@]} c
            for ((i = 0, c = 0; i < l_n_results && c < ${#__BOX_CALLBACKS[@]}; i++)); do
                local l_result_="${l_result[i]}"
                local l_callback="${__BOX_CALLBACKS["$l_result_"]:-}"
                if [ -n "$l_callback" ]; then
                    if config debug; then {
                        echo 'PROCESS BOX CALLBACK:' "$l_callback"
                    } | __box_log
                    fi

                    __box_exec_callback_sandboxed \
                        "$l_callback" $l_renderer_code "$l_result_"; l_callback_code=$?

                    if config debug; then {
                        printf "EXIT CALLBACK: %s (code=%d)\n" "$l_callback" $l_callback_code
                    } | __box_log
                    fi

                    if [ $l_callback_code -gt 0 ] &&
                        [ "${__BOX['abortOnCallbackFailure']?}" = 'true' ]; then
                        exit $l_callback_code
                    fi
                    unset 'l_result[i]'
                    c=$((c+1))
                fi
            done
            if config debug; then {
                echo 'result (remaining) ['
                    __pretty_print_array l_result | __treeify 2 0
                echo ']'
            } | __box_log
            fi
        fi

        # Step 5: process the remaining results that use the box common callback
        local l_callback="${__BOX['callback']?}"
        if [ -n "$l_callback" ] && {
            [ $l_renderer_code -eq "${DIALOG_EXTRA:-3}" ] ||
            [ $l_renderer_code -eq "${DIALOG_HELP:-2}" ] ||
            [ $l_renderer_code -eq "${DIALOG_OK:-0}" ] ||
            [ $l_renderer_code -eq "${DIALOG_ITEM_HELP:-4}" ] ||
            [ "${__BOX['alwaysInvokeCallback']?}" = 'true' ]
        }; then
            if config debug; then {
                echo 'PROCESS BOX CALLBACK:' "$l_callback"
            } | __box_log
            fi

            __box_exec_callback_sandboxed \
                "$l_callback" $l_renderer_code "${l_result[@]}"; l_callback_code=$?

            if config debug; then {
                printf "EXIT CALLBACK: %s code=%d\n" "$l_callback" $l_callback_code
            } | __box_log
            fi

            if [ $l_callback_code -gt 0 ] && [ "${__BOX['abortOnCallbackFailure']?}" = 'true' ]; then
                exit $l_callback_code
            fi
        fi

        # Step 6: prevent the box from looping, if needed
        if [ $l_renderer_code -ne "${DIALOG_EXTRA:-3}" ] &&
            [ $l_renderer_code -ne "${DIALOG_HELP:-2}" ] &&
            [ $l_renderer_code -ne "${DIALOG_OK:-0}" ] &&
            [ $l_renderer_code -ne "${DIALOG_ITEM_HELP:-4}" ] ||
            [ "${__BOX['loop']?}" != 'true' ]; then
            break
        fi

        if config debug; then {
            printf "LOOP BOX: %s (%s)\n" "$l_type" "$l_title"
        } | __box_log
        fi

        # Clean up everything to ensure we don't mistakenly propagate the old values to the new box,
        # if it will be canceled
        unset l_callback_code l_errfd
        l_result=()
    done

    if [ ${l_errfd+xyz} ]; then
        exec {l_errfd}>&-
    fi

    if config debug; then {
        printf "EXIT BOX: %s (%s) code=%d\n" "$l_type" "$l_title" \
            "${l_callback_code:-${l_renderer_code?}}"
    } | __box_log
    fi

    __BOX['depth']=$((${__BOX['depth']?}-1))

    if [ "${__BOX['propagateCallbackExitCode']?}" = 'true' ] && [ ${l_callback_code+xyz} ]; then
        return "$l_callback_code"
    fi
    return ${l_renderer_code?}
}
readonly -f __box_exec
# }}}

# Execute the box renderer with the given arguments.
# Must be called in a subshell (e.g., command substitution ( $(cmd) ) operation).
# @hide
function __box_exec_renderer() { # {{{
    local l_renderer="${1?}"; shift
    if config isDialogRenderer >/dev/null || [ "${__BOX['timeout']}" -eq 0 ]; then
        "$l_renderer" "${@?}"
        return $?
    fi

    local l_bashpid=$BASHPID l_fifo l_stty_copy
    l_fifo="$(__create_fifo_file)"
    l_stty_copy="$(stty -g)"

    # Start a background process to monitor the FIFO file for the next byte from the renderer. Any
    # interaction with the box will produce bytes, such as escape codes, needed to manipulate the
    # terminal (e.g., move cursor, change character color, etc.). If no activity is detected within
    # the given timeout period, the renderer process will be killed. This effectively replicates the
    # Dialog's --timeout option
    while :; do
        read -r -t "${__BOX['timeout']}" -N 1
        case $? in
            0) continue;;
            1) break;;
        esac
        # Kill the most recent process in the parent subshell, which is the renderer process
        pkill -SIGINT -n -P $l_bashpid
        break
    done < "$l_fifo" &

    # Start the renderer to output the box drawings to both the terminal and the FIFO file
    local -i l_code
    "$l_renderer" "${@?}" > >(tee "$l_fifo"); l_code=$?
    if [ $l_code -gt 128 ] && [ $l_code -lt 255 ]; then # Killed or crashed
        # Newt-based terminal apps use S-Lang C library to interact with the terminal as follows:
        #    newtInit:
        #      SLsmg_init_smg (initializes SLsmg routines like alternate screen buffer)
        #      SLang_init_tty (prepares the TTY for single-character input)
        #      SLtt_set_cursor_visibility(0) (disables cursor)
        #
        #    newtFinished:
        #      SLtt_set_cursor_visibility(1) (enables cursor)
        #      SLsmg_reset_smg (ends SLsmg routines clearing the alternate screen buffer)
        #      SLang_reset_tty (resets the TTY input settings)
        #
        # As the renderer was killed on timeout, the newtFinished chain won't be triggered, meaning,
        # the terminal will be left in a messed-up state, so we should fix this...
        tput cnorm # enable cursor
        tput rmcup # remove alternate screen buffer
        stty "$l_stty_copy" # restore TTY input settings
    fi
    rm "$l_fifo"
    return $l_code
}
readonly -f __box_exec_renderer
# }}}

# Execute the user's callback in a "sandbox" (sub-shell).
# Args:
# - 1: callback to execute
# - 2: exit code to pass to the callback
# - 3...: arguments to pass to the callback, if any
# The returning value is the callback exit code.
# @hide
function __box_exec_callback_sandboxed() { # {{{
    local l_callback="${1?}"; shift
    local -i l_code="${1?}"; shift
    local -a l_args=("$@")
    local l_exported_vars
    l_exported_vars="$(__create_temp_file)" || exit $?

    # Step 1: preprocess the result, if required
    if [ ${__BOX['preprocess-result-callback']+xyz} ] && [ ${#l_args[@]} -gt 0 ]; then
        readarray -t l_args <<< "$(__set_shell_exit_code $l_code;
            "${__BOX['preprocess-result-callback']?}" "${l_args[@]}")"
    fi

    # Step 2: run the callback depending on type, then dump the exported vars and capture
    # the callback status code
    if [ -f "$l_callback" ]; then (
        local l_callback_code
        local l_file="$l_callback"
        if [ "${__BOX['changeToCallbackDir']?}" = 'true' ]; then
            cd "${l_file%/*}" || return $?
            l_file="${l_file##*/}"
        fi
        # External executable as callback
        if [ -x "$l_file" ]; then
            # In order to execute, ensure the non-absolute files are prefixed with "./" to
            # reference the current directory. It's ok if the callback is already prefixed
            if [ "${l_file:0:1}" != '/' ]; then
                l_file="./$l_file"
            fi
            "$l_file" "${l_args[@]}"; l_callback_code=$?
            # We can't capture exported vars from executables, even if it's a shell script,
            # so we remove the file here to avoid processing an empty file
            rm "$l_exported_vars"
        else # shell file as callback
            # Set the $? before sourcing the callback
            __set_shell_exit_code $l_code
            # shellcheck disable=1090
            source "$l_file" "${l_args[@]}"; l_callback_code=$?
            export -p > "$l_exported_vars"
        fi
        return $l_callback_code

        # Local function as callback if ends with "()"
    ) elif [ "${l_callback: -2}" = '()' ]; then (
        local l_callback_code
        local l_fn="$l_callback"
        l_fn="${l_fn::-2}"
        # Set the $? before invoking the callback
        __set_shell_exit_code $l_code
        "$l_fn" "${l_args[@]}"; l_callback_code=$?
        export -p > "$l_exported_vars"
        return $l_callback_code
    ) else
        __panic "${__BOX['type']?}: The callback is not a file nor a local function: $l_callback"
    fi; local l_callback_code=$?

    # Step 3: replace the old exported vars with those dumped in the sub-shell, if any
    if [ -s "$l_exported_vars" ]; then
        # shellcheck disable=1090
        source <(sed 's/^declare/& -g/' "$l_exported_vars") || exit $?
    fi
    rm "$l_exported_vars"

    # Step 4: exit with the code returned by the callback
    return $l_callback_code
}
readonly -f __box_exec_callback_sandboxed
# }}}

function __box_print_log_header() { # {{{
    cat <<- EOL
===========================================================
boxlib v$__BOXLIB_VERSION (recorded on $(date -R))
===========================================================
Bash Version           : $BASH_VERSION
System Info (uname)    :
  System Name          : $(uname -s)
  Node Name            : $(uname -n)
  Kernel Release       : $(uname -r)
  Kernel Version       : $(uname -v)
  Machine              : $(uname -m)
  Processor Type       : $(uname -p 2>/dev/null || echo 'N/A')
  Hardware Platform    : $(uanem -i 2>/dev/null || echo 'N/A')
  OS                   : $(uname -o)
Renderer Error FIFO    : $(ls -l "$__BOXLIB_FIFO_RENDERER_ERROR")
===========================================================
EOL
}
readonly -f __box_print_log_header
# }}}

# Helper function to log (w/formatting) everything coming from stdin to file.
# @hide
function __box_log() { # {{{
    __treeify "${__BOX['depth']}" >> "${__CONFIG['debug']}"
}
readonly -f __box_log
# }}}
