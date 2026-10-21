"""Compare the recommendation with the current model/effort and render the coloured hint."""
from __future__ import annotations

from stability import TIER_ORDER, State, confidence

GREEN = "\033[38;2;152;195;121m"
AMBER = "\033[38;2;229;192;123m"
RED = "\033[38;2;224;108;117m"
BLUE_DIM = "\033[2;38;2;97;175;239m"
GRAY = "\033[38;5;245m"
RESET = "\033[0m"

GRAY_BELOW = 0.60
TIER_LABEL = {"haiku": "Haiku", "sonnet": "Sonnet", "opus": "Opus"}
EFFORT_NAMES = ["low", "medium", "high", "xhigh"]
EFFORT_INDEX = {"low": 0, "medium": 1, "high": 2, "xhigh": 3, "max": 4}
MAX_EFFORT_BY_TIER = {"haiku": 3, "sonnet": 3, "opus": 3}


def current_tier(model_id: str | None) -> str | None:
    lowered = (model_id or "").lower()
    return next((tier for tier in TIER_ORDER if tier in lowered), None)


def effort_index(level: str | None) -> int | None:
    return EFFORT_INDEX.get(level) if isinstance(level, str) else None


def render_hint(state: State, cur_tier: str, cur_effort: int | None) -> tuple[str, str]:
    rec_tier = state.shown_tier
    rec_effort = min(state.shown_effort, MAX_EFFORT_BY_TIER[rec_tier])
    dm = TIER_ORDER[rec_tier] - TIER_ORDER[cur_tier]
    de = 0 if cur_effort is None else rec_effort - cur_effort

    target = TIER_LABEL[rec_tier] if cur_effort is None else f"{TIER_LABEL[rec_tier]} · {EFFORT_NAMES[rec_effort]}"
    if dm == 0 and de == 0:
        colour, plain = GREEN, "✓ right fit"
    elif dm >= 2 or de >= 3:
        colour, plain = RED, f"⇡⇡ {target}"
    elif dm > 0 or de > 0:
        colour, plain = AMBER, f"⇡ {target}"
    else:
        colour, plain = BLUE_DIM, f"⇣ {target}"
    if confidence(state) < GRAY_BELOW:
        colour = GRAY
    return colour + plain + RESET, plain
