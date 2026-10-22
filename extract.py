import re

with open('docs/town-art-direction.html', 'r', encoding='utf-8') as f:
    html = f.read()

clean = re.sub(r'data:image/[^;]+;base64,[^\"]+', '...', html)
clean = re.sub(r'<style[\s\S]*?</style>', '', clean, flags=re.IGNORECASE)
clean = re.sub(r'<script[\s\S]*?</script>', '', clean, flags=re.IGNORECASE)
text = re.sub(r'<[^>]+>', '\n', clean)
lines = [l.strip() for l in text.split('\n') if l.strip()]

with open('docs/extracted_art_guide.txt', 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))

print('Written', len(lines), 'lines')
