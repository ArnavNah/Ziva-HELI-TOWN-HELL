"""Build the local, copy-ready HTML audit from its Markdown source."""
from pathlib import Path
import html
import re

root = Path(__file__).resolve().parents[1]
source = root / 'docs/IMPLEMENT_AIR_MODEL_INTEGRATION_PROMPT.md'
lines = source.read_text(encoding='utf-8').splitlines()

def inline(text):
    text = html.escape(text)
    return re.sub(r'`([^`]+)`', r'<code>\1</code>', text)

parts = []
i = 0
while i < len(lines):
    line = lines[i]
    if not line.strip():
        i += 1
        continue
    if line.startswith('```'):
        block = []
        i += 1
        while i < len(lines) and not lines[i].startswith('```'):
            block.append(lines[i])
            i += 1
        parts.append('<div class="prompt"><button type="button">Copy prompt</button><pre>' + html.escape('\n'.join(block)) + '</pre></div>')
    elif line.startswith('#'):
        level = len(line) - len(line.lstrip('#'))
        parts.append(f'<h{level}>' + inline(line[level:].strip()) + f'</h{level}>')
    elif line.startswith('!['):
        match = re.match(r'!\[(.*?)\]\((.*?)\)', line)
        parts.append(f'<figure><img src="{html.escape(match[2], quote=True)}" alt="{html.escape(match[1], quote=True)}"><figcaption>Rendered production wrappers · thumbnails normalized for inspection</figcaption></figure>')
    elif line.startswith('|'):
        table = []
        while i < len(lines) and lines[i].startswith('|'):
            table.append([x.strip() for x in lines[i].strip('|').split('|')])
            i += 1
        parts.append('<div class="table"><table><thead><tr>' + ''.join('<th>' + inline(x) + '</th>' for x in table[0]) + '</tr></thead><tbody>')
        for row in table[2:]:
            parts.append('<tr>' + ''.join('<td>' + inline(x) + '</td>' for x in row) + '</tr>')
        parts.append('</tbody></table></div>')
        continue
    elif line.startswith('- '):
        parts.append('<ul>')
        while i < len(lines) and lines[i].startswith('- '):
            parts.append('<li>' + inline(lines[i][2:]) + '</li>')
            i += 1
        parts.append('</ul>')
        continue
    else:
        parts.append('<p>' + inline(line) + '</p>')
    i += 1

page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>ZIVA · Air model integration brief</title>
<style>
:root{color-scheme:dark}*{box-sizing:border-box}body{margin:0;background:#0d131a;color:#d9e3ed;font:16px/1.65 system-ui,sans-serif}main{max-width:1240px;margin:auto;padding:48px 32px 90px}h1{font-size:clamp(30px,4vw,48px);line-height:1.15;color:#fff;max-width:950px}h2{margin-top:56px;padding-top:20px;border-top:1px solid #2b3b4b;color:#8cdbc5;font-size:25px}p,li{max-width:1050px}li{margin-bottom:12px}figure{margin:30px 0}img{width:100%;border:1px solid #35495c;border-radius:12px}figcaption{color:#93a5b6;font-size:13px}a{color:#8cdbc5}.table{overflow:auto}table{border-collapse:collapse;width:100%;font-size:14px}td,th{text-align:left;padding:14px;border-bottom:1px solid #304151;vertical-align:top}th{background:#1b2a37;color:#fff}.prompt{position:relative;background:#16212d;border:1px solid #34495e;border-radius:12px;padding:58px 24px 24px;margin:24px 0}pre{white-space:pre-wrap;overflow-wrap:anywhere;margin:0;font:14px/1.7 ui-monospace,Consolas,monospace;color:#e0ebf4}button{position:absolute;right:14px;top:12px;background:#8cdbc5;color:#10251f;border:0;border-radius:7px;padding:9px 14px;font-weight:700;cursor:pointer}button:focus-visible{outline:3px solid white;outline-offset:3px}.tag{color:#8cdbc5;font-weight:700;letter-spacing:.15em;font-size:12px}.source{display:inline-block;padding:9px 14px;border:1px solid #40596d;border-radius:8px;text-decoration:none}@media print{body{background:white;color:black}main{padding:0}h1,h2{color:black}button{display:none}.prompt{background:#eee;padding:20px;break-inside:avoid}pre{color:black}.table{overflow:visible}}
</style><main><div class="tag">ZIVA / ASSET REVIEW</div><a class="source" href="IMPLEMENT_AIR_MODEL_INTEGRATION_PROMPT.md">Open Markdown prompt source</a>'''
page += '\n'.join(parts)
page += '''</main><script>document.querySelectorAll('button').forEach(b=>b.addEventListener('click',async()=>{const text=b.parentNode.querySelector('pre').textContent;try{await navigator.clipboard.writeText(text);b.textContent='Copied';setTimeout(()=>b.textContent='Copy prompt',1800)}catch(e){const r=document.createRange();r.selectNodeContents(b.parentNode.querySelector('pre'));const s=window.getSelection();s.removeAllRanges();s.addRange(r);b.textContent='Selected — press Ctrl+C'}}));</script></html>'''
out = root / 'docs/air-model-replacement-and-animation-brief.html'
out.write_text(page, encoding='utf-8')
print(out)
