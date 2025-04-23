#!/usr/bin/env bash
# vim: set fdm=marker:

# @hide
declare -A __EDIT

# Sets up a new file edit box. Corresponds to the --editbox argument in Dialog.
# In Whiptail, this feature is emulated using the default editor.
# Also performs the actual drawing of the edit box.
function edit() { # {{{
    if [ $# -eq 1 ] && [ "$1" = 'help' ]; then
        __edit_help
        return 0
    fi

    # Clean up the old edit box
    __EDIT=(
        ['inPlace']='false'
    )

    local -a l_box_args
    local l_param l_value
    while [ $# -gt 0 ]; do
        l_param="${1%%=*}"
        l_value="${1#*=}"
        case "$l_param" in
            file|editor) __EDIT["$l_param"]="$l_value";;
            inPlace) __assert_bool "$l_value" && __EDIT["$l_param"]="${__BOOLS["$l_value"]?}";;
            text|text+) : Ignored;;
            *) l_box_args+=("$1")
        esac
        local l_code=$?
        if [ $l_code -gt 0 ]; then
            exit $l_code
        fi
        shift
    done

    if [ ! ${__EDIT['file']+xyz} ]; then
        __panic "edit: Missing 'file' option."
    fi
    if [ ! -f "${__EDIT['file']?}" ]; then
        __panic "edit: Cannot open file: ${__EDIT['file']?}"
    fi

    if [ ! ${__EDIT['editor']+xyz} ] && config isDialogRenderer >/dev/null; then
        __box 'edit' text="${__EDIT['file']?}" "${l_box_args[@]}"
        __box_set_dump_callback '__edit_dump_callback'
        if [ "${__EDIT['inPlace']?}" = 'true' ]; then
            __box_set_capture_renderer_raw_result_callback '__edit_capture_renderer_raw_result_callback'
        fi
        __box_draw
    else
        if [ -z "${__EDIT['editor']-}" ]; then
            __EDIT['editor']="$(__find_default_editor)"
        fi
        __box 'edit' "${l_box_args[@]}"
        __box_set_dump_callback '__edit_dump_callback'
        if [ "${__EDIT['inPlace']?}" = 'true' ]; then
            __box_exec "${__EDIT['editor']?}" "${__EDIT['file']?}"
        else
            local l_file_copy
            l_file_copy="$(__create_temp_file)" &&
            # Append the original file name to enable syntax highlighting based on the extension
            mv "$l_file_copy" "${l_file_copy}_${__EDIT['file']##*/}" || exit $?; l_file_copy="$_"

            cp "${__EDIT['file']?}" "$l_file_copy" && (
                trap 'rm "'"$l_file_copy"'"' EXIT
                __box_exec '__edit_exec_editor_and_print_file' "${__EDIT['editor']?}" "$l_file_copy"
            )
        fi
    fi
} # }}}

# @hide
function __edit_exec_editor_and_print_file() { # {{{
    local l_editor="${1?}" l_file="${2?}"
    "$l_editor" "$l_file"; local l_editor_code=$?
    if [ $l_editor_code -eq 0 ]; then
        cat "$l_file" >&2 # print to stderr, as it will be later redirected to stdout
        return $?
    fi
    return $l_editor_code
}
readonly -f __edit_exec_editor_and_print_file
# }}}

# @hide
function __edit_capture_renderer_raw_result_callback() { # {{{
    cat > "${__EDIT['file']?}"
}
readonly -f __edit_capture_renderer_raw_result_callback
# }}}

# @hide
function __edit_dump_callback() { # {{{
    echo 'EDIT {'
        __pretty_print_array __EDIT | __treeify 2 0
    echo '}'
}
readonly -f __edit_dump_callback
# }}}
