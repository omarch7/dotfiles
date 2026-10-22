# Model and Effort Recommendation Status Line Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a colour-coded, flicker-resistant hint in the Claude Code status line naming the best Claude model tier and effort level for the work so far, as judged by a local Open-Jev model.

**Architecture:** A stdlib-only Python package `model_hint` sits beside `context-bar.sh`. On each status line render, `context-bar.sh` pipes its stdin JSON to `python3 model_hint render`. That command reads the transcript tail and, once per completed turn, starts a detached worker. The worker summarises the session, asks Open-Jev, smooths the result into a per-session cache and writes it back. The render command waits briefly for that result, then prints the hint (coloured line plus plain line), which bash appends to line 1.

**Tech Stack:** bash, jq (existing script); Python ≥ 3.9 standard library only (`json`, `urllib`, `subprocess`, `dataclasses`, `unittest`, `http.server` for test stubs).

**Spec:** `docs/superpowers/specs/2026-10-21-model-effort-recommendation-statusline-design.md`

## Global Constraints

- Python ≥ 3.9, standard library only (the dotfiles are shared with macOS's system `python3`). Every module starts with `from __future__ import annotations`.
- Package directory: `claude/.claude/scripts/model_hint/`. `~/.claude/scripts` is already a symlink to `claude/.claude/scripts`, so nothing new needs linking.
- Tests: `cd claude/.claude/scripts/model_hint && python3 -m unittest discover -s tests -t . -v`. Single module: `python3 -m unittest tests.test_<name> -v` from the same directory.
- Open-Jev URL: `OPENJEV_URL` env var, default `http://127.0.0.1:8791/v1/systemone`. No other network calls.
- Open-Jev rejects over-length input with HTTP 422 (4,096 tokens per candidate sequence). Summary cap: `MAX_STATE_CHARS = 7000`.
- Effort levels recommended: `low`, `medium`, `high`, `xhigh` (indices 0–3). Never `max`. Current `max` compares as index 4.
- Tiers: `haiku` < `sonnet` < `opus`, labels `Haiku`, `Sonnet`, `Opus`.
- Hint text, exactly: `✓ right fit`, `⇡ <Tier> · <effort>`, `⇡⇡ <Tier> · <effort>`, `⇣ <Tier> · <effort>`. Drop ` · <effort>` when the current model reports no effort.
- Colours: green `\033[38;2;152;195;121m`, amber `\033[38;2;229;192;123m` (matches `C_WARN`), red `\033[38;2;224;108;117m` (matches `C_CRIT`), dim blue `\033[2;38;2;97;175;239m`, gray `\033[38;5;245m` (matches `C_GRAY`), reset `\033[0m`.
- Stability constants: `ALPHA_NEW = 0.4`, `MODEL_MARGIN = 0.15`, `FAST_LANE = 0.85`, `EFFORT_BAND = 0.15`. Gray below `GRAY_BELOW = 0.60`.
- Cache: `${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline/model-hint/<session_id>.json`, atomic writes.
- The render path never prints errors or tracebacks, always exits 0, and waits for the worker at most `RENDER_WAIT = 0.7` s. A hidden hint means printing nothing.
- The hint shows only on the Claude subscription provider (`ANTHROPIC_BASE_URL` unset, `PROVIDER == claude` in `context-bar.sh`).
- The dotfiles repo is on GitHub: **no real prompt, transcript or project content in any committed file or fixture.** Test data is synthetic.

## Review Focus

- **Slash commands and injected messages counted as prompts.** `/model opus`, `<local-command-stdout>…`, skill bodies (`isMeta`) and "[Request interrupted…]" must never become "the latest prompt". Test: `test_prompt_text_filters` (Task 1).
- **Long sessions with multi-megabyte transcripts.** Rendering with a current cache must stay fast because only the tail is read. Test: `test_large_transcript_render_is_fast` (Task 6).
- **A half-written last line** while Claude Code is appending must be skipped, not crash. Test: `test_skips_malformed_and_partial_lines` (Task 1).
- **A huge pasted prompt** (tens of thousands of chars, non-ASCII, newlines) must still produce a summary under the cap that keeps the newest prompt. Test: `test_budget_with_huge_prompt` (Task 2).
- **Open-Jev hanging** (GPU busy) must not freeze the status line: render returns within the wait budget. Test: `test_slow_server_render_returns_quickly` (Task 6). A corrupt cache file from a killed write must be ignored: `test_corrupt_cache_is_ignored` (Task 6).

---

### Task 1: Transcript reading and prompt filtering

**Files:**
- Create: `claude/.claude/scripts/model_hint/transcript.py`
- Create: `claude/.claude/scripts/model_hint/tests/__init__.py` (empty)
- Create: `claude/.claude/scripts/model_hint/tests/fixtures.py`
- Test: `claude/.claude/scripts/model_hint/tests/test_transcript.py`

**Interfaces:**
- Produces (`transcript.py`):
  - `read_entries(path: str) -> list[dict]`: every parseable JSON line; malformed lines skipped.
  - `read_tail_entries(path: str, max_bytes: int = 262_144) -> list[dict]`: parse only the last `max_bytes`, drop the first (possibly partial) line, skip malformed.
  - `is_main(entry: dict) -> bool`: `entry.get("isSidechain")` is not true.
  - `prompt_text(entry: dict) -> str | None`
  - `completed_turn_indices(entries: list[dict]) -> list[int]`: indices of main `type == "assistant"` entries with `message.stop_reason == "end_turn"`.
  - `last_completed_turn(entries: list[dict]) -> str | None`: `uuid` of the last such entry.
- Produces (`tests/fixtures.py`). Each builder returns a dict with a fresh unique `uuid`:
  - `user(text: str, meta: bool = False, sidechain: bool = False)` → `{"type":"user","isSidechain":sidechain,"isMeta":meta or None,"message":{"role":"user","content":text}}`
  - `assistant_text(text, stop="end_turn", sidechain=False, model="claude-sonnet-5-5", cwd="/repo")` → `message.content = [{"type":"text","text":text}]`
  - `assistant_tool(name, input: dict, tool_id: str, cwd="/repo")` → `stop_reason "tool_use"`, `content = [{"type":"tool_use","id":tool_id,"name":name,"input":input}]`
  - `tool_result(tool_id, content="ok", is_error=False)` → user entry with `content = [{"type":"tool_result","tool_use_id":tool_id,"content":content,"is_error":is_error}]`
  - `write_transcript(dir: str, entries: list[dict], trailing_partial: bool = False) -> str`: writes (overwriting) `<dir>/transcript.jsonl` and returns its path. With `trailing_partial`, appends `{"type":"assist` without a newline.

`prompt_text` rules, in order:
1. `None` unless main, `type == "user"`, and `isMeta` not true.
2. Text = the string content, or the joined `text` blocks of list content. `None` if there are none (tool results).
3. Strip whitespace. `None` if empty or it starts with one of `("<local-command", "<task-notification", "<system-reminder", "[Request interrupted", "[Request cancelled")`.
4. If it contains `<command-name>`: take the name and the `<command-args>` text. Return `None` if args are empty or the name is in `SESSION_COMMANDS = {"/model","/effort","/clear","/compact","/config","/fast","/resume","/rename","/theme","/vim","/exit","/status","/cost","/context","/help","/login","/logout","/permissions","/memory","/hooks","/mcp","/agents","/plugin"}`. Otherwise return `f"{name} {args}"`.
5. Otherwise return the text.

- [ ] **Step 1: Write the failing tests** (`unittest.TestCase`; use `tempfile.TemporaryDirectory()` for `tmp`)

```python
def test_skips_malformed_and_partial_lines(self):
    p = write_transcript(tmp, [user("a"), assistant_text("b")], trailing_partial=True)
    self.assertEqual(len(read_entries(p)), 2)

def test_tail_drops_leading_partial_line(self):
    p = write_transcript(tmp, [user("x" * 1000) for _ in range(400)] + [assistant_text("done")])
    tail = read_tail_entries(p, max_bytes=8192)
    self.assertEqual(tail[-1]["message"]["content"][0]["text"], "done")
    self.assertLess(len(tail), 10)

def test_prompt_text_filters(self):
    self.assertEqual(prompt_text(user("fix the bug")), "fix the bug")
    self.assertIsNone(prompt_text(user("<command-name>/model</command-name>\n<command-args>opus</command-args>")))
    self.assertEqual(prompt_text(user("<command-name>/superpowers:brainstorming</command-name><command-args>add a hook</command-args>")),
                     "/superpowers:brainstorming add a hook")
    self.assertIsNone(prompt_text(user("<local-command-stdout>Set model</local-command-stdout>")))
    self.assertIsNone(prompt_text(user("Base directory for this skill", meta=True)))
    self.assertIsNone(prompt_text(user("hi", sidechain=True)))
    self.assertIsNone(prompt_text(tool_result("t1")))
    self.assertIsNone(prompt_text(user("[Request interrupted by user]")))

def test_last_completed_turn(self):
    a = assistant_text("one"); t = assistant_tool("Bash", {"command": "ls"}, "t1")
    self.assertEqual(last_completed_turn([user("q"), a, user("q2"), t]), a["uuid"])
    self.assertIsNone(last_completed_turn([user("q"), t]))
    self.assertEqual(last_completed_turn([a, assistant_text("sub", sidechain=True)]), a["uuid"])
    self.assertEqual(completed_turn_indices([user("q"), a, user("q2"), t]), [1])
```

- [ ] **Step 2: Run `python3 -m unittest tests.test_transcript -v`.** Expected: errors, `ModuleNotFoundError: No module named 'transcript'`.
- [ ] **Step 3: Implement `transcript.py`** with the interfaces and rules above. `read_tail_entries`: seek to `max(0, size - max_bytes)`, read, decode UTF-8 with `errors="replace"`, and drop the first line when the offset is > 0.
- [ ] **Step 4: Run the tests again.** Expected: 4 tests OK.
- [ ] **Step 5: Commit**

```bash
git add claude/.claude/scripts/model_hint
git commit -m "Add transcript reading for model hint"
```

---

### Task 2: Session signals and the Open-Jev summary

**Files:**
- Create: `claude/.claude/scripts/model_hint/summary.py`
- Test: `claude/.claude/scripts/model_hint/tests/test_summary.py`

**Interfaces:**
- Consumes: `is_main`, `prompt_text` (Task 1); fixtures.
- Produces:
  - `@dataclass Signals`: `prompt_count: int`, `prompts: list[str]` (last 3, oldest first), `last_reply: str`, `files_touched: list[str]` (most recent first, ≤ 15, relative to cwd when under it), `files_edited: int`, `tool_failures: int`, `shell_failures: int`, `max_edits_same_file: int`, `max_retries_same_failing_command: int`, `ended: str` (`"question"`, `"failing"` or `"ok"`).
  - `collect_signals(entries: list[dict], recent_turns: int = 3) -> Signals`
  - `format_summary(sig: Signals, lean: bool = False) -> str`
  - `build_summary(entries: list[dict], lean: bool = False) -> str` = `format_summary(collect_signals(entries), lean)`
  - Constants: `MAX_STATE_CHARS = 7000`, `MAX_PROMPT_CHARS = 600`, `MAX_LATEST_PROMPT_CHARS = 2000`, `MAX_REPLY_CHARS = 1050`, `MAX_FILES = 15`.

Definitions (main entries only):
- **Recent window:** entries from the 3rd-to-last prompt onward (all entries if fewer than 3 prompts).
- **Edit tools:** `Edit`, `Write`, `MultiEdit`, `NotebookEdit`, using `input["file_path"]` or `input["notebook_path"]`. `Read`'s `file_path` also counts toward `files_touched`.
- **Failures:** tool results with `is_error` true. A shell failure is one whose `tool_use_id` maps to a `Bash` call. Retries are counted per identical failing `command` string.
- **cwd:** the `cwd` field of the last main entry that has one.
- **`ended`:** looks only at entries after the last prompt. It is `"question"` if the last tool call there is `AskUserQuestion` or `last_reply.rstrip()` ends with `?`. Otherwise `"failing"` if the last tool result there has `is_error`. Otherwise `"ok"`.

Summary text, one item per line, exactly this wording:

```
A developer is working with an AI coding assistant. Summary of the session so far.
Prompts in this session: {prompt_count}
Earlier prompts (oldest first):
- {prompt}
Latest prompt: {prompt}
Assistant's latest reply (trimmed): {last_reply}
Files touched recently: {comma-separated}
Recent activity: {files_edited} files edited; {tool_failures} failed tool calls; {shell_failures} failed shell commands; most edits to one file: {n}; most retries of one failing command: {n}.
How the last turn ended: {completed normally | still failing | waiting on the developer's answer to a question}
```

- `lean=True` omits the reply, files and ending lines. Lines whose content would be empty are omitted.
- Collapse every run of whitespace (including newlines) in prompts and the reply to a single space.
- Then truncate with `…`: earlier prompts to 600 chars, the latest to 2,000, the reply to 1,050.
- If the result still exceeds `MAX_STATE_CHARS`, trim in this order until it fits: drop earlier prompts oldest-first, then the files line, then the reply line, then shorten the latest prompt.

- [ ] **Step 1: Write the failing tests**

```python
def test_counts_edits_failures_and_circling(self):
    es = [user("p1"),
          assistant_tool("Edit", {"file_path": "/repo/a.py"}, "e1"), tool_result("e1"),
          assistant_tool("Edit", {"file_path": "/repo/a.py"}, "e2"), tool_result("e2"),
          assistant_tool("Write", {"file_path": "/repo/b.py"}, "w1"), tool_result("w1"),
          assistant_tool("Bash", {"command": "pytest"}, "b1"), tool_result("b1", is_error=True),
          assistant_tool("Bash", {"command": "pytest"}, "b2"), tool_result("b2", is_error=True),
          assistant_text("Still failing. Should I keep going?")]
    s = collect_signals(es)
    self.assertEqual((s.files_edited, s.tool_failures, s.shell_failures), (2, 2, 2))
    self.assertEqual((s.max_edits_same_file, s.max_retries_same_failing_command), (2, 2))
    self.assertEqual(s.files_touched[:2], ["b.py", "a.py"])
    self.assertEqual(s.ended, "question")

def test_ended_failing_ok_and_ask_tool(self):
    fail = [user("p"), assistant_tool("Bash", {"command": "make"}, "b"), tool_result("b", is_error=True), assistant_text("It fails.")]
    self.assertEqual(collect_signals(fail).ended, "failing")
    self.assertEqual(collect_signals([user("p"), assistant_text("Done.")]).ended, "ok")
    ask = [user("p"), assistant_tool("AskUserQuestion", {}, "q"), tool_result("q"), assistant_text("Noted.")]
    self.assertEqual(collect_signals(ask).ended, "question")

def test_recent_window_and_prompts(self):
    es = [user("p1"), assistant_tool("Edit", {"file_path": "/repo/old.py"}, "o"), tool_result("o"), assistant_text("x")]
    for i in range(2, 6): es += [user(f"p{i}"), assistant_text("y")]
    s = collect_signals(es)
    self.assertEqual((s.prompt_count, s.prompts, s.files_edited), (5, ["p3", "p4", "p5"], 0))

def test_summary_lines_and_lean(self):
    s = Signals(5, ["p3", "p4", "p5"], "Found a race.", ["a.py"], 1, 2, 1, 1, 1, "failing")
    out = format_summary(s)
    for line in ("Prompts in this session: 5", "Latest prompt: p5", "Assistant's latest reply (trimmed): Found a race.",
                 "Files touched recently: a.py", "How the last turn ended: still failing"):
        self.assertIn(line, out)
    lean = format_summary(s, lean=True)
    for gone in ("Assistant's latest reply", "Files touched", "How the last turn ended"):
        self.assertNotIn(gone, lean)

def test_budget_with_huge_prompt(self):
    s = Signals(2, ["old " * 3000, "ünïcode\n" * 5000], "r" * 5000, [f"f{i}.py" for i in range(15)], 15, 0, 0, 1, 0, "ok")
    out = format_summary(s)
    self.assertLessEqual(len(out), MAX_STATE_CHARS)
    self.assertIn("Latest prompt: ünïcode", out)

def test_trim_drops_earlier_prompts_first(self):
    s = Signals(3, ["e" * 600, "e" * 600, "latest"], "r" * 1000, ["a.py"], 1, 0, 0, 1, 0, "ok")
    with mock.patch("summary.MAX_STATE_CHARS", len(format_summary(s)) - 100):
        out = format_summary(s)
    self.assertIn("Assistant's latest reply", out); self.assertIn("Files touched", out); self.assertIn("Latest prompt: latest", out)
```

- [ ] **Step 2: Run `python3 -m unittest tests.test_summary -v`.** Expected: `ModuleNotFoundError: No module named 'summary'`.
- [ ] **Step 3: Implement `summary.py`** per the interfaces and definitions. `format_summary` must read `MAX_STATE_CHARS` from the module at call time so the patch in the last test applies.
- [ ] **Step 4: Run the tests again.** Expected: 6 tests OK.
- [ ] **Step 5: Commit:** `git add claude/.claude/scripts/model_hint && git commit -m "Add session summary for model hint"`

---

### Task 3: Open-Jev client

**Files:**
- Create: `claude/.claude/scripts/model_hint/openjev.py`
- Modify: `claude/.claude/scripts/model_hint/tests/fixtures.py` (add stub server)
- Test: `claude/.claude/scripts/model_hint/tests/test_openjev.py`

**Interfaces:**
- Produces (`openjev.py`):
  - `@dataclass Reading`: `model_probs: dict[str, float]` (keys `haiku`, `sonnet`, `opus`), `effort_probs: list[float]` (length 4), `effort_score: float`.
  - `class OpenJevError(Exception)`
  - `DEFAULT_URL = "http://127.0.0.1:8791/v1/systemone"`
  - `ask(state: str, url: str | None = None, timeout: float = 3.0) -> Reading`. URL precedence: argument, then `OPENJEV_URL`, then `DEFAULT_URL`. Any connection error, timeout, non-200 status or unexpected shape raises `OpenJevError`.
  - `QUESTIONS`, exact copy:

```python
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
```

  - Request body: `{"model": "open-jev", "state": state, "questions": QUESTIONS}`. Parse from `answers.model.probabilities`, `answers.effort.probabilities` (keys `"0"`–`"3"`) and `answers.effort.score`.
- Produces (`tests/fixtures.py`):
  - `reading_response(model: dict, effort_probs: list, score: float) -> dict`: a server-shaped response body.
  - `class StubOpenJev(responses, delay: float = 0.0, status: int = 200)`: a context manager running a threaded `http.server` on port 0. It exposes `.url` (ending `/v1/systemone`) and `.requests` (parsed JSON bodies). `responses` is a list served in order (the last one repeats) or a callable taking the body.
  - `closed_port_url() -> str`: binds port 0, closes it, and returns an `http://127.0.0.1:<port>/v1/systemone` URL.

- [ ] **Step 1: Write the failing tests**

```python
R = reading_response({"haiku": .1, "sonnet": .7, "opus": .2}, [.1, .2, .6, .1], 1.7)

def test_request_shape_and_parse(self):
    with StubOpenJev([R]) as stub:
        r = ask("S", url=stub.url)
    body = stub.requests[0]
    self.assertEqual(body["state"], "S")
    self.assertEqual(set(body["questions"]), {"model", "effort"})
    self.assertEqual(set(body["questions"]["model"]["criteria"]), {"haiku", "sonnet", "opus"})
    self.assertEqual(len(body["questions"]["effort"]["criteria"]), 4)
    self.assertEqual(r, Reading({"haiku": .1, "sonnet": .7, "opus": .2}, [.1, .2, .6, .1], 1.7))

def test_connection_refused_is_fast_error(self):
    t = time.monotonic()
    with self.assertRaises(OpenJevError): ask("S", url=closed_port_url())
    self.assertLess(time.monotonic() - t, 1.0)

def test_timeout_raises(self):
    with StubOpenJev([R], delay=2.0) as stub, self.assertRaises(OpenJevError):
        ask("S", url=stub.url, timeout=0.3)

def test_http_422_and_bad_shape_raise(self):
    with StubOpenJev([{"error": "too long"}], status=422) as stub, self.assertRaises(OpenJevError): ask("S", url=stub.url)
    with StubOpenJev([{"answers": {}}]) as stub, self.assertRaises(OpenJevError): ask("S", url=stub.url)

def test_env_url_used(self):
    with StubOpenJev([R]) as stub, mock.patch.dict(os.environ, {"OPENJEV_URL": stub.url}):
        ask("S")
    self.assertEqual(len(stub.requests), 1)
```

- [ ] **Step 2: Run `python3 -m unittest tests.test_openjev -v`.** Expected: `ModuleNotFoundError: No module named 'openjev'`.
- [ ] **Step 3: Implement `openjev.py` and the fixture additions.** Use `urllib.request` with `timeout`.
- [ ] **Step 4: Run the tests again.** Expected: 5 tests OK.
- [ ] **Step 5: Commit:** `git add claude/.claude/scripts/model_hint && git commit -m "Add Open-Jev client for model hint"`

---

### Task 4: Stability (smoothing, stickiness, fast lane)

**Files:**
- Create: `claude/.claude/scripts/model_hint/stability.py`
- Test: `claude/.claude/scripts/model_hint/tests/test_stability.py`

**Interfaces:**
- Consumes: `Reading` (Task 3).
- Produces:
  - `TIER_ORDER = {"haiku": 0, "sonnet": 1, "opus": 2}` and the four constants from Global Constraints.
  - `@dataclass State`: `smoothed_model: dict[str, float] | None = None`, `smoothed_effort: float | None = None`, `shown_tier: str | None = None`, `shown_effort: int | None = None`. Methods `to_dict() -> dict` and `@classmethod from_dict(d: dict | None) -> State`, which returns an empty `State()` for `None` or any malformed input.
  - `level_for(score: float) -> int` = `min(3, max(0, floor(score + 0.5)))`
  - `update(state: State, reading: Reading, smooth: bool = True) -> State`: pure, returns a new `State`.
  - `confidence(state: State) -> float` = `smoothed_model[shown_tier]`, or `0.0` when empty.

Algorithm for `update`:

```python
raw_tier = argmax(reading.model_probs); raw_level = argmax(reading.effort_probs)
if not smooth or state.shown_tier is None:
    return State(dict(reading.model_probs), reading.effort_score, raw_tier, level_for(reading.effort_score))
sm = {k: (1 - ALPHA_NEW) * state.smoothed_model[k] + ALPHA_NEW * reading.model_probs[k] for k in TIER_ORDER}
se = (1 - ALPHA_NEW) * state.smoothed_effort + ALPHA_NEW * reading.effort_score
tier, level = state.shown_tier, state.shown_effort
if reading.model_probs[raw_tier] >= FAST_LANE and TIER_ORDER[raw_tier] > TIER_ORDER[tier]:
    tier, sm = raw_tier, dict(reading.model_probs)
elif sm[argmax(sm)] - sm[tier] >= MODEL_MARGIN:
    tier = argmax(sm)
if reading.effort_probs[raw_level] >= FAST_LANE and raw_level > level:
    level, se = raw_level, reading.effort_score
else:
    target = level_for(se)
    if target > level and se >= level + 0.5 + EFFORT_BAND: level = target
    elif target < level and se <= level - 0.5 - EFFORT_BAND: level = target
return State(sm, se, tier, level)
```

- [ ] **Step 1: Write the failing tests.** Add `rd(h, s, o, eff=(.1, .7, .1, .1), score=1.0) -> Reading` to `tests/fixtures.py`; Task 8 reuses it.

```python
def seeded(h, s, o, tier, level=1, se=1.0): return State({"haiku": h, "sonnet": s, "opus": o}, se, tier, level)

def test_first_reading_sets_pick(self):
    st = update(State(), rd(.1, .8, .1, score=1.2))
    self.assertEqual((st.shown_tier, st.shown_effort), ("sonnet", 1))

def test_single_odd_turn_does_not_flip_and_sustained_shift_does(self):
    st = update(seeded(.2, .6, .2, "sonnet"), rd(.02, .18, .80))
    self.assertEqual(st.shown_tier, "sonnet")
    self.assertEqual(update(st, rd(.02, .18, .80)).shown_tier, "opus")

def test_close_call_keeps_shown(self):
    self.assertEqual(update(seeded(.1, .5, .4, "sonnet"), rd(.1, .45, .45)).shown_tier, "sonnet")

def test_fast_lane_up_only(self):
    up = update(seeded(.1, .8, .1, "sonnet"), rd(.02, .08, .90))
    self.assertEqual((up.shown_tier, up.smoothed_model["opus"]), ("opus", .90))
    self.assertEqual(update(seeded(.05, .15, .80, "opus"), rd(.90, .08, .02)).shown_tier, "opus")

def test_effort_dead_band_and_fast_lane(self):
    st = seeded(.1, .8, .1, "sonnet", level=1, se=1.0)
    for _ in range(10): st = update(st, rd(.1, .8, .1, eff=(.1, .4, .4, .1), score=1.6))
    self.assertEqual(st.shown_effort, 1)
    st = seeded(.1, .8, .1, "sonnet", level=1, se=1.0)
    st = update(st, rd(.1, .8, .1, eff=(.1, .3, .4, .2), score=2.2)); self.assertEqual(st.shown_effort, 1)
    st = update(st, rd(.1, .8, .1, eff=(.1, .3, .4, .2), score=2.2)); self.assertEqual(st.shown_effort, 2)
    fast = update(seeded(.1, .8, .1, "sonnet", level=1), rd(.1, .8, .1, eff=(.02, .03, .9, .05), score=2.0))
    self.assertEqual(fast.shown_effort, 2)

def test_smooth_false_follows_raw(self):
    st = update(seeded(.1, .8, .1, "sonnet"), rd(.6, .3, .1, score=0.2), smooth=False)
    self.assertEqual((st.shown_tier, st.shown_effort), ("haiku", 0))

def test_roundtrip_and_bad_input(self):
    st = seeded(.1, .8, .1, "sonnet")
    self.assertEqual(State.from_dict(st.to_dict()), st)
    self.assertEqual(State.from_dict({"junk": 1}), State()); self.assertEqual(State.from_dict(None), State())
    self.assertEqual(confidence(st), .8); self.assertEqual(confidence(State()), 0.0)
```

Compare floats with `assertAlmostEqual` where needed.

- [ ] **Step 2: Run `python3 -m unittest tests.test_stability -v`.** Expected: `ModuleNotFoundError: No module named 'stability'`.
- [ ] **Step 3: Implement `stability.py`** per the algorithm.
- [ ] **Step 4: Run the tests again.** Expected: 7 tests OK.
- [ ] **Step 5: Commit:** `git add claude/.claude/scripts/model_hint && git commit -m "Add anti-flicker smoothing for model hint"`

---

### Task 5: Hint comparison and rendering

**Files:**
- Create: `claude/.claude/scripts/model_hint/hint.py`
- Test: `claude/.claude/scripts/model_hint/tests/test_hint.py`

**Interfaces:**
- Consumes: `State`, `confidence`, `TIER_ORDER` (Task 4).
- Produces:
  - `current_tier(model_id: str | None) -> str | None`: the first of `haiku`/`sonnet`/`opus` found in the lowercased id, else `None`.
  - `effort_index(level: str | None) -> int | None`: `low` 0, `medium` 1, `high` 2, `xhigh` 3, `max` 4, anything else `None`.
  - `render_hint(state: State, cur_tier: str, cur_effort: int | None) -> tuple[str, str]`: returns `(coloured, plain)`. `coloured` = colour + plain + reset.
  - Constants: the colours and `GRAY_BELOW` from Global Constraints, `TIER_LABEL`, `EFFORT_NAMES = ["low", "medium", "high", "xhigh"]`, `MAX_EFFORT_BY_TIER = {"haiku": 3, "sonnet": 3, "opus": 3}` (the recommended effort is clamped to this).

Rules, with `dm = TIER_ORDER[rec] - TIER_ORDER[cur]` and `de = rec_effort - cur_effort` (`de = 0` when `cur_effort is None`):
- **green:** `dm == de == 0`.
- **red:** `dm >= 2 or de >= 3`.
- **amber:** otherwise if `dm > 0 or de > 0` (mixed directions count as up).
- **dim blue:** all remaining cases.
- **gray:** replaces any of the above colours when `confidence(state) < GRAY_BELOW`. The text stays the same.

- [ ] **Step 1: Write the failing tests** (helper `S(tier, lvl, p=.8)` builds a `State` whose `smoothed_model[tier] == p`)

```python
def test_states(self):
    cases = [((S("sonnet", 2), "sonnet", 2), "✓ right fit", GREEN),
             ((S("sonnet", 2), "sonnet", 0), "⇡ Sonnet · high", AMBER),
             ((S("opus", 2), "haiku", 1), "⇡⇡ Opus · high", RED),
             ((S("sonnet", 3), "sonnet", 0), "⇡⇡ Sonnet · xhigh", RED),
             ((S("haiku", 0), "opus", 2), "⇣ Haiku · low", BLUE_DIM),
             ((S("sonnet", 3), "opus", 1), "⇡ Sonnet · xhigh", AMBER),
             ((S("opus", 3), "opus", 4), "⇣ Opus · xhigh", BLUE_DIM),
             ((S("opus", 2), "sonnet", None), "⇡ Opus", AMBER),
             ((S("opus", 2, p=.55), "sonnet", 2), "⇡ Opus · high", GRAY)]
    for args, text, colour in cases:
        coloured, plain = render_hint(*args)
        self.assertEqual(plain, text); self.assertEqual(coloured, colour + text + RESET)
        self.assertNotIn("\033", plain)

def test_parsers(self):
    self.assertEqual(current_tier("claude-opus-5-5"), "opus")
    self.assertEqual(current_tier("eu.anthropic.claude-sonnet-4-6"), "sonnet")
    self.assertIsNone(current_tier("qwen3-coder")); self.assertIsNone(current_tier(None))
    self.assertEqual(effort_index("max"), 4); self.assertIsNone(effort_index(None))
```

- [ ] **Step 2: Run `python3 -m unittest tests.test_hint -v`.** Expected: `ModuleNotFoundError: No module named 'hint'`.
- [ ] **Step 3: Implement `hint.py`.**
- [ ] **Step 4: Run the tests again.** Expected: 2 tests OK.
- [ ] **Step 5: Commit:** `git add claude/.claude/scripts/model_hint && git commit -m "Add hint colouring for model hint"`

---

### Task 6: Per-session cache and the `render` / `worker` commands

**Files:**
- Create: `claude/.claude/scripts/model_hint/cache.py`
- Create: `claude/.claude/scripts/model_hint/__main__.py`
- Test: `claude/.claude/scripts/model_hint/tests/test_cli.py`

**Interfaces:**
- Consumes: Tasks 1–5.
- Produces (`cache.py`):
  - `cache_dir() -> pathlib.Path` (per Global Constraints; created on demand)
  - `safe_id(session_id: str) -> str`: replaces every char outside `[A-Za-z0-9_-]` with `_`.
  - `@dataclass CacheEntry`: `turn_key: str | None = None`, `state: State = field(default_factory=State)`, `error: bool = False`
  - `load(session_id: str) -> CacheEntry`: an empty entry when the file is missing or unparseable.
  - `save(session_id: str, entry: CacheEntry) -> None`: write to a temp file in the same dir, then `os.replace`.
  - `claim_pending(session_id: str, turn_key: str) -> bool`: `False` if `<id>.pending` holds this `turn_key` and is younger than `PENDING_MAX_AGE = 10.0` s. Otherwise writes it and returns `True`.
  - `clear_pending(session_id: str) -> None`
- Produces (`__main__.py`), run as `python3 <dir> <command>`:
  - `render`: reads status line JSON from stdin.
    1. `cur = current_tier(model.id)`. Print nothing if `None`.
    2. `key = last_completed_turn(read_tail_entries(transcript_path))`, falling back to the cached `turn_key` when the tail has none.
    3. If `key` differs from the cached key and `claim_pending` succeeds: spawn the worker (`subprocess.Popen([sys.executable, <dir>, "worker", sid, path, key], start_new_session=True)`, stdio to `DEVNULL`). Then poll `load` every `POLL = 0.05` s for up to `RENDER_WAIT = 0.7` s, until `turn_key == key`. Wait only when this render did the spawning.
    4. Load the entry. Print nothing if it has `error` or no `shown_tier`. Otherwise print `coloured` and `plain` from `render_hint(state, cur, effort_index(effort.level))` on two lines.
    5. Catch every exception: no output, exit 0.
  - `worker SESSION_ID TRANSCRIPT TURN_KEY`:
    - Read all entries and cut after the entry whose `uuid == TURN_KEY` (keep all if not found), then call `build_summary`.
    - `ask(summary, timeout=WORKER_TIMEOUT)` with `WORKER_TIMEOUT = 3.0`.
    - On success: `save(CacheEntry(key, update(prev.state, reading), False))`.
    - On `OpenJevError`: `save(CacheEntry(key, prev.state, True))`.
    - Always `clear_pending`.

- [ ] **Step 1: Write the failing tests.** Test helpers, defined in `test_cli.py`:
  - `render_proc(path, url, model_id="claude-sonnet-5-5", sid="s1") -> subprocess.CompletedProcess` runs `[sys.executable, PKG_DIR, "render"]` with stdin `{"session_id": sid, "transcript_path": path, "model": {"id": model_id}, "effort": {"level": "high"}}`. The env sets `XDG_CACHE_HOME=<tmp>` and `OPENJEV_URL=url`.
  - `render(...) -> str` returns its stdout.
  - `cache_dir_in(tmp) -> Path` = `<tmp>/claude-statusline/model-hint`.
  - `cache_load(sid)` and `seed_cache(sid, turn_key, tier, level, p=.8)` call `cache.load` / `cache.save` with `XDG_CACHE_HOME` patched to `tmp`.
  - Add to `tests/fixtures.py` (Task 8 reuses it): `HAIKU = reading_response({"haiku": .9, "sonnet": .08, "opus": .02}, [.9, .05, .03, .02], .15)`.

```python
def test_first_turn_shows_hint_and_asks_once(self):
    p = write_transcript(tmp, [user("rename x"), assistant_text("done")])
    with StubOpenJev([HAIKU]) as stub:
        out1 = render(p, stub.url); out2 = render(p, stub.url)
    self.assertEqual(out1.splitlines()[1], "⇣ Haiku · low"); self.assertEqual(out1, out2)
    self.assertEqual(len(stub.requests), 1)

def test_mid_turn_keeps_pick_and_new_turn_asks_again(self):
    es = [user("rename x"), assistant_text("done")]; p = write_transcript(tmp, es)
    with StubOpenJev([HAIKU]) as stub:
        render(p, stub.url)
        p = write_transcript(tmp, es + [user("next"), assistant_tool("Bash", {"command": "ls"}, "t")])
        self.assertEqual(render(p, stub.url).splitlines()[1], "⇣ Haiku · low"); self.assertEqual(len(stub.requests), 1)
        p = write_transcript(tmp, es + [user("next"), assistant_text("ok")]); render(p, stub.url)
    self.assertEqual(len(stub.requests), 2)

def test_server_down_hides_hint(self):
    p = write_transcript(tmp, [user("q"), assistant_text("a")])
    res = render_proc(p, closed_port_url())
    self.assertEqual((res.returncode, res.stdout), (0, "")); self.assertTrue(cache_load("s1").error)

def test_unknown_model_and_no_turn_print_nothing(self):
    with StubOpenJev([HAIKU]) as stub:
        self.assertEqual(render(write_transcript(tmp, [user("q"), assistant_text("a")]), stub.url, model_id="qwen3-coder"), "")
        self.assertEqual(render(write_transcript(tmp, [user("q")]), stub.url), "")
    self.assertEqual(len(stub.requests), 0)

def test_corrupt_cache_is_ignored(self):
    cache_dir_in(tmp).mkdir(parents=True); (cache_dir_in(tmp) / "s1.json").write_text("{not json")
    with StubOpenJev([HAIKU]) as stub:
        self.assertEqual(render(write_transcript(tmp, [user("q"), assistant_text("a")]), stub.url).splitlines()[1], "⇣ Haiku · low")

def test_sessions_are_separate_and_ids_sanitized(self):
    p = write_transcript(tmp, [user("q"), assistant_text("a")])
    OPUS = reading_response({"haiku": .02, "sonnet": .08, "opus": .9}, [.02, .03, .9, .05], 2.0)
    with StubOpenJev([HAIKU]) as a, StubOpenJev([OPUS]) as b:
        self.assertEqual(render(p, a.url, sid="s1").splitlines()[1], "⇣ Haiku · low")
        self.assertEqual(render(p, b.url, sid="s2").splitlines()[1], "⇡ Opus · high")
        render(p, a.url, sid="../../evil")
    self.assertTrue({"s1.json", "s2.json", "______evil.json"} <= {f.name for f in cache_dir_in(tmp).iterdir()})
    self.assertFalse((cache_dir_in(tmp).parent.parent / "evil.json").exists())

def test_slow_server_render_returns_quickly(self):
    with StubOpenJev([HAIKU], delay=5.0) as stub:
        t = time.monotonic(); out = render(write_transcript(tmp, [user("q"), assistant_text("a")]), stub.url)
    self.assertLess(time.monotonic() - t, 1.5); self.assertEqual(out, "")

def test_large_transcript_render_is_fast(self):
    es = [x for i in range(2000) for x in (user("p" * 5000), assistant_text("r" * 5000))]  # ~20 MB
    p = write_transcript(tmp, es); seed_cache("s1", turn_key=es[-1]["uuid"], tier="opus", level=2)
    t = time.monotonic(); out = render(p, closed_port_url())
    self.assertLess(time.monotonic() - t, 0.5); self.assertEqual(out.splitlines()[1], "⇡ Opus · high")
```

- [ ] **Step 2: Run `python3 -m unittest tests.test_cli -v`.** Expected: failures, because `__main__.py` is missing (`can't find '__main__' module`).
- [ ] **Step 3: Implement `cache.py` and `__main__.py`** per the interfaces. `__main__.py` puts its own directory on `sys.path[0]` (true by default when run as `python3 <dir>`).
- [ ] **Step 4: Run the full suite** (`python3 -m unittest discover -s tests -t . -v`). Expected: all OK.
- [ ] **Step 5: Commit:** `git add claude/.claude/scripts/model_hint && git commit -m "Add render and worker commands for model hint"`

---

### Task 7: Status line integration

**Files:**
- Modify: `claude/.claude/scripts/context-bar.sh` (top: add `SCRIPT_DIR`; output section, around the `line1=` / `plain_line1=` assignments)
- Test: `claude/.claude/scripts/model_hint/tests/test_context_bar.py`

**Interfaces:**
- Consumes: `python3 <dir> render` (Task 6) prints either nothing or two lines (coloured, plain). `cache.save` and `CacheEntry` are used in the test to pre-seed.

Behaviour:
- `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`.
- `effort_level=$(echo "$input" | jq -r '.effort.level // empty')`. The model label in both `line1` and `plain_line1` becomes `${model}${effort_level:+ · ${effort_level}}`.
- Only when `PROVIDER == claude` and `command -v python3` succeeds: read the two lines from `printf '%s' "$input" | python3 "$SCRIPT_DIR/model_hint" render 2>/dev/null`. When the plain line is non-empty, append `${C_GRAY} │ ${C_RESET}${hint_color}` to `line1` and ` │ ${hint_plain}` to `plain_line1`.
- Nothing else in the script changes.

- [ ] **Step 1: Write the failing tests.** Helpers: `run_bar_proc(extra_env=None, effort="high", last_prompt="q", seed=True) -> CompletedProcess` and `run_bar(...) -> str` (its stdout). They write the transcript `[user(last_prompt), assistant_text("a")]` and run `bash <repo>/claude/.claude/scripts/context-bar.sh` with the mock JSON on stdin. Env: `LC_ALL=C.UTF-8`, `XDG_CACHE_HOME=<tmp>`, `OPENJEV_URL=closed_port_url()`, and `ANTHROPIC_BASE_URL` removed. Mock JSON: `model {id: "claude-sonnet-5-5", display_name: "Sonnet 5.5"}`, `effort {level: "high"}`, `cwd: <tmp>`, `transcript_path`, `session_id`, `context_window {context_window_size: 200000}`. Pre-seed the cache with `turn_key` = the transcript's `end_turn` uuid and `State` showing `opus`/2 at 0.8. `strip()` removes ANSI.

```python
def test_line1_shows_effort_and_hint(self):
    line1 = strip(run_bar().splitlines()[0])
    self.assertIn("Sonnet 5.5 · high", line1); self.assertTrue(line1.endswith("│ ⇡ Opus · high"))

def test_no_hint_on_other_providers(self):
    line1 = strip(run_bar(extra_env={"ANTHROPIC_BASE_URL": "http://localhost:1"}).splitlines()[0])
    self.assertNotIn("⇡", line1); self.assertIn("Sonnet 5.5 · high", line1)

def test_no_effort_field(self):
    self.assertNotIn("Sonnet 5.5 · ", strip(run_bar(effort=None).splitlines()[0]))

def test_last_message_width_includes_hint(self):
    lines = run_bar(last_prompt="m" * 500).splitlines()
    self.assertEqual(len(lines[-1]), len(strip(lines[0])) + 2)

def test_server_down_no_hint_and_exit_zero(self):
    res = run_bar_proc(seed=False)
    self.assertEqual(res.returncode, 0); self.assertNotIn("⇡", strip(res.stdout.splitlines()[0]))
```

- [ ] **Step 2: Run `python3 -m unittest tests.test_context_bar -v`.** Expected: `test_line1_shows_effort_and_hint` and `test_no_hint_on_other_providers` FAIL (no effort label or hint yet). The other three already pass; they guard against regressions, and the width test catches a missed `plain_line1` update.
- [ ] **Step 3: Modify `context-bar.sh`** per Behaviour.
- [ ] **Step 4: Run the full suite.** Expected: all OK. Also run `bash -n claude/.claude/scripts/context-bar.sh` (no output).
- [ ] **Step 5: Commit:** `git add claude/.claude/scripts && git commit -m "Show model and effort hint in context bar"`

---

### Task 8: Replay and prompt-sample tools

**Files:**
- Create: `claude/.claude/scripts/model_hint/replay.py`
- Modify: `claude/.claude/scripts/model_hint/__main__.py` (add `replay` and `prompts` subcommands)
- Test: `claude/.claude/scripts/model_hint/tests/test_replay.py`

**Interfaces:**
- Consumes: `read_entries`, `completed_turn_indices`, `prompt_text`, `Signals`, `format_summary`, `build_summary`, `ask`, `update`, `State`.
- Produces (`replay.py`):
  - `@dataclass TurnResult`: `turn: int`, `prompt: str` (latest prompt at that turn), `raw: tuple[str, int]` (raw argmax tier and `level_for(score)`), `shown: tuple[str, int]`, `seconds: float` (time taken by `ask_fn`).
  - `replay_session(entries: list[dict], ask_fn: Callable[[str], Reading], lean: bool = False, smooth: bool = True) -> list[TurnResult]`: for each completed turn index `i`, `build_summary(entries[:i + 1], lean)`, then `ask_fn`, then `update`.
  - `count_changes(shown: list[tuple[str, int]]) -> int`: the number of positions where the value differs from the previous one.
  - `sample_prompts(history_path: str, n: int, seed: int) -> list[str]`: `display` values from `history.jsonl` that are non-empty and don't start with `/`, sampled with `random.Random(seed)`.
- CLI:
  - `replay TRANSCRIPT [--lean] [--no-stability]` prints `turn<TAB>raw<TAB>shown<TAB>seconds<TAB>prompt[:60]` per turn, then the footer `turns=<n> changes=<k> p50=<s> max=<s>`.
  - `prompts HISTORY [--sample 40] [--seed 1]` prints `tier·effort<TAB>prompt[:80]` per prompt, then the footer `haiku=<n> sonnet=<n> opus=<n> low=<n> medium=<n> high=<n> xhigh=<n>`. Each prompt is summarised as `Signals(1, [text], "", [], 0, 0, 0, 0, 0, "ok")` with `lean=True`.
  - Both print to the terminal only.

- [ ] **Step 1: Write the failing tests.** A fake `ask_fn` returns canned `Reading`s, so no server is needed. Add `write_history(dir, displays: list[str]) -> str` to `tests/fixtures.py`: it writes `<dir>/history.jsonl` with one `{"display": d}` per line. `run_cli(args, url) -> str` runs `[sys.executable, PKG_DIR, *args]` with `OPENJEV_URL=url`.

```python
def test_one_result_per_completed_turn(self):
    es = [user("p1"), assistant_text("a"), user("p2"), assistant_tool("Bash", {"command": "x"}, "t"), tool_result("t"), assistant_text("b")]
    res = replay_session(es, lambda s: rd(.1, .8, .1))
    self.assertEqual([(r.turn, r.prompt) for r in res], [(1, "p1"), (2, "p2")])

def test_count_changes(self):
    self.assertEqual(count_changes([("sonnet", 2), ("sonnet", 2), ("opus", 2), ("opus", 3)]), 2)

def test_stability_reduces_changes(self):
    es = [x for i in range(8) for x in (user(f"p{i}"), assistant_text("a"))]
    flip = itertools.cycle([rd(.1, .5, .4), rd(.1, .4, .5)])
    raw = replay_session(es, lambda s: next(flip), smooth=False)
    stable = replay_session(es, lambda s: next(flip))
    self.assertEqual(count_changes([r.shown for r in raw]), 7)
    self.assertEqual(count_changes([r.shown for r in stable]), 0)

def test_sample_prompts(self):
    h = write_history(tmp, ["/model opus", "", "fix it", "add tests", "why slow"])
    self.assertEqual(sorted(sample_prompts(h, 3, seed=1)), ["add tests", "fix it", "why slow"])
    self.assertEqual(sample_prompts(h, 2, seed=1), sample_prompts(h, 2, seed=1))

def test_cli_replay_footer(self):
    p = write_transcript(tmp, [user("p1"), assistant_text("a"), user("p2"), assistant_text("b")])
    with StubOpenJev([HAIKU]) as stub:
        out = run_cli(["replay", p], stub.url)
    self.assertTrue(out.splitlines()[-1].startswith("turns=2 changes=0"))
```

- [ ] **Step 2: Run `python3 -m unittest tests.test_replay -v`.** Expected: `ModuleNotFoundError: No module named 'replay'`.
- [ ] **Step 3: Implement `replay.py` and the two subcommands.**
- [ ] **Step 4: Run the full suite.** Expected: all OK.
- [ ] **Step 5: Commit:** `git add claude/.claude/scripts/model_hint && git commit -m "Add replay tools for tuning model hint"`

---

### Task 9: Tune on real sessions (needs the Open-Jev server)

**Files:**
- Possibly modify: `claude/.claude/scripts/model_hint/stability.py`, `hint.py` (constants), `openjev.py` (`QUESTIONS` wording), plus any tests whose expected values depend on them
- Create: `docs/superpowers/reports/2026-10-21-model-hint-tuning.md`

- [ ] **Step 1: Check the server.** Run `curl -s -m 2 http://127.0.0.1:8791/health`. Expected: `{"status": "ready", ...}`. If it isn't ready, stop and ask the user to start it.
- [ ] **Step 2: Pick sessions.** Run `find ~/.claude/projects -name '*.jsonl' -size +50k -printf '%s %p\n' | sort -rn | head -6` and label them S1–S6.
- [ ] **Step 3: Replay each session in four variants:** default, `--lean`, `--no-stability`, `--lean --no-stability`, as `python3 claude/.claude/scripts/model_hint replay <path> [flags]`. Record `turns`, `changes`, `p50` and `max` from each footer. Eyeball the per-turn picks in the terminal for sense.
- [ ] **Step 4: Sample prompts.** Run `python3 claude/.claude/scripts/model_hint prompts ~/.claude/history.jsonl --sample 40`. Eyeball the picks, especially the Haiku/Sonnet border and the effort spread, and record the footer counts.
- [ ] **Step 5: Tune if needed.** Change the constants or `QUESTIONS` wording only if the picks look wrong, if the default variant changes more than about once per five turns on average, or if it takes more than about two turns to follow an obvious shift. Re-run Steps 3–4 after each change and update the dependent tests. If the lean summary is clearly better than the rich one, **stop and report to the user** instead of switching (the rich summary is the user's choice).
- [ ] **Step 6: Write the report.** It contains only labels and numbers: a table of S1–S6 × 4 variants (turns, changes), latency p50/max for the default variant, the prompt-sample footer counts, the final constants, and one paragraph on what changed and why. No prompt text, no file paths, no project names.
- [ ] **Step 7: Run the full suite.** Expected: all OK.
- [ ] **Step 8: Commit:** `git add docs/superpowers/reports claude/.claude/scripts/model_hint && git commit -m "Tune model hint on replayed sessions"`

---

### Task 10: New default, README, live check

**Files:**
- Modify (untracked, not committed): `~/.claude/settings.json`
- Modify: `README.md` (new `### Claude Code Model Hint` section right after `### Claude Code Attention Indicators`)

- [ ] **Step 1: Change the default model and effort.**
  1. `cp ~/.claude/settings.json ~/.claude/settings.json.bak-2026-10-21`
  2. `jq '.model = "sonnet" | .effortLevel = "high"' ~/.claude/settings.json > ~/.claude/settings.json.tmp && mv ~/.claude/settings.json.tmp ~/.claude/settings.json`
  3. Verify: `jq -c '{model, effortLevel, modelSettings}' ~/.claude/settings.json`. Expected: `{"model":"sonnet","effortLevel":"high","modelSettings":{"claude-opus-5-5":{"effortLevel":"xhigh"}}}`.
- [ ] **Step 2: Write the README section** (under 25 lines). Cover what the hint shows, the five colours and their meaning, that it needs the local Open-Jev server at `OPENJEV_URL` (default `http://127.0.0.1:8791/v1/systemone`), that it hides on other providers or when the server is down, the cache location, and how to run the tests and `replay`.
- [ ] **Step 3: Live check.** Start `claude` in a scratch directory.
  1. Send an easy prompt ("what does `git status -s` print?"). After the turn ends, with no further input, the hint should appear within about 1 s (expect `⇣ Haiku · …` or `✓ right fit`), and `~/.cache/claude-statusline/model-hint/<session_id>.json` should exist.
  2. Send a hard prompt ("design a lock-free queue in Rust and prove it's linearizable"). After that turn, the hint should step up (amber or red).
  3. Run `/model opus`. The colour should update on the next render.
  - **If the hint doesn't update after a turn while you're idle:** add `"refreshInterval": 5` to `.statusLine` in `~/.claude/settings.json` (back it up as in Step 1), then repeat steps 1 and 2.
- [ ] **Step 4: Commit:** `git add README.md && git commit -m "Document model hint in README"`
