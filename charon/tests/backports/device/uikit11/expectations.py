import re, sys, json
sources = dict(a.split('=', 1) for a in sys.argv[1:])
pattern = re.compile(r'^(?:  |ok   )(.+?): (.*)$')
out = ['static const char *const charon_expected[][3] = {']
count = 0
for test, path in sources.items():
    for line in open(path, errors='replace'):
        line = line.rstrip('\n')
        m = pattern.match(line)
        if not m:
            continue
        name, value = m.groups()
        if re.match(r'^\s*\d+ \|', line) or re.match(r'^\s*\d+ \|', name):
            continue
        if test == 'systemspacing' and 'baseline' in name:
            continue
        if test == 'batchupdates' and name == 'the order of everything':
            continue
        out.append('    {%s, %s, %s},' % (json.dumps(test), json.dumps(name), json.dumps(value)))
        count += 1
out.append('};')
out.append('static const unsigned charon_expected_count = %d;' % count)
print('\n'.join(out))
