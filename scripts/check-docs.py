#!/usr/bin/env python3
"""Check the public documentation's local assets, attribution and language anchors."""
from pathlib import Path
import re
import sys
from urllib.parse import unquote

root = Path(__file__).resolve().parent.parent
readme = (root / 'README.md').read_text()
errors = []
for anchor in ('english', '中文'):
    if f'<a id="{anchor}"></a>' not in readme:
        errors.append(f'missing README anchor: {anchor}')
    badges = re.findall(r'\[!\[[^\]]+\]\([^\n]+?\)\]\(([^)]+)\)', readme)
    if f'#{anchor}' not in badges:
        errors.append(f'missing same-page language badge: {anchor}')
if 'README.zh' in readme or 'README.en' in readme:
    errors.append('language switch must not point to another Markdown file')
if readme.find('<a id="中文"></a>') < readme.find('## Build and contribute'):
    errors.append('Chinese section must follow the complete English section')
if 'Qiushan · @QiushanHuang' not in readme:
    errors.append('missing requested maintainer attribution')
documents = [root / name for name in ('README.md', 'CONTRIBUTING.md', 'CONTRIBUTORS.md', 'SECURITY.md', 'CHANGELOG.md')]
documents += [p for p in (root / 'docs').rglob('*.md') if 'superpowers' not in p.parts]
documents += [root / 'assets/branding/README.md']
for document in documents:
    content = document.read_text()
    if re.search(r'/Users/(?!Shared(?:/|$))[^/\s]+/', content):
        errors.append(f'private workspace path in {document.relative_to(root)}')
    links = re.findall(r'\]\(([^)\s]+)\)', content) + re.findall(r'(?:src|href)="([^"]+)"', content)
    for link in links:
        if link.startswith(('https://', 'http://', '#', 'mailto:')):
            continue
        filename, _, fragment = unquote(link).partition('#')
        target = document.parent / filename
        if not target.exists():
            errors.append(f'{document.relative_to(root)}: missing {link}')
        elif fragment and target.suffix == '.md' and f'id="{fragment}"' not in target.read_text():
            errors.append(f'{document.relative_to(root)}: missing explicit anchor {link}')
if errors:
    print('\n'.join(errors), file=sys.stderr)
    raise SystemExit(1)
print(f'PASS: {len(documents)} public documents, local links/assets, attribution and same-page language badges')
