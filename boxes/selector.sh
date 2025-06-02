#!/usr/bin/env bash
# vim: set fdm=marker:

# @hide
declare -A __SELECTOR

# Sets up a new file/directory selector box. Corresponds to the --dselect & --fselect arguments in Dialog.
# In Whiptail this feature is emulated using a menu box.
# Also performs the actual drawing of the selector box.
function selector() { # {{{
    if [ $# -eq 1 ] && [ "$1" = 'help' ]; then
        __selector_help
        return 0
    fi

    # Clean up the old selector box
    __SELECTOR=(
        ['path']=''
        ['path-uncanonicalized']=''
        ['last-path']=''
        ['loop']=0
    )

    local l_param l_value l_type='fselect' l_code
    local -a l_box_args
    while [ $# -gt 0 ]; do
        l_param="${1%%=*}"
        l_value="${1#*=}"
        case "$l_param" in
            text|text+) __panic 'selector: "text" option is unsupported.';;
            filepath) __SELECTOR['path']="$l_value";;
            directory)
                l_type='dselect'
                __SELECTOR['path']="$l_value";;
            cancelLabel) __SELECTOR["$l_param"]="$l_value";;
            *) l_box_args+=("$1")
        esac
        l_code=$?
        if [ $l_code -gt 0 ]; then
            exit $l_code
        fi
        shift
    done

    if config isDialogRenderer >/dev/null; then
        local -a l_boxlib_args
        # Add cancel label option only if it was provided by the user to avoid showing nothing
        if [ ${__SELECTOR['cancelLabel']+xyz} ]; then
            l_boxlib_args+=(cancelLabel="${__SELECTOR['cancelLabel']?}")
        fi
        __box "$l_type" \
            text="${__SELECTOR['path']?}" \
            width='max' \
            height='max' \
            "${l_boxlib_args[@]}" "${l_box_args[@]}"
        __box_set_dump_callback '__selector_dump_callback'
        __box_draw
    else
        __SELECTOR['path-uncanonicalized']="${__SELECTOR['path']?}"
        __SELECTOR['path']="$(__selector_canonicalize_path "${__SELECTOR['path']?}")"

        local -a l_files
        while :; do
            local l_selected_name l_last_path="${__SELECTOR['last-path']?}" l_match_exactly=0
            # Paths ending with a slash point to a directory, so we must match them exactly to avoid
            # case when a directory partially matches a file, which is not the intended behavior
            if [ "${l_last_path: -1}" = '/' ]; then
                l_match_exactly=1
                l_last_path="${l_last_path::-1}"
            fi
            # Pre-select the last directory name, if any, when jumping to the parent directory with
            # (../). It also should be in the same the path, i.e., share the same common root
            # directory in case the path was changed manually using path editor
            if [ -n "$l_last_path" ] && [ "${l_last_path%/*}" = "${__SELECTOR['path']%/*}" ]; then
                l_selected_name="${l_last_path##*/}"
            else
                l_selected_name="${__SELECTOR['path']##*/}"
            fi

            # If the path doesn't end with a slash, it could be a file or a directory; in either
            # case, we can't apply the wildcard (*), so the path's tail should be removed
            if [ -n "${__SELECTOR['path']?}" ] && [ "${__SELECTOR['path']: -1}" != '/' ]; then
                __SELECTOR['path']="${__SELECTOR['path']%/*}/"
            fi

            # Create a list of the path contents depending on the selector type
            local l_nullglob_set=0
            shopt -q nullglob && l_nullglob_set=1
            shopt -s nullglob
            if [ "$l_type" = 'dselect' ]; then
                l_files=(
                    # ** Match .dot/ directories first! **
                    "${__SELECTOR['path']?}".*/
                    "${__SELECTOR['path']?}"*/
                )
            else
                l_files=(
                    # ** Match .dot files first! **
                    "${__SELECTOR['path']?}".*
                    "${__SELECTOR['path']?}"*
                )
            fi
            if [ $l_nullglob_set -eq 0 ]; then
                shopt -u nullglob
            fi

            # Set up menu box
            menu \
                text="${__SELECTOR['path-uncanonicalized']:-${__SELECTOR['path']?}}" \
                cancelLabel="Edit/${__SELECTOR['cancelLabel']:-Exit}" \
                "${l_box_args[@]}"
            __box_set_dump_callback '__selector_dump_callback'

            # Show (.) and (..) as the first entries. We want them even if the directory is empty or
            # cannot be opened (e.g., no perms), so that the user can select the current path with
            # (.) or jump to the parent with (..)
            menuEntry title='./'
            if [ "${__SELECTOR['path']?}" != '/' ]; then # show dot-dot unless root is reached
                menuEntry title='../'
            fi
            # Do not process the '.' and '..' at this point
            unset 'l_files[0]' 'l_files[1]'

            # Add directories first
            local i l_total=${#l_files[@]} l_last_match=''
            for ((i = 2; i < l_total + 2; i++)); do
                local l_file="${l_files[i]}"
                if [ "$l_type" = 'fselect' ]; then
                    if [ ! -d "$l_file" ]; then
                        continue
                    fi
                    # Remove this directory to create a file-only list when should also select files
                    unset 'l_files[i]'
                else
                    # Remove the trailing slash when globbing for directories only
                    l_file="${l_file::-1}"
                fi

                local l_name="${l_file##*/}"
                local l_selected='false'
                if [ "$l_name" = "${l_selected_name?}" ] || {
                    [ $l_match_exactly -eq 0 ] &&
                    [ "$l_last_match" != "${l_selected_name?}" ] &&
                    # Perform partial string match aka startsWith
                    [ "${l_name::${#l_selected_name}}" = "${l_selected_name?}" ]
                }; then
                    l_last_match="${l_selected_name?}"
                    l_selected='true'
                fi
                menuEntry \
                    title="$l_name/" \
                    summary=' folder' \
                    selected="$l_selected"
            done

            # Now, add files, if needed
            if [ "$l_type" = 'fselect' ]; then
                for l_file in "${l_files[@]}"; do
                    local l_name="${l_file##*/}"
                    local l_selected='false'
                    if [ "$l_name" = "${l_selected_name?}" ] || {
                        [ $l_match_exactly -eq 0 ] &&
                        [ "$l_last_match" != "${l_selected_name?}" ] &&
                        # Perform partial string match aka startsWith
                        [ "${l_name::${#l_selected_name}}" = "${l_selected_name?}" ]
                    }; then
                        l_last_match="${l_selected_name?}"
                        l_selected='true'
                    fi
                    menuEntry \
                        title="$l_name" \
                        summary=' file' \
                        selected="$l_selected"
                done
            fi

            __box_set_result_validation_callback '__selector_menu_result_validation_callback'
            __box_set_preprocess_result_callback '__selector_menu_preprocess_result_callback'

            menuDraw; l_code=$?
            if [ "${__SELECTOR['loop']?}" -eq 1 ]; then
                continue
            fi
            break
        done
        return $l_code
    fi
} # }}}

