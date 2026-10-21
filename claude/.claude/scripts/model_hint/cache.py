"""Per-session cache of the recommendation, plus a marker so only one worker runs per turn."""
from __future__ import annotations

import json
import os
import re
import tempfile
import time
from dataclasses import dataclass, field
from pathlib import Path

from stability import State

PENDING_MAX_AGE = 10.0


@dataclass
class CacheEntry:
    turn_key: str | None = None
    state: State = field(default_factory=State)
    error: bool = False


def cache_dir() -> Path:
    base = os.environ.get("XDG_CACHE_HOME") or os.path.join(os.path.expanduser("~"), ".cache")
    return Path(base) / "claude-statusline" / "model-hint"


def safe_id(session_id: str) -> str:
    return re.sub(r"[^A-Za-z0-9_-]", "_", session_id)


def _path(session_id: str, suffix: str) -> Path:
    return cache_dir() / f"{safe_id(session_id)}{suffix}"


def load(session_id: str) -> CacheEntry:
    try:
        data = json.loads(_path(session_id, ".json").read_text(encoding="utf-8"))
        key = data.get("turn_key")
        return CacheEntry(key if isinstance(key, str) else None, State.from_dict(data.get("state")),
                          data.get("error") is True)
    except (OSError, ValueError, AttributeError):
        return CacheEntry()


def save(session_id: str, entry: CacheEntry) -> None:
    directory = cache_dir()
    directory.mkdir(parents=True, exist_ok=True)
    payload = json.dumps({"turn_key": entry.turn_key, "state": entry.state.to_dict(), "error": entry.error})
    fd, tmp = tempfile.mkstemp(dir=directory, prefix=".tmp-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(payload)
        os.replace(tmp, _path(session_id, ".json"))
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def claim_pending(session_id: str, turn_key: str) -> bool:
    marker = _path(session_id, ".pending")
    try:
        if marker.read_text(encoding="utf-8") == turn_key and time.time() - marker.stat().st_mtime < PENDING_MAX_AGE:
            return False
    except OSError:
        pass
    marker.parent.mkdir(parents=True, exist_ok=True)
    marker.write_text(turn_key, encoding="utf-8")
    return True


def clear_pending(session_id: str) -> None:
    try:
        _path(session_id, ".pending").unlink()
    except OSError:
        pass
