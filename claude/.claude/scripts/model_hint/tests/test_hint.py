from __future__ import annotations

import unittest

from hint import current_tier, effort_index, render_hint
from stability import State

GREEN = "\033[38;2;152;195;121m"
AMBER = "\033[38;2;229;192;123m"
RED = "\033[38;2;224;108;117m"
BLUE_DIM = "\033[2;38;2;97;175;239m"
GRAY = "\033[38;5;245m"
RESET = "\033[0m"


def S(tier: str, lvl: int, p: float = .8) -> State:
    rest = (1 - p) / 2
    probs = {t: (p if t == tier else rest) for t in ("haiku", "sonnet", "opus")}
    return State(probs, float(lvl), tier, lvl)


class HintTest(unittest.TestCase):
    def test_states(self):
        cases = [((S("sonnet", 2), "sonnet", 2), "✓ right fit", GREEN),
                 ((S("sonnet", 2), "sonnet", 0), "⇡ Sonnet · high", AMBER),
                 ((S("opus", 2), "haiku", 1), "⇡⇡ Opus · high", RED),
                 ((S("sonnet", 3), "sonnet", 0), "⇡⇡ Sonnet · xhigh", RED),
                 ((S("haiku", 0), "opus", 2), "⇣ Haiku · low", BLUE_DIM),
                 ((S("sonnet", 3), "opus", 1), "⇡ Sonnet · xhigh", AMBER),
                 ((S("opus", 3), "opus", 4), "⇣ Opus · xhigh", BLUE_DIM),
                 ((S("opus", 2), "sonnet", None), "⇡ Opus", AMBER),
                 ((S("sonnet", 0), "sonnet", None), "✓ right fit", GREEN),
                 ((S("opus", 2, p=.40), "sonnet", 2), "⇡ Opus · high", GRAY),
                 ((S("opus", 2, p=.50), "sonnet", 2), "⇡ Opus · high", AMBER)]
        for args, text, colour in cases:
            with self.subTest(text=text, args=args[1:]):
                coloured, plain = render_hint(*args)
                self.assertEqual(plain, text)
                self.assertEqual(coloured, colour + text + RESET)
                self.assertNotIn("\033", plain)

    def test_parsers(self):
        self.assertEqual(current_tier("claude-opus-5-5"), "opus")
        self.assertEqual(current_tier("eu.anthropic.claude-sonnet-4-6"), "sonnet")
        self.assertEqual(current_tier("claude-haiku-5-5"), "haiku")
        self.assertIsNone(current_tier("qwen3-coder"))
        self.assertIsNone(current_tier(None))
        self.assertEqual(effort_index("max"), 4)
        self.assertEqual(effort_index("xhigh"), 3)
        self.assertIsNone(effort_index(None))
        self.assertIsNone(effort_index("turbo"))


if __name__ == "__main__":
    unittest.main()
