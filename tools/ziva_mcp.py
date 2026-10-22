"""Call the local Ziva MCP bridge and keep reviewable responses in artifacts."""
import json
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
ENDPOINT = "http://127.0.0.1:7012/api/mcp"

def call(name, arguments):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "tools/call",
                       "params": {"name": name, "arguments": arguments}}).encode()
    request = urllib.request.Request(ENDPOINT, data=body, headers={
        "Content-Type": "application/json", "Accept": "application/json, text/event-stream"})
    with urllib.request.urlopen(request, timeout=330) as response:
        raw = response.read().decode()
    if any(line.startswith("data: ") for line in raw.splitlines()):
        messages = [json.loads(line[6:]) for line in raw.splitlines() if line.startswith("data: ")]
        result = next(message for message in reversed(messages) if message.get("id") == 1)
    else:
        result = json.loads(raw)
    if "error" in result:
        raise RuntimeError(result["error"])
    result = result["result"]
    (ROOT / "artifacts" / "ziva-last-result.json").write_text(json.dumps(result), encoding="utf-8")
    for content in result.get("content", []):
        if content.get("type") == "text":
            print(content["text"][:6000], flush=True)
        elif content.get("type") == "image":
            import base64
            destination = ROOT / "artifacts" / ("ziva-" + name + ".png")
            destination.write_bytes(base64.b64decode(content["data"]))
            print("Saved Ziva image:", destination, flush=True)
    if result.get("isError"):
        raise RuntimeError("Ziva tool returned an error")
    return result

def write(path, content, reason):
    target = ROOT / path
    if target.exists():
        backup = ROOT / ".codex-backups" / "strike-meadow-20261014" / path
        if not backup.exists():
            backup.parent.mkdir(parents=True, exist_ok=True)
            backup.write_bytes(target.read_bytes())
        return call("edit_file", {"reasoning": reason, "file_path": "res://" + path,
                    "search_text": target.read_text(encoding="utf-8-sig"), "replace_text": content})
    return call("create_file", {"reasoning": reason, "file_path": "res://" + path, "content": content})

if __name__ == "__main__":
    import sys
    call(sys.argv[1], json.loads(sys.argv[2]))
