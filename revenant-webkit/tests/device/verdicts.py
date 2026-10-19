#!/usr/bin/env python3
"""Prints the verdicts a test page reported, reading the server's request log."""
import sys
import urllib.parse

passed = failed = 0
seen = set()
for line in sys.stdin:
    if '?' not in line:
        continue
    query = urllib.parse.parse_qs(line.split('?', 1)[1])
    page = query.get('page', ['?'])[0]
    for result in query.get('results', [''])[0].split('~~'):
        if not result:
            continue
        verdict, _, rest = result.partition('|')
        check, _, detail = rest.partition('|')
        if (page, check) in seen:
            continue
        seen.add((page, check))
        print('%-7s %-22s %-34s %s' % (verdict, page, check, detail))
        if verdict == 'PASS':
            passed += 1
        else:
            failed += 1

print('----')
print('%d passed, %d failed' % (passed, failed))
if not passed and not failed:
    print('no verdicts could be read from the log')
    sys.exit(1)
sys.exit(1 if failed else 0)
