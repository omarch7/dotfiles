"""Synthetic transcript builders and test helpers. No real session content."""
from __future__ import annotations

import itertools
import json
import os

_ids = itertools.count(1)


def _uuid() -> str:
    return f"00000000-0000-0000-0000-{next(_ids):012d}"


def user(text: str, meta: bool = False, sidechain: bool = False) -> dict:
    return {"type": "user", "uuid": _uuid(), "isSidechain": sidechain, "isMeta": meta or None,
            "message": {"role": "user", "content": text}}


def assistant_text(text: str, stop: str = "end_turn", sidechain: bool = False,
                   model: str = "claude-sonnet-5-5", cwd: str = "/repo") -> dict:
    return {"type": "assistant", "uuid": _uuid(), "isSidechain": sidechain, "cwd": cwd,
            "message": {"role": "assistant", "model": model, "stop_reason": stop,
                        "content": [{"type": "text", "text": text}]}}


def assistant_tool(name: str, input: dict, tool_id: str, cwd: str = "/repo") -> dict:
    return {"type": "assistant", "uuid": _uuid(), "isSidechain": False, "cwd": cwd,
            "message": {"role": "assistant", "model": "claude-sonnet-5-5", "stop_reason": "tool_use",
                        "content": [{"type": "tool_use", "id": tool_id, "name": name, "input": input}]}}


def tool_result(tool_id: str, content: str = "ok", is_error: bool = False) -> dict:
    return {"type": "user", "uuid": _uuid(), "isSidechain": False,
            "message": {"role": "user", "content": [
                {"type": "tool_result", "tool_use_id": tool_id, "content": content, "is_error": is_error}]}}


def write_transcript(dir: str, entries: list[dict], trailing_partial: bool = False) -> str:
    path = os.path.join(dir, "transcript.jsonl")
    with open(path, "w", encoding="utf-8") as f:
        for e in entries:
            f.write(json.dumps(e) + "\n")
        if trailing_partial:
            f.write('{"type":"assist')
    return path
