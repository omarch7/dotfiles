from __future__ import annotations

import json
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import cache
from stability import State
from tests.fixtures import assistant_text, closed_port_url, user, write_transcript

CONTEXT_BAR = str(Path(__file__).resolve().parents[2] / "context-bar.sh")
ANSI = re.compile(r"\033\[[0-9;]*m")


def strip(text: str) -> str:
    return ANSI.sub("", text)


class ContextBarTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = self._tmp.name

    def tearDown(self):
        self._tmp.cleanup()

    def run_bar_proc(self, extra_env=None, effort="high", last_prompt="q", seed=True):
        end = assistant_text("a")
        path = write_transcript(self.tmp, [user(last_prompt), end])
        if seed:
            probs = {"haiku": .1, "sonnet": .1, "opus": .8}
            with mock.patch.dict(os.environ, {"XDG_CACHE_HOME": self.tmp}):
                cache.save("bar", cache.CacheEntry(end["uuid"], State(probs, 2.0, "opus", 2), False))
        status = {"session_id": "bar", "transcript_path": path, "cwd": self.tmp,
                  "model": {"id": "claude-sonnet-5-5", "display_name": "Sonnet 5.5"},
                  "context_window": {"context_window_size": 200000}}
        if effort:
            status["effort"] = {"level": effort}
        env = {k: v for k, v in os.environ.items() if k != "ANTHROPIC_BASE_URL"}
        env.update(LC_ALL="C.UTF-8", XDG_CACHE_HOME=self.tmp, OPENJEV_URL=closed_port_url())
        env.update(extra_env or {})
        return subprocess.run(["bash", CONTEXT_BAR], input=json.dumps(status), capture_output=True,
                              text=True, env=env, timeout=30)

    def run_bar(self, **kwargs) -> str:
        return self.run_bar_proc(**kwargs).stdout

    def test_line1_shows_effort_and_hint(self):
        line1 = strip(self.run_bar().splitlines()[0])
        self.assertIn("Sonnet 5.5 · high", line1)
        self.assertTrue(line1.endswith("│ ⇡ Opus · high"), line1)

    def test_no_hint_on_other_providers(self):
        line1 = strip(self.run_bar(extra_env={"ANTHROPIC_BASE_URL": "http://localhost:1"}).splitlines()[0])
        self.assertNotIn("⇡", line1)
        self.assertIn("Sonnet 5.5 · high", line1)

    def test_no_effort_field(self):
        self.assertNotIn("Sonnet 5.5 · ", strip(self.run_bar(effort=None).splitlines()[0]))

    def test_last_message_width_includes_hint(self):
        lines = self.run_bar(last_prompt="m" * 500).splitlines()
        self.assertEqual(len(lines[-1]), len(strip(lines[0])) + 2)

    def test_server_down_no_hint_and_exit_zero(self):
        res = self.run_bar_proc(seed=False)
        self.assertEqual(res.returncode, 0)
        self.assertNotIn("⇡", strip(res.stdout.splitlines()[0]))


if __name__ == "__main__":
    unittest.main()
