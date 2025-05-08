#!/usr/bin/env bash
# vim: set fdm=marker:

# @hide
declare -A __MENU
# @hide
declare -a __MENU_ENTRIES

# Sets up a new menu box. Corresponds to the --menu & --inputmenu arguments in Dialog/Whiptail.
# In Whiptail, the input menu is simulated using a normal menu and an input box.
function menu() { # {{{
    if [ $# -eq 1 ] && [ "$1" = 'help' ]; then
        __menu_help
        return 0
    fi

    # Clean up the old menu
    __MENU=(
        ['menuHeight']=0
        ['prefix']=''
        ['keepPrefix']='false'
        ['loop']='false'
        ['rename']='false'
        ['defaultEntry']=''
    )
    __MENU_ENTRIES=()

    local -a l_box_args l_entry_args
    local l_param l_value l_raw_param l_parsing_entries=0
    while [ $# -gt 0 ]; do
        # Parse & collect menu entries in square brackets to process them separately later
        if [ $l_parsing_entries -eq 1 ]; then
            l_raw_param="$1"
            case "$l_raw_param" in
                '[') __panic "menu: Missing the closing square bracket (]) for the menu entry: ${l_entry_args[*]}";;
                ']') l_parsing_entries=0;;
                # Allow [ and ] to be used as-is when escaped
                '\['|'\]') l_raw_param="${l_raw_param:1}";;
            esac
            l_entry_args+=("$l_raw_param")
            shift
            continue
        elif [ "$1" = '[' ]; then
            l_parsing_entries=1
            l_entry_args+=('[')
            shift
            continue
        fi
        l_param="${1%%=*}"
        l_value="${1#*=}"
        case "$l_param" in
            menuHeight) __MENU["$l_param"]="$l_value";;
            prefix) __menu_set_prefix_type "$l_value";;
            keepPrefix|loop|rename)
                __assert_bool "$l_value" && __MENU["$l_param"]="${__BOOLS["$l_value"]?}";;
            *) l_box_args+=("$1")
        esac
        local l_code=$?
        if [ $l_code -gt 0 ]; then
            exit $l_code
        fi
        shift
    done

    if [ $l_parsing_entries -eq 1 ]; then
        __panic "menu: Missing the closing square bracket (]) for the menu entry: ${l_entry_args[*]}"
    fi

    if [ "${__MENU['rename']?}" = 'true' ] && config isDialogRenderer >/dev/null; then
        __box 'inputmenu' "${l_box_args[@]}"
    else
        __box 'menu' "${l_box_args[@]}"
    fi
    __box_set_dump_callback '__menu_dump_callback'
    __box_set_preprocess_result_callback '__menu_preprocess_result_callback'
    if [ "${__MENU['rename']?}" = 'true' ] && ! config isDialogRenderer >/dev/null; then
        __box_set_result_validation_callback '__menu_inputmenu_result_validation_callback'
    fi
    __box_set_capture_renderer_result_callback '__menu_capture_renderer_result_callback'
    __box_set_capture_renderer_code_callback '__menu_capture_renderer_code_callback'

    local -a entry
    local arg
    for arg in "${l_entry_args[@]}"; do
        case "$arg" in
            '[') unset entry;;
            ']') menuEntry "${entry[@]}";;
            *) entry+=("$arg")
        esac
    done
} # }}}

