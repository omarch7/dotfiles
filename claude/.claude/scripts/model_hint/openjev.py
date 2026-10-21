"""Ask the local Open-Jev server which model tier and effort fit a session summary."""
from __future__ import annotations

import http.client
import json
import os
import urllib.error
import urllib.request
from dataclasses import dataclass

DEFAULT_URL = "http://127.0.0.1:8791/v1/systemone"
TIERS = ("haiku", "sonnet", "opus")

QUESTIONS = {
    "model": {"type": "choice", "instructions": "Which assistant tier fits the work in this session best right now?",
              "criteria": {"haiku": "Quick, mechanical or lookup tasks: renames, small edits, simple questions, running a command.",
                           "sonnet": "Everyday feature work and bug fixes across a few files with normal reasoning.",
                           "opus": "Hard, open-ended or high-stakes work: architecture, tricky debugging, large refactors, design."}},
    "effort": {"type": "score", "instructions": "How much careful reasoning does the next step of this work need?",
               "criteria": ["Low: obvious, little thinking needed.", "Medium: some reasoning or a few steps.",
                            "High: deep reasoning, many steps or subtle tradeoffs.",
                            "Extra high: very hard problems needing extended, careful reasoning."]},
}


class OpenJevError(Exception):
    """Open-Jev could not be reached or returned something unusable."""


@dataclass
class Reading:
    model_probs: dict[str, float]
    effort_probs: list[float]
    effort_score: float


def ask(state: str, url: str | None = None, timeout: float = 3.0) -> Reading:
    target = url or os.environ.get("OPENJEV_URL") or DEFAULT_URL
    body = json.dumps({"model": "open-jev", "state": state, "questions": QUESTIONS}).encode()
    request = urllib.request.Request(target, data=body, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            if response.status != 200:
                raise OpenJevError(f"HTTP {response.status}")
            data = json.load(response)
    except OpenJevError:
        raise
    except (urllib.error.URLError, http.client.HTTPException, OSError, ValueError) as error:
        raise OpenJevError(str(error)) from error
    try:
        answers = data["answers"]
        model = answers["model"]["probabilities"]
        effort = answers["effort"]
        n_levels = len(QUESTIONS["effort"]["criteria"])
        return Reading(
            model_probs={tier: float(model[tier]) for tier in TIERS},
            effort_probs=[float(effort["probabilities"][str(i)]) for i in range(n_levels)],
            effort_score=float(effort["score"]),
        )
    except (KeyError, TypeError, ValueError) as error:
        raise OpenJevError(f"unexpected response: {error}") from error
