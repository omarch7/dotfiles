from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

import cache
from stability import State
from tests.fixtures import (HAIKU, StubOpenJev, assistant_text, assistant_tool, closed_port_url,
                            reading_response, user, write_transcript)

PKG_DIR = str(Path(__file__).resolve().parent.parent)


class CliTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = self._tmp.name

    def tearDown(self):
        self._tmp.cleanup()

    def render_proc(self, path, url, model_id="claude-sonnet-5-5", sid="s1"):
        status = {"session_id": sid, "transcript_path": path, "model": {"id": model_id},
                  "effort": {"level": "high"}}
        env = dict(os.environ, XDG_CACHE_HOME=self.tmp, OPENJEV_URL=url)
        return subprocess.run([sys.executable, PKG_DIR, "render"], input=json.dumps(status),
                              capture_output=True, text=True, env=env, timeout=30)

    def render(self, *args, **kwargs) -> str:
        return self.render_proc(*args, **kwargs).stdout

    def cache_dir_in(self) -> Path:
        return Path(self.tmp) / "claude-statusline" / "model-hint"

    def cache_load(self, sid):
        with mock.patch.dict(os.environ, {"XDG_CACHE_HOME": self.tmp}):
            return cache.load(sid)

    def seed_cache(self, sid, turn_key, tier, level, p=.8):
        rest = (1 - p) / 2
        probs = {t: (p if t == tier else rest) for t in ("haiku", "sonnet", "opus")}
        with mock.patch.dict(os.environ, {"XDG_CACHE_HOME": self.tmp}):
            cache.save(sid, cache.CacheEntry(turn_key, State(probs, float(level), tier, level), False))

    def test_first_turn_shows_hint_and_asks_once(self):
        p = write_transcript(self.tmp, [user("rename x"), assistant_text("done")])
        with StubOpenJev([HAIKU]) as stub:
            out1 = self.render(p, stub.url)
            out2 = self.render(p, stub.url)
        self.assertEqual(out1.splitlines()[1], "⇣ Haiku · low")
        self.assertEqual(out1, out2)
        self.assertEqual(len(stub.requests), 1)

    def test_mid_turn_keeps_pick_and_new_turn_asks_again(self):
        es = [user("rename x"), assistant_text("done")]
        p = write_transcript(self.tmp, es)
        with StubOpenJev([HAIKU]) as stub:
            self.render(p, stub.url)
            p = write_transcript(self.tmp, es + [user("next"), assistant_tool("Bash", {"command": "ls"}, "t")])
            self.assertEqual(self.render(p, stub.url).splitlines()[1], "⇣ Haiku · low")
            self.assertEqual(len(stub.requests), 1)
            p = write_transcript(self.tmp, es + [user("next"), assistant_text("ok")])
            self.render(p, stub.url)
        self.assertEqual(len(stub.requests), 2)

    def test_server_down_hides_hint(self):
        p = write_transcript(self.tmp, [user("q"), assistant_text("a")])
        res = self.render_proc(p, closed_port_url())
        self.assertEqual((res.returncode, res.stdout), (0, ""))
        self.assertTrue(self.cache_load("s1").error)

    def test_unknown_model_and_no_turn_print_nothing(self):
        with StubOpenJev([HAIKU]) as stub:
            p = write_transcript(self.tmp, [user("q"), assistant_text("a")])
            self.assertEqual(self.render(p, stub.url, model_id="qwen3-coder"), "")
            self.assertEqual(self.render(write_transcript(self.tmp, [user("q")]), stub.url), "")
        self.assertEqual(len(stub.requests), 0)

    def test_corrupt_cache_is_ignored(self):
        self.cache_dir_in().mkdir(parents=True)
        (self.cache_dir_in() / "s1.json").write_text("{not json")
        with StubOpenJev([HAIKU]) as stub:
            p = write_transcript(self.tmp, [user("q"), assistant_text("a")])
            self.assertEqual(self.render(p, stub.url).splitlines()[1], "⇣ Haiku · low")

    def test_sessions_are_separate_and_ids_sanitized(self):
        p = write_transcript(self.tmp, [user("q"), assistant_text("a")])
        opus = reading_response({"haiku": .02, "sonnet": .08, "opus": .9}, [.02, .03, .9, .05], 1.2)
        with StubOpenJev([HAIKU]) as a, StubOpenJev([opus]) as b:
            self.assertEqual(self.render(p, a.url, sid="s1").splitlines()[1], "⇣ Haiku · low")
            self.assertEqual(self.render(p, b.url, sid="s2").splitlines()[1], "⇡ Opus · high")
            self.render(p, a.url, sid="../../evil")
        names = {f.name for f in self.cache_dir_in().iterdir()}
        self.assertTrue({"s1.json", "s2.json", "______evil.json"} <= names)
        self.assertFalse((self.cache_dir_in().parent.parent / "evil.json").exists())

    def test_slow_server_render_returns_quickly(self):
        with StubOpenJev([HAIKU], delay=5.0) as stub:
            p = write_transcript(self.tmp, [user("q"), assistant_text("a")])
            t = time.monotonic()
            out = self.render(p, stub.url)
            elapsed = time.monotonic() - t
        self.assertLess(elapsed, 1.5)
        self.assertEqual(out, "")

    def test_large_transcript_render_is_fast(self):
        es = [x for _ in range(2000) for x in (user("p" * 5000), assistant_text("r" * 5000))]  # ~20 MB
        p = write_transcript(self.tmp, es)
        self.seed_cache("s1", turn_key=es[-1]["uuid"], tier="opus", level=2)
        t = time.monotonic()
        out = self.render(p, closed_port_url())
        self.assertLess(time.monotonic() - t, 0.5)
        self.assertEqual(out.splitlines()[1], "⇡ Opus · high")

    def test_worker_crash_is_cached_as_error(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("model_hint_main", str(Path(PKG_DIR) / "__main__.py"))
        main = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(main)
        end = assistant_text("a")
        p = write_transcript(self.tmp, [user("q"), end])
        with mock.patch.dict(os.environ, {"XDG_CACHE_HOME": self.tmp}), \
                mock.patch.object(main, "build_summary", side_effect=RuntimeError("boom")):
            cache.claim_pending("w1", end["uuid"])
            main.cmd_worker("w1", p, end["uuid"])
            entry = cache.load("w1")
        self.assertEqual((entry.turn_key, entry.error), (end["uuid"], True))
        self.assertFalse((self.cache_dir_in() / "w1.pending").exists())


if __name__ == "__main__":
    unittest.main()
