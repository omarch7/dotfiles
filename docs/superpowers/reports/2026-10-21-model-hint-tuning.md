# Model Hint Tuning Report

**Date:** 2026-10-21
**Plan:** `docs/superpowers/plans/2026-10-21-model-effort-statusline.md`, Task 9
**Open-Jev:** Open-Jev-9B (`Qwen/Qwen3.5-9B` + LoRA decision head), local server, `--max-length 4096`

Six real Claude Code sessions (S1–S6) were replayed turn by turn through the full pipeline. The
sample also included 40 past prompts from `~/.claude/history.jsonl`. This report holds only labels
and numbers.

## Finding 1: every turn was counted twice (fixed)

Claude Code writes each content block of a reply as its own transcript line: a `thinking` line,
then a `text` line. All of them carry `stop_reason: end_turn` and share one `message.id`. The first
replay found 177 "turns" in the six sessions, but there were really 98. Live, this would have made
the hint ask Open-Jev and apply smoothing twice per turn, once before the reply text existed.
`completed_turn_indices` now counts one turn per message, on the last line that carries reply
text (commit "Count a split reply as one completed turn").

## Finding 2: Open-Jev's effort score is compressed (recalibrated)

The effort question returns an expected level from 0 (low) to 3 (xhigh). On real sessions it
never reached the plan's 1.5 boundary for "high":

| Raw effort score (rich summary, 98 turns) | p10 | p25 | p50 | p75 | p90 | max |
|---|---|---|---|---|---|---|
| | 0.41 | 0.75 | 0.96 | 1.14 | 1.35 | 1.58 |

With the plan's boundaries (0.5 / 1.5 / 2.5), shown effort was medium 88 times and low 10 times,
never high. Against the new Sonnet · high default, the hint would therefore never show green.
The boundaries are now 0.65 / 1.10 / 1.40, roughly the 20th, 70th and 93rd percentiles. The dead
band was scaled with them, from 0.15 to 0.10.

## Finding 3: the gray cutoff was too high (recalibrated)

Open-Jev's top-tier probability on these turns had p25 0.52, p50 0.63 and p75 0.76. With the
plan's `GRAY_BELOW = 0.60`, about half of all hints were gray. It is now `0.45`, which makes about
11% of turns gray.

## Results with the final constants

Hint changes per session. Default = rich summary + stability rules.

| Session | Turns | Default | Lean | Rich, no stability | Lean, no stability |
|---|---|---|---|---|---|
| S1 | 36 | 3 | 2 | 15 | 7 |
| S2 | 15 | 1 | 2 | 12 | 4 |
| S3 | 9 | 1 | 2 | 8 | 3 |
| S4 | 8 | 1 | 2 | 7 | 5 |
| S5 | 25 | 2 | 0 | 14 | 16 |
| S6 | 5 | 2 | 2 | 2 | 2 |
| **Total** | **98** | **10** | **10** | **58** | **37** |

- The stability rules cut changes by 83% (58 → 10), to about one change every 10 turns.
- The rich and lean summaries change equally often. The rich one spreads effort across levels
  (simulated shown effort: low 19, medium 33, high 46), while lean stays near medium. The rich
  summary is kept, as the user chose.
- In simulation against the Sonnet · high default, the shown colours over all 98 turns were:
  dim blue 56, green 20, amber 11, gray 11.

Open-Jev latency per turn, default variant (runs in the background, never blocks the status line):

| | S1 | S2 | S3 | S4 | S5 | S6 |
|---|---|---|---|---|---|---|
| p50 (s) | 0.53 | 0.51 | 0.51 | 0.64 | 0.37 | 0.37 |
| max (s) | 0.70 | 0.60 | 0.53 | 1.08 | 0.71 | 0.41 |

Single-prompt sample (40 past prompts, lean, raw picks): haiku 21, sonnet 17, opus 2; low 8,
medium 28, high 4, xhigh 0.

## Final constants

| Constant | Plan | Final |
|---|---|---|
| `ALPHA_NEW` | 0.4 | 0.4 |
| `MODEL_MARGIN` | 0.15 | 0.15 |
| `FAST_LANE` | 0.85 | 0.85 |
| `EFFORT_THRESHOLDS` | 0.5 / 1.5 / 2.5 | 0.65 / 1.10 / 1.40 |
| `EFFORT_BAND` | 0.15 | 0.10 |
| `GRAY_BELOW` | 0.60 | 0.45 |
| `QUESTIONS` wording | unchanged | unchanged |

The thresholds were calibrated on only 98 turns from six sessions. Re-run
`python3 claude/.claude/scripts/model_hint replay <transcript>` on newer sessions if the hint feels
stuck on one effort level.
