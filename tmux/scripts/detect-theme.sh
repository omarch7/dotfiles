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
    # Unset all catppuccin-generated options so the -o flag doesn't skip them.
    # This covers @thm_* (palette), @_ctp_* (internals), @catppuccin_status_*
    # (compiled modules), and @catppuccin_*_color (module accent colors).
    tmux show-options -g \
        | awk '/^@(thm_|_ctp_|catppuccin_status_|catppuccin_[a-z_]+_color )/ {print $1}' \
        | while read -r opt; do
            tmux set -gu "$opt"
        done

    tmux set -g @catppuccin_flavor "$flavor"
    bash ~/.tmux/plugins/tmux/catppuccin.tmux
    tmux source ~/.tmux/scripts/status.conf
    # Re-run plugin scripts to replace #{battery_percentage} etc. with #(script) calls
    bash ~/.tmux/plugins/tmux-battery/battery.tmux
    bash ~/.tmux/plugins/tmux-cpu/cpu.tmux

    # Switch lsd color theme
    lsd_theme="$HOME/.config/lsd/themes/catppuccin-${flavor}/colors.yaml"
    if [ -f "$lsd_theme" ]; then
        cp "$lsd_theme" "$HOME/.config/lsd/colors.yaml"
    fi
fi
