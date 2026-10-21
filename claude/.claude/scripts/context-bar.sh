#!/bin/bash

# Color codes
C_RESET='\033[0m'
C_GRAY='\033[38;5;245m'
C_BAR_EMPTY='\033[38;5;238m'
C_WARN='\033[38;2;229;192;123m'  # amber, >= 75%
C_CRIT='\033[38;2;224;108;117m'  # red, >= 90%
C_PACE='\033[38;5;250m'          # pace tick in limit bars

# Nerd Font icons
ICON_CTX='󰍛'    # nf-md-memory
ICON_5H='󰅐'     # nf-md-clock_outline
ICON_WEEK='󰃰'   # nf-md-calendar_clock
ICON_DAY='󰃭'    # nf-md-calendar

ROUTER_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline"
ROUTER_CACHE_TTL=60      # seconds before a background refresh is kicked off
ROUTER_CACHE_MAX_AGE=600 # older than this, the router is treated as unreachable

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

input=$(cat)

# Extract model, directory, and cwd
model=$(echo "$input" | jq -r '.model.display_name // .model.id // "?"')
effort_level=$(echo "$input" | jq -r '.effort.level // empty')
model_label="${model}${effort_level:+ · ${effort_level}}"

# Detect provider from the API base URL
base_url="${ANTHROPIC_BASE_URL:-}"
if [[ -z "$base_url" ]]; then
    PROVIDER=claude
    PROVIDER_ICON='󰛄'
    C_ACCENT='\033[38;2;199;141;136m'  # Anthropic orange
elif [[ "$base_url" == *hellofresh.io* ]]; then
    PROVIDER=router
    PROVIDER_ICON='󰧑'
    C_ACCENT='\033[38;5;74m'  # Bedrock blue
else
    PROVIDER=local
    PROVIDER_ICON='󰍹'
    C_ACCENT='\033[38;2;136;199;141m'  # local/self-hosted muted green
fi

# Render a bar for a percentage; turns amber/red as it fills up.
# Optional third arg: cell index (0..width) where a pace tick "│" is drawn.
render_bar() {
    local pct=$1 width=${2:-12} tick=${3:-} color=$C_ACCENT bar="" i progress
    [[ $pct -gt 100 ]] && pct=100
    if [[ $pct -ge 90 ]]; then
        color=$C_CRIT
    elif [[ $pct -ge 75 ]]; then
        color=$C_WARN
    fi
    for ((i=0; i<width; i++)); do
        [[ "$tick" == "$i" ]] && bar+="${C_PACE}│${C_RESET}"
        # Fill of this cell in hundredths: >= 100 is full, >= 40 is half
        progress=$((pct * width - i * 100))
        if [[ $progress -ge 100 ]]; then
            bar+="${color}█${C_RESET}"
        elif [[ $progress -ge 40 ]]; then
            bar+="${color}▄${C_RESET}"
        else
            bar+="${C_BAR_EMPTY}░${C_RESET}"
        fi
    done
    [[ "$tick" == "$width" ]] && bar+="${C_PACE}│${C_RESET}"
    printf '%s' "$bar"
}

# Pace tick position: how far through a window we are, as a cell index of an 8-wide bar
pace_tick() {
    local resets=$1 window=$2 left elapsed
    [[ -z "$resets" ]] && return
    left=$(( resets - $(date +%s) ))
    [[ $left -lt 0 ]] && left=0
    [[ $left -gt $window ]] && left=$window
    elapsed=$(( window - left ))
    echo $(( (elapsed * 8 + window / 2) / window ))
}

# Time until a reset epoch: "45m", "2h13m", "3d4h"
fmt_countdown() {
    local left
    [[ -z "$1" ]] && return
    left=$(( $1 - $(date +%s) ))
    [[ $left -lt 0 ]] && left=0
    if [[ $left -ge 86400 ]]; then
        echo "$((left / 86400))d$(( (left % 86400) / 3600 ))h"
    elif [[ $left -ge 3600 ]]; then
        echo "$((left / 3600))h$(( (left % 3600) / 60 ))m"
    else
        echo "$((left / 60))m"
    fi
}

