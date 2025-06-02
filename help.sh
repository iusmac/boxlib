#!/usr/bin/env bash
# vim: set fdm=marker:

# @hide
function __box_help() { # {{{
    cat << EOL
Usage: ${1?} <options>

Tip: the '+=' operator will concatenate with the previous '<option>=' value, e.g.:
    $1 \
      title='My very long ' \
      title+='box title'.

Common options:
    title= title+=
        The string that is displayed at the top of the box.
        Same as using Whiptail/Dialog's '--title' option.

        Defaults to an empty string.

    text= text+=
        The string that is displayed inside the box.
        Defaults to an empty string.

    width=
        The width of the box.
        Use 'auto' or '0' to auto-size to fit the contents. Use 'max' or '-1' to maximize.
        Can be denoted using percent sign, (e.g., '50%'), to adjust dynamically based on
        the 'tput cols' command.
        Defaults to: 0 (auto adapt to content. Also requires 'height=0').

    height=
        The height of the box.
        Use 'auto' or '0' to auto-size to fit the contents. Use 'max' or '-1' to maximize.
        Can be denoted using percent sign, (e.g., '50%'), to adjust dynamically based on
        the 'tput lines' command.
        Defaults to: 0 (auto adapt to content. Also requires 'width=0').

    callback=
        The callback to receive the result(s) from the box. The callback will be:
        - invoked as a local function if it ends with "()"
        - executed if it's a file with the "execute" bit set
        - sourced as a shell script file if it's none of the above

        In all cases, the callback should expect the result(s) as input parameters.
        When invoked, the \$? variable will contain the exit code from the renderer (Whiptail/Dialog).

        NOTE:
            - The callback execution will be "sandboxed", i.e., it will run in a sub-shell.
              This ensures the interaction is isolated.

            - If the callback is a relative path to a file, then it will be searched starting
              from the working directory.
              Also, the CWD will be changed to where the callback file is located before
              executing/sourcing it. To disable, set 'changeToCallbackDir=false'.

    changeToCallbackDir=
        Whether to change the working directory to where the callback script/executable
        is located before executing/sourcing it.
        Possible values: 'true' (or 1), 'false' (or 0).
        Defaults to: 'true'.

    abortOnCallbackFailure=
        Whether to abort immediately when the callback exits with a non-zero code.
        This will cause the whole callback chain to be interrupted including this box.
        For example, if applied on the root box that is the entry point for all boxes (e.g., main menu),
        then the app will exit. Useful for debugging/development purposes or in combination with 'loop=true' option.
        Possible values: 'true' (or 1), 'false' (or 0).
        Defaults to: 'false'.

    propagateCallbackExitCode=
        Whether to propagate the callback exit code instead of the renderer exit code when the box exits.
        Also, if no callback is provided, the renderer exit code will be used.
        Possible values: 'true' (or 1), 'false' (or 0).
        Defaults to: 'true'.

    alwaysInvokeCallback=
        Whether to invoke the callback even if the renderer (Whiptail/Dialog) exited with a non-zero code.
        A non-zero code means the user pressed ESC key or "Cancel" button or answered "No".
        When set to 'true', the callback will always be invoked, and the \$? variable will contain the
        exit code from the renderer.
        Possible values: 'true' (or 1), 'false' (or 0).
        Defaults to: 'false'.

    printResult=
        Whether to print the result(s) to stdout, each on a new line, after the box exits.
        Possible values: 'true' (or 1), 'false' (or 0).
        Defaults to: 'false'.

    abortOnRendererFailure=
        Whether to abort immediately when the box renderer (Whiptail/Dialog) exits with a non-zero
        code AND with an error message printed to the standard error.
        No callbacks will be invoked even if 'alwaysInvokeCallback' option has been used.
        Useful to fail-fast on renderer errors, such as invalid options.
        You may also want to combine it with the 'abortOnCallbackFailure=true' option, to cause the whole
        callback chain, if any, to be interrupted.
        Possible values: 'true' (or 1), 'false' (or 0).
        Defaults to: 'false'.

    loop=
        Whether to loop the box until it exits with a non-zero code. Mainly useful for menus or when
        used in combination with 'abortOnCallbackFailure=true' option to control the loop granularly.
        Possible values: 'true' (or 1), 'false' (or 0).
        Defaults to: 'false'.

    hideBreadcrumb=
        Whether to hide the box from the breadcrumbs stack displayed at the top of the screen.
        Possible values: 'true' (or 1), 'false' (or 0).
        Defaults to: 'false'.

    sleep=
        Sleep (delay) for the given number of seconds after the box exits with a zero code.
        Useful when a pause is needed before displaying the next box
        NOTE: this is not the same as using Dialog's '--sleep' option. Instead, the 'sleep' command
        will be used after the box has been cleared.

    timeout=
        Timeout (exit with error code) if no user response within the given number of seconds.
        Same as using Dialog's '--timeout' option. This behavior is replicated internally by the
        library when using Whiptail.
        A timeout of zero seconds is ignored and the decimal part will be dropped.

    term=
        The value for the \$TERM variable that will be used to render this box.
        Defaults to: "\$TERM".

    ( --opt val ... )
        The special round bracket syntax to pass Whiptail/Dialog-specific options to the box, as if
        used on the command line. It can be used multiple times in any order.
        NOTE: since parentheses are special to the shell, you will usually need to escape or quote them.
        Example usage:
            text \
                title='Welcome' \
                text='Hello World!' \
                \( --backtitle 'My backtitle' --fb \)

    yesLabel=
        Set the text of the 'Yes' button.
        Same as using Whiptail/Dialog's '--yes-button/--yes-label' option.

    noLabel=
        Set the text of the 'No' button.
        Same as using Whiptail/Dialog's '--no-button/--no-label' option.

    okLabel=
        Set the text of the 'Ok' button.
        Same as using Whiptail/Dialog's '--ok-button/--ok-label' option.

    cancelLabel=
        Set the text of the 'Cancel' button.
        Same as using Whiptail/Dialog's '--cancel-button/--cancel-label' option.

    scrollbar=
        Whether to force the display of a vertical scrollbar.
        Same as using Whiptail/Dialog's '--scrolltext/--scrollbar' option.
        Possible values: 'true' (or 1), 'false' (or 0).
        Defaults to: 'false'.

    topleft=
        Whether to put window in top-left corner.
        Same as using Whiptail/Dialog's '--topleft/--begin 0 0' option.
        Possible values: 'true' (or 1), 'false' (or 0).
        Defaults to: 'false'.

    help
        Print the usage screen and exit.
EOL
}
readonly -f __box_help
# }}}

