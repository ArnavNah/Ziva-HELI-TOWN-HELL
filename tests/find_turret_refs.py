import os, re
pattern = re.compile(r'(\$Turret|get_node.*[\'"]Turret[\'"])')
for root, dirs, files in os.walk('src'):
    for f in files:
        if f.endswith('.gd'):
            fp = os.path.join(root, f)
            with open(fp, 'r', encoding='utf-8', errors='ignore') as file:
                for idx, line in enumerate(file, 1):
                    if pattern.search(line):
                        print(f"{fp}:{idx}: {line.strip()}")
