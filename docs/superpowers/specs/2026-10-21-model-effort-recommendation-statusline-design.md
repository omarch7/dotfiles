# Model and Effort Recommendation in the Claude Code Status Line

**Date:** 2026-10-21
**Status:** Approved

## Summary

Add a colour-coded hint to the Claude Code status line (`claude/.claude/scripts/context-bar.sh`)
that recommends which Claude model tier (Haiku, Sonnet or Opus) and which effort level fit the
work in the current session. A locally served Open-Jev model reads a short summary of the session
so far and returns the recommendation. The hint updates silently as the session goes on. The user
still switches by hand with `/model` and `/effort`. As part of this work, the user's default changes
from Opus · xhigh to Sonnet · high.

## Why

Choosing between Haiku, Sonnet and Opus, and an effort level, is a decision the user wants taken
off their plate. Today the default is Opus at xhigh effort for everything (`"model": "opus"`,
`"effortLevel": "xhigh"` and a `modelSettings` entry for `claude-opus-5-5` at `xhigh` in
`~/.claude/settings.json`, which isn't tracked in the dotfiles). The recommendation should come from what's being asked and what's
actually happening in the session, not from a guess made once at the start.

## Goals

- Show a recommended model tier and effort level in the status line, updated as the session progresses.
- Base it on the work so far: recent prompts plus what Claude has been doing, not only the latest prompt.
- Make it readable at a glance: colour says whether to step up, step down or stay.
- Stay silent: nothing appears in the chat, nothing is blocked, nothing is added to Claude's context.

## Non-goals

- **Switching the model or effort automatically.** Claude Code doesn't let hooks or the status line
  change either one; only `/model`, the model picker, `/config`, `/effort` or an SDK host can.
- **A launcher command** (e.g. a `cj "prompt"` wrapper around `claude`). The user considered and rejected it.
- **A separate Claude Code hook.** The status line receives everything it needs (see Constraints).
- Recommending Fable, `best`, non-Claude models or `max` effort.
- Choosing models for subagents.
- Retraining or fine-tuning Open-Jev.

## Anti-goals (would make this a failure even if it works)

- The status line feels slow, freezes or flickers because of the Open-Jev call.
- The hint is noisy: flashy colour for low-confidence guesses, or nagging to downgrade mid-session.
- The status line breaks or shows error text when the Open-Jev server is down.
- Session content leaves the machine. Open-Jev runs locally; nothing else is called.

## Constraints

### Open-Jev server

- Already running locally from `~/Projects/Open-Jev`:
  `python -m jev.server --checkpoint ./checkpoints/open-jev-9b/package/checkpoint --device cuda:0 --max-length 4096 --batch-size 1 --no-prefix-cache --host 0.0.0.0 --port 8791`
- Endpoint: `POST http://127.0.0.1:8791/v1/systemone`. Health: `GET /health`.
- Request shape: `{"state": "<text>", "questions": {<id>: {"type": "choice"|"noul"|"score", "instructions": ..., "criteria": ...}}}`.
  `choice` returns `choice` plus a `probabilities` map. `score` takes an ordered list of criteria
  and returns `score` (expected index), per-index `probabilities` and `confidence`.
  See `~/Projects/Open-Jev/configs/example-request.json` and `jev/client.py`.
- **4,096-token input limit** (server flag). The state sent must be a compact summary, never the raw transcript.
- Measured: about 0.12 s per request with a 3-candidate choice plus a 3-level score.
- A first probe gave sensible results:

  | Prompt | Model | Effort (low/med/high probabilities) |
  |---|---|---|
  | rename foo to bar in utils.py | haiku 0.85 | 0.84 / 0.15 / 0.01 |
  | add a --verbose flag and wire it to the logger | sonnet 0.85 | 0.36 / 0.61 / 0.02 |
  | distributed training deadlocks on 4 GPUs, find out why | opus 0.91 | 0.03 / 0.48 / 0.49 |
  | what does git rebase --onto do | haiku 0.63 | 0.41 / 0.47 / 0.12 |

  The probe framed state as `A developer typed this request into a coding assistant: "<prompt>"`
  and described the tiers as: haiku = quick, mechanical or lookup tasks; sonnet = everyday feature
  work and bug fixes across a few files; opus = hard, open-ended or high-stakes work (architecture,
  tricky debugging, large refactors, design).

### Claude Code status line

- Input JSON (stdin) includes `model.id`, `model.display_name`, `effort.level` (`low`…`max`, live,
  reflects mid-session `/effort` changes, **absent when the model doesn't support effort**),
  `session_id`, `prompt_id` (absent until the first prompt), and `transcript_path`.
- It re-runs on session start, on each new assistant message, after `/compact`, on permission/vim
  mode changes and on an optional `refreshInterval` timer. Updates are debounced at 300 ms.
  **A new update cancels a still-running script**, and a slow script delays the status line.
- Event-driven updates go quiet when the session is idle. Work that finishes in the background after
  the last render won't show until the next trigger unless `refreshInterval` is set.

### Existing script

- `claude/.claude/scripts/context-bar.sh` is bash with `jq` and `curl`, symlinked into `~/.claude/scripts/`.
- It already has the patterns to reuse: a cache directory (`$XDG_CACHE_HOME/claude-statusline`), a
  background refresh with a lock file (`refresh_router_cache`), and colour constants (`C_GRAY`,
  `C_WARN` amber `#e5c07b`, `C_CRIT` red `#e06c75`, `C_ACCENT`).
- Line 1 is `<provider icon> <model> │ <context bar> <pct> of <max>k`. The final "last user message"
  line is truncated to the widest line above, measured from plain-text twins (`plain_line1` etc.).
  Anything added to line 1 must be added to `plain_line1` too.
- Three providers (`claude`, `router` via a Bedrock gateway, `local`) give different model IDs,
  e.g. `claude-opus-5-5` versus `eu.anthropic.claude-sonnet-4-6`.

### Transcript

- JSONL at `transcript_path`. Main-conversation entries have `isSidechain: false`.
  User prompts are `type: "user"` with string or `text` content. Tool results are `type: "user"`
  with `tool_result` content (which carries an error flag). Assistant entries carry `message.model`
  and content blocks of type `text`, `thinking` and `tool_use` (tool name plus input, e.g. file paths).
- There are many other entry types (`attachment`, `system`, `api-request*`, `mode`, …) to ignore.

## What the user decided

- **Status line only.** No launcher, no blocking, no chat messages.
- **Recommendation reflects the work so far** and updates between prompts.
- **The hint names the best model and effort for the task**, in either direction. The recommendation
  itself is never held back by what switching would cost; only the styling of a step down is kept quiet.
- **New default: Sonnet · high.** In `~/.claude/settings.json`, set `"model": "sonnet"` and
  `"effortLevel": "high"`. Starting in the middle means the hint can point up to Opus or down to
  Haiku, and all four colour states can occur.
- **Display: a hint after the context bar on line 1 ("option A").** Colour meanings:
  - green `✓ right fit`: current model and effort match the recommendation
  - amber `⇡ Sonnet · high`: step up one notch
  - red `⇡⇡ Opus · high`: a big step up
  - dim blue `⇣ Haiku · low`: could go cheaper. Kept quiet on purpose, because switching down
    mid-session throws away the prompt cache and usually costs more than it saves.

Mockup (glyphs simplified):

```
◆ Opus 5.5 · high   │ ▣ ████░░░░░░░░ 34% of 200k │ ✓ right fit        (green)
◆ Sonnet 5.5 · low  │ ▣ ██░░░░░░░░░░ 18% of 200k │ ⇡ Sonnet · high    (amber)
◆ Haiku 5.5 · medium│ ▣ █░░░░░░░░░░░  9% of 200k │ ⇡⇡ Opus · high     (red)
◆ Opus 5.5 · high   │ ▣ █████░░░░░░░ 41% of 200k │ ⇣ Haiku · low      (dim blue)
```

## Stability: the hint must not flip-flop (user's priority)

The user explicitly wants to avoid an indicator that flips back and forth. Open-Jev is deterministic
(same input, same output), so wobble comes from the input changing between turns and from picks
sitting near a boundary. The user approved these four rules, in order of impact. The numbers are
starting points for the builder to tune.

1. **Decide once per turn.** Recalculate only when a main-conversation turn finishes (the last
   assistant message has ended its turn rather than stopping for a tool call). Every other status line
   render shows the saved pick. No mid-turn recalculation.
2. **Smooth across turns.** Blend each turn's Open-Jev probabilities into a running average per
   session, about 60% previous and 40% new. Pick from the smoothed distribution. A single odd turn
   barely moves it; a sustained shift shows within about two turns.
3. **Ties go to what's already shown.** Change the shown model pick only when the new leader beats the
   currently shown option by a clear margin (about 15 percentage points of smoothed probability).
   For effort, use the continuous expected level (Open-Jev's `score`) with a dead band around each
   boundary, so a borderline medium/high case doesn't alternate.
4. **Fast lane for clear steps up.** If a single turn's raw result is very confident (about ≥ 85%) for
   a higher tier or a higher effort than currently shown, switch immediately without waiting for the
   average to catch up. Steps down always go through smoothing.

Also:
- The gray-when-unsure rule (call 4 below) keeps low-confidence wobble from showing in colour.
- A new session (new `session_id`, including after `/clear`) starts with no history. Its first
  completed turn sets the pick directly.
- When the user switches model or effort, the colour comparison updates on the next render. That's
  expected and not counted as flip-flopping. The smoothed recommendation itself is about the task and
  doesn't reset on a switch.
- Smoothing state (running averages and the shown pick) lives in the per-session cache.

## Calls made during design (the user can overrule any of these)

1. **No separate hook.** The status line already gets the live model, effort and transcript, so
   everything lives in the status line script (or a helper it calls). This is also how the user's
   "just the statusline" was read.
2. **Show the current effort next to the model name** on line 1 (`Opus 5.5 · high`), since the hint
   compares against it. When `effort.level` is absent, show the model name alone.
3. **Effort recommendations use `low`, `medium`, `high`, `xhigh`**, never `max`.
4. **Low confidence shows gray.** If Open-Jev is less than about 60% sure of its pick, show the hint
   in gray instead of a colour. The exact threshold is the builder's to tune.
5. **What counts as "big" (red):** the model would jump two tiers (Haiku → Opus), or effort would jump
   three or more levels (low → xhigh). Any other step up is amber.
6. **Mixed directions** (e.g. model down, effort up) count as a step up: amber or red, showing the
   full target `⇡ Sonnet · xhigh`. Only when every part goes down is it dim blue.
7. **Hide the hint** (show nothing, no error) when the Open-Jev server is unreachable or times out,
   when the current model isn't recognisable as Haiku, Sonnet or Opus (e.g. a local non-Claude
   model), or before the first turn of a session has finished.
8. **When the model doesn't support effort**, recommend and compare only the model tier.
9. **Main conversation only.** Subagent (sidechain) activity is ignored when summarising.
10. **"Work so far" signals**, summarised into the 4,096-token budget (user agreed to the richer set):
    - the last few user prompts (about 3), newest marked as such, each truncated
    - **Claude's last text reply**, trimmed to about 300 tokens: the best clue to what the work turned
      out to be (e.g. "fix the failing test" turning into a race condition)
    - **paths of the files touched** in recent turns (paths only, no contents)
    - **how the last turn ended**: tests or commands passing, still failing, or Claude waiting on a
      question from the user
    - from recent turns: how many distinct files Claude edited or wrote, how many tool calls failed,
      how many shell commands failed, and signs of going in circles (the same file edited repeatedly,
      the same failing command retried)
    - how long the session has been running (number of user prompts)

    Leave out Claude's thinking, raw tool output and the full conversation. When the summary would
    exceed the budget, trim in this order: oldest prompts first, then the file list, then the reply,
    never the newest prompt. Open-Jev returns HTTP 422 for over-length input rather than truncating,
    so the budget must be enforced before sending, with a safety margin for the question text.
    The builder picks the exact summary format and the Open-Jev question wording, starting from the probe above.
11. **Claude subscription provider only, for now.** On the `router` (Bedrock gateway) and `local`
    providers, hide the hint. The gateway offers older models with different effort support
    (e.g. Sonnet 4.6 has no `xhigh`, Haiku 4.5 has no effort at all) and it isn't known which tiers it
    offers. The dotfiles are also shared with macOS machines that have no Open-Jev server. Extending
    to the router later means adding a per-provider table of available models and effort levels.
12. **Never recommend something the user can't switch to.** Clamp the recommended effort to what the
    recommended model supports, and compare against `effort.level`, which reports the level Claude
    Code actually applies. On the subscription's 5.5 models every level from `low` to `xhigh` is
    supported, so this is a safety rule rather than a common case.
13. **Settings change touches only `model` and `effortLevel`.** The existing
    `modelSettings."claude-opus-5-5".effortLevel: "xhigh"` entry stays. `/effort` saves per-model levels
    there, so switching to Opus will still bring up xhigh. The hint will then show whether that's more
    than the task needs. The edit goes straight into `~/.claude/settings.json` (not tracked in the
    dotfiles); no new dotfiles file is added for it.

## Requirements on timing

- The status line must never wait on Open-Jev for more than a short, fixed timeout (well under a
  second). Prefer a background refresh with a per-session cache, like `refresh_router_cache`.
- Only ask Open-Jev once per completed turn (see Stability). Don't re-ask on every render.
- **By the time a turn finishes, the hint must reflect that turn.** The user looks at it right before
  typing the next prompt. Because Claude Code cancels in-flight scripts and goes quiet when idle, the
  builder must make sure the final result gets drawn, e.g. via a short synchronous call when new
  activity is detected, or a `refreshInterval`. Whichever way, check that the status line still feels
  instant during a busy turn.
- The cache is keyed by `session_id` so concurrent sessions don't share recommendations.

## Validation

- Replay a sample of the user's past prompts from `~/.claude/history.jsonl` through the recommender
  and eyeball the picks for sense, especially the Haiku/Sonnet border and the effort spread. Use this
  to tune the question wording and the confidence threshold.
- Replay several real past sessions turn by turn (transcripts under `~/.claude/projects/*/*.jsonl`,
  main conversation only) through the full pipeline, including smoothing and stickiness. For each
  session report the sequence of shown hints and **how many times the hint changed**. Compare
  (a) the lean summary versus the richer summary and (b) with versus without the stability rules.
  Use the change count as the flip-flop measure when tuning the blend, margin and fast-lane numbers.
- Test the status line script with mock stdin JSON covering: each colour state, gray low-confidence,
  effort absent, unrecognised model, server down (including connection refused, as on a Mac with no
  server), empty transcript, and router/local providers (hint hidden).
- Run a real session on the new Sonnet · high default and confirm the hint updates after a turn ends
  without lag, and that easy and hard prompts move it down and up.

## Left to the builder

- Exact Open-Jev question wording, candidate descriptions and summary format.
- Mapping from Open-Jev's effort output to the four levels (e.g. a 4-level `score`, or a 3-level score plus a rule for `xhigh`).
- Confidence threshold value and how model and effort confidences combine.
- Caching and refresh mechanics within the timing requirements above.
- Whether the logic lives inline in `context-bar.sh` or in a helper script beside it.
- Exact ANSI colours for green and dim blue (amber and red already exist in the script).

## Out of scope

- Changes to the context bar, limits line, git line or last-message line beyond width bookkeeping.
- Managing the Open-Jev server (starting, stopping, choosing the checkpoint).