# @hide
function __calendar_help() { # {{{
    cat << EOL
Sets up a new calendar box and draws it. Corresponds to the '--calendar' argument in Dialog.
In Whiptail, this feature is emulated using an input field with validation.
The output (as well as the input) defaults to the format 'dd/mm/yyyy'.

See $__BOXLIB_DIR/demo/calendar.sh for an example.

$(__box_help 'calendar')

Options:
    day=
        The day of the calendar.
        Example: 25.
        Defaults to: current day.

    month=
        The month of the calendar.
        Example: 12.
        Defaults to: current month.

    year=
        The year of the calendar.
        Example: 2024.
        Defaults to: current year.

    dateFormat=
        The format of the outputted date string.
        NOTE: in Dialog, the '--date-format' option will be used, which relies on 'strftime', whereas
        in Whiptail, the 'date' command will be used. So, there may be slight differences in the
        format specifiers.
        Defaults to: '%d/%m/%Y'.

    forceInputBox=
        Whether to force use of the input box instead of the Dialog's calendar.
        Possible values: 'true' (or 1), 'false' (or 0).
        Defaults to: 'false'.
EOL
}
readonly -f __calendar_help
# }}}

# @hide
function __config_help() { # {{{
    cat << EOL
Component to globally configure the library set common box options.

NOTE:
    - Config changes affect only future boxes.
    - Box-specific or Whiptail/Dialog-specific options take precedence over options set via config.

Usage: config <options> [<box-options>]

Options:
    headerTitle= headerTitle+=
        The string to be displayed on the backdrop, at the top of the screen alongside the breadcrumbs.
        Defaults to an empty string.

    rendererPath=
        The absolute path to Dialog or Whiptail binary that will render the boxes.
        Defaults to 'dialog'.

    rendererName=
        The renderer name when renderer binary is specified.
        Possible values: 'dialog', 'whiptail'.
        Defaults to: 'dialog'.

    breadcrumbsDelim=
        Set the breadcrumb delimiter string. Can by any length.
        Defaults to: ' > '.

    debug=
    debug
        The file name where to write debug logs. This option takes precedence over the BOXLIB_DEBUG
        environment variable.
        When no value is provided, will exit with "0" or "1" indicating the enabled debug state.
        Possible values:
            'stdout'          prints debug to the standard output
            'stderr'          prints debug to the standard error
            <filename>        writes debug to the given 'filename'
        Defaults to '/dev/null'.

    isDialogRenderer
        Check whether Dialog is the default renderer. Will print 'true' or 'false' and also exit
        with 0 or 1.

    reset
        Reset the configuration to defaults.

    help
        Print the usage screen and exit.
EOL
} # }}}

