#!/usr/bin/env bash
# vim: set fdm=marker:

# @hide
declare -A __FORM
# @hide
declare -a __FORM_FIELDS __FORM_COLUMN_SIZES

# Field type bits.
# 0 = input (e.g., enter text), 1 = hidden (e.g., password), 2 = readonly (e.g., label)
# @hide
readonly __FORM_INPUT_TYPE_FLAG=0 __FORM_HIDDEN_TYPE_FLAG=1 __FORM_READONLY_TYPE_FLAG=2

# Sets up a new form box. Corresponds to the --form, --mixedform & --passwordform arguments in Dialog.
# In Whiptail, this feature is emulated using a normal menu and an input box to edit the fields.
function form() { # {{{
    if [ $# -eq 1 ] && [ "$1" = 'help' ]; then
        __form_help
        return 0
    fi

    # Clean up the old form
    __FORM=(
        ['formHeight']=0
        ['columns']=1
        ['fieldWidth']=0
        ['fieldMaxLength']=0
    )
    __FORM_FIELDS=()
    __FORM_COLUMN_SIZES=()

    local -a l_box_args l_field_args
    local l_param l_value l_raw_param l_parsing_fields=0 l_cancel_label
    while [ $# -gt 0 ]; do
        # Parse & collect form-fields in square brackets to process them separately later
        if [ $l_parsing_fields -eq 1 ]; then
            l_raw_param="$1"
            case "$l_raw_param" in
                '[') __panic "form: Missing the closing square bracket (]) for the field: ${l_field_args[*]}";;
                ']') l_parsing_fields=0;;
                # Allow [ and ] to be used as-is when escaped
                '\['|'\]') l_raw_param="${l_raw_param:1}";;
            esac
            l_field_args+=("$l_raw_param")
            shift
            continue
        elif [ "$1" = '[' ]; then
            l_parsing_fields=1
            l_field_args+=('[')
            shift
            continue
        fi
        l_param="${1%%=*}"
        l_value="${1#*=}"
        case "$l_param" in
            formHeight|columns|fieldWidth|fieldMaxLength) __FORM["$l_param"]="$l_value";;
            cancelLabel) l_cancel_label="$l_value";;
            *) l_box_args+=("$1")
        esac
        local l_code=$?
        if [ $l_code -gt 0 ]; then
            exit $l_code
        fi
        shift
    done

    if [ $l_parsing_fields -eq 1 ]; then
        __panic "form: Missing the closing square bracket (]) for the field: ${l_field_args[*]}"
    fi

    if ! [ "${__FORM['columns']?}" -ge 0 ]; then
        __panic "form: Invalid 'columns' value: ${__FORM['columns']?}"
    fi

    if config isDialogRenderer >/dev/null; then
        local -a l_boxlib_args
        # Add cancel label option only if it was provided by the user to avoid showing nothing
        if [ ${l_cancel_label+xyz} ]; then
            l_boxlib_args+=(cancelLabel="${l_cancel_label?}")
        fi
        __box 'mixedform' "${l_boxlib_args[@]}" "${l_box_args[@]}"
    else
        __box 'menu' cancelLabel="${l_cancel_label-Done}" "${l_box_args[@]}"
        __box_set_result_validation_callback '__form_menu_result_validation_callback'
    fi
    __box_set_dump_callback '__form_dump_callback'

    local -a l_field
    local l_arg
    for l_arg in "${l_field_args[@]}"; do
        case "$l_arg" in
            '[') unset l_field;;
            ']') formField "${l_field[@]}";;
            *) l_field+=("$l_arg")
        esac
    done
} # }}}

