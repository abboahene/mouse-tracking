#!/usr/bin/env bash
# Universal Mouse Cursor Support (Bash & Zsh)
# Sourcing this file enables clicking to move the cursor in the terminal line editor.
# Usage:
#   mt --toggle   # Toggle on/off
#   mt --on       # Force enable
#   mt --off      # Force disable

# ==============================================================================
# ZSH IMPLEMENTATION
# ==============================================================================
if [[ -n "$ZSH_VERSION" ]]; then

    # Global variable to store the starting column of the cursor
    typeset -g ZLE_MOUSE_START_COL=1

    function zle-mouse-move() {
        local content=""
        local char=""
        
        # Read the mouse event sequence (SGR format: \e[<ID;X;YM)
        while read -k 1 char; do
            content+="$char"
            if [[ "$char" == "M" || "$char" == "m" ]]; then
                break
            fi
        done

        local -a params
        local content_body="${content%[Mm]}"
        params=("${(@s/;/)${content_body}}")

        local button="${params[1]}"
        local click_col="${params[2]}"

        # Only react to left click PRESS (button 0, last char M)
        # If last char is 'm' (release), or button is different (drag is typically modifier+button)
        # SGR mouse drag reports as button + 32, so button 32 is left-drag.
        # We ONLY want simple click press (button 0, ending in M).
        
        # Check terminator
        local terminator="${content: -1}"

        # If it's not a press (M), ignore
        if [[ "$terminator" != "M" ]]; then
            return 0
        fi

        # If it's not button 0 (left click), ignore strings like 32 (drag)
        if [[ "$button" != "0" ]]; then
            return 0
        fi

        # Calculate target position using the captured start column
        # Offset = Click_Col - Start_Col
        local target_pos=$(( click_col - ZLE_MOUSE_START_COL ))

        # Clamp and apply
        if (( target_pos < 0 )); then target_pos=0; fi
        if (( target_pos > ${#BUFFER} )); then target_pos=${#BUFFER}; fi

        CURSOR=$target_pos
    }

    # Internal Hook Functions
    function _mouse_zle_line_init() {
        # Enable Mouse Tracking
        print -n '\e[?1000h\e[?1006h'
        
        # Query Cursor Position to find prompt end
        print -n '\e[6n'
        
        local resp=""
        local char=""
        
        # Read expected response: ESC [ Row ; Col R
        if read -s -k 1 -t 0.1 char && [[ "$char" == $'\e' ]]; then
            read -s -k 1 -t 0.1 char # [
            while read -s -k 1 -t 0.1 char; do
                if [[ "$char" == "R" ]]; then break; fi
                resp+="$char"
            done
            local -a fields
            fields=("${(@s/;/)${resp}}")
            ZLE_MOUSE_START_COL=${fields[2]}
        fi
    }

    function _mouse_zle_line_finish() {
        # Disable Mouse Tracking
        print -n '\e[?1000l\e[?1006l'
    }

    function _mouse_impl_on() {
        if [[ "$TERM" != "dumb" ]]; then
            zle -N zle-mouse-move
            zle -N zle-line-init _mouse_zle_line_init
            zle -N zle-line-finish _mouse_zle_line_finish
            bindkey '\e[<' zle-mouse-move
        fi
    }

    function _mouse_impl_off() {
        # Disable tracking immediately
        print -n '\e[?1000l\e[?1006l'
        # Unbind key
        bindkey -r '\e[<' 2>/dev/null
        # Remove widgets
        zle -D zle-line-init 2>/dev/null
        zle -D zle-line-finish 2>/dev/null
        zle -D zle-mouse-move 2>/dev/null
    }

    function _mouse_impl_toggle() {
        # Check if the key is bound to our widget
        if bindkey | grep -q 'zle-mouse-move'; then
            _mouse_impl_off
            echo "Mouse cursor disabled."
        else
            _mouse_impl_on
            echo "Mouse cursor enabled."
        fi
    }

    # Main Control Command
    function mt() {
        case "$1" in
            --on)
                _mouse_impl_on
                ;;
            --off)
                _mouse_impl_off
                ;;
            --toggle)
                _mouse_impl_toggle
                ;;
            *)
                echo "Usage: mt [--on | --off | --toggle]"
                return 1
                ;;
        esac
    }

    # Enable by default on source
    _mouse_impl_on

    return
