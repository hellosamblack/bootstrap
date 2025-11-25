import os

found = []
for root, dirs, files in os.walk('.'):
    # Ignore typical folders
    if '.git' in root or 'node_modules' in root or '.venv' in root:
        continue
    for f in files:
        if f.endswith('.md'):
            path = os.path.join(root, f)
            try:
                with open(path, 'r', encoding='utf-8') as fh:
                    lines = fh.read().splitlines()
                    # Skip empty content
                    if len(lines) > 0 and lines[-1].strip() == '```':
                        found.append(path)
            except Exception:
                continue

if not found:
    print('No markdown files end with a trailing fence (```).')
else:
    print('Files with trailing fence:')
    for p in found:
        print(p)