# @hide
function __selector_show_path_editor() { # {{{
    local l_code l_input l_path="${__SELECTOR['path-uncanonicalized']:-${__SELECTOR['path']?}}"
    l_input="$(input \
        cancelLabel="${__SELECTOR['cancelLabel']:-Exit}" \
        value="$l_path" \
        width='max' \
        hideBreadcrumb='true')"; l_code=$?
    case $l_code in
        # Update the provided path without "canonicalizing" it
        "${DIALOG_OK:-0}") __SELECTOR['path-uncanonicalized']="$l_input";;
        # When ESC is pressed, the input box will return empty, so we should reuse the old path
        "${DIALOG_ESC:-255}") l_input="$l_path"
    esac
    __SELECTOR['path']="$(__selector_canonicalize_path "$l_input")"
    return $l_code
}
readonly -f __selector_show_path_editor
# }}}

# @hide
function __selector_menu_result_validation_callback() { # {{{
    local l_code=$?
    if [ $l_code -eq 1 ]; then # Edit/Exit button pressed
        __selector_show_path_editor; l_code=$?
        if [ $l_code -eq 1 ]; then # Cancel button pressed
            __SELECTOR['loop']=0
            # Propagate the menu's code, which is also equals to 1
            return "$__BOX_VALIDATION_CALLBACK_PROPAGATE"
        fi
        # When user provided a new path or pressed ESC key, we return to the menu box
        __SELECTOR['last-path']=''
        __SELECTOR['loop']=1
        return "$__BOX_VALIDATION_CALLBACK_BREAK"
    elif [ $l_code -gt 1 ]; then
        __SELECTOR['loop']=0
        return "$__BOX_VALIDATION_CALLBACK_PROPAGATE"
    fi

    local l_entry="${1?}"
    # In Whiptail we emulate the selector using a menu box, so we must call the preprocess result
    # callback on the menu component for compatibility
    l_entry="$(__menu_preprocess_result_callback "$l_entry")"

    # Current entry was selected. The user should receive the path, whether canonicalized or not
    if [ "$l_entry" = './' ]; then
        __SELECTOR['loop']=0
        return "$__BOX_VALIDATION_CALLBACK_PROPAGATE"
    fi

    # Ensure to canonicalize the empty path to CWD (.) before modifying it
    if [ -z "${__SELECTOR['path']?}" ]; then
        __SELECTOR['path']="$(__selector_canonicalize_path '.')"
    fi

    # Remove the uncanonicalized path when the user selected a canonical path
    __SELECTOR['path-uncanonicalized']=''

    # Jump to the parent directory
    if [ "$l_entry" = '../' ]; then
        local l_last_path="${__SELECTOR['path']?}"
        local l_last_path_trailing_char="${l_last_path: -1}"
        # Temporarily strip off the last char (could be a slash) so we can remove the path tail
        l_last_path="${l_last_path::-1}"
        __SELECTOR['path']="${l_last_path%/*}/"
        __SELECTOR['last-path']="${l_last_path}${l_last_path_trailing_char}"
        __SELECTOR['loop']=1
        return "$__BOX_VALIDATION_CALLBACK_BREAK"
    fi

    # Jump inside the selected directory
    if [ "${l_entry: -1}" = '/' ]; then
        __SELECTOR['loop']=1
        __SELECTOR['last-path']=''
        __SELECTOR['path']+="$l_entry"
        return "$__BOX_VALIDATION_CALLBACK_BREAK"
    fi

    # File is selected. The user should receive the canonical filepath
    __SELECTOR['loop']=0
    __SELECTOR['path']+="$l_entry"
    return "$__BOX_VALIDATION_CALLBACK_PROPAGATE"
}
readonly -f __selector_menu_result_validation_callback
# }}}