# Adds a new entry to the menu list.
function menuEntry() { # {{{
    if [ $# -eq 1 ] && [ "$1" = 'help' ]; then
        __menu_entry_help
        return 0
    fi
    if [ "${__BOX['type']:-}" != 'menu' ] && [ "${__BOX['type']:-}" != 'inputmenu' ]; then
        __panic 'menuEntry: Cannot create a menu entry without a menu box.'
    fi
    local l_title='' l_summary='' l_selected='false' l_callback='' l_param l_value
    while [ $# -gt 0 ]; do
        l_param="${1%%=*}"
        l_value="${1#*=}"
        case "$l_param" in
            title) l_title="$l_value";;
            summary) l_summary="$l_value";;
            selected) __assert_bool "$l_value" && l_selected="${__BOOLS["$l_value"]?}";;
            callback) l_callback="$l_value";;
            *) __panic "menuEntry: Unrecognized argument: $1"
        esac
        local l_code=$?
        if [ $l_code -gt 0 ]; then
            exit $l_code
        fi
        shift
    done

    if [ -n "$l_callback" ] && [ -z "$l_title" ] && [ "${__MENU['prefix']?}" != 'num' ]; then
        __panic 'menuEntry: A non-empty title is required when the callback option is used, or, set prefix="num".'
    fi

    if [ -n "${__MENU['prefix']?}" ]; then
        local l_prefix n=$(( (${#__MENU_ENTRIES[@]} + 2) / 2 ))
        case "${__MENU['prefix']?}" in
            num) l_prefix="$n";;
            alpha)
                local -n l_charset=__ALPHA_CHARSET
                l_prefix="${l_charset[(n-1) % ${#l_charset[@]}]}"
                ;;
            alphanum*)
                local -n l_charset=__ALPHANUM1_CHARSET
                case "${__MENU['prefix']?}" in
                    alphanum0) local -n l_charset=__ALPHANUM0_CHARSET;;
                    # skip the 0 in 1-9,0,a-z sequence and jump to 'a'
                    alphanum) [ $n -ge 10 ] && n=$((n+1))
                esac
                l_prefix="${l_charset[(n-1) % ${#l_charset[@]}]}"
                ;;
        esac
        l_title="$l_prefix) $l_title"
    fi

    if [ "$l_selected" = 'true' ]; then
        __MENU['defaultEntry']="$l_title"
    fi

    __MENU_ENTRIES+=("$l_title" "$l_summary")

    # Wire up the entry with the specific callback, if specified
    if [ -n "$l_callback" ]; then
        __box_add_callback "$l_title" "$l_callback"
    fi
} # }}}

