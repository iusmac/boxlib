#!/usr/bin/env bash
# vim: set fdm=marker:

# @hide
declare -A __LIST
# @hide
declare -a __LIST_ENTRIES

# Sets up a new list box. Corresponds to --buildlist, --checklist, --radiolist & --treeview arguments
# in Dialog/Whiptail.
# In Whiptail, the buildlist feature is emulated using the checklist box. The treeview feature is
# emulated using the radiolist box.
# If 'type' option not specified, then a checklist will be selected.
function list() { # {{{
    if [ $# -eq 1 ] && [ "$1" = 'help' ]; then
        __list_help
        return 0
    fi

    # Clean up the old list
    __LIST=(
        ['type']='checklist'
        ['listHeight']=0
        ['prefix']=''
        ['keepPrefix']='false'
    )
    __LIST_ENTRIES=()

    local -a l_box_args l_entry_args
    local l_param l_value l_raw_param l_parsing_entries=0
    while [ $# -gt 0 ]; do
        # Parse & collect list entries in square brackets to process them separately later
        if [ $l_parsing_entries -eq 1 ]; then
            l_raw_param="$1"
            case "$l_raw_param" in
                '[') __panic "list: Missing the closing square bracket (]) for the list entry: ${l_entry_args[*]}";;
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
            type) __list_set_type "$l_value";;
            listHeight) __LIST["$l_param"]="$l_value";;
            prefix) __list_set_prefix_type "$l_value";;
            keepPrefix) __assert_bool "$l_value" && __LIST["$l_param"]="${__BOOLS["$l_value"]?}";;
            *) l_box_args+=("$1")
        esac
        local l_code=$?
        if [ $l_code -gt 0 ]; then
            exit $l_code
        fi
        shift
    done

    if [ $l_parsing_entries -eq 1 ]; then
        __panic "list: Missing the closing square bracket (]) for the list entry: ${l_entry_args[*]}"
    fi

    local l_type="${__LIST['type']?}"
    if ! config isDialogRenderer >/dev/null; then
        if [ "$l_type" = 'buildlist' ] || [ "$l_type" = 'treelist' ]; then
            case "$l_type" in
                buildlist) l_type='checklist';;
                treelist) l_type='radiolist';;
            esac
            # Tag column is suppressed in Dialog's buildlist/treelist box
            l_box_args+=(\( --notags \))
        fi
    fi
    __box "$l_type" "${l_box_args[@]}"
    __box_set_dump_callback '__list_dump_callback'
    __box_set_preprocess_result_callback '__list_preprocess_result_callback'

    local -a l_entry
    local l_arg
    for l_arg in "${l_entry_args[@]}"; do
        case "$l_arg" in
            '[') unset l_entry;;
            ']') listEntry "${l_entry[@]}";;
            *) l_entry+=("$l_arg")
        esac
    done
} # }}}

# Adds a new choice to the list.
function listEntry() { # {{{
    if [ $# -eq 1 ] && [ "$1" = 'help' ]; then
        __list_entry_help
        return 0
    fi
    if ! __list_box_created; then
        __panic "listEntry: Cannot create a choice entry without a list box."
    fi
    local l_title='' l_summary='' l_state='OFF' l_callback='' l_param l_value l_depth
    while [ $# -gt 0 ]; do
        l_param="${1%%=*}"
        l_value="${1#*=}"
        case "$l_param" in
            title) l_title="$l_value";;
            summary) l_summary="$l_value";;
            selected)
                __assert_bool "$l_value" && # NOTE: using if condition to propagate the error code
                if [ "${__BOOLS["$l_value"]?}" = 'true' ]; then
                    l_state='ON'
                fi
                ;;
            callback) l_callback="$l_value";;
            depth) l_depth="$l_value";;
            *) __panic "listEntry: Unrecognized argument: $1"
        esac
        local l_code=$?
        if [ $l_code -gt 0 ]; then
            exit $l_code
        fi
        shift
    done

    if [ -n "$l_callback" ] && [ -z "$l_title" ] && [ "${__LIST['prefix']?}" != 'num' ]; then
        __panic 'listEntry: A non-empty title is required when the callback option is used, or, set prefix="num".'
    fi

    if [ "${__LIST['type']?}" = 'treelist' ]; then
        if [ ${l_depth+xyz} ]; then
            if ! [ "${l_depth?}" -ge 0 ]; then
                __panic "listEntry: Invalid depth value: $l_depth"
            fi
        else
            l_depth=0
        fi
    elif [ ${l_depth+xyz} ]; then
        __panic "listEntry: The 'depth' option can only be used with a tree list."
    fi

    if [ -n "${__LIST['prefix']?}" ]; then
        local l_batch_size=3
        if [ "${__LIST['type']?}" = 'treelist' ] && config isDialogRenderer >/dev/null; then
            l_batch_size=4
        fi
        local l_prefix n=$(( (${#__LIST_ENTRIES[@]} + l_batch_size) / l_batch_size ))
        case "${__LIST['prefix']?}" in
            num) l_prefix="$n";;
            alpha)
                local -n l_charset=__ALPHA_CHARSET
                local l_char="${l_charset[(n-1) % ${#l_charset[@]}]}"
                l_prefix="$l_char"
                ;;
            alphanum*)
                local -n l_charset=__ALPHANUM1_CHARSET
                case "${__LIST['prefix']?}" in
                    alphanum0) local -n l_charset=__ALPHANUM0_CHARSET;;
                    # skip the 0 in 1-9,0,a-z sequence and jump to 'a'
                    alphanum) [ $n -ge 10 ] && n=$((n+1))
                esac
                l_prefix="${l_charset[(n-1) % ${#l_charset[@]}]}"
                ;;
        esac
        l_title="$l_prefix) $l_title"
        # Tag column is suppressed in Dialog's buildlist/treelist box, so add the prefix to the
        # summary too
        if [ "${__LIST['type']?}" = 'buildlist' ] || [ "${__LIST['type']?}" = 'treelist' ]; then
            l_summary="$l_prefix) $l_summary"
        fi
    fi

    if [ "${__LIST['type']?}" = 'treelist' ] && [ "$l_depth" -gt 0 ] &&
        ! config isDialogRenderer >/dev/null; then
        local i l_prefix=''
        for ((i = 0; i < l_depth; i++)); do
            l_prefix+='│  '
        done
        l_summary="${l_prefix}${l_summary}"
    fi

    __LIST_ENTRIES+=("$l_title" "$l_summary" "$l_state")
    if [ "${__LIST['type']?}" = 'treelist' ] && config isDialogRenderer >/dev/null; then
        __LIST_ENTRIES+=("$l_depth")
    fi

    # Wire up the entry with the specific callback, if specified
    if [ -n "$l_callback" ]; then
        __box_add_callback "$l_title" "$l_callback"
    fi
} # }}}

