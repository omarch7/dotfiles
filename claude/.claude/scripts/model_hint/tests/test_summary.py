from __future__ import annotations

import unittest
from unittest import mock

from summary import MAX_STATE_CHARS, Signals, collect_signals, format_summary
from tests.fixtures import assistant_text, assistant_tool, tool_result, user


class SummaryTest(unittest.TestCase):
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
        fail = [user("p"), assistant_tool("Bash", {"command": "make"}, "b"), tool_result("b", is_error=True),
                assistant_text("It fails.")]
        self.assertEqual(collect_signals(fail).ended, "failing")
        self.assertEqual(collect_signals([user("p"), assistant_text("Done.")]).ended, "ok")
        ask = [user("p"), assistant_tool("AskUserQuestion", {}, "q"), tool_result("q"), assistant_text("Noted.")]
        self.assertEqual(collect_signals(ask).ended, "question")

    def test_recent_window_and_prompts(self):
        es = [user("p1"), assistant_tool("Edit", {"file_path": "/repo/old.py"}, "o"), tool_result("o"),
              assistant_text("x")]
        for i in range(2, 6):
            es += [user(f"p{i}"), assistant_text("y")]
        s = collect_signals(es)
        self.assertEqual((s.prompt_count, s.prompts, s.files_edited), (5, ["p3", "p4", "p5"], 0))

    def test_summary_lines_and_lean(self):
        s = Signals(5, ["p3", "p4", "p5"], "Found a race.", ["a.py"], 1, 2, 1, 1, 1, "failing")
        out = format_summary(s)
        for line in ("Prompts in this session: 5", "Latest prompt: p5",
                     "Assistant's latest reply (trimmed): Found a race.",
                     "Files touched recently: a.py", "How the last turn ended: still failing"):
            self.assertIn(line, out)
        lean = format_summary(s, lean=True)
        for gone in ("Assistant's latest reply", "Files touched", "How the last turn ended"):
            self.assertNotIn(gone, lean)

    def test_budget_with_huge_prompt(self):
        s = Signals(2, ["old " * 3000, "ünïcode\n" * 5000], "r" * 5000, [f"f{i}.py" for i in range(15)],
                    15, 0, 0, 1, 0, "ok")
        out = format_summary(s)
        self.assertLessEqual(len(out), MAX_STATE_CHARS)
        self.assertIn("Latest prompt: ünïcode ünïcode", out)

    def test_trim_drops_earlier_prompts_first(self):
        s = Signals(3, ["e" * 600, "e" * 600, "latest"], "r" * 1000, ["a.py"], 1, 0, 0, 1, 0, "ok")
        with mock.patch("summary.MAX_STATE_CHARS", len(format_summary(s)) - 100):
            out = format_summary(s)
        self.assertIn("Assistant's latest reply", out)
        self.assertIn("Files touched", out)
        self.assertIn("Latest prompt: latest", out)
        self.assertEqual(out.count("\n- "), 1)


if __name__ == "__main__":
    unittest.main()