# Performs the actual drawing of the menu.
# Must be called after the menu box has been fully set up.
function menuDraw() { # {{{
    if [ $# -gt 0 ]; then
        if [ $# -eq 1 ] && [ "$1" = 'help' ]; then
            __menu_draw_help
            return 0
        fi
        __panic "menuDraw: Unrecognized argument(s): $*"
    fi
    if [ "${__BOX['type']:-}" != 'menu' ] && [ "${__BOX['type']:-}" != 'inputmenu' ]; then
        __panic "menuDraw: No menu box to draw."
    fi
    if [ ${#__MENU_ENTRIES[@]} -eq 0 ]; then
        __panic "menuDraw: Cannot draw a menu box without entries."
    fi

    local l_menu_height="${__MENU['menuHeight']?}"
    local l_num_entries=$(( ${#__MENU_ENTRIES[@]} / 2 ))
    case "$l_menu_height" in
        *%) l_menu_height="$(__scale_value "$l_menu_height" $l_num_entries)";;
        auto) l_menu_height=0;;
    esac
    if [ "$l_menu_height" -eq 0 ] && [ "${__MENU['rename']?}" = 'true' ] &&
        config isDialogRenderer >/dev/null; then
        # When using inputmenu and height is 0 (auto-size), Dialog doesn't calculate the menu height
        # for the entries. We need at least 3 rows to display 1 menu entry
        l_menu_height=$((l_num_entries * 3))
    fi

    local l_rc l_default_item_value_pos
    local -n l_extra_box_args=__BOX_RAW_USER_ARGS
    while :; do
        # Set the default entry item to the last selected entry, overriding the 'selected' option.
        # This is useful for maintaining context in looped menus
        if [ ${__MENU['last-entry']+xyz} ] || [ -n "${__MENU['defaultEntry']?}" ]; then
            if [ ${l_default_item_value_pos+xyz} ]; then
                l_extra_box_args[l_default_item_value_pos-1]="${__MENU['last-entry']?}"
            else
                l_extra_box_args+=('--default-item' "${__MENU['last-entry']:-"${__MENU['defaultEntry']?}"}")
                l_default_item_value_pos=${#l_extra_box_args[@]}
            fi
        fi

        __box_draw "$l_menu_height" "${__MENU_ENTRIES[@]}"; l_rc=$?

        # Ensure we respect the DIALOG_* exit status codes variables
        local -i l_renderer_code=${__MENU['renderer-code']?}
        if ! config isDialogRenderer >/dev/null; then
            __whiptail_to_dialog_code $l_renderer_code; l_renderer_code=$?
        fi

        # Prevent the menu box from looping, if needed
        if [ $l_renderer_code -ne "${DIALOG_EXTRA:-3}" ] &&
            [ $l_renderer_code -ne "${DIALOG_HELP:-2}" ] &&
            [ $l_renderer_code -ne "${DIALOG_OK:-0}" ] &&
            [ $l_renderer_code -ne "${DIALOG_ITEM_HELP:-4}" ] ||
            [ "${__MENU['loop']?}" != 'true' ]; then
            break
        fi
    done
    return "$l_rc"
} # }}}

# @hide
function __menu_set_prefix_type() { # {{{
    local -A l_prefixes=(
        ['num']='num'
		['alpha']='alpha'
		['alphanum']='alphanum'
		['alphanum0']='alphanum0'
		['alphanum1']='alphanum1'
    )
    local l_value="${1?}"
    if [ ! "${l_prefixes["$l_value"]+xyz}" ]; then
        __panic "menu: Unrecognized prefix type: $l_value. Possible prefixes: ${!l_prefixes[*]}"
    fi
    __MENU['prefix']="${l_prefixes["$l_value"]}"
}
readonly -f __menu_set_prefix_type
# }}}

# The callback that will preprocess the selected menu entry before invoking client's callback.
# @hide
function __menu_preprocess_result_callback() { # {{{
    local l_code=$? l_output="${1:-}"

    # Create the renamed summary when have one (comes from Whiptail)
    if [ "${__MENU['rename']?}" = 'true' ] && [ ${__MENU['renamed-summary']+xyz} ]; then
        l_output="RENAMED $l_output ${__MENU['renamed-summary']}"
    fi

    # Drop the prefix from the selected entry name
    if [ -n "${__MENU['prefix']?}" ] && [ "${__MENU['keepPrefix']?}" = 'false' ]; then
        if [ "${__MENU['rename']?}" = 'true' ] && [ $l_code -eq 3 ]; then
            # After renamed (renderer exited with code 3), temporarily strip off the 'RENAMED ' part
            # from the beginning of the output to remove the prefix
            l_output="${l_output#RENAMED }"
        fi

        l_output="${l_output#* }" # '1) Option' => 'Option'

        # Restore the 'RENAMED ' prefix
        if [ "${__MENU['rename']?}" = 'true' ] && [ $l_code -eq 3 ]; then
            l_output="RENAMED $l_output"
        fi
    fi

    printf "%s\n" "$l_output"
}
readonly -f __menu_preprocess_result_callback
# }}}

# Handle the selected entry renaming in an input box after it is selected
# @hide
function __menu_inputmenu_result_validation_callback() { # {{{
    local l_code=$?
    if [ $l_code -eq 0 ]; then # Entry selected
        local i l_total l_selected_entry="${1?}" l_selected_summary l_entry l_batch_size=2
        # Find the corresponding entry summary
        for ((i = 0, l_total = ${#__MENU_ENTRIES[@]}; i < l_total; i += l_batch_size)); do
            l_entry="${__MENU_ENTRIES[i]}"
            if [ "$l_selected_entry" = "$l_entry" ]; then
                l_selected_summary="${__MENU_ENTRIES[i+1]}"
                break
            fi
        done

        local l_input
        l_input="$(input \
            cancelLabel='Return' \
            text="$l_selected_entry" \
            value="$l_selected_summary" \
            width='max' \
            hideBreadcrumb='true')"; l_code=$?
        if [ $l_code -eq "${DIALOG_OK:-0}" ]; then
            # User pressed OK on the input box, so ensure the new summary is different
            if [ "$l_input" != "$l_selected_summary" ]; then
                __MENU['renamed-summary']="$l_input"
                # We exit with code 3 when user renamed the entry summary to line up with the
                # Dialog's behavior
                __BOX_VALIDATION_CALLBACK_RESPONSE[0]="${DIALOG_EXTRA:-3}"
                return "$__BOX_VALIDATION_CALLBACK_SWAP_RETCODE"
            fi
        else
            # Return to the menu when ESC or Return button is pressed
            return "$__BOX_VALIDATION_CALLBACK_RETRY"
        fi
    fi
    return "$__BOX_VALIDATION_CALLBACK_PROPAGATE"
}
readonly -f __menu_inputmenu_result_validation_callback
# }}}

# @hide
function __menu_capture_renderer_result_callback() { # {{{
    if [ $# -eq 1 ]; then
        __MENU['last-entry']="${1?}"
    fi
}
readonly -f __menu_capture_renderer_result_callback
# }}}

# @hide
function __menu_capture_renderer_code_callback() { # {{{
    __MENU['renderer-code']="${1?}"
}
readonly -f __menu_capture_renderer_code_callback
# }}}

# @hide
function __menu_dump_callback() { # {{{
    echo 'MENU {'
        __pretty_print_array __MENU | __treeify 2 0
    echo '}'
    echo 'MENU_ENTRIES {'
        local i l_batch_size=2
        for ((i = 0; i < ${#__MENU_ENTRIES[@]}; i += l_batch_size)); do
            printf 'title="%s" summary="%s"\n' "${__MENU_ENTRIES[i]}" "${__MENU_ENTRIES[i+1]}"
        done | __treeify 2 0
    echo '}'
}
readonly -f __menu_dump_callback
# }}}
