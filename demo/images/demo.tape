# vi: ft=elixir
# vim: set fdm=marker:

Require dialog
Require whiptail

Output frames/

Set Framerate 13

Set FontFamily "Ubuntu Mono"
Set Theme "MaterialDark" # "iTerm2 Tango Dark"

Set Padding 0
Set Margin 0
# NOTE: Upscale for a better quality when downscaling to 830x547
Set FontSize 50 # ~x2.3 upscale from 22
Set Width 2490 # 3x upscale from 830
Set Height 1638 # 3x upscale from 546

Env VHS "1"

# Display form box in both Dialog & Whiptail {{{
# Display form box in Dialog {{{2
Type "./demo/main.sh" Sleep 500ms
# NOTE: do not record until box is displayed to avoid blank frames
Hide
Enter
Wait+Screen /Example main menu\n/
Show

Sleep 1s

# Select form box option
Type "6" Sleep 2s
Hide
Enter
Wait+Screen /Example form box/
Show

Sleep 2s

# Fill in the First Name field
Type "John" Sleep 500ms

# Focus on the Last Name field
Down
Sleep 500ms
Hide

# Exit form box
Escape 2 # NOTE: emit twice to exit faster
# }}}

# Exit the main menu
Wait+Screen /Example main menu\n/
Escape 2 # NOTE: emit twice to exit faster

# Display form box in Whiptail {{{2
Type@0 "BOXLIB_USE_WHIPTAIL=1 ./demo/main.sh"
Enter

# Select form box option
Down 5 Enter

# Select and start filling same data as in Dialog's form
Enter Type@0 "John" Enter

# Focus on the Last Name field
Down
Show

Sleep 3s

# Select and start filling in the Last Name field
Hide
Enter
Wait+Screen /Last Name \(max length/
Show

Sleep 1s

Type@150ms "Doe" Sleep 1s

# Select and press OK button
Tab Sleep 500ms
Hide
Enter
Wait+Screen /Last Name\s*Doe/
Show

Sleep 3s

# Focus on Birth Date field
Down@150ms 3

# Select and start filling in the Birth Date field exceeding the max length by 1 char
Hide
Enter
Wait+Screen /Birth Date \(max length/
Show
Type "11/04/19782" Sleep 500ms

# Select and press OK button and wait for the box redraw as field exceeded max length, so it should
# be limited
Tab Sleep 500ms
Hide
Enter
Wait+Screen /1978[^2]/
Show

Sleep 1s

# Select and press OK button again
Tab Sleep 500ms
Hide
Enter
Wait+Screen /Birth Date\s*\d\d/
Show

Sleep 2s

# Select Done button
Tab@500ms 2 Sleep 500ms
Hide
Enter
Wait+Screen /Registration form result/
Show

Sleep 3s

# Exit form box
Hide
Enter
# }}}
# }}}

# Exit the main menu
Wait+Screen /Example main menu\n/
Escape 2 # NOTE: emit twice to exit faster
Enter

# Wait for the demo script to exit
Wait

# Re-launch the main menu box
Type@0 "./demo/main.sh"
Enter
Wait+Screen /Example main menu\n/
# Restore cursor position on the form box option
Type "6"
Show

Sleep 1s

# Display program box in both Dialog & Whiptail {{{
# Display program box in Dialog {{{2
# Select program box option
Type "f" Sleep 1s
Hide
Enter
Wait+Screen /Example program box\n/
Show

# Record until "Example long scrolling output (line 10)" line. The rest will be rendered by Whiptail
Wait+Screen /line 10/
Hide

# Wait for the program output to be fully processed
Wait+Screen /Done/

# Press OK button to exit program box
Enter
# }}}

# Exit the main menu
Wait+Screen /Example main menu\n/
Escape 2 # NOTE: emit twice to exit faster

# Wait for the demo script to exit
Enter
Wait

# Display program box in Whiptail {{{2
Type@0 "BOXLIB_USE_WHIPTAIL=1 ./demo/main.sh"
Enter
Wait+Screen /Example main menu\n/

# Select program box option
Type "f" Enter
Wait+Screen /line 15/
Show

# Wait for the program output to be fully processed
Wait+Screen /Done/

Sleep 2s

# Press OK button to exit program box
Hide
Enter
# }}}
# }}}

# Exit the main menu
Wait+Screen /Example main menu\n/
Escape 2 # NOTE: emit twice to exit faster

# Wait for the demo script to exit
Enter
Wait

# Re-launch the main menu box
Type@0 "./demo/main.sh"
Enter
Wait+Screen /Example main menu\n/
# Restore cursor position on the program box option
Type "f"
Show

Sleep 1s

# Display mixed program box in both Dialog & Whiptail {{{
# Display mixed program box in Dialog {{{2
# Select mixed progress box option
Type "c" Sleep 1s
Hide
Enter

# Wait for mixed progress box to start
Wait+Screen /Example mixed progress box\n/
Show

# Record until "Work in progress... [7/10]" line. The rest will be rendered by Whiptail
Wait+Screen /\[7.10\]/
Hide

# Wait for the mixed process to complete and return to main menu
Wait+Screen /Example main menu\n/
# }}}

# Exit the main menu
Escape 2 # NOTE: emit twice to exit faster

# Wait for the demo script to exit
Enter
Wait

# Display mixed program box in Whiptail {{{2
Type@0 "BOXLIB_USE_WHIPTAIL=1 ./demo/main.sh"
Enter
Wait+Screen /Example main menu\n/

# Select mixed progress box option
Type "c" Enter

# We'll resume recording when reaching the "Work in progress... [7/10]" line, where Dialog stopped
Wait+Screen /\[7.10\]/
Show

# Wait for the mixed process to complete and return to main menu
Wait+Screen /Example main menu\n/
# }}}
# }}}

Sleep 1s

# Display pause box in Whiptail {{{
# Select pause box option
Type "e" Sleep 500ms
Hide
Enter

# Wait for the pause box to start
Wait+Screen /Example pause box\n/
Show

# Wait for the pause box to complete and return to main menu
Wait+Screen /Example main menu\n/
# }}}

# Select Exit button in the main menu
Tab 2 Sleep 1s
