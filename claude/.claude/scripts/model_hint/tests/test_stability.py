from __future__ import annotations

import unittest

from stability import State, confidence, update
from tests.fixtures import rd


def seeded(h, s, o, tier, level=1, se=1.0):
    return State({"haiku": h, "sonnet": s, "opus": o}, se, tier, level)


class StabilityTest(unittest.TestCase):
    def test_first_reading_sets_pick(self):
        st = update(State(), rd(.1, .8, .1, score=0.9))
        self.assertEqual((st.shown_tier, st.shown_effort), ("sonnet", 1))

    def test_single_odd_turn_does_not_flip_and_sustained_shift_does(self):
        st = update(seeded(.2, .6, .2, "sonnet"), rd(.02, .18, .80))
        self.assertEqual(st.shown_tier, "sonnet")
        self.assertEqual(update(st, rd(.02, .18, .80)).shown_tier, "opus")

    def test_close_call_keeps_shown(self):
        self.assertEqual(update(seeded(.1, .5, .4, "sonnet"), rd(.1, .45, .45)).shown_tier, "sonnet")

    def test_fast_lane_up_only(self):
        up = update(seeded(.1, .8, .1, "sonnet"), rd(.02, .08, .90))
        self.assertEqual(up.shown_tier, "opus")
        self.assertAlmostEqual(up.smoothed_model["opus"], .90)
        self.assertEqual(update(seeded(.05, .15, .80, "opus"), rd(.90, .08, .02)).shown_tier, "opus")

    def test_effort_dead_band_and_fast_lane(self):
        st = seeded(.1, .8, .1, "sonnet", level=1, se=1.0)
        for _ in range(10):
            st = update(st, rd(.1, .8, .1, eff=(.1, .4, .4, .1), score=1.18))
        self.assertEqual(st.shown_effort, 1)
        st = seeded(.1, .8, .1, "sonnet", level=1, se=1.0)
        st = update(st, rd(.1, .8, .1, eff=(.1, .3, .4, .2), score=1.35))
        self.assertEqual(st.shown_effort, 1)
        st = update(st, rd(.1, .8, .1, eff=(.1, .3, .4, .2), score=1.35))
        self.assertEqual(st.shown_effort, 2)
        fast = update(seeded(.1, .8, .1, "sonnet", level=1), rd(.1, .8, .1, eff=(.02, .03, .9, .05), score=2.0))
        self.assertEqual(fast.shown_effort, 2)

    def test_effort_steps_down_past_band(self):
        st = seeded(.1, .8, .1, "sonnet", level=2, se=1.25)
        st = update(st, rd(.1, .8, .1, eff=(.6, .3, .05, .05), score=0.7))
        self.assertEqual(st.shown_effort, 2)
        st = update(st, rd(.1, .8, .1, eff=(.6, .3, .05, .05), score=0.7))
        self.assertEqual(st.shown_effort, 1)

    def test_smooth_false_follows_raw(self):
        st = update(seeded(.1, .8, .1, "sonnet"), rd(.6, .3, .1, score=0.2), smooth=False)
        self.assertEqual((st.shown_tier, st.shown_effort), ("haiku", 0))

    def test_roundtrip_and_bad_input(self):
        st = seeded(.1, .8, .1, "sonnet")
        self.assertEqual(State.from_dict(st.to_dict()), st)
        self.assertEqual(State.from_dict({"junk": 1}), State())
        self.assertEqual(State.from_dict(None), State())
        self.assertEqual(State.from_dict({"shown_tier": "gpt", "shown_effort": 1,
                                          "smoothed_model": {"gpt": 1.0}, "smoothed_effort": 1.0}), State())
        self.assertAlmostEqual(confidence(st), .8)
        self.assertEqual(confidence(State()), 0.0)


if __name__ == "__main__":
    unittest.main()