fi

# ==============================================================================
# BASH IMPLEMENTATION
# ==============================================================================
if [[ -n "$BASH_VERSION" ]]; then
    
    # Check for Bash 4.4+ (required for prompt expansion ${PS1@P})
    if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4) )); then
        echo "Mouse cursor support requires Bash 4.4 or newer."
        return 1
    fi

    _bash_mouse_handler() {
        # Read the remaining sequence from stdin (already ate \e[<)
        local content=""
        local char=""

        # Read loop similar to zsh but using read -n 1
        while IFS= read -r -n 1 char; do
            content+="$char"
            if [[ "$char" == "M" || "$char" == "m" ]]; then
                break
            fi
        done

        # Parse content: ID;X;Y[M|m]
        local body="${content%[Mm]}"
        IFS=';' read -r button click_col click_row <<< "$body"

        # Only Left Click (0)
        if [[ "$button" != "0" ]]; then
            return
        fi

        # Calculate Prompt Length
        # 1. Expand PS1 to what is actually shown
        local prompt_expanded="${PS1@P}"
        
        # 2. Strip ANSI codes to get visual length
        # Regex to remove \x1B[...]
        local prompt_stripped=$(sed "s/\x1B\[[0-9;]*[a-zA-Z]//g" <<< "$prompt_expanded")
        # There might be standard non-printing chars \[ ... \] in bash prompt raw, but @P handles them?
        # Actually @P produces the output string. Visible length is standard generic strip.
        local prompt_len=${#prompt_stripped}
        
        # In Bash, there is usually a trailing space or character not counted? 
        # Tuning might be needed.
        
    # Control Commands
    function _mouse_impl_on() {
        # Bind the function to the escape sequence
        bind -x '"\e[<": _bash_mouse_handler'

        # Append to PROMPT_COMMAND if not already there
        if [[ "$PROMPT_COMMAND" != *"_enable_mouse"* ]]; then
            PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND;}_enable_mouse"
        fi

        # Set DEBUG trap
        trap _disable_mouse DEBUG
    }

    function _mouse_impl_off() {
        # Turn off tracking immediately
        _disable_mouse
        
        # Unbind
        bind -r "\e[<" 2>/dev/null

        # Clean PROMPT_COMMAND
        PROMPT_COMMAND="${PROMPT_COMMAND//_enable_mouse/}"
        PROMPT_COMMAND="${PROMPT_COMMAND//;;/;}" # Remove potential double semi-colons
        PROMPT_COMMAND="${PROMPT_COMMAND/#;/}"   # Remove leading semi-colon
        PROMPT_COMMAND="${PROMPT_COMMAND/%;/}"   # Remove trailing semi-colon

        # Remove DEBUG trap
        trap - DEBUG
    }

    function _mouse_impl_toggle() {
        if [[ "$PROMPT_COMMAND" == *"_enable_mouse"* ]]; then
            _mouse_impl_off
            echo "Mouse cursor disabled."
        else
            _mouse_impl_on
            echo "Mouse cursor enabled."
        fi
    }

    # Main Control Command
    function mt() {
        case "$1" in
            --on)
                _mouse_impl_on
                ;;
            --off)
                _mouse_impl_off
                ;;
            --toggle)
                _mouse_impl_toggle
                ;;
            *)
                echo "Usage: mt [--on | --off | --toggle]"
                return 1
                ;;
        esac
    }

    # Enable by default on source
    _mouse_impl_on
    
    return
fi      # Remove DEBUG trap
        trap - DEBUG
    }

    function toggle-mouse-tracking() {
        if [[ "$PROMPT_COMMAND" == *"_enable_mouse"* ]]; then
            mouse-tracking-off
            echo "Mouse cursor disabled."
        else
            mouse-tracking-on
            echo "Mouse cursor enabled."
        fi
    }

    # Enable by default on source
    mouse-tracking-on
    
    return
fi

# ==============================================================================
# UNSUPPORTED SHELL
# ==============================================================================
echo "Unsupported shell. This script works with Zsh and Bash (4.4+)."
