#!/usr/bin/env python3
"""
list-overlays.py  repositories_yml

Reads repositories.yml and prints enabled overlay names in priority order
(highest first), one per line. Used by kport_find_pacscript and kport search
to avoid duplicating the YAML parsing logic.

Exit 0 on success (even if no overlays are enabled).
"""
import re, sys

if len(sys.argv) < 2:
    sys.exit(0)

try:
    txt = open(sys.argv[1]).read()
    blocks = re.findall(
        r'-\s+name:\s+(\S+).*?enabled:\s*(true|false)',
        txt, re.DOTALL
    )
    named = []
    for name, enabled in blocks:
        if enabled != 'true':
            continue
        m = re.search(
            r'-\s+name:\s+' + re.escape(name) + r'.*?priority:\s*(\d+)',
            txt, re.DOTALL
        )
        priority = int(m.group(1)) if m else 0
        named.append((priority, name))
    for _, name in sorted(named, reverse=True):
        print(name)
except Exception:
    pass
