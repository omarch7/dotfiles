from __future__ import annotations

import os
import time
import unittest
from unittest import mock

from openjev import OpenJevError, Reading, ask
from tests.fixtures import StubOpenJev, closed_port_url, reading_response

R = reading_response({"haiku": .1, "sonnet": .7, "opus": .2}, [.1, .2, .6, .1], 1.7)


class OpenJevTest(unittest.TestCase):
    def test_request_shape_and_parse(self):
        with StubOpenJev([R]) as stub:
            r = ask("S", url=stub.url)
        body = stub.requests[0]
        self.assertEqual(body["state"], "S")
        self.assertEqual(set(body["questions"]), {"model", "effort"})
        self.assertEqual(body["questions"]["model"]["type"], "choice")
        self.assertEqual(body["questions"]["effort"]["type"], "score")
        self.assertEqual(set(body["questions"]["model"]["criteria"]), {"haiku", "sonnet", "opus"})
        self.assertEqual(len(body["questions"]["effort"]["criteria"]), 4)
        self.assertEqual(r, Reading({"haiku": .1, "sonnet": .7, "opus": .2}, [.1, .2, .6, .1], 1.7))

    def test_connection_refused_is_fast_error(self):
        t = time.monotonic()
        with self.assertRaises(OpenJevError):
            ask("S", url=closed_port_url())
        self.assertLess(time.monotonic() - t, 1.0)

    def test_timeout_raises(self):
        with StubOpenJev([R], delay=2.0) as stub, self.assertRaises(OpenJevError):
            ask("S", url=stub.url, timeout=0.3)

    def test_http_422_and_bad_shape_raise(self):
        with StubOpenJev([{"error": "too long"}], status=422) as stub, self.assertRaises(OpenJevError):
            ask("S", url=stub.url)
        with StubOpenJev([{"answers": {}}]) as stub, self.assertRaises(OpenJevError):
            ask("S", url=stub.url)

    def test_env_url_used(self):
        with StubOpenJev([R]) as stub, mock.patch.dict(os.environ, {"OPENJEV_URL": stub.url}):
            ask("S")
        self.assertEqual(len(stub.requests), 1)


if __name__ == "__main__":
    unittest.main()
