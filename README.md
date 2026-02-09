# Universal Mouse Cursor Support for Zsh & Bash

A lightweight shell script that enables mouse click support for moving the cursor within the terminal line editor. No more holding down arrow keys to get to the middle of a long command!

## Features

-   **Cross-Shell Support**: Works with both **Zsh** and **Bash** (version 4.4+).
-   **Click to Move**: Simply click anywhere on the command line to move the cursor to that position.
-   **Toggleable**: Easy commands to enable, disable, or toggle the functionality on the fly.
-   **Safety Hooks**: Automatically disables mouse tracking when running commands (so it doesn't interfere with interactive TUI applications like `vim`, `less`, or `htop`) and re-enables it when the prompt returns.

## Installation

Simply source the script in your shell configuration file (`.zshrc` or `.bashrc`).

1.  Download `mouse-tracking.sh` to your preferred location.
2.  Add the following line to your RC file:

```bash
source /path/to/mouse-tracking.sh
```

## Usage

Once sourced, the mouse tracking is enabled by default. You can control it using the `mt` command:

```bash
mt --toggle   # Toggle mouse tracking on/off
mt --on       # Force enable mouse tracking
mt --off      # Force disable mouse tracking
```

## Capabilities & Limitations

### Capabilities
-   **Zsh**: robust cursor positioning using ZLE hooks.
-   **Bash**: uses `READLINE_POINT` and prompt expansion to calculate position.
-   **Prompt Awareness**: Attempts to calculate the correct cursor position by ignoring ANSI color codes in the prompt.

### Known Limitations (Inabilities)
-   **Left Click Only**: Currently only supports the primary mouse button (left click). Dragging, right-clicking, or scrolling is ignored.
-   **Bash Prompt Complexity**: In Bash, extremely complex prompts (e.g., multi-line or those with dynamic non-printing characters not properly escaped) *might* cause slight offset calculations in cursor placement.
-   **Terminal Compatibility**: Requires a terminal emulator that supports the SGR mouse mode (`\e[?1006h`). Most modern terminals (iTerm2, Alacritty, Kitty, Terminal.app, VS Code Terminal) support this.
-   **Bash Version**: Strictly requires Bash 4.4 or higher due to reliance on the `${PS1@P}` expansion feature.

## License

MIT License. See [LICENSE](LICENSE) file for details.
