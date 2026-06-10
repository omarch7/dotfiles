#!/usr/bin/env bash
# Detect system dark/light mode and sync the catppuccin flavor across CLI tools
# (tmux, starship, bat, lsd, glow, television, btop, claude code) that aren't
# themed elsewhere.
# Supports macOS, WSL2, and native Linux (Omarchy marker + freedesktop fallback).

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
            elif [ -e "$HOME/.config/omarchy/current/theme/light.mode" ]; then
                # Omarchy: light themes drop a light.mode marker in the active theme dir
                echo "light"
            elif gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | grep -qi light; then
                # Freedesktop fallback (GNOME-based DEs)
                echo "light"
            else
                echo "dark"
            fi
            ;;
        *)
            echo "dark"
            ;;
    esac
}

apply_theme() {
    local mode flavor state_file current

    mode=$(detect_mode)
    if [ "$mode" = "light" ]; then
        flavor="latte"
    else
        flavor="mocha"
    fi

    # Gate so we don't re-apply needlessly. The state file keeps this correct when
    # triggered by the Omarchy theme-set hook, which has no attached client/server.
    # But a fresh tmux server reloads the hardcoded @catppuccin_flavor default from
    # tmux.conf, which the cache can't see — so when a server is running we also
    # reconcile against its live flavor and re-apply if it has drifted.
    state_file="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles-theme/flavor"
    current=""
    [ -f "$state_file" ] && current=$(cat "$state_file")
    if [ "$current" = "$flavor" ]; then
        if tmux info &>/dev/null; then
            [ "$(tmux show-option -gqv @catppuccin_flavor)" = "$flavor" ] && return 0
        else
            return 0
        fi
    fi

    # --- tmux (only when a server is running) ---
    if tmux info &>/dev/null; then
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
    fi

    # --- starship ---
    starship_config="$HOME/.config/starship.toml"
    if [ -f "$starship_config" ]; then
        sed -i'' -e "s/^palette = \"catppuccin_[a-z]*\"/palette = \"catppuccin_${flavor}\"/" "$starship_config"
    fi

    # --- lsd ---
    lsd_theme="$HOME/.config/lsd/themes/catppuccin-${flavor}/colors.yaml"
    if [ -f "$lsd_theme" ]; then
        cp "$lsd_theme" "$HOME/.config/lsd/colors.yaml"
    fi

    # --- bat ---
    bat_config="$HOME/.config/bat/config"
    if [ -f "$bat_config" ]; then
        # Capitalize first letter: mocha -> Mocha, latte -> Latte
        bat_flavor="$(echo "$flavor" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
        sed -i'' -e "s/--theme=\"Catppuccin .*\"/--theme=\"Catppuccin ${bat_flavor}\"/" "$bat_config"
    fi

    # --- glow (config path differs by OS) ---
    if [ "$(uname -s)" = "Darwin" ]; then
        glow_config="$HOME/Library/Preferences/glow/glow.yml"
    else
        glow_config="$HOME/.config/glow/glow.yml"
    fi
    if [ -f "$glow_config" ]; then
        glow_theme="$HOME/.config/glow/themes/catppuccin-${flavor}.json"
        sed -i'' -e "s|style: \".*\"|style: \"${glow_theme}\"|" "$glow_config"
    fi

    # --- claude code (custom themes live in ~/.claude/themes; Claude Code's
    # "auto" theme only toggles the built-in presets, so point the theme
    # setting at the matching custom flavor instead) ---
    claude_settings="$HOME/.claude/settings.json"
    if [ -f "$claude_settings" ] && command -v jq &>/dev/null; then
        claude_tmp=$(mktemp)
        if jq --arg theme "custom:catppuccin-${flavor}" '.theme = $theme' "$claude_settings" >"$claude_tmp" 2>/dev/null; then
            mv "$claude_tmp" "$claude_settings"
        else
            rm -f "$claude_tmp"
        fi
    fi

    # --- television (random accent; skipped on Linux, not installed there) ---
    if [ "$(uname -s)" != "Linux" ]; then
        tv_config="$HOME/.config/television/config.toml"
        if [ -f "$tv_config" ]; then
            accents=(blue flamingo green lavender maroon mauve peach pink red rosewater sapphire sky teal yellow)
            accent="${accents[$((RANDOM % ${#accents[@]}))]}"
            sed -i'' -e "s/theme = \"catppuccin-[a-z]*-[a-z]*\"/theme = \"catppuccin-${flavor}-${accent}\"/" "$tv_config"
        fi
    fi

    # --- btop (macOS only; skipped on Linux where Omarchy manages the theme) ---
    if [ "$(uname -s)" = "Darwin" ] && command -v btop &>/dev/null; then
        btop_theme_dir="$HOME/.config/btop/themes"
        btop_theme_file="${btop_theme_dir}/catppuccin-${flavor}.theme"
        btop_link="${btop_theme_dir}/current.theme"
        if [ -f "$btop_theme_file" ]; then
            ln -sf "$btop_theme_file" "$btop_link"
        fi
    fi

    # Persist the applied flavor for the next run's gate.
    mkdir -p "$(dirname "$state_file")"
    echo "$flavor" > "$state_file"
}

# Run only when executed directly (sourcing for tests must have no side effects).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    apply_theme
fi
