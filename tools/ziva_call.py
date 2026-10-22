"""Call the project's local Ziva MCP; save image responses for visual QA."""
import base64
import json
import pathlib
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]

def call(name, arguments):
    payload = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "tools/call",
                          "params": {"name": name, "arguments": arguments}}).encode()
    request = urllib.request.Request("http://127.0.0.1:7012/api/mcp", payload,
        {"Content-Type": "application/json", "Accept": "application/json, text/event-stream"})
    with urllib.request.urlopen(request, timeout=330) as response:
        raw = response.read().decode()
    messages = [json.loads(line[6:]) for line in raw.splitlines() if line.startswith("data: ")]
    result = messages[-1] if messages else json.loads(raw)
    for index, item in enumerate(result.get("result", {}).get("content", [])):
        if item.get("type") == "image":
            output = ROOT / "artifacts" / (name + "_" + str(index) + ".png")
            output.parent.mkdir(exist_ok=True)
            output.write_bytes(base64.b64decode(item.pop("data")))
            item["saved_image"] = str(output)
    return result

if __name__ == "__main__":
    args = json.loads(pathlib.Path(sys.argv[2]).read_text(encoding="utf-8-sig")) if len(sys.argv) > 2 else {"reasoning": "Inspect the connected project before implementing the requested game polish."}
    print(json.dumps(call(sys.argv[1], args), ensure_ascii=True))
