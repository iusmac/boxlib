#!/usr/bin/env bash
# vim: set fdm=marker:

# @hide
declare -a __BREADCRUMBS

# Generates the header string to be displayed on the backdrop, at the top of the screen.
# This will include the breadcrumb stack.
# @hide
function __header_generate() { # {{{
    local l_header="${__CONFIG['headerTitle']?}"
    printf '%s' "$l_header"

    local l_total=${#__BREADCRUMBS[@]}
    if [ "$l_total" -gt 0 ]; then
        if [ -n "$l_header" ]; then
            printf ' | '
        fi
        local i l_delim="${__CONFIG['breadcrumbsDelim']?}"
        printf '%s' "${__BREADCRUMBS[0]}"
        for ((i = 1; i < l_total; i++)); do
            printf '%s%s' "$l_delim" "${__BREADCRUMBS[i]}"
        done
    fi
}
readonly -f __header_generate
# }}}

# Push a new element to the end of the breadcrumb stack.
# @hide
function __header_breadcrumbs_push() { # {{{
    local l_text="${1?}"
    if [ -z "$l_text" ]; then
        local l_total=${#__BREADCRUMBS[@]}
        l_text="Unnamed box #$((l_total + 1))"
    fi
    __BREADCRUMBS+=("$l_text")
}
readonly -f __header_breadcrumbs_push
# }}}

# Remove the last element from the breadcrumb stack.
# @hide
function __header_breadcrumbs_pop() { # {{{
    unset '__BREADCRUMBS[-1]'
}
readonly -f __header_breadcrumbs_pop
# }}}
