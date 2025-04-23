#!/usr/bin/env bash

if [ ! ${BOXLIB_LOADED+xyz} ]; then
    if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ] || {
        [ "${BASH_VERSINFO[0]:-0}" -eq 4 ] && [ "${BASH_VERSINFO[1]:-0}" -lt 3 ]
    }; then
        printf 'boxlib requires Bash 4.3 or later (you have %s)\n' "${BASH_VERSION:-N/A}" >&2
        exit 1
    fi

    # Setup global library vars for internal use
    readonly __BOXLIB_VERSION='1.3-beta'
    __BOXLIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || return $?
    readonly __BOXLIB_DIR

    # Create a FIFO file that will be used to capture stderr from the renderer
    readonly __BOXLIB_FIFO_RENDERER_ERROR="$__BOXLIB_DIR/.renderer_err_$UID"
    if [ -e "$__BOXLIB_FIFO_RENDERER_ERROR" ]; then
        rm "$__BOXLIB_FIFO_RENDERER_ERROR" || return $?
    fi
    if [ ! -p "$__BOXLIB_FIFO_RENDERER_ERROR" ]; then
        mkfifo -m 0600 "$__BOXLIB_FIFO_RENDERER_ERROR" || return $?
    fi

    # Load core library components
    source "$__BOXLIB_DIR"/utils.sh &&
    source "$__BOXLIB_DIR"/config.sh &&
    source "$__BOXLIB_DIR"/header.sh &&
    source "$__BOXLIB_DIR"/help.sh &&
    # Load box components
    source "$__BOXLIB_DIR"/boxes/box.sh &&
    source "$__BOXLIB_DIR"/boxes/calendar.sh &&
    source "$__BOXLIB_DIR"/boxes/confirm.sh &&
    source "$__BOXLIB_DIR"/boxes/edit.sh &&
    source "$__BOXLIB_DIR"/boxes/form.sh &&
    source "$__BOXLIB_DIR"/boxes/info.sh &&
    source "$__BOXLIB_DIR"/boxes/input.sh &&
    source "$__BOXLIB_DIR"/boxes/list.sh &&
    source "$__BOXLIB_DIR"/boxes/menu.sh &&
    source "$__BOXLIB_DIR"/boxes/pause.sh &&
    source "$__BOXLIB_DIR"/boxes/program.sh &&
    source "$__BOXLIB_DIR"/boxes/progress.sh &&
    source "$__BOXLIB_DIR"/boxes/range.sh &&
    source "$__BOXLIB_DIR"/boxes/selector.sh &&
    source "$__BOXLIB_DIR"/boxes/text.sh &&
    source "$__BOXLIB_DIR"/boxes/timepicker.sh || return $?

    __config_init || return $?

    readonly BOXLIB_LOADED=1
else
    return 0
fi
