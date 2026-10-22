"""Ask a Jev decision model which model tier and effort fit a session summary.

Two backends share the same /v1/systemone contract:
  open-jev  the local Open-Jev server (default)
  typesafe  TypeSafe's hosted Jev, authenticated with TYPESAFE_API_KEY

Pick one with JEV_BACKEND and, optionally, the model id with JEV_MODEL.
"""
from __future__ import annotations

import http.client
import json
import os
import urllib.error
import urllib.request
from dataclasses import dataclass

DEFAULT_URL = "http://127.0.0.1:8791/v1/systemone"
TYPESAFE_URL = "https://api.typesafe.ai/v1/systemone"
TIERS = ("haiku", "sonnet", "opus")

# Effort boundaries (low|medium|high|xhigh) on the 0-3 expected-level score.
# Open-Jev's score is compressed (0.4-1.6 on replayed sessions); these were calibrated on that data,
# see docs/superpowers/reports/2026-10-21-model-hint-tuning.md.
OPENJEV_THRESHOLDS = (0.65, 1.10, 1.40)
# TypeSafe reports calibrated probabilities, so start from plain rounding. Not tuned yet: run
# `model_hint replay --backend typesafe` and set JEV_EFFORT_THRESHOLDS if it reads high or low.
TYPESAFE_THRESHOLDS = (0.5, 1.5, 2.5)

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
    """The Jev backend could not be reached or returned something unusable."""


@dataclass
class Reading:
    model_probs: dict[str, float]
    effort_probs: list[float]
    effort_score: float
    effort_thresholds: tuple[float, ...] = OPENJEV_THRESHOLDS


@dataclass(frozen=True)
class Backend:
    name: str
    url: str
    model: str
    api_key: str | None
    effort_thresholds: tuple[float, ...]


BACKENDS = ("open-jev", "typesafe")


def _thresholds(raw: str | None, default: tuple[float, ...]) -> tuple[float, ...]:
    try:
        values = tuple(float(v) for v in (raw or "").split(","))
    except ValueError:
        return default
    return values if len(values) == 3 and list(values) == sorted(values) else default


def backend(name: str | None = None, model: str | None = None) -> Backend:
    """Resolve a backend from arguments, falling back to the environment."""
    env = os.environ
    name = (name or env.get("JEV_BACKEND") or "open-jev").strip().lower()
    model = model or env.get("JEV_MODEL") or None
    if name == "typesafe":
        return Backend(name, env.get("TYPESAFE_URL") or TYPESAFE_URL, model or "jev-latest",
                       env.get("TYPESAFE_API_KEY") or None,
                       _thresholds(env.get("JEV_EFFORT_THRESHOLDS"), TYPESAFE_THRESHOLDS))
    if name == "open-jev":
        return Backend(name, env.get("OPENJEV_URL") or DEFAULT_URL, model or "open-jev", None,
                       _thresholds(env.get("JEV_EFFORT_THRESHOLDS"), OPENJEV_THRESHOLDS))
    raise OpenJevError(f"unknown JEV_BACKEND {name!r}; use one of {', '.join(BACKENDS)}")


def ask(state: str, url: str | None = None, timeout: float = 3.0, using: Backend | None = None) -> Reading:
    target = using or backend()
    if target.name == "typesafe" and not target.api_key:
        raise OpenJevError("TYPESAFE_API_KEY is not set")
    headers = {"Content-Type": "application/json"}
    if target.api_key:
        headers["Authorization"] = f"Bearer {target.api_key}"
    body = json.dumps({"model": target.model, "state": state, "questions": QUESTIONS}).encode()
    request = urllib.request.Request(url or target.url, data=body, headers=headers)
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
            effort_thresholds=target.effort_thresholds,
        )
    except (KeyError, TypeError, ValueError) as error:
        raise OpenJevError(f"unexpected response: {error}") from error