# @hide
function __confirm_help() { # {{{
    cat << EOL
Sets up a new confirm box and draws it. Corresponds to the '--yesno' argument in Dialog/Whiptail.

See $__BOXLIB_DIR/demo/confirm.sh for an example.

$(__box_help 'confirm')
EOL
}
readonly -f __confirm_help
# }}}

# @hide
function __edit_help() { # {{{
    cat << EOL
Sets up a new file edit box and draws it. Corresponds to the '--editbox' argument in Dialog.
In Whiptail, unless 'editor' option is provided, the default editor will be used instead.

See $__BOXLIB_DIR/demo/edit.sh for an example.

$(__box_help 'edit')

Options
    file=
        The path to a file whose contents to edit.

    editor=
        The text editor to use. If an empty string is provided, the "good" default text editor will
        be determined via Debian's 'sensible-editor' helper command. Otherwise, the editor from the
        \$EDITOR or \$VISUAL environment variables, or one of 'nano', 'nano-tiny', or 'vi'.
        This option can be used with Dialog as well to replace the edit box.

    inPlace=
        Whether to edit the file in place after the box/editor exits.
        Possible values: 'true' (or 1), 'false' (or 0).
        Defaults to: 'false'.
EOL
}
readonly -f __edit_help
# }}}

# @hide
function __form_help() { # {{{
    cat << EOL
Sets up a new form box. Corresponds to the '--form', '--mixedform' & '--passwordform' arguments in Dialog.
In Whiptail, this feature is emulated using a normal menu and an input box to edit the fields.

Use up/down arrows (or control/N, control/P) to move between fields.

Unless a callback is specified via 'callback' option on the box, on exit, the contents of the
form-fields are written to the standard output, each field separated by a newline. The text used to
fill non-editable fields ('width' is zero or negative) is not written out.

To draw the form to the terminal, use 'formDraw'.

See $__BOXLIB_DIR/demo/form.sh for an example.

$(__box_help 'form')

Options
    formHeight=
        The form height, which determines the amount of rows to be displayed at one time, but the
        form will be scrolled if there are more rows than that.
        Use 'auto' or '0' to auto-size to fit the contents.
        Can be denoted using percent sign, (e.g., '50%'), to adjust dynamically based on the amount
        of rows.
        Defaults to: 'auto'.

    columns=
        The number of columns per row before wrapping fields to a new line.
        Using this, will effectively lay out, align, and distribute fields within the menu window.
        - If set to 0, all the fields should be manually positioned using coordinates.
        - If set to 1 or higher, fields will be arranged automatically. The individual field
          coordinates can still be overridden.
        Defaults to: 1.

    fieldWidth=
        The default field width.

    fieldMaxLength=
        The default permissible length of the data that can be entered in the fields.

    [ opt=val ... ]
        The special square bracket syntax to add form-fields, which accepts 'formField' options as-is.
        For example: form title='My form' [ title='First Name' width=10 ] [ ... ]
EOL
}
readonly -f __form_help
# }}}

# @hide
function __form_field_help() { # {{{
    cat << EOL
Adds a form entry. This can only be used after the form box has been set up.
Fields will appear in the form in the order they are added.

See $__BOXLIB_DIR/demo/form.sh for an example.

Usage: formField <options>

Options:
    type=
        The type(s) of the field. The field can combine multiple types, for example: 'hidden|readonly'.
        Possible values:
        - 'input' (A standard input field that allows to enter and edit text)
        - 'hidden' (A field that stores sensitive data not visible to the user, like passwords)
        - 'readonly' (A non-editable field that displays information to the user, similar to a label)
        Defaults to: 'input'.

    title=
        The title/label of the field.
        Defaults to an empty string.

    value=
        The initial value of the field.
        Defaults to an empty string.

    width=
        The width of the field that determines the number of characters that the user can see when
        editing the value.
        - If width value is 0, the field cannot be altered, and the contents of the field determine
          the displayed-length.
        - If width value is negative, the field cannot be altered, and the negated value is used to
          determine the displayed-length.
        Defaults to: 0.

    maxlength=
        The permissible length of the data that can be entered in the field.
        When value is 0, the value of 'width' is used instead.
        Defaults to: 0.

    titleX=
        The x-coordinate of the field's title within the form's window.
        This is automatically computed if 'columns' option is > 0, and a value starting with '+' or '-'
        can be used to adjust (increase or decrease) the automatically computed title's position by
        that amount.
        The unit of measurement is terminal columns.

    titleY=
        The y-coordinate of the field's title within the form's window.
        This is automatically computed if 'columns' option is > 0, and a value starting with '+' or '-'
        can be used to adjust (increase or decrease) the automatically computed title's position by
        that amount.
        The unit of measurement is terminal rows.

    valueX=
        The x-coordinate of the field's value within the form's window.
        Typically, you want it to be '\${#title} + 2' (+2 is for padding) in order for it to be
        positioned next to the title.
        This is automatically computed if 'columns' option is > 0, and a value starting with '+' or '-'
        can be used to adjust (increase or decrease) the automatically computed value's position by
        that amount.
        The unit of measurement is terminal columns.

    valueY=
        The y-coordinate of the field's value within the form's window.
        Typically, you want it to be the same as titleY.
        This is automatically computed if 'columns' option is > 0, and a value starting with '+' or '-'
        can be used to adjust (increase or decrease) the automatically computed value's position by
        that amount.
        The unit of measurement is terminal rows.

    help
        Print the usage screen and exit.
EOL
}
readonly -f __form_field_help
# }}}