# Adds a new field to the form.
function formField() { # {{{
    if [ $# -eq 1 ] && [ "$1" = 'help' ]; then
        __form_field_help
        return 0
    fi
    if [ "${__BOX['type']-}" != 'mixedform' ] && [ "${__BOX['type']-}" != 'menu' ] ||
        [ ${#__FORM[@]} -eq 0 ]; then
        __panic 'formField: Cannot create a field without a form box.'
    fi
    local l_type=0 l_title='' l_init_value='' l_width=${__FORM['fieldWidth']?} \
        l_maxlength=${__FORM['fieldMaxLength']?} l_titleX l_titleY l_valueX l_valueY l_param l_value
    while [ $# -gt 0 ]; do
        l_param="${1%%=*}"
        l_value="${1#*=}"
        case "$l_param" in
            type) l_type="$(__form_convert_field_types_to_bits "$l_value")";;
            title) l_title="$l_value";;
            title+) l_title+="$l_value";;
            value) l_init_value="$l_value";;
            value+) l_init_value+="$l_value";;
            width) l_width="$l_value";;
            maxlength) l_maxlength="$l_value";;
            titleX) l_titleX="$l_value";;
            titleY) l_titleY="$l_value";;
            valueX) l_valueX="$l_value";;
            valueY) l_valueY="$l_value";;
            *) __panic "formField: Unrecognized argument: $1"
        esac
        local l_code=$?
        if [ $l_code -gt 0 ]; then
            exit $l_code
        fi
        shift
    done

    local l_width_=$l_width
    if [ "$l_width_" -eq 0 ]; then
        # If width value is 0, the field cannot be altered, and the contents of the field
        # will determine the displayed-length
        l_width_=${#l_init_value}
    elif [ "$l_width_" -lt 0 ]; then
        # If width value is negative, the field cannot be altered, and the negated value is
        # used to determine the displayed-length
        l_width_=${l_width_::1}
    fi

    if config isDialogRenderer >/dev/null; then
        local l_cols=${__FORM['columns']?}
        if [ "$l_cols" -gt 0 ]; then
            local l_num_fields=$(( ${#__FORM_FIELDS[@]} / 9 ))
            # Determine the row number in the grid where the new field should be placed
            local l_row=$((l_num_fields / __FORM['columns'] + 1))
            # Determine the column number in the grid where the new field should be placed
            local l_col=$(( (l_num_fields + 1) % l_cols ))
            if [ $l_col -eq 0 ]; then
                l_col=$l_cols
            fi

            if [ ! ${l_titleY+xyz} ] || [[ ${l_titleY::1} =~ [+-] ]]; then
                l_titleY=$((l_row + l_titleY))
            fi
            if [ ! ${l_valueY+xyz} ] || [[ ${l_valueY::1} =~ [+-] ]]; then
                l_valueY=$((l_row + l_valueY))
            fi

            # Visually separate the title & value when should compute the horizontal shift
            # (x-coordinate) for the field's title
            if [ ! ${l_titleX+xyz} ] || [[ ${l_titleX::1} =~ [+-] ]] &&
                [ ${#l_title} -gt 0 ] && [ "$l_width_" -gt 0 ]; then
                l_title+=' '
            fi

            local l_column_sizes_pos=$((l_col * 2 - 2))

            # Compute the largest title size in the column where this field will be placed. It will be
            # used to decide the final column size when drawing
            if [ "${__FORM_COLUMN_SIZES[l_column_sizes_pos]--1}" -lt ${#l_title} ]; then
                __FORM_COLUMN_SIZES[l_column_sizes_pos]=${#l_title}
            fi

            # Compute the largest input value size in the column where this field will be placed. It will
            # be used to decide the final column size when drawing
            if [ "${__FORM_COLUMN_SIZES[l_column_sizes_pos+1]--1}" -lt "$l_width_" ]; then
                __FORM_COLUMN_SIZES[l_column_sizes_pos+1]=$l_width_
            fi
        else
            if [ ! ${l_titleX+xyz} ]; then
                l_titleX=0
            fi
            if [ ! ${l_titleY+xyz} ]; then
                l_titleY=0
            fi
            if [ ! ${l_valueX+xyz} ]; then
                l_valueX=0
            fi
            if [ ! ${l_valueY+xyz} ]; then
                l_valueY=0
            fi
        fi
    else
        # Compute the largest input value displayed-length in the second column that will be used to
        # decide the final column size when drawing
        if [ "${__FORM_COLUMN_SIZES[0]--1}" -lt "$l_width_" ]; then
            __FORM_COLUMN_SIZES[0]=$l_width_
        fi

        # Visually separate the title & value
        if [ ${#l_title} -gt 0 ] && [ "$l_width_" -gt 0 ]; then
            l_title+=' '
        fi
    fi
    __FORM_FIELDS+=(
        "$l_title" "$l_titleY" "${l_titleX-}"
        "$l_init_value" "$l_valueY" "${l_valueX-}"
        "$l_width" "$l_maxlength" "$l_type"
    )
}
# }}}

# Performs the actual drawing of the form.
# Must be called after the form box has been fully set up.
function formDraw() { # {{{
    if [ $# -gt 0 ]; then
        if [ $# -eq 1 ] && [ "$1" = 'help' ]; then
            __form_draw_help
            return 0
        fi
        __panic "formDraw: Unrecognized argument(s): $*"
    fi
    if [ ${#__FORM_FIELDS[@]} -eq 0 ]; then
        __panic 'formDraw: Cannot draw a form box without fields.'
    fi
    if config isDialogRenderer >/dev/null; then
        if [ "${__BOX['type']-}" != 'mixedform' ]; then
            __panic 'formDraw: No form box to draw.'
        fi

        local l_cols=${__FORM['columns']?} l_batch_size=9
        local l_form_height="${__FORM['formHeight']?}"
        if [ "${l_form_height: -1}" = '%' ]; then
            if [ "$l_cols" -gt 0 ]; then
                local l_num_fields=$(( ${#__FORM_FIELDS[@]} / l_batch_size ))
                local l_rows=$(( (l_num_fields - 1) / l_cols + 1 ))
            else
                __panic 'formDraw: Cannot calculate form height from percentage when columns = 0'
            fi
            l_form_height="$(__scale_value "$l_form_height" "$l_rows")"
        fi

        if [ "$l_cols" -gt 0 ]; then
            # If form height is restricted to one row with more than 1 field, then the alignment
            # should be done by field instead of column. This prevents the visible columns from
            # vertically aligning with the invisible columns in the row below
            local l_align_by_field=0
            if [ "$l_form_height" -eq 1 ] && [ "$l_cols" -gt 1 ]; then
                l_align_by_field=1
            fi

            local i l_field_n l_col
            for ((i = 0, l_field_n = 1; i < ${#__FORM_FIELDS[@]}; i += l_batch_size, l_field_n++)); do
                l_col=$((l_field_n % l_cols))
                if [ $l_col -eq 0 ]; then
                    l_col=$l_cols
                fi

                # Compute the horizontal shift (x-coordinate) for the field's title (including
                # possible adjustments when the coordinate value starts with a '+' or '-') based on
                # the x-coordinate, title and width sizes of the previous column. This shift can
                # also be seen as the beginning of the column in the grid where this field is
                # placed. Otherwise, we use the user's coordinate, if any
                local l_title_x="${__FORM_FIELDS[i+2]?}"
                if [ -z "$l_title_x" ] || [[ ${l_title_x::1} =~ [+-] ]]; then
                    if [ "$l_col" -eq 1 ]; then
                        # The first column (index 0) always starts at position 1
                        __FORM_FIELDS[i+2]=$((__FORM_FIELDS[i+2] + 1))
                    else
                        local l_prev_column_sizes_pos=$(( (l_col - 1) * 2 - 2 ))
                        if [ $l_align_by_field -eq 1 ]; then
                            # Use the title displayed-length and width of the previous field for
                            # horizontal shift
                            local l_prev_title_width=${#__FORM_FIELDS[i-l_batch_size]}
                            local l_prev_value_width="${__FORM_FIELDS[i-l_batch_size+6]?}"
                            if [ "$l_prev_value_width" -eq 0 ]; then
                                # If width is 0, the field cannot be altered, and the contents of
                                # the field will determine the displayed-length
                                l_prev_value_width=${#__FORM_FIELDS[i-l_batch_size+3]}
                                # If the contents of the field is also empty, then use the previous
                                # column width so that two fields are not too close to each other
                                if [ "$l_prev_value_width" -eq 0 ]; then
                                    l_prev_value_width=${__FORM_COLUMN_SIZES[l_prev_column_sizes_pos+1]?}
                                fi
                            elif [ "$l_prev_value_width" -lt 0 ]; then
                                # If width value is negative, the field cannot be altered, and the
                                # negated value is used to determine the displayed-length
                                l_prev_value_width=${l_prev_value_width::1}
                            fi
                        else
                            # Use the largest title displayed-length and width of the previous
                            # column for horizontal shift
                            local l_prev_title_width=${__FORM_COLUMN_SIZES[l_prev_column_sizes_pos]?}
                            local l_prev_value_width=${__FORM_COLUMN_SIZES[l_prev_column_sizes_pos+1]?}
                        fi
                        local l_prev_title_x=${__FORM_FIELDS[i-l_batch_size+2]?}
                        local l_prev_column_width=$((l_prev_title_x + l_prev_title_width + l_prev_value_width))
                        __FORM_FIELDS[i+2]=$((l_title_x + l_prev_column_width + 1)) # +1 is for left padding
                    fi
                fi

                # Compute the horizontal shift (x-coordinate) for the field's value (including
                # possible adjustments when the coordinate value starts with a '+' or '-') that will
                # be positioned next to the title. Otherwise, we use the user's coordinate, if any
                local l_value_x="${__FORM_FIELDS[i+5]?}"
                if [ -z "$l_value_x" ] || [[ ${l_value_x::1} =~ [+-] ]]; then
                    if [ $l_align_by_field -eq 1 ]; then
                        # Align the value to the title displayed-length when should align by field
                        local l_title_size=${#__FORM_FIELDS[i]}
                    else
                        local l_column_sizes_pos=$((l_col * 2 - 2))
                        # Use the largest title displayed-length in the column to shift the value
                        local l_title_size=${__FORM_COLUMN_SIZES[l_column_sizes_pos]?}
                    fi
                    l_title_x="${__FORM_FIELDS[i+2]?}"
                    __FORM_FIELDS[i+5]=$((l_title_x + l_title_size + l_value_x))
                fi
            done
        fi
        __box_draw "$l_form_height" "${__FORM_FIELDS[@]}"
    else
        if [ "${__BOX['type']-}" != 'menu' ] || [ ${#__FORM[@]} -eq 0 ]; then
            __panic 'formDraw: No form box to draw.'
        fi

        local l_batch_size=9 l_menu_height="${__FORM['formHeight']?}"
        if [ "${l_menu_height: -1}" = '%' ]; then
            local l_num_fields=$(( ${#__FORM_FIELDS[@]} / l_batch_size ))
            l_menu_height="$(__scale_value "$l_menu_height" "$l_num_fields")"
        fi

        local l_rc l_default_item_value_pos
        local -n l_extra_box_args=__BOX_RAW_USER_ARGS
        # Menu box looper to reflect changes made in the input field
        while :; do
            local i l_batch_size=9
            local -a l_entries=()
            for ((i = 0; i < ${#__FORM_FIELDS[@]}; i += l_batch_size)); do
                local l_type="${__FORM_FIELDS[i+8]?}" l_title="${__FORM_FIELDS[i]?}" \
                    l_init_value="${__FORM_FIELDS[i+3]?}" l_width="${__FORM_FIELDS[i+6]?}" \
                    l_maxlength="${__FORM_FIELDS[i+7]?}"

                if [ "$l_width" -lt 0 ]; then
                    # If l_width value is negative, the field cannot be altered, and the negated value
                    # is used to determine the displayed-length
                    l_width=${l_width::1}
                fi
                if [ "$l_maxlength" -le 0 ]; then
                    # If the permissible length of the data that can be entered in the field is 0 or
                    # less, the value of 'width' is used instead
                    l_maxlength="$l_width"
                fi

                local l_display_init_value="$l_init_value" l_underscores
                if [ "$l_width" -gt "$l_maxlength" ]; then
                    l_display_init_value="${l_init_value:0:l_maxlength}"
                    printf -v l_underscores "%${l_maxlength}s" ''
                elif [ "$l_width" -gt 0 ]; then
                    l_display_init_value="${l_init_value:0:l_width}"
                    printf -v l_underscores "%${l_width}s" ''
                fi
                l_underscores=${l_underscores// /_}

                # Display a placeholder instead if there's a password
                if [ ${#l_init_value} -gt 0 ] && [ $((l_type & __FORM_HIDDEN_TYPE_FLAG)) -gt 0 ]; then
                    # Replace each individual character with asterisk
                    l_display_init_value="${l_display_init_value//?/*}"
                fi

                # Fill the remainder of the permissible chars in the initial value with underscores
                l_display_init_value+=${l_underscores:${#l_display_init_value}}

                local l_is_value_truncated=0
                if [ ${#l_init_value} -gt ${#l_display_init_value} ]; then
                    l_is_value_truncated=1
                fi

                # Fill the remainder of the initial value with spaces using the largest input value
                # displayed-length to evenly align all fields in the window. NOTE: a loop is used
                # instead of Printf for right padding, as the latter is byte-oriented when
                # processing strings, thus no support for multibyte (UTF-8) strings
                local l_ii rem=$((__FORM_COLUMN_SIZES[0] - ${#l_display_init_value}))
                for ((l_ii = 0; l_ii < rem; l_ii++)); do
                    l_display_init_value+=' '
                done

                # Show a ">" at the end to indicate truncation
                if [ $l_is_value_truncated -eq 1 ]; then
                    l_display_init_value="${l_display_init_value::-1}>"
                fi

                l_entries+=("$l_title" "$l_display_init_value")
            done

            # Set the default entry item to the last selected field
            if [ ${__FORM['last-selected-field']+xyz} ]; then
                if [ ${l_default_item_value_pos+xyz} ]; then
                    l_extra_box_args[l_default_item_value_pos-1]="${__FORM['last-selected-field']?}"
                else
                    l_extra_box_args+=('--default-item' "${__FORM['last-selected-field']?}")
                    l_default_item_value_pos=${#l_extra_box_args[@]}
                fi
            fi

            __box_draw "$l_menu_height" "${l_entries[@]}"; l_rc=$?

            # Prevent the menu box from looping, if needed
            if [ $l_rc -gt 0 ] || [ "${__BOX['loop']?}" != 'true' ] &&
                [ "${__FORM['redraw']-0}" -eq 0 ]; then
                break
            fi
            __FORM['redraw']=0
        done
        return $l_rc
    fi
} # }}}

# @hide
function __form_menu_result_validation_callback() { # {{{
    local l_code=$?
    if [ $l_code -eq 0 ]; then # Entry selected
        local i l_selected_title="${1?}" l_title l_batch_size=9
        # Find the corresponding field's value by title
        for ((i = 0; i < ${#__FORM_FIELDS[@]}; i += l_batch_size)); do
            l_title="${__FORM_FIELDS[i]?}"
            if [ "$l_selected_title" = "$l_title" ]; then
                break
            fi
        done

        __FORM['last-selected-field']="$l_selected_title"

        local l_type="${__FORM_FIELDS[i+8]?}" l_width=${__FORM_FIELDS[i+6]?} \
            l_maxlength=${__FORM_FIELDS[i+7]?}
        if [ "$l_width" -le 0 ]; then
            # Break and redraw the menu form when selected a non-editable field (as per Dialog: if
            # width value is negative or 0, the field cannot be altered)
            __FORM['redraw']=1
            return "$__BOX_VALIDATION_CALLBACK_BREAK"
        fi
        if [ "$l_maxlength" -le 0 ]; then
            # If the permissible length of the data that can be entered in the field is 0, the value
            # of 'width' is used instead
            l_maxlength="$l_width"
        fi
        if [ "$l_maxlength" -eq 0 ]; then
            # Break and redraw the menu form when selected a non-editable field
            __FORM['redraw']=1
            return "$__BOX_VALIDATION_CALLBACK_BREAK"
        fi

        if [ $((l_type & __FORM_READONLY_TYPE_FLAG)) -gt 0 ]; then
            # Break and redraw the menu form when selected a readonly field
            __FORM['redraw']=1
            return "$__BOX_VALIDATION_CALLBACK_BREAK"
        fi

        local l_value="${__FORM_FIELDS[i+3]?}" l_input_type='text'
        if [ $((l_type & __FORM_HIDDEN_TYPE_FLAG)) -gt 0 ]; then
            l_input_type='password'
        fi
        while :; do
            l_value="$(input \
                type="$l_input_type" \
                text="$l_selected_title(max length: $l_maxlength)" \
                value="${l_value:0:l_maxlength}" \
                width='max' \
                hideBreadcrumb='true')"; l_code=$?
            if [ $l_code -eq 0 ]; then
                if [ ${#l_value} -gt "$l_maxlength" ]; then
                    continue
                fi
                __FORM_FIELDS[i+3]="$l_value"
            fi
            # Break and redraw the menu form when value has been changed or ESC button is pressed
            __FORM['redraw']=1
            return "$__BOX_VALIDATION_CALLBACK_BREAK"
        done
    elif [ $l_code -eq 1 ]; then # Done button pressed
        l_code=0
        __BOX_VALIDATION_CALLBACK_RESPONSE[0]=$l_code

        local i l_value l_width l_batch_size=9
        for ((i = 0; i < ${#__FORM_FIELDS[@]}; i += l_batch_size)); do
            l_value="${__FORM_FIELDS[i+3]?}"
            l_width=${__FORM_FIELDS[i+6]?}
            # As per Dialog, should include only visible fields in the output
            if [ "$l_width" -gt 0 ]; then
                __BOX_VALIDATION_CALLBACK_RESPONSE+=("$l_value")
            fi
        done
        # We're sending to the user's callback the form result with 0 (success) code
        return "$__BOX_VALIDATION_CALLBACK_SWAP_RESULT_AND_RETCODE"
    fi
    # Propagate the ESC key press
    return "$__BOX_VALIDATION_CALLBACK_PROPAGATE"
}
readonly -f __form_menu_result_validation_callback
# }}}

# Convert string representation of the field type(s) to bits.
# The type can be mixed, such as 'hidden|readonly'.
# @hide
function __form_convert_field_types_to_bits() { # {{{
    # Note that, any field is an input
    local l_bits=$__FORM_INPUT_TYPE_FLAG
    local IFS='|' l_type
    for l_type in ${1?}; do
        case "$l_type" in
            input);;
            hidden) l_bits=$((l_bits + __FORM_HIDDEN_TYPE_FLAG));;
            readonly) l_bits=$((l_bits + __FORM_READONLY_TYPE_FLAG));;
            *) __panic "formField: Invalid field type: $l_type"
        esac
    done
    printf '%d' $l_bits
}
readonly -f __form_convert_field_types_to_bits
# }}}

# @hide
function __form_dump_callback() { # {{{
    echo 'FORM {'
        __pretty_print_array __FORM | __treeify 2 0
    echo '}'
    echo 'FORM_FIELDS {'
        local i l_batch_size=9
        for ((i = 0; i < ${#__FORM_FIELDS[@]}; i += l_batch_size)); do
            printf '%d: title="%s" titleY=%d titleX=%d ' $((i/l_batch_size+1)) \
                "${__FORM_FIELDS[@]:i:3}"
            printf 'value="%s" valueY=%d valueX=%d ' "${__FORM_FIELDS[@]:i+3:3}"
            printf 'width=%d maxlength=%d type=%d\n' "${__FORM_FIELDS[@]:i+6:3}"
        done | __treeify 2 0
    echo '}'
    echo 'FORM_COLUMN_SIZES {'
        local l_batch_size=2
        for ((i = 0; i < ${#__FORM_COLUMN_SIZES[@]}; i += l_batch_size)); do
            printf '%d: title=%d value=%d\n' $((i/l_batch_size+1)) \
                "${__FORM_COLUMN_SIZES[@]:i:2}"
        done | __treeify 2 0
    echo '}'
}
readonly -f __form_dump_callback
# }}}
