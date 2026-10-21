"""Model hint for the Claude Code status line.

  python3 model_hint render                    status line JSON on stdin; prints coloured + plain hint, or nothing
  python3 model_hint worker SID PATH TURN_KEY  background: summarise, ask Open-Jev, update the cache
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time

import cache
from cache import CacheEntry
from hint import current_tier, effort_index, render_hint
from openjev import OpenJevError, ask
from stability import update
from summary import build_summary
from transcript import last_completed_turn, read_entries, read_tail_entries

PKG_DIR = os.path.dirname(os.path.abspath(__file__))
RENDER_WAIT = 0.7
POLL = 0.05
WORKER_TIMEOUT = 3.0


def spawn_worker(sid: str, path: str, key: str) -> None:
    subprocess.Popen([sys.executable, PKG_DIR, "worker", sid, path, key], start_new_session=True,
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     close_fds=True)


def cmd_render(raw: str) -> None:
    data = json.loads(raw)
    cur = current_tier((data.get("model") or {}).get("id"))
    sid, path = data.get("session_id"), data.get("transcript_path")
    if cur is None or not sid or not path:
        return
    entry = cache.load(sid)
    key = last_completed_turn(read_tail_entries(path)) or entry.turn_key
    if key and key != entry.turn_key and cache.claim_pending(sid, key):
        spawn_worker(sid, path, key)
        deadline = time.monotonic() + RENDER_WAIT
        while time.monotonic() < deadline:
            time.sleep(POLL)
            entry = cache.load(sid)
            if entry.turn_key == key:
                break
    if entry.error or entry.state.shown_tier is None:
        return
    coloured, plain = render_hint(entry.state, cur, effort_index((data.get("effort") or {}).get("level")))
    print(coloured)
    print(plain)


def cmd_worker(sid: str, path: str, key: str) -> None:
    try:
        prev = cache.load(sid)
        if prev.turn_key == key and not prev.error:
            return
        entries = read_entries(path)
        cut = next((i for i, e in enumerate(entries) if e.get("uuid") == key), None)
        if cut is not None:
            entries = entries[: cut + 1]
        try:
            reading = ask(build_summary(entries), timeout=WORKER_TIMEOUT)
        except OpenJevError:
            cache.save(sid, CacheEntry(key, prev.state, True))
            return
        cache.save(sid, CacheEntry(key, update(prev.state, reading), False))
    finally:
        cache.clear_pending(sid)


def main(argv: list[str]) -> int:
    command = argv[1] if len(argv) > 1 else ""
    if command == "render":
        try:
            cmd_render(sys.stdin.read())
        except Exception:
            pass
        return 0
    if command == "worker" and len(argv) == 5:
        cmd_worker(argv[2], argv[3], argv[4])
        return 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
