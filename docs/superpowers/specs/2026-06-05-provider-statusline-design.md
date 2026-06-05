# Provider Indicator in Claude Code Context Bar

**Date:** 2026-06-05
**Status:** Approved

## Summary

Replace the hardcoded `󰛄` icon and static `COLOR` variable in `context-bar.sh` with a dynamic provider indicator. The provider is detected from the model ID in the statusLine JSON input and `ANTHROPIC_BASE_URL` env var. The derived icon and color drive the entire bar — the provider icon, model label, and context bar accent blocks all switch together.

## Provider Detection Logic

Detection runs at script start, before any output is built, in this priority order:

1. `ANTHROPIC_BASE_URL` is set in the environment → **Local**
2. Model ID (`.model.id` from JSON input) contains `anthropic` (e.g. `eu.anthropic.claude-*`) → **Bedrock**
3. Otherwise → **Claude** (subscription)

## Icons, Colors & ANSI Codes

| Provider | Icon | Codepoint | Color | ANSI (256-color) |
|----------|------|-----------|-------|------------------|
| Claude   | `󰛄`  | `\Uf01c4` | Anthropic orange | `\033[38;5;166m` |
| Bedrock  | `󰧑`  | `󰧑` | AWS yellow   | `\033[38;5;220m` |
| Local    | `󰍹`  | `\Uf0379` | NVIDIA green     | `\033[38;5;112m` |

Font requirement: Hack Nerd Font (already in use).

## Changes to `context-bar.sh`

- Remove the `COLOR` variable and its `case` block.
- Add provider detection block that sets three variables: `PROVIDER_ICON`, `PROVIDER_LABEL` (for plain-text length calculation), and `C_ACCENT`.
- Replace the hardcoded `󰛄` in the output line with `$PROVIDER_ICON`.
- Replace the hardcoded `󰛄` in the plain-text length calculation with `$PROVIDER_LABEL`.
- No other logic changes.

## Output Examples

**Bedrock** (yellow):
```
󰧑 eu.anthropic.claude-sonnet-4-6 | dotfiles | main (0 files, synced 2m ago) | ████░░░░░░ 12% of 200k tokens
```

**Claude subscription** (orange):
```
󰛄 claude-sonnet-4-6 | dotfiles | main (0 files, synced 2m ago) | ████░░░░░░ 12% of 200k tokens
```

**Local** (green):
```
󰍹 claude-sonnet-4-6 | dotfiles | main (0 files, synced 2m ago) | ████░░░░░░ 12% of 200k tokens
```

## Out of Scope

- No label text added (e.g. "Bedrock" / "Local") — icon + color is sufficient
- No changes to git status, context bar width, or token calculation logic
- No fallback for unknown model IDs beyond defaulting to Claude
