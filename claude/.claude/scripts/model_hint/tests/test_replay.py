from __future__ import annotations

import itertools
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from replay import count_changes, replay_session, sample_prompts
from tests.fixtures import (HAIKU, StubOpenJev, assistant_text, assistant_tool, rd, tool_result, user,
                            write_history, write_transcript)

PKG_DIR = str(Path(__file__).resolve().parent.parent)


class ReplayTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = self._tmp.name

    def tearDown(self):
        self._tmp.cleanup()

    def run_cli(self, args, url) -> str:
        env = dict(os.environ, OPENJEV_URL=url)
        return subprocess.run([sys.executable, PKG_DIR, *args], capture_output=True, text=True,
                              env=env, timeout=30).stdout

    def test_one_result_per_completed_turn(self):
        es = [user("p1"), assistant_text("a"), user("p2"), assistant_tool("Bash", {"command": "x"}, "t"),
              tool_result("t"), assistant_text("b")]
        res = replay_session(es, lambda s: rd(.1, .8, .1))
        self.assertEqual([(r.turn, r.prompt) for r in res], [(1, "p1"), (2, "p2")])
        self.assertEqual(res[0].shown, ("sonnet", 1))

    def test_count_changes(self):
        self.assertEqual(count_changes([("sonnet", 2), ("sonnet", 2), ("opus", 2), ("opus", 3)]), 2)
        self.assertEqual(count_changes([]), 0)

    def test_stability_reduces_changes(self):
        es = [x for i in range(8) for x in (user(f"p{i}"), assistant_text("a"))]
        flip = itertools.cycle([rd(.1, .5, .4), rd(.1, .4, .5)])
        raw = replay_session(es, lambda s: next(flip), smooth=False)
        stable = replay_session(es, lambda s: next(flip))
        self.assertEqual(count_changes([r.shown for r in raw]), 7)
        self.assertEqual(count_changes([r.shown for r in stable]), 0)

    def test_sample_prompts(self):
        h = write_history(self.tmp, ["/model opus", "", "fix it", "add tests", "why slow"])
        self.assertEqual(sorted(sample_prompts(h, 3, seed=1)), ["add tests", "fix it", "why slow"])
        self.assertEqual(sample_prompts(h, 2, seed=1), sample_prompts(h, 2, seed=1))
        self.assertEqual(len(sample_prompts(h, 50, seed=1)), 3)

    def test_cli_replay_footer(self):
        p = write_transcript(self.tmp, [user("p1"), assistant_text("a"), user("p2"), assistant_text("b")])
        with StubOpenJev([HAIKU]) as stub:
            out = self.run_cli(["replay", p], stub.url)
        self.assertTrue(out.splitlines()[-1].startswith("turns=2 changes=0 "), out)

    def test_cli_prompts_footer(self):
        h = write_history(self.tmp, ["fix it", "add tests"])
        with StubOpenJev([HAIKU]) as stub:
            out = self.run_cli(["prompts", h, "--sample", "2"], stub.url)
        self.assertEqual(out.splitlines()[-1], "haiku=2 sonnet=0 opus=0 low=2 medium=0 high=0 xhigh=0")


if __name__ == "__main__":
    unittest.main()
