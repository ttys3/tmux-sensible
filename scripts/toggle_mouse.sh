#!/usr/bin/env bash

# https://github.com/gpakosz/.tmux/blob/788ffd8e6f51d268a502c94e563f5bef32bec882/.tmux.conf#L270

_toggle_mouse() {
    old=$(tmux show -gv mouse)
    new=""

    if [ "$old" = "on" ]; then
        new="off"
    else
        new="on"
    fi

    tmux set -g mouse $new
    tmux display "mouse mode set $new"
}

_toggle_mouse
