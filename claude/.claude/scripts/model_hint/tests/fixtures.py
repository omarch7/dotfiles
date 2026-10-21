"""Synthetic transcript builders and test helpers. No real session content."""
from __future__ import annotations

import itertools
import json
import os
import socket
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

_ids = itertools.count(1)


def _uuid() -> str:
    return f"00000000-0000-0000-0000-{next(_ids):012d}"


def user(text: str, meta: bool = False, sidechain: bool = False) -> dict:
    return {"type": "user", "uuid": _uuid(), "isSidechain": sidechain, "isMeta": meta or None,
            "message": {"role": "user", "content": text}}


def assistant_text(text: str, stop: str = "end_turn", sidechain: bool = False,
                   model: str = "claude-sonnet-5-5", cwd: str = "/repo", msg_id: str | None = None) -> dict:
    entry = {"type": "assistant", "uuid": _uuid(), "isSidechain": sidechain, "cwd": cwd,
             "message": {"role": "assistant", "model": model, "stop_reason": stop,
                         "content": [{"type": "text", "text": text}]}}
    if msg_id:
        entry["message"]["id"] = msg_id
    return entry


def assistant_thinking(msg_id: str, stop: str = "end_turn", cwd: str = "/repo") -> dict:
    """Claude Code writes each content block of one reply as its own line, sharing message.id."""
    return {"type": "assistant", "uuid": _uuid(), "isSidechain": False, "cwd": cwd,
            "message": {"id": msg_id, "role": "assistant", "model": "claude-sonnet-5-5", "stop_reason": stop,
                        "content": [{"type": "thinking", "thinking": "…", "signature": "sig"}]}}


def assistant_tool(name: str, input: dict, tool_id: str, cwd: str = "/repo") -> dict:
    return {"type": "assistant", "uuid": _uuid(), "isSidechain": False, "cwd": cwd,
            "message": {"role": "assistant", "model": "claude-sonnet-5-5", "stop_reason": "tool_use",
                        "content": [{"type": "tool_use", "id": tool_id, "name": name, "input": input}]}}


def tool_result(tool_id: str, content: str = "ok", is_error: bool = False) -> dict:
    return {"type": "user", "uuid": _uuid(), "isSidechain": False,
            "message": {"role": "user", "content": [
                {"type": "tool_result", "tool_use_id": tool_id, "content": content, "is_error": is_error}]}}


def write_transcript(dir: str, entries: list[dict], trailing_partial: bool = False) -> str:
    path = os.path.join(dir, "transcript.jsonl")
    with open(path, "w", encoding="utf-8") as f:
        for e in entries:
            f.write(json.dumps(e) + "\n")
        if trailing_partial:
            f.write('{"type":"assist')
    return path


def reading_response(model: dict, effort_probs: list, score: float) -> dict:
    """A response body shaped like the real /v1/systemone answer."""
    choice = max(model, key=model.get)
    return {
        "answers": {
            "model": {"type": "choice", "choice": choice, "probabilities": dict(model),
                      "confidence": max(model.values())},
            "effort": {"type": "score", "score": score,
                       "probabilities": {str(i): p for i, p in enumerate(effort_probs)},
                       "confidence": max(effort_probs),
                       "legend": {str(i): f"level {i}" for i in range(len(effort_probs))}},
        },
        "model": "Qwen/Qwen3.5-9B",
        "usage": {"input_tokens": 100, "output_tokens": 0},
        "metadata": {"method": "lora_decision_head", "inference_seconds": 0.1},
    }


class StubOpenJev:
    """A tiny local HTTP server standing in for the Open-Jev endpoint."""

    def __init__(self, responses, delay: float = 0.0, status: int = 200):
        self.responses, self.delay, self.status = responses, delay, status
        self.requests: list = []
        self._served = 0

    def _next(self, body):
        if callable(self.responses):
            return self.responses(body)
        response = self.responses[min(self._served, len(self.responses) - 1)]
        self._served += 1
        return response

    def __enter__(self):
        stub = self

        class Handler(BaseHTTPRequestHandler):
            def do_POST(self):
                length = int(self.headers.get("Content-Length") or 0)
                body = json.loads(self.rfile.read(length) or b"null")
                stub.requests.append(body)
                if stub.delay:
                    time.sleep(stub.delay)
                payload = json.dumps(stub._next(body)).encode()
                try:
                    self.send_response(stub.status)
                    self.send_header("Content-Type", "application/json")
                    self.send_header("Content-Length", str(len(payload)))
                    self.end_headers()
                    self.wfile.write(payload)
                except OSError:
                    pass

            def log_message(self, *args):
                pass

        self._server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self._server.daemon_threads = True
        self._server.block_on_close = False
        threading.Thread(target=self._server.serve_forever, daemon=True).start()
        self.url = f"http://127.0.0.1:{self._server.server_address[1]}/v1/systemone"
        return self

    def __exit__(self, *exc):
        self._server.shutdown()
        self._server.server_close()
        return False


def closed_port_url() -> str:
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    port = s.getsockname()[1]
    s.close()
    return f"http://127.0.0.1:{port}/v1/systemone"


def rd(h: float, s: float, o: float, eff=(.1, .7, .1, .1), score: float = 1.0):
    """A Reading with the given tier probabilities and effort distribution."""
    from openjev import Reading
    return Reading({"haiku": h, "sonnet": s, "opus": o}, list(eff), score)


HAIKU = reading_response({"haiku": .9, "sonnet": .08, "opus": .02}, [.9, .05, .03, .02], .15)


def write_history(dir: str, displays: list[str]) -> str:
    path = os.path.join(dir, "history.jsonl")
    with open(path, "w", encoding="utf-8") as f:
        for d in displays:
            f.write(json.dumps({"display": d, "pastedContents": {}, "project": "/repo",
                                "sessionId": "s", "timestamp": 0}) + "\n")
    return path