# Percentage text, coloured to match the bar once it is in warning territory
pct_color() {
    if [[ $1 -ge 90 ]]; then
        printf '%s' "$C_CRIT"
    elif [[ $1 -ge 75 ]]; then
        printf '%s' "$C_WARN"
    else
        printf '%s' "$C_GRAY"
    fi
}

file_age() {
    local mtime
    mtime=$(stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null) || return 1
    echo $(( $(date +%s) - mtime ))
}

# Refresh the router's /key/info in the background so the bar never waits on the network
refresh_router_cache() {
    local token="${ANTHROPIC_AUTH_TOKEN:-${ANTHROPIC_API_KEY:-}}"
    local cache="$ROUTER_CACHE_DIR/key-info.json" lock="$ROUTER_CACHE_DIR/refresh.lock"
    [[ -z "$token" ]] && return
    mkdir -p "$ROUTER_CACHE_DIR"
    # Skip if another refresh started in the last 30s
    if [[ -f "$lock" ]] && [[ $(file_age "$lock") -lt 30 ]]; then
        return
    fi
    touch "$lock"
    (
        tmp="$cache.$$"
        if curl -sf -m 5 -H "Authorization: Bearer $token" "${base_url%/}/key/info" -o "$tmp" \
            && jq -e '.info.budget_limits' "$tmp" >/dev/null 2>&1; then
            mv "$tmp" "$cache"
        else
            rm -f "$tmp"
        fi
        rm -f "$lock"
    ) </dev/null >/dev/null 2>&1 &
}

cwd=$(echo "$input" | jq -r '.cwd // empty')
dir=$(basename "$cwd" 2>/dev/null || echo "?")

# Get git branch, uncommitted file count, and sync status
branch=""
git_status=""
if [[ -n "$cwd" && -d "$cwd" ]]; then
    branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
    if [[ -n "$branch" ]]; then
        # Count uncommitted files
        file_count=$(git -C "$cwd" --no-optional-locks status --porcelain -uall 2>/dev/null | wc -l | tr -d ' ')

        # Check sync status with upstream
        sync_status=""
        upstream=$(git -C "$cwd" rev-parse --abbrev-ref @{upstream} 2>/dev/null)
        if [[ -n "$upstream" ]]; then
            # Get last fetch time
            fetch_head="$cwd/.git/FETCH_HEAD"
            fetch_ago=""
            if [[ -f "$fetch_head" ]]; then
                fetch_time=$(stat -f %m "$fetch_head" 2>/dev/null || stat -c %Y "$fetch_head" 2>/dev/null)
                if [[ -n "$fetch_time" ]]; then
                    now=$(date +%s)
                    diff=$((now - fetch_time))
                    if [[ $diff -lt 60 ]]; then
                        fetch_ago="<1m ago"
                    elif [[ $diff -lt 3600 ]]; then
                        fetch_ago="$((diff / 60))m ago"
                    elif [[ $diff -lt 86400 ]]; then
                        fetch_ago="$((diff / 3600))h ago"
                    else
                        fetch_ago="$((diff / 86400))d ago"
                    fi
                fi
            fi

            counts=$(git -C "$cwd" rev-list --left-right --count HEAD...@{upstream} 2>/dev/null)
            ahead=$(echo "$counts" | cut -f1)
            behind=$(echo "$counts" | cut -f2)
            if [[ "$ahead" -eq 0 && "$behind" -eq 0 ]]; then
                if [[ -n "$fetch_ago" ]]; then
                    sync_status="synced ${fetch_ago}"
                else
                    sync_status="synced"
                fi
            elif [[ "$ahead" -gt 0 && "$behind" -eq 0 ]]; then
                sync_status="${ahead} ahead"
            elif [[ "$ahead" -eq 0 && "$behind" -gt 0 ]]; then
                sync_status="${behind} behind"
            else
                sync_status="${ahead} ahead, ${behind} behind"
            fi
        else
            sync_status="no upstream"
        fi

        # Build git status string
        if [[ "$file_count" -eq 0 ]]; then
            git_status="(0 files uncommitted, ${sync_status})"
        elif [[ "$file_count" -eq 1 ]]; then
            # Show the actual filename when only one file is uncommitted
            single_file=$(git -C "$cwd" --no-optional-locks status --porcelain -uall 2>/dev/null | head -1 | sed 's/^...//')
            git_status="(${single_file} uncommitted, ${sync_status})"
        else
            git_status="(${file_count} files uncommitted, ${sync_status})"
        fi
    fi
