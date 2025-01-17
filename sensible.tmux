#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# used to match output from `tmux list-keys`
KEY_BINDING_REGEX="bind-key[[:space:]]\+\(-r[[:space:]]\+\)\?\(-T prefix[[:space:]]\+\)\?"

is_osx() {
	local platform=$(uname)
	[ "$platform" == "Darwin" ]
}

iterm_terminal() {
	[[ "$TERM_PROGRAM" =~ ^iTerm ]]
}

command_exists() {
	local command="$1"
	type "$command" >/dev/null 2>&1
}

# returns prefix key, e.g. 'C-a'
prefix() {
	tmux show-option -gv prefix
}

# if prefix is 'C-a', this function returns 'a'
prefix_without_ctrl() {
	local prefix="$(prefix)"
	echo "$prefix" | cut -d '-' -f2
}

option_value_not_changed() {
	local option="$1"
	local default_value="$2"
	local option_value=$(tmux show-option -gv "$option")
	[ "$option_value" == "$default_value" ]
}

server_option_value_not_changed() {
	local option="$1"
	local default_value="$2"
	local option_value=$(tmux show-option -sv "$option")
	[ "$option_value" == "$default_value" ]
}

key_binding_not_set() {
	local key="$1"
	if $(tmux list-keys | grep -q "${KEY_BINDING_REGEX}${key}[[:space:]]"); then
		return 1
	else
		return 0
	fi
}

key_binding_not_changed() {
	local key="$1"
	local default_value="$2"
	if $(tmux list-keys | grep -q "${KEY_BINDING_REGEX}${key}[[:space:]]\+${default_value}"); then
		# key still has the default binding
		return 0
	else
		return 1
	fi
}

main() {
	# OPTIONS

	# enable utf8 (option removed in tmux 2.2)
	tmux set-option -g utf8 on 2>/dev/null

	# enable utf8 in tmux status-left and status-right (option removed in tmux 2.2)
	tmux set-option -g status-utf8 on 2>/dev/null

	# address vim mode switching delay (http://superuser.com/a/252717/65504)
	if server_option_value_not_changed "escape-time" "500"; then
		tmux set-option -s escape-time 0
	fi

	# increase scrollback buffer size
	if option_value_not_changed "history-limit" "2000"; then
		tmux set-option -g history-limit 50000
	fi

	# tmux messages are displayed for 4 seconds
	if option_value_not_changed "display-time" "750"; then
		tmux set-option -g display-time 4000
	fi

	# refresh 'status-left' and 'status-right' more often
	if option_value_not_changed "status-interval" "15"; then
		tmux set-option -g status-interval 5
	fi

	# required (only) on OS X
	if is_osx && command_exists "reattach-to-user-namespace" && option_value_not_changed "default-command" ""; then
		tmux set-option -g default-command "reattach-to-user-namespace -l $SHELL"
	fi

	# upgrade $TERM, tmux 1.9
	if option_value_not_changed "default-terminal" "screen"; then
		tmux set-option -g default-terminal "screen-256color"
	fi
	# upgrade $TERM, tmux 2.0+
	if server_option_value_not_changed "default-terminal" "screen"; then
		tmux set-option -s default-terminal "screen-256color"
	fi

	# tmux >= 3.2
	# tmux set-option -as terminal-features ",xterm-256color:RGB"

	# tmux 3.1
	tmux set-option -as terminal-overrides ",xterm-256color:RGB"

	# I don't think emacs key bindings in tmux command prompt are better than vi keys
	# tmux set-option -g status-keys emacs
	# force Vi mode
	# really you should export VISUAL or EDITOR environment variable, see manual
	tmux set-option -g status-keys vi
	tmux set-option -g mode-keys vi

	# focus events enabled for terminals that support them
	tmux set-option -g focus-events on

	# super useful when using "grouped sessions" and multi-monitor setup
	if ! iterm_terminal; then
		tmux set-window-option -g aggressive-resize on
	fi

	# DEFAULT KEY BINDINGS

	local prefix="$(prefix)"
	local prefix_without_ctrl="$(prefix_without_ctrl)"

	# if C-b is not prefix
	if [ $prefix != "C-b" ]; then
		# unbind obsolete default binding
		if key_binding_not_changed "C-b" "send-prefix"; then
			tmux unbind-key C-b
		fi

		# pressing `prefix + prefix` sends <prefix> to the shell
		if key_binding_not_set "$prefix"; then
			tmux bind-key "$prefix" send-prefix
		fi
	fi

	# If Ctrl-a is prefix then `Ctrl-a + a` switches between alternate windows.
	# Works for any prefix character.
	if key_binding_not_set "$prefix_without_ctrl"; then
		tmux bind-key "$prefix_without_ctrl" last-window
	fi

	# easier switching between next/prev window
	if key_binding_not_set "C-p"; then
		tmux bind-key C-p previous-window
	fi
	if key_binding_not_set "C-n"; then
		tmux bind-key C-n next-window
	fi

	# source `.tmux.conf` file - as suggested in `man tmux`
	if key_binding_not_set "R"; then
		tmux bind-key R run-shell ' \
			tmux source-file ~/.tmux.conf > /dev/null; \
			tmux display-message "Sourced .tmux.conf!"'
	fi

	# pane swap
	tmux bind-key '>' swap-pane -D # swap current pane with the next one
	tmux bind-key '<' swap-pane -U # swap current pane with the previous one

	# new popup on current dir
	tmux bind-key g run-shell "tmux popup -xC -yC -w140 -h40 -KER 'zsh' -d '#{pane_current_path}'"

	# maximize current pane
	tmux bind-key + run-shell "$CURRENT_DIR/scripts/maximize_pane.sh #{session_name} #D"

	# toggle mouse
	tmux bind-key m run-shell "$CURRENT_DIR/scripts/toggle_mouse.sh"

	# edit configuration
	# copy from oh my tmux https://github.com/gpakosz/.tmux/blob/41af713ff786ae2ea38ec52f7d7ef258ccd9fb9c/.tmux.conf#L26
	tmux bind-key e new-window -n "~/.tmux.conf" "\${EDITOR:-nvim} ~/.tmux.conf && tmux source ~/.tmux.conf && tmux display \"~/.tmux.conf sourced\""
}

main

# vim: set ft=sh ts=4 sw=4 tw=120 noet :