# @hide
function __selector_menu_preprocess_result_callback() { # {{{
    echo "${__SELECTOR['path-uncanonicalized']:-${__SELECTOR['path']?}}"
}
readonly -f __selector_menu_preprocess_result_callback
# }}}

# Helper function to canonicalize the filepath.
# - Expands dot (.) and dot-dot (..) to absolute path
# - Resolves path relative to current working directory
# - Does not expand symbolic links
# - Consumes all the parent directory references (../)
# - Removes double slashes
# - Preserves the trailing slash on directories
# - Preserves the trailing slash dot (/.)
# @hide
function __selector_canonicalize_path() { # {{{
    local l_path="${1?}" l_keep_trailing_slash=0 l_keep_trailing_slash_dot=0

    if [ -z "$l_path" ]; then
        # Exit earlier as realpath command cannot deal with empty paths
        return
    fi

    if [ "$l_path" = '.' ]; then
        l_path+='/'
    fi

    case "$l_path" in
        */) l_keep_trailing_slash=1;;
        */.) l_keep_trailing_slash_dot=1;;
    esac

    local l_path_uncanonicalized="$l_path"
    # Try canonicalize path using realpath from GNU coreutils or fallback to a hand-crafted solution
    if ! l_path="$(realpath --quiet --canonicalize-missing --no-symlinks "$l_path" 2>/dev/null)"; then
        l_path="$l_path_uncanonicalized"
        if [ "${l_path::1}" != '/' ]; then
            # Paths that don't start with a slash are relative, so must resolve them relative to PWD
            l_path="$(pwd)/$l_path"
        fi
        local IFS='/' l_part
        local -a l_parts
        for l_part in $l_path; do
            case "$l_part" in
                ''|.) ;; # Ignore extra slashes (//) and trailing dots (/.)
                '..') [ ${#l_parts[@]} -gt 0 ] && unset 'l_parts[-1]';; # Remove last component
                *) l_parts+=("$l_part")
            esac
        done
        # Reassemble the canonicalized path
        l_path="/${l_parts[*]}"
    fi

    if [ "$l_path" = '/' ]; then
        l_keep_trailing_slash=0
        l_keep_trailing_slash_dot=0
    fi

    if [ "$l_keep_trailing_slash" -eq 1 ]; then
        l_path+='/'
    elif [ "$l_keep_trailing_slash_dot" -eq 1 ]; then
        l_path+='/.'
    fi
    echo "$l_path"
}
readonly -f __selector_canonicalize_path
# }}}

# @hide
function __selector_dump_callback() { # {{{
    echo 'SELECTOR {'
        __pretty_print_array __SELECTOR | __treeify 2 0
    echo '}'
    # Since this feature is emulated in Whiptail using a menu box, need to dump it too
    if ! config isDialogRenderer >/dev/null; then
        __menu_dump_callback
    fi
}
readonly -f __selector_dump_callback
# }}}
