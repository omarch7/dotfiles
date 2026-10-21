"""Read Claude Code transcripts (JSONL) and pick out user prompts and completed turns."""
from __future__ import annotations

import json
import os
import re

SKIP_PREFIXES = ("<local-command", "<task-notification", "<system-reminder", "<bash-",
                 "[Request interrupted", "[Request cancelled")
# User-type entries Claude Code injects itself (compaction summaries, transcript-only notes)
SKIP_FLAGS = ("isMeta", "isCompactSummary", "isVisibleInTranscriptOnly")

# Slash commands that control the session rather than describe work.
SESSION_COMMANDS = {"/model", "/effort", "/clear", "/compact", "/config", "/fast", "/resume", "/rename",
                    "/theme", "/vim", "/exit", "/status", "/cost", "/context", "/help", "/login", "/logout",
                    "/permissions", "/memory", "/hooks", "/mcp", "/agents", "/plugin"}

_NAME_RE = re.compile(r"<command-name>(.*?)</command-name>", re.S)
_ARGS_RE = re.compile(r"<command-args>(.*?)</command-args>", re.S)


def _parse_lines(lines) -> list[dict]:
    entries = []
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        if isinstance(entry, dict):
            entries.append(entry)
    return entries


def read_entries(path: str) -> list[dict]:
    with open(path, encoding="utf-8", errors="replace") as f:
        return _parse_lines(f)


def read_tail_entries(path: str, max_bytes: int = 262_144) -> list[dict]:
    size = os.path.getsize(path)
    offset = max(0, size - max_bytes)
    with open(path, "rb") as f:
        f.seek(offset)
        text = f.read().decode("utf-8", errors="replace")
    lines = text.split("\n")
    if offset > 0:
        lines = lines[1:]
    return _parse_lines(lines)


def is_main(entry: dict) -> bool:
    return entry.get("isSidechain") is not True


def message_of(entry: dict) -> dict:
    """The entry's message object, or {} when missing or malformed."""
    message = entry.get("message")
    return message if isinstance(message, dict) else {}


def content_blocks(entry: dict, kind: str) -> list[dict]:
    content = message_of(entry).get("content")
    if not isinstance(content, list):
        return []
    return [b for b in content if isinstance(b, dict) and b.get("type") == kind]


def _text_of(content) -> str | None:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        texts = [b.get("text", "") for b in content if isinstance(b, dict) and b.get("type") == "text"]
        return "\n".join(texts) if texts else None
    return None


def prompt_text(entry: dict) -> str | None:
    if not is_main(entry) or entry.get("type") != "user" or any(entry.get(f) is True for f in SKIP_FLAGS):
        return None
    text = _text_of(message_of(entry).get("content"))
    if text is None:
        return None
    text = text.strip()
    if not text or text.startswith(SKIP_PREFIXES):
        return None
    if "<command-name>" in text:
        name_match = _NAME_RE.search(text)
        args_match = _ARGS_RE.search(text)
        name = name_match.group(1).strip() if name_match else ""
        args = args_match.group(1).strip() if args_match else ""
        if not args or name in SESSION_COMMANDS:
            return None
        return f"{name} {args}"
    return text


def completed_turn_indices(entries: list[dict]) -> list[int]:
    """One index per finished reply. Claude Code writes each content block of a reply as its own
    line (thinking, then text), all marked end_turn and sharing message.id; count only the last
    line that carries reply text."""
    last_by_message: dict[str, int] = {}
    for i, e in enumerate(entries):
        message = message_of(e)
        if (is_main(e) and e.get("type") == "assistant" and message.get("stop_reason") == "end_turn"
                and content_blocks(e, "text")):
            last_by_message[message.get("id") or e.get("uuid") or str(i)] = i
    return sorted(last_by_message.values())


def last_completed_turn(entries: list[dict]) -> str | None:
    indices = completed_turn_indices(entries)
    return entries[indices[-1]].get("uuid") if indices else None
