"""Replay past sessions and prompts through the recommender, to tune it. Output stays in the terminal."""
from __future__ import annotations

import json
import random
import time
from dataclasses import dataclass
from typing import Callable

from openjev import Reading
from stability import State, level_for, update
from summary import build_summary
from transcript import completed_turn_indices, prompt_text


@dataclass
class TurnResult:
    turn: int
    prompt: str
    raw: tuple[str, int]
    shown: tuple[str, int]
    seconds: float


def raw_pick(reading: Reading) -> tuple[str, int]:
    tier = max(reading.model_probs, key=reading.model_probs.get)
    return tier, level_for(reading.effort_score, reading.effort_thresholds)


def replay_session(entries: list[dict], ask_fn: Callable[[str], Reading], lean: bool = False,
                   smooth: bool = True) -> list[TurnResult]:
    state = State()
    results = []
    for n, i in enumerate(completed_turn_indices(entries), start=1):
        upto = entries[: i + 1]
        prompts = [p for p in (prompt_text(e) for e in upto) if p]
        started = time.monotonic()
        reading = ask_fn(build_summary(upto, lean))
        seconds = time.monotonic() - started
        state = update(state, reading, smooth=smooth)
        results.append(TurnResult(n, prompts[-1] if prompts else "", raw_pick(reading),
                                  (state.shown_tier, state.shown_effort), seconds))
    return results


def count_changes(shown: list[tuple[str, int]]) -> int:
    return sum(1 for prev, cur in zip(shown, shown[1:]) if prev != cur)


def sample_prompts(history_path: str, n: int, seed: int) -> list[str]:
    displays = []
    with open(history_path, encoding="utf-8", errors="replace") as f:
        for line in f:
            try:
                text = (json.loads(line).get("display") or "").strip()
            except (ValueError, AttributeError):
                continue
            if text and not text.startswith("/"):
                displays.append(text)
    return random.Random(seed).sample(displays, min(n, len(displays)))
