"""Keep the recommendation steady: smooth across turns, stick to the shown pick, fast-lane clear steps up."""
from __future__ import annotations

import math
from dataclasses import asdict, dataclass

from openjev import Reading

TIER_ORDER = {"haiku": 0, "sonnet": 1, "opus": 2}
ALPHA_NEW = 0.4       # weight of the newest reading in the running average
MODEL_MARGIN = 0.15   # smoothed lead needed to change the shown tier
FAST_LANE = 0.85      # single-turn confidence that switches upward immediately
EFFORT_BAND = 0.15    # dead band around each effort boundary
MAX_LEVEL = 3


@dataclass
class State:
    smoothed_model: dict[str, float] | None = None
    smoothed_effort: float | None = None
    shown_tier: str | None = None
    shown_effort: int | None = None

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, d: dict | None) -> State:
        try:
            model = d["smoothed_model"]
            state = cls({k: float(model[k]) for k in TIER_ORDER}, float(d["smoothed_effort"]),
                        d["shown_tier"], d["shown_effort"])
        except (KeyError, TypeError, ValueError):
            return cls()
        if state.shown_tier not in TIER_ORDER or state.shown_effort not in range(MAX_LEVEL + 1):
            return cls()
        return state


def level_for(score: float) -> int:
    return min(MAX_LEVEL, max(0, math.floor(score + 0.5)))


def _argmax(probs) -> str | int:
    if isinstance(probs, dict):
        return max(probs, key=probs.get)
    return max(range(len(probs)), key=probs.__getitem__)


def update(state: State, reading: Reading, smooth: bool = True) -> State:
    raw_tier = _argmax(reading.model_probs)
    raw_level = _argmax(reading.effort_probs)
    if not smooth or state.shown_tier is None:
        return State(dict(reading.model_probs), reading.effort_score, raw_tier, level_for(reading.effort_score))

    sm = {k: (1 - ALPHA_NEW) * state.smoothed_model[k] + ALPHA_NEW * reading.model_probs[k] for k in TIER_ORDER}
    se = (1 - ALPHA_NEW) * state.smoothed_effort + ALPHA_NEW * reading.effort_score
    tier, level = state.shown_tier, state.shown_effort

    if reading.model_probs[raw_tier] >= FAST_LANE and TIER_ORDER[raw_tier] > TIER_ORDER[tier]:
        tier, sm = raw_tier, dict(reading.model_probs)
    else:
        leader = _argmax(sm)
        if sm[leader] - sm[tier] >= MODEL_MARGIN:
            tier = leader

    if reading.effort_probs[raw_level] >= FAST_LANE and raw_level > level:
        level, se = raw_level, reading.effort_score
    else:
        target = level_for(se)
        if target > level and se >= level + 0.5 + EFFORT_BAND:
            level = target
        elif target < level and se <= level - 0.5 - EFFORT_BAND:
            level = target

    return State(sm, se, tier, level)


def confidence(state: State) -> float:
    if not state.smoothed_model or state.shown_tier is None:
        return 0.0
    return state.smoothed_model.get(state.shown_tier, 0.0)
