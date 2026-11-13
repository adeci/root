import json
import os
import sys
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

REQUESTS = "/run/mock-llm/requests.jsonl"
RELEASE = "/run/mock-llm/release"
SUGGESTION = {
    "title": "Acme Power statement",
    "tags": ["Utilities"],
    "correspondents": ["Acme Power"],
    "document_types": ["Bill"],
    "dates": ["2025-02-28"],
}


def completion(request):
    """A chat completion calling the request's tool with SUGGESTION."""
    call = {
        "id": "call-0",
        "type": "function",
        "function": {
            "name": request["tools"][0]["function"]["name"],
            "arguments": json.dumps(SUGGESTION),
        },
    }
    message = {"role": "assistant", "content": None, "tool_calls": [call]}
    return {
        "id": "chatcmpl-0",
        "object": "chat.completion",
        "created": 0,
        "model": request["model"],
        "choices": [
            {"index": 0, "finish_reason": "tool_calls", "message": message},
        ],
    }


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers["Content-Length"])
        request = json.loads(self.rfile.read(length))
        entry = {
            "path": self.path,
            "authorization": self.headers["Authorization"],
            "body": request,
        }
        with open(REQUESTS, "a") as log:
            log.write(json.dumps(entry) + "\n")
        while not os.path.exists(RELEASE):
            time.sleep(0.5)
        reply = json.dumps(completion(request)).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(reply)))
        self.end_headers()
        self.wfile.write(reply)


HTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