fi

# Get transcript path for context calculation and last message feature
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')

# Get context window size from JSON (accurate), but calculate tokens from transcript
# (more accurate than total_input_tokens which excludes system prompt/tools/memory)
# See: github.com/anthropics/claude-code/issues/13652
max_context=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
max_k=$((max_context / 1000))

# Calculate context usage from transcript
baseline=20000  # system prompt (~3k), tools (~15k), memory (~300), plus ~2k dynamic context
context_length=0
if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
    context_length=$(jq -s '
        map(select(.message.usage and .isSidechain != true and .isApiErrorMessage != true)) |
        last |
        if . then
            (.message.usage.input_tokens // 0) +
            (.message.usage.cache_read_input_tokens // 0) +
            (.message.usage.cache_creation_input_tokens // 0)
        else 0 end
    ' < "$transcript_path")
fi
if [[ "$context_length" -gt 0 ]]; then
    pct=$((context_length * 100 / max_context))
    pct_prefix=""
else
    # At conversation start (or before the transcript exists), ~20k baseline is already loaded
    pct=$((baseline * 100 / max_context))
    pct_prefix="~"
fi
[[ $pct -gt 100 ]] && pct=100

# Limit/budget segments share one line under the model; each is built twice:
# coloured for output, plain for width calculation
segments=()
plain_segments=()
add_segment() {
    local icon=$1 label=$2 pct=$3 tick=$4 value=$5 resets=$6 countdown detail=""
    countdown=$(fmt_countdown "$resets")
    [[ -n "$value" ]] && detail+=" ${value}"
    [[ -n "$countdown" ]] && detail+=" ↻${countdown}"
    # value is a percentage for limits, dollars left for budgets
    segments+=("${C_ACCENT}${icon}${C_RESET} ${C_GRAY}${label}${C_RESET} $(render_bar "$pct" 8 "$tick")$(pct_color "$pct")${detail}${C_RESET}")
    plain_segments+=("${icon} ${label} xxxxxxxx${tick:+x}${detail}")
}

if [[ "$PROVIDER" == claude ]]; then
    # Subscription limits; only present after the first API response in the session
    while IFS='|' read -r window used resets; do
        [[ -z "$used" ]] && continue
        used=${used%.*}
        if [[ "$window" == five_hour ]]; then
            add_segment "$ICON_5H" "5h" "$used" "$(pace_tick "$resets" 18000)" "${used}%" "$resets"
        else
            add_segment "$ICON_WEEK" "week" "$used" "$(pace_tick "$resets" 604800)" "${used}%" "$resets"
        fi
    done < <(echo "$input" | jq -r '
        .rate_limits // {} | to_entries[] |
        select(.key == "five_hour" or .key == "seven_day") |
        select(.value.used_percentage != null) |
        "\(.key)|\(.value.used_percentage)|\(.value.resets_at // "")"' 2>/dev/null | sort)
elif [[ "$PROVIDER" == router ]]; then
    cache="$ROUTER_CACHE_DIR/key-info.json"
    age=$(file_age "$cache" 2>/dev/null || echo 999999)
    [[ $age -ge $ROUTER_CACHE_TTL ]] && refresh_router_cache
    if [[ -f "$cache" && $age -lt $ROUTER_CACHE_MAX_AGE ]]; then
        # Weekly first, then daily
        while IFS='|' read -r duration spent budget resets; do
            [[ -z "$budget" ]] && continue
            used=$(awk -v s="$spent" -v b="$budget" 'BEGIN { if (b > 0) printf "%d", s * 100 / b; else print 0 }')
            left=$(awk -v s="$spent" -v b="$budget" 'BEGIN { l = b - s; if (l < 0) l = 0; printf "%.2f", l }')
            if [[ "$duration" == 7d ]]; then
                week_left=$left
                add_segment "$ICON_WEEK" "week" "$used" "$(pace_tick "$resets" 604800)" "\$${left} left" "$resets"
            elif [[ "$duration" == 1d ]]; then
                capped=""
                # The daily allowance is capped by what is left of the weekly budget
                if [[ -n "${week_left:-}" ]] && awk -v d="$left" -v w="$week_left" 'BEGIN { exit !(w < d) }'; then
                    left=$week_left
                    used=$(awk -v l="$left" -v b="$budget" 'BEGIN { printf "%d", (b - l) * 100 / b }')
                    capped=" (wk cap)"
                fi
                add_segment "$ICON_DAY" "day" "$used" "$(pace_tick "$resets" 86400)" "\$${left} left${capped}" "$resets"
            fi
        done < <(jq -r '
            .info as $i |
            $i.budget_limits // [] | sort_by(.budget_duration != "7d") | .[] |
            "\(.budget_duration)|\($i.budget_limits_usage[.budget_duration].current_spend // 0)|\(.max_budget)|\(
                (.reset_at // "") | sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") |
                (try fromdateiso8601 catch ""))"' "$cache" 2>/dev/null)
    fi
fi

# Build output: Line 1 = Provider + Model + Context bar
#            : Line 2 = Limits/budgets side by side (when available)
#            : Line 3 = Dir + Branch (Git info)
line1="${C_ACCENT}${PROVIDER_ICON} ${model_label}${C_GRAY} │ ${C_ACCENT}${ICON_CTX}${C_RESET} $(render_bar "$pct") $(pct_color "$pct")${pct_prefix}${pct}%${C_GRAY} of ${max_k}k${C_RESET}"
plain_line1="${PROVIDER_ICON} ${model_label} │ ${ICON_CTX} xxxxxxxxxxxx ${pct_prefix}${pct}% of ${max_k}k"

# Model/effort recommendation from Jev: local Open-Jev or hosted TypeSafe, via JEV_BACKEND (Claude subscription only)
if [[ "$PROVIDER" == claude ]] && command -v python3 >/dev/null 2>&1; then
    hint_color="" hint_plain=""
    { IFS= read -r hint_color; IFS= read -r hint_plain; } < <(printf '%s' "$input" | python3 "$SCRIPT_DIR/model_hint" render 2>/dev/null)
    if [[ -n "$hint_plain" ]]; then
        line1+="${C_GRAY} │ ${C_RESET}${hint_color}"
        plain_line1+=" │ ${hint_plain}"
    fi
fi

limits_line=""
plain_limits_line=""
for i in "${!segments[@]}"; do
    if [[ $i -gt 0 ]]; then
        limits_line+="${C_GRAY} │ ${C_RESET}"
        plain_limits_line+=" │ "
    fi
    limits_line+="${segments[$i]}"
    plain_limits_line+="${plain_segments[$i]}"
done

git_line="${C_GRAY}  ${dir}"
[[ -n "$branch" ]] && git_line+=" │  ${branch} ${git_status}"
git_line+="${C_RESET}"

printf '%b\n' "$line1"
[[ -n "$limits_line" ]] && printf '%b\n' "$limits_line"
printf '%b\n' "$git_line"

# Get user's last message (text only, not tool results, skip unhelpful messages)
if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
    # Truncate to the widest line above (measured without ANSI codes)
    max_len=${#plain_line1}
    [[ ${#plain_limits_line} -gt $max_len ]] && max_len=${#plain_limits_line}
    last_user_msg=$(jq -rs '
        # Messages to skip (not useful as context)
        def is_unhelpful:
            startswith("[Request interrupted") or
            startswith("[Request cancelled") or
            . == "";

        [.[] | select(.type == "user") |
         select(.message.content | type == "string" or
                (type == "array" and any(.[]; .type == "text")))] |
        reverse |
        map(.message.content |
            if type == "string" then .
            else [.[] | select(.type == "text") | .text] | join(" ") end |
            gsub("\n"; " ") | gsub("  +"; " ")) |
        map(select(is_unhelpful | not)) |
        first // ""
    ' < "$transcript_path" 2>/dev/null)

    if [[ -n "$last_user_msg" ]]; then
        if [[ ${#last_user_msg} -gt $max_len ]]; then
            echo "󰭹 ${last_user_msg:0:$((max_len - 3))}..."
        else
            echo "󰭹 ${last_user_msg}"
        fi
    fi
fi
