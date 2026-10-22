"""Turn a transcript into a short, budgeted text summary for Open-Jev."""
from __future__ import annotations

from collections import Counter
from dataclasses import dataclass

from transcript import content_blocks as _blocks
from transcript import is_main, prompt_text

MAX_STATE_CHARS = 7000
MAX_PROMPT_CHARS = 600
MAX_LATEST_PROMPT_CHARS = 2000
MAX_REPLY_CHARS = 1050
MAX_FILES = 15

EDIT_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}
ENDINGS = {"ok": "completed normally", "failing": "still failing",
           "question": "waiting on the developer's answer to a question"}


@dataclass
class Signals:
    prompt_count: int
    prompts: list[str]
    last_reply: str
    files_touched: list[str]
    files_edited: int
    tool_failures: int
    shell_failures: int
    max_edits_same_file: int
    max_retries_same_failing_command: int
    ended: str


def _input(block: dict) -> dict:
    value = block.get("input")
    return value if isinstance(value, dict) else {}


def _relative(path: str, cwd: str | None) -> str:
    if cwd:
        root = cwd.rstrip("/") + "/"
        if path.startswith(root):
            return path[len(root):]
    return path


def collect_signals(entries: list[dict], recent_turns: int = 3) -> Signals:
    main = [e for e in entries if is_main(e)]
    prompt_idx = [i for i, e in enumerate(main) if prompt_text(e) is not None]
    prompts = [prompt_text(main[i]) for i in prompt_idx]
    start = prompt_idx[-recent_turns] if len(prompt_idx) >= recent_turns else 0
    window = main[start:]
    turn = main[prompt_idx[-1]:] if prompt_idx else main
    cwd = next((e["cwd"] for e in reversed(main) if e.get("cwd")), None)

    last_reply = ""
    for e in reversed(main):
        texts = [b.get("text", "") for b in _blocks(e, "text")] if e.get("type") == "assistant" else []
        if texts:
            last_reply = "\n".join(texts)
            break

    calls = {b.get("id"): b for e in main if e.get("type") == "assistant" for b in _blocks(e, "tool_use")}

    edits: Counter = Counter()
    touched: list[str] = []
    for e in window:
        if e.get("type") != "assistant":
            continue
        for b in _blocks(e, "tool_use"):
            inp = _input(b)
            path = inp.get("file_path") or inp.get("notebook_path")
            if not isinstance(path, str) or not path:
                continue
            if b.get("name") in EDIT_TOOLS:
                edits[path] += 1
                touched.append(path)
            elif b.get("name") == "Read":
                touched.append(path)
    recent_first: list[str] = []
    for path in reversed(touched):
        rel = _relative(path, cwd)
        if rel not in recent_first:
            recent_first.append(rel)

    tool_failures = shell_failures = 0
    failing_commands: Counter = Counter()
    for e in window:
        for b in _blocks(e, "tool_result"):
            if b.get("is_error") is not True:
                continue
            tool_failures += 1
            call = calls.get(b.get("tool_use_id")) or {}
            if call.get("name") == "Bash":
                shell_failures += 1
                failing_commands[str(_input(call).get("command", ""))] += 1

    last_call = None
    last_result = None
    for e in turn:
        for b in _blocks(e, "tool_use"):
            last_call = b
        for b in _blocks(e, "tool_result"):
            last_result = b
    if (last_call and last_call.get("name") == "AskUserQuestion") or last_reply.rstrip().endswith("?"):
        ended = "question"
    elif last_result and last_result.get("is_error") is True:
        ended = "failing"
    else:
        ended = "ok"

    return Signals(
        prompt_count=len(prompts),
        prompts=prompts[-3:],
        last_reply=last_reply,
        files_touched=recent_first[:MAX_FILES],
        files_edited=len(edits),
        tool_failures=tool_failures,
        shell_failures=shell_failures,
        max_edits_same_file=max(edits.values(), default=0),
        max_retries_same_failing_command=max(failing_commands.values(), default=0),
        ended=ended,
    )


def _clean(text: str) -> str:
    return " ".join(text.split())


def _truncate(text: str, limit: int) -> str:
    if limit <= 0:
        return ""
    return text if len(text) <= limit else text[: limit - 1] + "…"


def format_summary(sig: Signals, lean: bool = False) -> str:
    earlier = [_truncate(_clean(p), MAX_PROMPT_CHARS) for p in sig.prompts[:-1]]
    latest = _truncate(_clean(sig.prompts[-1]), MAX_LATEST_PROMPT_CHARS) if sig.prompts else ""
    reply = "" if lean else _truncate(_clean(sig.last_reply), MAX_REPLY_CHARS)
    files = "" if lean else ", ".join(sig.files_touched[:MAX_FILES])
    activity = (f"Recent activity: {sig.files_edited} files edited; {sig.tool_failures} failed tool calls; "
                f"{sig.shell_failures} failed shell commands; most edits to one file: {sig.max_edits_same_file}; "
                f"most retries of one failing command: {sig.max_retries_same_failing_command}.")
    ending = "" if lean else ENDINGS.get(sig.ended, ENDINGS["ok"])

    def render() -> str:
        lines = ["A developer is working with an AI coding assistant. Summary of the session so far.",
                 f"Prompts in this session: {sig.prompt_count}"]
        if earlier:
            lines.append("Earlier prompts (oldest first):")
            lines += [f"- {p}" for p in earlier]
        if latest:
            lines.append(f"Latest prompt: {latest}")
        if reply:
            lines.append(f"Assistant's latest reply (trimmed): {reply}")
        if files:
            lines.append(f"Files touched recently: {files}")
        lines.append(activity)
        if ending:
            lines.append(f"How the last turn ended: {ending}")
        return "\n".join(lines)

    limit = MAX_STATE_CHARS
    out = render()
    while len(out) > limit and earlier:
        earlier.pop(0)
        out = render()
    if len(out) > limit:
        files = ""
        out = render()
    if len(out) > limit:
        reply = ""
        out = render()
    if len(out) > limit:
        latest = _truncate(latest, len(latest) - (len(out) - limit))
        out = render()
    return out


def build_summary(entries: list[dict], lean: bool = False) -> str:
    return format_summary(collect_signals(entries), lean)