# @hide
function __form_draw_help() { # {{{
    cat << EOL
Performs the actual drawing of the form. This can only be used after the form box has been fully set up.

See $__BOXLIB_DIR/demo/form.sh for an example.

Usage: formDraw <options>

    help
        Print the usage screen and exit.
EOL
}
readonly -f __form_draw_help
# }}}

# @hide
function __info_help() { # {{{
    cat << EOL
Sets up a new info box and draws it. Corresponds to the '--infobox' argument in Dialog/Whiptail.

TIP:
    Due to an old bug (see [1]), Whiptail fails to render the info box in an xterm-based terminals
    (e.g., gnome-terminal). As a workaround, boxlib implicitly uses 'linux' terminfo whenever
    '\$TERM' matches 'xterm*' or '*-256color'. The 'linux' terminfo has color support, but if it
    doesn't work for you, try setting the 'term' option to 'vt220' or 'ansi' instead.
    - [1] https://bugs.launchpad.net/ubuntu/+source/newt/+bug/604212

See $__BOXLIB_DIR/demo/info.sh for an example.

$(__box_help 'info')

Options
    clear=
        Whether to clear the screen after the box exits. Unless specified otherwise, this option is
        implicitly set to 'true' when combined with the 'sleep' option.
        Possible values: 'true' (or 1), 'false' (or 0).
        Defaults to: 'false'.
EOL
}
readonly -f __info_help
# }}}

# @hide
function __input_help() { # {{{
    cat << EOL
Sets up a new input box and draws it. Corresponds to the '--inputbox' & --passwordbox arguments in Dialog/Whiptail.

See $__BOXLIB_DIR/demo/input.sh for an example.
See $__BOXLIB_DIR/demo/password.sh for an example.

$(__box_help 'input')

Options:
    type=
        The type of the input box.
        Possible values: 'text', 'password'.
        Defaults to: 'text'.

    value=
        The value used to initialize the input string.
        Defaults to an empty string.
EOL
}
readonly -f __input_help
# }}}

