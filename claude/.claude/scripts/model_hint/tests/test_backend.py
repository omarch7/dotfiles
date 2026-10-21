from __future__ import annotations

import os
import unittest
from unittest import mock

from openjev import OPENJEV_THRESHOLDS, TYPESAFE_THRESHOLDS, TYPESAFE_URL, OpenJevError, ask, backend
from stability import State, update
from tests.fixtures import StubOpenJev, closed_port_url, reading_response

R = reading_response({"haiku": .1, "sonnet": .7, "opus": .2}, [.1, .2, .6, .1], 2.0)
CLEAN = {k: "" for k in ("JEV_BACKEND", "JEV_MODEL", "JEV_EFFORT_THRESHOLDS", "OPENJEV_URL",
                         "TYPESAFE_URL", "TYPESAFE_API_KEY")}


class BackendTest(unittest.TestCase):
    def setUp(self):
        patcher = mock.patch.dict(os.environ, CLEAN)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_default_is_local_open_jev(self):
        b = backend()
        self.assertEqual((b.name, b.model, b.api_key, b.effort_thresholds),
                         ("open-jev", "open-jev", None, OPENJEV_THRESHOLDS))

    def test_typesafe_defaults(self):
        os.environ.update(JEV_BACKEND="TypeSafe", TYPESAFE_API_KEY="k")
        b = backend()
        self.assertEqual((b.name, b.url, b.model, b.api_key, b.effort_thresholds),
                         ("typesafe", TYPESAFE_URL, "jev-latest", "k", TYPESAFE_THRESHOLDS))

    def test_typesafe_sends_bearer_and_model(self):
        os.environ.update(JEV_BACKEND="typesafe", JEV_MODEL="jev-1.13.0", TYPESAFE_API_KEY="secret")
        with StubOpenJev([R]) as stub:
            os.environ["TYPESAFE_URL"] = stub.url
            reading = ask("S")
        self.assertEqual(stub.requests[0]["model"], "jev-1.13.0")
        self.assertEqual(stub.headers[0].get("Authorization"), "Bearer secret")
        self.assertEqual(reading.effort_thresholds, TYPESAFE_THRESHOLDS)

    def test_open_jev_sends_no_auth(self):
        with StubOpenJev([R]) as stub:
            ask("S", url=stub.url)
        self.assertNotIn("Authorization", stub.headers[0])
        self.assertEqual(stub.requests[0]["model"], "open-jev")

    def test_typesafe_without_key_fails_before_network(self):
        os.environ.update(JEV_BACKEND="typesafe", TYPESAFE_URL=closed_port_url())
        with self.assertRaisesRegex(OpenJevError, "TYPESAFE_API_KEY"):
            ask("S")

    def test_unknown_backend_raises(self):
        os.environ["JEV_BACKEND"] = "gpt"
        with self.assertRaises(OpenJevError):
            backend()

    def test_arguments_beat_environment(self):
        os.environ.update(JEV_BACKEND="typesafe", JEV_MODEL="jev-preview")
        b = backend("open-jev", "my-ckpt")
        self.assertEqual((b.name, b.model), ("open-jev", "my-ckpt"))

    def test_threshold_override_and_bad_values(self):
        os.environ["JEV_EFFORT_THRESHOLDS"] = "0.7,1.2,1.9"
        self.assertEqual(backend().effort_thresholds, (0.7, 1.2, 1.9))
        for bad in ("1,2", "a,b,c", "2,1,3"):
            os.environ["JEV_EFFORT_THRESHOLDS"] = bad
            self.assertEqual(backend().effort_thresholds, OPENJEV_THRESHOLDS)

    def test_thresholds_follow_the_reading(self):
        # Score 2.0: past every Open-Jev boundary (xhigh) but only "high" on TypeSafe's scale.
        with StubOpenJev([R]) as stub:
            local = ask("S", url=stub.url)
            os.environ.update(JEV_BACKEND="typesafe", TYPESAFE_API_KEY="k")
            hosted = ask("S", url=stub.url)
        self.assertEqual(update(State(), local).shown_effort, 3)
        self.assertEqual(update(State(), hosted).shown_effort, 2)


if __name__ == "__main__":
    unittest.main()
