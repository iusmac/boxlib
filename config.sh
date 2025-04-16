#!/usr/bin/env bash
# vim: set fdm=marker:

# @hide
declare -A __CONFIG
# @hide
declare -a __CONFIG_BOX_ARGS __CONFIG_BOX_RAW_USER_ARGS __CONFIG_BOX_RAW_USER_WIDGET_ARGS

# Configure the project at the global level.
function config() { # {{{
    if [ $# -eq 0 ] || { [ $# -eq 1 ] && [ "$1" = 'help' ]; }; then
        __config_help
        return 0
    fi

    while [ $# -eq 1 ]; do
        case "$1" in
            debug) test "${__CONFIG['debug']?}" != '/dev/null';;
            isDialogRenderer)
                case "${__CONFIG['rendererName']?}" in
                    dialog) echo 'true'; __set_shell_exit_code 0;;
                    *) echo 'false'; __set_shell_exit_code 1
                esac
                ;;
            *) break
        esac
        return $?
    done

    local l_param l_value l_raw_arg l_parsing_raw_args=0 l_parsing_widget_args=0
    while [ $# -gt 0 ]; do
        if [ $l_parsing_raw_args -eq 1 ]; then
            l_raw_arg="$1"
            case "$l_raw_arg" in
                '(') __panic "config: Missing the closing round bracket ')' for the Dialog/Whiptail-specific arguments: ( ${__CONFIG_BOX_RAW_USER_ARGS[*]} ${__CONFIG_BOX_RAW_USER_WIDGET_ARGS[*]}";;
                ')') l_parsing_raw_args=0; l_parsing_widget_args=0;;
                # Prevent the user from tampering the input/output
                --output-separator|--output-fd|--input-fd) shift;; # skip the value as well
                --separate-output);;
                # Allow ( and ) to be used as-is when escaped
                '\('|'\)') l_raw_arg="${l_raw_arg:1}";&
                *)
                    # Collect widget args separately to append them at the very end so Dialog can
                    # parse them correctly
                    if [ $l_parsing_widget_args -eq 1 ] || [ "$l_raw_arg" = '--and-widget' ]; then
                        l_parsing_widget_args=1
                        __CONFIG_BOX_RAW_USER_WIDGET_ARGS+=("$l_raw_arg")
                    else
                        __CONFIG_BOX_RAW_USER_ARGS+=("$l_raw_arg")
                    fi
            esac
            shift
            continue
        fi
        case "$1" in
            '(')
                l_parsing_raw_args=1
                shift
                continue
                ;;
            reset)
                __CONFIG_BOX_ARGS=()
                __CONFIG_BOX_RAW_USER_ARGS=()
                __CONFIG_BOX_RAW_USER_WIDGET_ARGS=()
                __config_init
                shift
                continue
                ;;
        esac
        l_param="${1%%=*}"
        l_value="${1#*=}"
        case "$l_param" in
            # Specific options
            rendererPath) __config_set_renderer_binary_path "$l_value";;
            rendererName) __config_set_renderer_name "$l_value";;
            debug) __config_set_debug "$l_value";;
            # Generic raw options
            headerTitle|breadcrumbsDelim) __CONFIG["$l_param"]="$l_value";;
            *) __CONFIG_BOX_ARGS+=("$1")
        esac
        local l_code=$?
        if [ $l_code -gt 0 ]; then
            exit $l_code
        fi
        shift
    done

    if [ $l_parsing_raw_args -eq 1 ]; then
        __panic "config: Missing the closing round bracket ')' for the Dialog/Whiptail-specific arguments: ( ${__CONFIG_BOX_RAW_USER_ARGS[*]} ${__CONFIG_BOX_RAW_USER_WIDGET_ARGS[*]}"
    fi
} # }}}

# (Re-)initializes the config component.
# Should be called when sourcing the core component.
# @hide
function __config_init() { # {{{
    __CONFIG=(
        ['rendererBinary']='dialog'
        ['rendererName']='dialog'
        ['headerTitle']=''
        ['breadcrumbsDelim']=' > '
        ['debug']='/dev/null'
    )
    # Fallback to whiptail when cannot use dialog
    if [ "${BOXLIB_USE_WHIPTAIL:-0}" = '1' ] || ! which 'dialog' &>/dev/null; then
        if which 'whiptail' &>/dev/null; then
            __CONFIG['rendererBinary']='whiptail'
            __CONFIG['rendererName']='whiptail'
        else
            __panic 'config: Neither Dialog nor Whiptail was found in your system.'
        fi
    fi

    if [ -n "${BOXLIB_DEBUG-}" ]; then
        __config_set_debug "$BOXLIB_DEBUG"
    fi

    return 0
}
readonly -f __config_init
# }}}

# @hide
function __config_set_renderer_binary_path() { # {{{
    local l_exe="${1?}"
    if [ ! -x "$l_exe" ] && ! which "$l_exe" >/dev/null; then
        __panic "config: '$l_exe' is not an executable file or does not exist."
    fi
    __CONFIG['rendererBinary']="$l_exe"
}
readonly -f __config_set_renderer_binary_path
# }}}

# @hide
function __config_set_renderer_name() { # {{{
    local l_value="${1?}"
    case "$l_value" in
        whiptail|dialog) __CONFIG['rendererName']="$l_value";;
        *) __panic "config: Unrecognized renderer name: '$l_value'. Possible names: whiptail dialog"
    esac
} # }}}

# @hide
function __config_set_debug() { # {{{
    local l_value="${1?}"
    case "$l_value" in
        stdout|stderr) l_value="/dev/$l_value";;
    esac
    __CONFIG['debug']="${l_value:-/dev/null}"
}
readonly -f __config_set_debug
# }}}