# @hide
function __list_help() { # {{{
    cat << EOL
Sets up a new list box. Corresponds to '--buildlist', '--checklist' & '--radiolist' arguments in Dialog/Whiptail.
In Whiptail, the buildlist feature is emulated using the checklist box.

To add list choices, use 'listEntry' command or the square bracket syntax [ entryOption1=val1 ... ],
which accepts 'listEntry' options as-is.

To draw the list to the terminal, use 'listDraw'.

See $__BOXLIB_DIR/demo/buildlist.sh for an example.
See $__BOXLIB_DIR/demo/checklist.sh for an example.
See $__BOXLIB_DIR/demo/radiolist.sh for an example.
See $__BOXLIB_DIR/demo/treelist.sh for an example.

$(__box_help 'list')

Options:
    type=
        The type of the list box.
        Possible values;
            'build'    displays two lists, side-by-side. The results are written in the order
                       displayed in the selected-window.
            'check'    similar to a [menu](#menu), but allows to select either many entries or none
                       at all. The results are written in the order displayed in the window.
            'radio'    similar to a [menu](#menu), but allows to select either a single entry or none at all.
            'tree'     similar to a radio list, but displays entries organized as a tree. The depth
                       is controlled using the 'depth'. The entry 'title' is not displayed. After
                       selecting an entry, the entry title is the output.
        Defaults to: 'check'.

    listHeight=
        The list height, which determines the amount of choices to be displayed at one time, but
        the list will be scrolled if there are more entries than that.
        Use 'auto' or '0' to auto-size to fit the contents.
        Can be denoted using percent sign, (e.g., '50%'), to adjust dynamically based on
        the amount of choices.
        Defaults to: 'auto'.

    prefix=
        Whether to prefix the entry titles in the list with enumeration, alphabetic letters, or both.
        This is especially useful for quickly selecting a choice using the keyboard.
        Unless the 'keepPrefix' option is used, the prefix will be stripped off before
        printing/returning the result.
        Possible values:
            'num'          cardinal number: 1,2,3... 15,16...
            'alpha'        alphabet letter: a-z (after z, it goes back to a)
            'alphanum'     alphanumeric: 1-9,a-z (after z, it goes back to 1)
            'alphanum0'    full alphanumeric: 0-9,a-z (after z, it goes back to 0)
            'alphanum1'    hybrid alphanumeric: 1-9,0,a-z (after z, it goes back to 1)

    keepPrefix=
        Whether to keep the prefix in the selected entry when printing/returning the result.
        This can be useful if you want to use the prefix initials to match entries.
        Possible values: 'true' (or 1), 'false' (or 0).
        Defaults to: 'false'.

    [ opt=val ... ]
        The special square bracket syntax to add list choices, which accepts 'listEntry' options as-is.
        For example: list title='My list' [ title='Option 1' summary='Summary 1' ] [ ... ]
EOL
}
readonly -f __list_help
# }}}

# @hide
function __list_entry_help() { # {{{
    cat << EOL
Adds a choice entry. This can only be used after the list box has been set up.
Choice entries will appear in the list in the order they are added.

See $__BOXLIB_DIR/demo/buildlist.sh for an example.
See $__BOXLIB_DIR/demo/checklist.sh for an example.
See $__BOXLIB_DIR/demo/radiolist.sh for an example.
See $__BOXLIB_DIR/demo/treelist.sh for an example.

Usage: listEntry <options>

Options:
    title=
        The title of the choice entry.
        Defaults to an empty string.

    summary=
        The summary of the entry.
        Defaults to an empty string.

    selected=
        Whether to preselect the choice.
        Possible values: 'true' (or 1), 'false' (or 0).
        Defaults to: 'false'.

    depth=
        The depth of the entry in the tree list.
        Defaults to: 0

    callback=
        The callback to invoke when this entry is selected in the list. The callback will be:
        - invoked as a local function if it ends with "()"
        - executed if it's a file with the "execute" bit set
        - sourced as a shell script file if it's none of the above

        In all cases, the callback should expect the title of the selected entry as first
        input parameter.
        When invoked, the \$? variable will contain the exit code from the renderer (Whiptail/Dialog).

        NOTE:
            - This option takes precedence over the list's 'callback' parameter.

            - The callback execution will be "sandboxed", i.e., it will run in a sub-shell.
              This ensures the interaction is isolated.

            - If the callback is a relative path to a file, then it will be searched starting
              from the working directory.
              Also, the CWD will be changed to where the callback file is located before
              executing/sourcing it. To disable, set 'changeToCallbackDir=false'.

    help
        Print the usage screen and exit.
EOL
}
readonly -f __list_entry_help
# }}}

# @hide
function __list_draw_help() { # {{{
    cat << EOL
Performs the actual drawing of the list. This can only be used after the list box has been fully set up.

See $__BOXLIB_DIR/demo/buildlist.sh for an example.
See $__BOXLIB_DIR/demo/checklist.sh for an example.
See $__BOXLIB_DIR/demo/radiolist.sh for an example.

Usage: listDraw <options>

    help
        Print the usage screen and exit.
EOL
}
readonly -f __list_draw_help
# }}}

# @hide
function __menu_help() { # {{{
    cat << EOL
Sets up a new menu box. Corresponds to the '--menu' && '--inputmenu' arguments in Dialog/Whiptail.
In Whiptail, the input menu is simulated using a normal menu and an input box allowing you to edit
the menu entry summary when it is selected, similar to how it works in Dialog.

To add menu entries, use 'menuEntry' command or the square bracket syntax [ entryOption1=val1 ... ],
which accepts 'menuEntry' options as-is.

To draw the menu to the terminal, use 'menuDraw'.

See $__BOXLIB_DIR/demo/menu.sh for an example.
See $__BOXLIB_DIR/demo/inputmenu.sh for an example.

$(__box_help 'menu')

Options:
    menuHeight=
        The menu height, which determines the amount of entries to be displayed in the menu at one
        time, but the menu will be scrolled if there are more entries than that.
        Use 'auto' or '0' to auto-size to fit the contents.
        Can be denoted using percent sign, (e.g., '50%'), to adjust dynamically based on
        the menu entires.
        Defaults to: 'auto'.

    prefix=
        Whether to prefix the entry titles in the list with enumeration, alphabetic letters, or both.
        This is especially useful for quickly selecting an entry using the keyboard.
        Unless the 'keepPrefix' option is used, the prefix will be stripped off before
        printing/returning the result.
        Possible values:
            'num'          cardinal number: 1,2,3... 15,16...
            'alpha'        alphabet letter: a-z (after z, it goes back to a)
            'alphanum'     alphanumeric: 1-9,a-z (after z, it goes back to 1)
            'alphanum0'    full alphanumeric: 0-9,a-z (after z, it goes back to 0)
            'alphanum1'    hybrid alphanumeric: 1-9,0,a-z (after z, it goes back to 1)

    keepPrefix=
        Whether to keep the prefix in the selected entry when printing/returning the result.
        This can be useful if you want to use the prefix initials to match entries.
        Possible values: 'true' (or 1), 'false' (or 0).
        Defaults to: 'false'.

    rename=
        Whether renaming the menu entry summary is allowed. The output after renaming will follow
        this format: RENAMED <entry> <summary>
        After renaming, the exit status is equal to 3.
        Possible values: 'true' (or 1), 'false' (or 0).
        Defaults to: 'false'.

    [ opt=val ... ]
        The special square bracket syntax to add menu entries, which accepts 'menuEntry' options
        as-is. For example: menu title='My menu' [ title='Option 1' summary='Summary 1' ] [ ... ]
EOL
}
readonly -f __menu_help
# }}}

# @hide
function __menu_entry_help() { # {{{
    cat << EOL
Adds a menu entry. This can only be used after the menu box has been set up.
Menu entries will appear in the menu in the order they are added.

See $__BOXLIB_DIR/demo/menu.sh for an example.

Usage: menuEntry <options>

Options:
    title=
        The title of the menu entry.
        Defaults to an empty string.

    summary=
        The summary of the entry.
        Defaults to an empty string.

    selected=
        Whether to preselect the entry. Same as '--default-item' argument in Whiptail/Dialog.
        Possible values: 'true' (or 1), 'false' (or 0).
        Defaults to: 'false'.

    callback=
        The callback to invoke when this entry is selected in the menu. The callback will be:
        - invoked as a local function if it ends with "()"
        - executed if it's a file with the "execute" bit set
        - sourced as a shell script file if it's none of the above

        In all cases, the callback should expect the title of the selected entry as first
        input parameter.
        When invoked, the \$? variable will contain the exit code from the renderer (Whiptail/Dialog).

        NOTE:
            - This option takes precedence over the menu's 'callback' parameter.

            - The callback execution will be "sandboxed", i.e., it will run in a sub-shell.
              This ensures the interaction is isolated.

            - If the callback is a relative path to a file, then it will be searched starting
              from the working directory.
              Also, the CWD will be changed to where the callback file is located before
              executing/sourcing it. To disable, set 'changeToCallbackDir=false'.

    help
        Print the usage screen and exit.
EOL
}
readonly -f __menu_entry_help
# }}}

# @hide
function __menu_draw_help() { # {{{
    cat << EOL
Performs the actual drawing of the menu. This can only be used after the menu box has been fully set up.

See $__BOXLIB_DIR/demo/menu.sh for an example.

Usage: menuDraw <options>

    help
        Print the usage screen and exit.
EOL
}
readonly -f __menu_draw_help
# }}}

# @hide
function __text_help() { # {{{
    cat << EOL
Sets up a new text box and draws it. Corresponds to the '--msgbox', '--textbox', '--tailbox' &
'--tailboxbg' arguments in Dialog/Whiptail.
In whpitail, the tailbox feature is emulated using a program box.

See $__BOXLIB_DIR/demo/text.sh for an example.
See $__BOXLIB_DIR/demo/text_file_follow.sh for an example.

$(__box_help 'text')

Options:
    file=
        The path to a file whose contents to display in the box.
        This takes precedence over the 'text' option.

    follow=
        Whether to follow the file as in "tail -f" command.
        In Dialog, long lines can be scrolled horizontally using vi-style 'h' (left) and 'l' (right),
        or arrow-keys. A '0' resets the scrolling. In Whiptail, new lines are wrapped by default.
        Possible values: 'true' (or 1), 'false' (or 0).
        Defaults to: 'false'.

    inBackground=
        Whether to follow the file in the background, as in "tail -f &" command, while displaying
        other widgets.
        If no widgets are added using the '--and-widget' option, the display of the box will be
        postponed until another box is launched, which will then be used as widget.
        NOTE: Dialog will perform all of the background widgets in the same process, polling for updates.
        You may use Tab to traverse between the widgets on the screen, and close them individually,
        e.g., by pressing ENTER.
        Possible values: 'true' (or 1), 'false' (or 0).
        Defaults to: 'false'.
EOL
}
readonly -f __text_help
# }}}

# @hide
function __pause_help() { # {{{
    cat << EOL
Sets up a new pause box and draws it. Corresponds to the '--pause' argument in Dialog.
In whpitail, this feature is emulated using a menu box.

See $__BOXLIB_DIR/demo/pause.sh for an example.

$(__box_help 'pause')

Options:
    seconds=
        The amount of seconds to pause, after which the box will timeout.
        The decimal part will be dropped.
EOL
}
readonly -f __input_help
# }}}

# @hide
function __program_help() { # {{{
    cat << EOL
Sets up a new program box that will display the output of a command. Corresponds to the --prgbox,
--programbox & --progressbox arguments in Dialog.

In Whiptail, the program feature is emulated using an info & text box.

IMPORTANT:
    When using process substitution to feed the program box, it's crucial to 'wait' for the process
    substitution's PID to ensure correct behavior of the box, especially with hideOk="false" option.
    See example:

        { /bin/cmd; } > >(program text='Working in progress...') 2>&1
        wait \$!

        # Pitfall: the result of \$! could be empty if process substitution is fed by an external
        # command ('/bin/cmd' in this case). As a workaround, wrap external command call using a
        # Bash function or put everything in {...} block and redirect the output of the block as
        # shown above. For more details, see https://unix.stackexchange.com/a/524844

    The rationale behind that, is because the program box reads your program's output in a separate
    subshell. Once your program finishes, the subshell running the program box will be
    effectively detached from the main Bash process. By explicitly waiting for it before exiting your
    script or launching another box, you ensure the program box can clean up the screen and restore
    TTY input settings.

    Also, this strictly requires *Bash v4.4* for the process substitution's PID to be waitable. For
    Bash v4.3, use flock-style locking mechanism to achieve the same.

See $__BOXLIB_DIR/demo/program.sh for an example.

$(__box_help 'program')

Options:
    command=
        The command(s) to execute via 'sh -c <command>' whose output will be displayed in the box.
        If omitted, then the output will be read from stdin.

    hideOk=
        Whether to hide the "OK" button after the command has completed.
        Possible values: 'true' (or 1), 'false' (or 0).
        Defaults to: 'false'.
EOL
}
readonly -f __program_help
# }}}

# @hide
function __progress_help() { # {{{
    cat << EOL
Sets up a new progress box and draws it. Corresponds to the '--gauge' & '--mixedgauge' arguments in
Dialog/Whiptail.
To adjust the progress, such as percentage or text, use 'progressSet'.

In Whiptail, the mixed progress is simulated using a normal progress.

See $__BOXLIB_DIR/demo/progress.sh for an example.
See $__BOXLIB_DIR/demo/mixedprogress.sh for an example.

$(__box_help 'progress')

Options:
    value=
        The initial value to calculate the percentage of the progress bar. If 'total' option is not
        set, then this value is the % value of the progress bar. Can be updated using progressSet
        command.
        Decimal part will be dropped.
        Defaults to 0.

    total=
        The initial "total" or "complete" value used to calculate the % value that will be displayed
        in the progress bar. Here's the general formula: percentage=value/total*100
        Can be updated using progressSet command.
        Decimal part will be dropped.
        Defaults to 0.

    entry=
        The entry (row) name to add. Each entry must be paired with a 'state=' option. Any amount of
        entries can be added, or you can add them later with 'progressSet' command. The entry name
        should be unique, so that its state can be updated using 'progressSet' command.
        IMPORTANT: the number of 'entry=' and 'state=' options must be equal. The following example
        will fail (2 entries and 1 state):
              progress \
                  entry='Entry1' \
                  state="\$PROGRESS_N_A_STATE" \
                  entry='Entry2'

    state=
        The state of the entry. The entry state can be any string. If the string starts with a
        leading '-' (e.g., '-20'), then it will be suffixed with a % sign, such as '20%'.
        There are 10 special entry states encoded as digits (0-9), publicly available as numeric
        constant variables:
        - PROGRESS_SUCCEEDED_STATE (0)   = Succeeded
        - PROGRESS_FAILED_STATE (1)      = Failed
        - PROGRESS_PASSED_STATE (2)      = Passed
        - PROGRESS_COMPLETED_STATE (3)   = Completed
        - PROGRESS_CHECKED_STATE (4)     = Checked
        - PROGRESS_DONE_STATE (5)        = Done
        - PROGRESS_SKIPPED_STATE (6)     = Skipped
        - PROGRESS_IN_PROGRESS_STATE (7) = In Progress
        - PROGRESS_BLANK_STATE (8)       = (blank)
        - PROGRESS_N_A_STATE (9)         = N/A
EOL
}
readonly -f __progress_help
# }}}

# @hide
function __progress_set_help() { # {{{
    cat << EOL
Performs adjustments on the progress box.

See $__BOXLIB_DIR/demo/progress.sh for an example.
See $__BOXLIB_DIR/demo/mixedprogress.sh for an example.

Usage: progressSet [<options>]

Options:
    text=
    text+=
        The new string to display inside the progress box. The '+=' operator will concatenate with
        the previous 'text=' value (e.g., 'progressSet text='very long line1\n' text+='very long line2').

    value=
        The new value to calculate the percentage of the progress bar. If 'total' option is not set,
        then this value is the % value of the progress bar.
        Decimal part will be dropped.

    total=
        The new "total" or "complete" value used to calculate the % value that will be displayed in the
        progress bar. Here's the general formula: percentage=value/total*100

    entry=
        The entry (row) name to add or update, if it already exists.

    state=
        The state of the entry that is being added or updated.

    help
        Print the usage screen and exit.
EOL
}
readonly -f __progress_set_help
# }}}

# @hide
function __progress_exit_help() { # {{{
    cat << EOL
Manually causes the progress box to exit. Normally, the progress box will exit
automatically as soon as it reaches 100% or when your script terminates.

See $__BOXLIB_DIR/demo/progress.sh for an example.
See $__BOXLIB_DIR/demo/mixedprogress.sh for an example.

Usage: progressSet [<options>]

Options
    help
        Print the usage screen and exit.
EOL
}
readonly -f __progress_exit_help
# }}}

# @hide
function __range_help() { # {{{
    cat << EOL
Component to set up a new range box and perform drawing to the terminal. Corresponds to the '--rangebox' argument in Dialog.
In Whiptail, this feature is emulated using an input field with validation.

See $__BOXLIB_DIR/demo/range.sh for an example.

$(__box_help 'range')

Options:
    min=
        The minimum value of the range.
        Example: 0.
        Defaults to: 0.

    max=
        The maximum value of the range.
        Example: 10.
        Defaults to: minimum value.

    default=
        The default value of the range.
        Example: 5.
        Defaults to: minimum value.
EOL
}
readonly -f __range_help
# }}}

# @hide
function __selector_help() { # {{{
    cat << EOL
Sets up a new file/directory selector box and draws it. Corresponds to the '--dselect' & '--fselect'
arguments in Dialog.
In Whiptail this feature is emulated using a menu box.

Path Editor: the 'Cancel' button has been replaced with 'Edit/Exit', which opens an input box
             allowing you to edit the path, similar to how it works in Dialog.

Quick Selection: as in Dialog, you can use incomplete paths to pre-select the first entry that
                 partially match.

Navigation:
    - The '.' (dot) entry selects the current directory or the string "as-is", as provided in the
      path editor.
    - The '..' (dot-dot) entry navigates to the parent directory.
    - Selecting an entry in the menu list will canonicalize the filepath using 'realpath' command.
    - Pressing the 'ESC' key exits the selector box. Alternatively, you should go through the path
      editor box to exit.

See $__BOXLIB_DIR/demo/selector.sh for an example.

$(__box_help 'selector')

Options:
    filepath=
        The path to a file or directory. If a file path is provided, the path contents will be
        displayed, and the filename will be pre-selected.
        Corresponds to the '--fselect' argument in Dialog.
        This option is used by default.
        Defaults to an empty string.

    directory=
        The path to a directory. If a file path is provided, the filename will be discarded, and the
        path contents will be displayed instead.
        Corresponds to the '--dselect' argument in Dialog.
        NOTE: only directories will be visible in the selector box when using this option.
        Defaults to an empty string.
EOL
}
readonly -f __selector_help
# }}}

# @hide
function __timepicker_help() { # {{{
    cat << EOL
Component to set up a new time picker box and perform drawing to the terminal. Corresponds to the '--timebox' argument in Dialog.
In Whiptail, this feature is emulated using an input field with validation.
The output (as well as the input) defaults to the format 'hh:mm:ss'.

See $__BOXLIB_DIR/demo/timepicker.sh for an example.

$(__box_help 'timepicker')

Options:
    hour=
        The hour of the time picker.
        Example: 15.
        Defaults to: current hour.

   minute=
        The minute of the time picker.
        Example: 10.
        Defaults to: current minute.

   second=
        The second of the time picker.
        Example: 59.
        Defaults to: current second.

   timeFormat=
        The format of the outputted time string.
        NOTE: in Dialog, the '--time-format' option will be used, which relies on 'strftime',
        whereas in Whiptail, the 'date' command will be used. So, there may be slight differences
        in the format specifiers.
        Defaults to: '%H:%M:%S'.

   forceInputBox=
        Whether to force use of the [input](#input) box instead of the Dialog's time box.
        Possible values: 'true' (or 1), 'false' (or 0).
        Defaults to: 'false'.
EOL
}
readonly -f __timepicker_help
# }}}
