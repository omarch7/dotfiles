#!/usr/bin/env bash
# Tests for detect_mode() native-Linux detection in detect-theme.sh.
# Sources the script (which must be side-effect-free) and overrides HOME +
# gsettings to exercise each branch. Run on Linux: `bash test-detect-theme.sh`.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/detect-theme.sh"

fail=0
assert_eq() {
    if [ "$1" = "$2" ]; then
        echo "PASS: $3"
    else
        echo "FAIL: $3 — expected '$2', got '$1'"
        fail=1
    fi
}

if [ "$(uname -s)" != "Linux" ]; then
    echo "SKIP: Linux-only detection tests (uname=$(uname -s))"
    exit 0
fi

if grep -qi microsoft /proc/version 2>/dev/null; then
    echo "SKIP: WSL2 environment — native-Linux branches not exercised here"
    exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp"
gsettings() { return 1; }  # default: no light signal

# 1. Omarchy light.mode marker present -> light
mkdir -p "$HOME/.config/omarchy/current/theme"
touch "$HOME/.config/omarchy/current/theme/light.mode"
assert_eq "$(detect_mode)" "light" "omarchy light.mode marker -> light"

# 2. Marker absent, gsettings reports light -> light (fallback)
rm -f "$HOME/.config/omarchy/current/theme/light.mode"
gsettings() { echo "'prefer-light'"; }
assert_eq "$(detect_mode)" "light" "gsettings prefer-light -> light"

# 3. Marker absent, gsettings reports dark -> dark
gsettings() { echo "'prefer-dark'"; }
assert_eq "$(detect_mode)" "dark" "gsettings prefer-dark -> dark"

# 4. Marker absent, gsettings unavailable -> dark (default)
gsettings() { return 1; }
assert_eq "$(detect_mode)" "dark" "no signal -> dark default"

exit $fail
