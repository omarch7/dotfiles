"""Model hint for the Claude Code status line.

  python3 model_hint render                    status line JSON on stdin; prints coloured + plain hint, or nothing
  python3 model_hint worker SID PATH TURN_KEY  background: summarise, ask Open-Jev, update the cache
  python3 model_hint replay TRANSCRIPT [--lean] [--no-stability]   tuning: per-turn picks and change count
  python3 model_hint prompts HISTORY [--sample N] [--seed S]       tuning: picks for sampled past prompts
"""
from __future__ import annotations

import argparse
import json
import os
import statistics
import subprocess
import sys
import time
from collections import Counter

import cache
from cache import CacheEntry
from hint import EFFORT_NAMES, current_tier, effort_index, render_hint
from openjev import TIERS, OpenJevError, ask
from replay import count_changes, raw_pick, replay_session, sample_prompts
from stability import update
from summary import Signals, build_summary, format_summary
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
    prev = cache.load(sid)
    try:
        if prev.turn_key == key and not prev.error:
            return
        entries = read_entries(path)
        cut = next((i for i, e in enumerate(entries) if e.get("uuid") == key), None)
        if cut is not None:
            entries = entries[: cut + 1]
        reading = ask(build_summary(entries), timeout=WORKER_TIMEOUT)
        cache.save(sid, CacheEntry(key, update(prev.state, reading), False))
    except Exception:
        # Record the turn as failed (hint hidden) so renders don't keep respawning and waiting.
        try:
            cache.save(sid, CacheEntry(key, prev.state, True))
        except OSError:
            pass
    finally:
        cache.clear_pending(sid)


TOOL_TIMEOUT = 15.0


def _pick(tier: str, level: int) -> str:
    return f"{tier}·{EFFORT_NAMES[level]}"


def _oneline(text: str, width: int) -> str:
    return " ".join(text.split())[:width]


def cmd_replay(args: list[str]) -> None:
    parser = argparse.ArgumentParser(prog="model_hint replay")
    parser.add_argument("transcript")
    parser.add_argument("--lean", action="store_true")
    parser.add_argument("--no-stability", action="store_true")
    opts = parser.parse_args(args)
    results = replay_session(read_entries(opts.transcript), lambda s: ask(s, timeout=TOOL_TIMEOUT),
                             lean=opts.lean, smooth=not opts.no_stability)
    for r in results:
        print(f"{r.turn}\t{_pick(*r.raw)}\t{_pick(*r.shown)}\t{r.seconds:.2f}\t{_oneline(r.prompt, 60)}")
    seconds = [r.seconds for r in results] or [0.0]
    print(f"turns={len(results)} changes={count_changes([r.shown for r in results])} "
          f"p50={statistics.median(seconds):.2f}s max={max(seconds):.2f}s")


def cmd_prompts(args: list[str]) -> None:
    parser = argparse.ArgumentParser(prog="model_hint prompts")
    parser.add_argument("history")
    parser.add_argument("--sample", type=int, default=40)
    parser.add_argument("--seed", type=int, default=1)
    opts = parser.parse_args(args)
    counts: Counter = Counter()
    for text in sample_prompts(opts.history, opts.sample, opts.seed):
        summary = format_summary(Signals(1, [text], "", [], 0, 0, 0, 0, 0, "ok"), lean=True)
        tier, level = raw_pick(ask(summary, timeout=TOOL_TIMEOUT))
        counts[tier] += 1
        counts[EFFORT_NAMES[level]] += 1
        print(f"{_pick(tier, level)}\t{_oneline(text, 80)}")
    print(" ".join(f"{name}={counts[name]}" for name in (*TIERS, *EFFORT_NAMES)))


def main(argv: list[str]) -> int:
    command = argv[1] if len(argv) > 1 else ""
    if command == "replay":
        cmd_replay(argv[2:])
        return 0
    if command == "prompts":
        cmd_prompts(argv[2:])
        return 0
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
