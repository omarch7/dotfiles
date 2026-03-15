#!/usr/bin/env bash
# Detect system dark/light mode and update catppuccin tmux flavor accordingly.
# Supports macOS and WSL2.

detect_mode() {
    case "$(uname -s)" in
        Darwin)
            # macOS: defaults returns "Dark" in dark mode, fails in light mode
            if defaults read -g AppleInterfaceStyle &>/dev/null; then
                echo "dark"
            else
                echo "light"
            fi
            ;;
        Linux)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                # WSL2: query Windows registry (0 = dark, 1 = light)
                local val
                val=$(powershell.exe -NoProfile -NonInteractive -Command \
                    "Get-ItemPropertyValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name AppsUseLightTheme" 2>/dev/null | tr -d '\r')
                if [ "$val" = "0" ]; then
                    echo "dark"
                else
                    echo "light"
                fi
            else
                echo "dark"
            fi
            ;;
        *)
            echo "dark"
            ;;
    esac
}

mode=$(detect_mode)

if [ "$mode" = "light" ]; then
    flavor="latte"
else
    flavor="mocha"
fi

current=$(tmux show-option -gqv @catppuccin_flavor)
if [ "$current" != "$flavor" ]; then
    tmux set -g @catppuccin_flavor "$flavor"
    tmux run ~/.tmux/plugins/tmux/catppuccin.tmux
fi
