#!/usr/bin/env bash

# Helper script to generate demo.gif from demo.tape using VHS.
# The recording will produce PNG frames of the terminal, but the actual GIF is
# encoded via Gifski to preserve the max possible visual quality from these PNG
# images.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || return $?

width=830
height=546
quality=80
tape="$ROOT/demo.tape"
frames_dir=frames
out_gif="$ROOT/demo.gif"

declare -i fps
fps="$(awk '/Set Framerate/ { print $3; exit }' "$tape" | grep .)" || return $?

rm -rf "$frames_dir"

vhs "$tape" &&
    read -r -N 1 -p 'Frames have been generated! Press any key to generate GIF image...' &&
    # Create a 24bit MPEG video flow from PNGs for Gifski, while merging
    # terminal screenshots with the cursor movements as we go
    ffmpeg \
    -r $fps -i "$frames_dir"/frame-text-%05d.png \
    -r $fps -i "$frames_dir"/frame-cursor-%05d.png \
    -filter_complex '[0][1]overlay' -pix_fmt yuv444p -f yuv4mpegpipe - | \
        gifski \
            --output "$out_gif" \
            --quality $quality \
            --fps $fps \
            --width $width \
            --height $height -
