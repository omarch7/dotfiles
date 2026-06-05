# Provider Indicator in Context Bar — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the hardcoded `󰛄` icon and static `COLOR` variable in `context-bar.sh` with a dynamic provider indicator (icon + accent color) derived from the model ID and `ANTHROPIC_BASE_URL` env var.

**Architecture:** Provider detection runs at script start, sets `PROVIDER_ICON`, `PROVIDER_LABEL` (plain-text version for length calculation), and `C_ACCENT`. These three variables replace all current references to the hardcoded icon and the static `COLOR`/`C_ACCENT` block. No other logic changes.

**Tech Stack:** Bash, ANSI 256-color escape codes, Hack Nerd Font glyphs.

---

### Task 1: Replace static color block with provider detection

**Files:**
- Modify: `claude/.claude/scripts/context-bar.sh`

The script currently has:
1. A `COLOR="blue"` variable at the top
2. A `case "$COLOR" in ...` block that sets `C_ACCENT`
3. A hardcoded `󰛄` icon in two places:
   - Line 172: the output line `"󰛄 ${C_ACCENT}${model}..."`
   - Line 181: the plain-text length calc `"󰛄 ${model}..."`

Replace all of the above with a provider detection block.

- [ ] **Step 1: Open the file and locate the static color block**

The block to remove is at the top of `claude/.claude/scripts/context-bar.sh`:

```bash
COLOR="blue"

# Color codes
C_RESET='\033[0m'
C_GRAY='\033[38;5;245m'  # explicit gray for default text
C_BAR_EMPTY='\033[38;5;238m'
case "$COLOR" in
    orange)   C_ACCENT='\033[38;5;173m' ;;
    blue)     C_ACCENT='\033[38;5;74m' ;;
    teal)     C_ACCENT='\033[38;5;66m' ;;
    green)    C_ACCENT='\033[38;5;71m' ;;
    lavender) C_ACCENT='\033[38;5;139m' ;;
    rose)     C_ACCENT='\033[38;5;132m' ;;
    gold)     C_ACCENT='\033[38;5;136m' ;;
    slate)    C_ACCENT='\033[38;5;60m' ;;
    cyan)     C_ACCENT='\033[38;5;37m' ;;
    *)        C_ACCENT="$C_GRAY" ;;  # gray: all same color
esac
```

- [ ] **Step 2: Replace the static color block with provider detection**

Replace the entire block above (lines 5–22) with:

```bash
# Color codes
C_RESET='\033[0m'
C_GRAY='\033[38;5;245m'
C_BAR_EMPTY='\033[38;5;238m'
```

Then, **after** the `input=$(cat)` and `model=...` lines (i.e. after the model ID is extracted from JSON), add the provider detection block:

```bash
# Detect provider from model ID and environment
model_id=$(echo "$input" | jq -r '.model.id // ""')
if [[ -n "${ANTHROPIC_BASE_URL:-}" ]]; then
    PROVIDER_ICON='󰍹'
    PROVIDER_LABEL='󰍹'
    C_ACCENT='\033[38;5;112m'  # NVIDIA green
elif [[ "$model_id" == *anthropic* ]]; then
    PROVIDER_ICON='󰧑'
    PROVIDER_LABEL='󰧑'
    C_ACCENT='\033[38;5;220m'  # AWS yellow
else
    PROVIDER_ICON='󰛄'
    PROVIDER_LABEL='󰛄'
    C_ACCENT='\033[38;5;166m'  # Anthropic orange
fi
```

Note on the Bedrock icon: `󰧑` is the Unicode character at `󰧑` (surrogate pair for U+F05D1). Paste the literal glyph into the script — do not use `\u` escape sequences in bash strings, they are not interpreted.

- [ ] **Step 3: Replace the hardcoded icon in the output line**

Find (around line 172 after edits):
```bash
output="󰛄 ${C_ACCENT}${model}${C_GRAY} |   ${dir}"
```

Replace with:
```bash
output="${PROVIDER_ICON} ${C_ACCENT}${model}${C_GRAY} |   ${dir}"
```

- [ ] **Step 4: Replace the hardcoded icon in the plain-text length calculation**

Find (around line 181 after edits):
```bash
plain_output="󰛄 ${model} |   ${dir}"
```

Replace with:
```bash
plain_output="${PROVIDER_LABEL} ${model} |   ${dir}"
```

- [ ] **Step 5: Smoke-test the script manually for all three providers**

Run each variant and verify the output line starts with the correct icon and color:

```bash
# Claude subscription (no ANTHROPIC_BASE_URL, plain model ID)
echo '{"model":{"display_name":"claude-sonnet-4-6","id":"claude-sonnet-4-6"},"cwd":"/tmp","context_window":{"context_window_size":200000}}' \
  | bash claude/.claude/scripts/context-bar.sh

# Bedrock (eu.anthropic. prefix in model ID)
echo '{"model":{"display_name":"claude-sonnet-4-6","id":"eu.anthropic.claude-sonnet-4-6"},"cwd":"/tmp","context_window":{"context_window_size":200000}}' \
  | bash claude/.claude/scripts/context-bar.sh

# Local (ANTHROPIC_BASE_URL set)
ANTHROPIC_BASE_URL=http://localhost:11434 \
  echo '{"model":{"display_name":"claude-sonnet-4-6","id":"claude-sonnet-4-6"},"cwd":"/tmp","context_window":{"context_window_size":200000}}' \
  | ANTHROPIC_BASE_URL=http://localhost:11434 bash claude/.claude/scripts/context-bar.sh
```

Expected: each run prints a first line starting with the correct icon in the correct color (orange / yellow / green). Verify the colors render visibly different in your terminal.

- [ ] **Step 6: Commit**

```bash
git add claude/.claude/scripts/context-bar.sh
git commit -m "feat(context-bar): dynamic provider icon and color (Claude/Bedrock/Local)"
```