# Performs the actual drawing of the list.
# Must be called after the list box has been fully set up.
function listDraw() { # {{{
    if [ $# -gt 0 ]; then
        if [ $# -eq 1 ] && [ "$1" = 'help' ]; then
            __list_draw_help
            return 0
        fi
        __panic "listDraw: Unrecognized argument(s): $*"
    fi
    if ! __list_box_created; then
        __panic "listDraw: No list box to draw."
    fi
    if [ ${#__LIST_ENTRIES[@]} -eq 0 ]; then
        __panic "listDraw: Cannot draw a list box without entries."
    fi

    local l_list_height="${__LIST['listHeight']?}"
    case "$l_list_height" in
        *%)
            local l_num_entries=$(( ${#__LIST_ENTRIES[@]} / 3 ))
            l_list_height="$(__scale_value "$l_list_height" "$l_num_entries")"
            ;;
        auto) l_list_height=0;;
    esac

    __box_draw "$l_list_height" "${__LIST_ENTRIES[@]}"
} # }}}

# Helper to set the type of the list box with validation.
# @hide
function __list_set_type() { # {{{
    local -A l_list_types=(
        ['build']='buildlist'
        ['check']='checklist'
        ['radio']='radiolist'
        ['tree']='treelist'
    )
    local l_value="${1?}"
    if [ ! "${l_list_types["$l_value"]+xyz}" ]; then
        __panic "list: Unrecognized list type: $l_value. Possible types: ${!l_list_types[*]}"
    fi
    __LIST['type']="${l_list_types["$l_value"]}"
}
readonly -f __list_set_type
# }}}

# @hide
function __list_set_prefix_type() { # {{{
    local -A l_prefixes=(
        ['num']='num'
        ['alpha']='alpha'
		['alphanum']='alphanum'
		['alphanum0']='alphanum0'
		['alphanum1']='alphanum1'
    )
    local l_value="${1?}"
    if [ ! "${l_prefixes["$l_value"]+xyz}" ]; then
        __panic "list: Unrecognized prefix: $l_value. Possible prefixes: ${!l_prefixes[*]}"
    fi
    __LIST['prefix']="${l_prefixes["$l_value"]}"
}
readonly -f __list_set_prefix_type
# }}}

# The callback that will preprocess the selected choice entry before invoking client's callback.
# @hide
function __list_preprocess_result_callback() { # {{{
    local l_entry
    for l_entry; do
        # Drop the prefix from the selected entry name
        if [ -n "${__LIST['prefix']?}" ] && [ "${__LIST['keepPrefix']?}" = 'false' ]; then
            l_entry="${l_entry#* }" # '1) Option' => 'Option'
        fi
        printf "%s\n" "$l_entry"
    done
}
readonly -f __list_preprocess_result_callback
# }}}

# @hide
function __list_box_created() { # {{{
    case "${__BOX['type']:-}" in
        radiolist|checklist|buildlist|treelist) return 0
    esac
    return 1
}
readonly -f __list_box_created
# }}}

# @hide
function __list_dump_callback() { # {{{
    echo 'LIST {'
        __pretty_print_array __LIST | __treeify 2 0
    echo '}'
    echo 'LIST_ENTRIES {'
        local i l_batch_size=3
            if [ "${__LIST['type']?}" = 'treelist' ] && config isDialogRenderer >/dev/null; then
            l_batch_size=4
        fi
        for ((i = 0; i < ${#__LIST_ENTRIES[@]}; i += l_batch_size)); do
            printf 'title="%s" summary="%s" state=%s' "${__LIST_ENTRIES[i]}" "${__LIST_ENTRIES[i+1]}" \
                "${__LIST_ENTRIES[i+2]}"
            if [ $l_batch_size -eq 4 ]; then
                printf ' depth=%s' "${__LIST_ENTRIES[i+3]}"
            fi
            echo
        done | __treeify 2 0
    echo '}'
}
readonly -f __list_dump_callback
# }}}
