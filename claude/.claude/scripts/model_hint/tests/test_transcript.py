from __future__ import annotations

import tempfile
import unittest

from tests.fixtures import (assistant_text, assistant_thinking, assistant_tool, tool_result, user,
                            write_transcript)
from transcript import (completed_turn_indices, last_completed_turn, prompt_text, read_entries,
                        read_tail_entries)


class TranscriptTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = self._tmp.name

    def tearDown(self):
        self._tmp.cleanup()

    def test_skips_malformed_and_partial_lines(self):
        p = write_transcript(self.tmp, [user("a"), assistant_text("b")], trailing_partial=True)
        self.assertEqual(len(read_entries(p)), 2)

    def test_tail_drops_leading_partial_line(self):
        p = write_transcript(self.tmp, [user("x" * 1000) for _ in range(400)] + [assistant_text("done")])
        tail = read_tail_entries(p, max_bytes=8192)
        self.assertEqual(tail[-1]["message"]["content"][0]["text"], "done")
        self.assertLess(len(tail), 10)

    def test_prompt_text_filters(self):
        self.assertEqual(prompt_text(user("fix the bug")), "fix the bug")
        self.assertIsNone(prompt_text(user("<command-name>/model</command-name>\n<command-args>opus</command-args>")))
        self.assertEqual(
            prompt_text(user("<command-name>/superpowers:brainstorming</command-name><command-args>add a hook</command-args>")),
            "/superpowers:brainstorming add a hook")
        self.assertIsNone(prompt_text(user("<local-command-stdout>Set model</local-command-stdout>")))
        self.assertIsNone(prompt_text(user("Base directory for this skill", meta=True)))
        self.assertIsNone(prompt_text(user("hi", sidechain=True)))
        self.assertIsNone(prompt_text(tool_result("t1")))
        self.assertIsNone(prompt_text(user("[Request interrupted by user]")))

    def test_last_completed_turn(self):
        a = assistant_text("one")
        t = assistant_tool("Bash", {"command": "ls"}, "t1")
        self.assertEqual(last_completed_turn([user("q"), a, user("q2"), t]), a["uuid"])
        self.assertIsNone(last_completed_turn([user("q"), t]))
        self.assertEqual(last_completed_turn([a, assistant_text("sub", sidechain=True)]), a["uuid"])
        self.assertEqual(completed_turn_indices([user("q"), a, user("q2"), t]), [1])

    def test_split_reply_counts_as_one_turn(self):
        es = [user("q"), assistant_thinking("m1"), assistant_text("part one", msg_id="m1"),
              assistant_text("part two", msg_id="m1"), user("q2"), assistant_thinking("m2")]
        self.assertEqual(completed_turn_indices(es), [3])
        self.assertEqual(last_completed_turn(es), es[3]["uuid"])

    def test_injected_shell_and_compaction_messages_are_not_prompts(self):
        self.assertIsNone(prompt_text(user("<bash-input>ls -la</bash-input>")))
        self.assertIsNone(prompt_text(user("<bash-stdout>warning: unused</bash-stdout><bash-stderr></bash-stderr>")))
        compact = user("This session is being continued from a previous conversation...")
        compact["isCompactSummary"] = True
        self.assertIsNone(prompt_text(compact))
        hidden = user("shown only in the transcript view")
        hidden["isVisibleInTranscriptOnly"] = True
        self.assertIsNone(prompt_text(hidden))

    def test_malformed_entries_do_not_raise(self):
        self.assertIsNone(prompt_text({"type": "user", "message": "not a dict"}))
        self.assertEqual(completed_turn_indices([{"type": "assistant", "message": "x"},
                                                 {"type": "assistant", "message": {"content": "x",
                                                                                   "stop_reason": "end_turn"}}]), [])


if __name__ == "__main__":
    unittest.main()
