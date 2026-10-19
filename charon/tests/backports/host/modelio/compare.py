#!/usr/bin/env python3
# compare.py HOST PORT [TOLERANCE] [LABEL] : the two probes' answers, line by line, by key.
# A key is everything up to the first number in a line, so "box vertices 9" and "box vertices 12" are
# the same measurement. Everything from that first number to the end of the line is the measurement,
# and every number in it is compared to a tolerance, so a value the two round differently is not a
# difference. A key one side has and the other does not is reported on its own line: that is a
# measurement the host cannot be asked, not a disagreement.
#
# The whole tail is compared, not the first number of it.  A line can carry a pixel tuple, a
# checksum, a vertex normal, a UV or a material property, and reading only the number behind the key
# threw all of that away: on a green pair, 153 ciimage checksums and 12 RGBA tuples and 94 ModelIO
# lines could be changed and this script still said "the same".  Keyed by the first number, compared
# by all of them.
import re, sys

# compare.py HOST PORT [TOLERANCE] [LABEL] : the two probes' answers, line by line, by key.
host_path, port_path = sys.argv[1], sys.argv[2]
tolerance = float(sys.argv[3]) if len(sys.argv) > 3 else 0.0
label = sys.argv[4] if len(sys.argv) > 4 else 'modelio'

# The key is the text up to the first number; the measurement is the number and everything after it.
# Group 2 is the first number and group 3 the rest of the line, so the two are not read twice.
KEY = re.compile(r'^(.*?)(-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)(.*)$')

def read(path):
    # A key seen again is the same key a second time, and is matched as such: the two runs walk the
    # same script, so the n-th occurrence of a key here is the n-th occurrence there.
    lines, seen = {}, {}
    for line in open(path):
        line = line.rstrip('\n')
        # MEASUREMENT LINES ARE NOT PARITY CLAIMS. The sanity line, the sweeps, the (ring, column) dumps and
        # the tri lists exist to be read - they are how the cylinder was found to build a ring the system
        # does not - and counting them as differences made the tally report 267 where 27 are real, which
        # broke the known-open check that exists precisely to catch that. They are skipped here and named,
        # so a difference in the API surface can never be hidden among them either: they are excluded from
        # the comparison, not from the run.
        if line.split(' ')[0] in ('sanity', 'sweep', 'radial', 'second', 'dump', 'tri', 'verts', 'level'):
            continue
        m = KEY.match(line)
        key = m.group(1) if m else line
        seen[key] = seen.get(key, 0) + 1
        # the tail is the number the key stopped at and the rest of the line, so a pixel tuple,
        # a checksum, a normal, a UV or a property type after it is compared and not dropped
        lines[(key, seen[key])] = ((m.group(2) + m.group(3)) if m else None, line)
    return lines

def numbers(text):
    return [float(x) for x in re.findall(r'-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?', text)]

host, port = read(host_path), read(port_path)
same = different = only = 0
only_host = only_port = 0
for key, (value, line) in host.items():
    if key not in port:
        only += 1
        only_host += 1
        print('only the system answers: %s' % line)
        continue
    other = port[key][1]
    if value is None:
        # A line with no number in it is a name or a set of names: the text is the measurement.
        if line == other:
            same += 1
            continue
    else:
        a, b = numbers(value), numbers(port[key][0] if port[key][0] is not None else '')
        if len(a) == len(b) and all(abs(x - y) <= tolerance for x, y in zip(a, b)):
            same += 1
            continue
    different += 1
    print('different: %s' % line)
    print('        the port: %s' % other)
for key, (value, line) in port.items():
    if key not in host:
        only += 1
        only_port += 1
        print('only the port answers: %s' % line)
# THE TALLY IS ASSERTED, and it used to be unreadable: the summary printed len(host) as "measurements"
# while also reporting keys that only the PORT has, so 264 + 41 + 55 came to 360 against a stated 317 and
# looked like a counting bug. There was no counting bug. `measurements` is the HOST S key count, so the
# identity is  same + different + only_host == len(host)  and the port-only keys are OUTSIDE it, making the
# cross-side total len(host) + only_port. Both are now stated, and both identities are checked - a tally
# that does not add up must fail the run rather than be routed to someone else.
assert same + different + only_host == len(host), (
    'the categories do not sum over the host: %d + %d + %d != %d'
    % (same, different, only_host, len(host)))
assert only_host + only_port == only, 'one-side-only does not split: %d + %d != %d' % (only_host, only_port, only)
print('%s: %d host keys = %d the same + %d different + %d host-only; %d port-only, %d across both sides'
      ' (tolerance %g)'
      % (label, len(host), same, different, only_host, only_port, len(host) + only_port, tolerance))
sys.exit(0 if different == 0 else 1)
