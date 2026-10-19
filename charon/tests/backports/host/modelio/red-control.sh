#!/bin/sh
# THE RED CONTROL: the comparison must GO RED when a value that agrees today is wrong, and must stay
# GREEN when only an excluded measurement line is wrong.
#
# db5eebaf asked for this and the first attempt was invalid: the plant was made on a key that was
# ALREADY differing, so the tally did not move and the run correctly stayed green. A red control on a
# key that is already red demonstrates nothing. So this script picks a key whose host and port lines are
# byte-identical RIGHT NOW, proves it, and only then plants.
#
# The plants are made in a SCRATCH COPY of the port answers, never in the tree and never in the real
# answers, and the script asserts the real answers are untouched afterwards. Both plants are one-sided:
# only the port line changes, so each assertion is about the comparison and not about a rebuild.
#
# What this control does and does not prove: it proves the COMPARISON responds to a wrong value on an
# agreeing key and ignores an excluded one. It does not prove the probe emits those lines; run.sh covers
# that, and the answers it writes are the ones this reads.
set -eu

root=$(cd "$(dirname "$0")/../../../.." && pwd)
runs="$root/.agent-work/runs"
diff="$runs/modelio-diff"
cmp="$root/tests/backports/host/modelio/compare.py"
key="box vertices"

fail() { echo "RED CONTROL FAILED: $1" >&2; exit 1; }

# The control reads the answers a run produced. If they are not there there is nothing to control and
# that is NOT a control failure: exiting 1 would say the harness is broken when in fact it was never
# run. Exit 2 says exactly that, so a missing run cannot be mistaken for a passing or a failing control.
for answers in "$diff/host/answers.txt" "$diff/port/answers.txt"; do
    [ -f "$answers" ] || { echo "run $root/tests/backports/host/modelio/run.sh first" >&2; exit 2; }
done

echo "1. a key that agrees today, byte for byte"
host=$(grep '^'"$key" "$diff/host/answers.txt" || true)
port=$(grep '^'"$key" "$diff/port/answers.txt" || true)
[ -n "$host" ] || fail "$key is absent from the host answers"
echo "   HOST $host"
echo "   PORT $port"
[ "$host" = "$port" ] || fail "$key does not agree today, so a plant on it cannot demonstrate anything"

echo "   the difference set before either plant:"
set +e
python3 "$cmp" "$diff/host/answers.txt" "$diff/port/answers.txt" >"$runs/redcontrol-before.txt" 2>&1
set -e
grep -E 'host keys' "$runs/redcontrol-before.txt" | sed 's/^/   /'
grep '^different: ' "$runs/redcontrol-before.txt" | sort > "$runs/redcontrol-before.keys"

echo "2. wrong value on $key, which agrees today: must go RED and name it"
cp "$diff/port/answers.txt" "$runs/redcontrol-port.txt"
python3 - "$runs/redcontrol-port.txt" "$key" <<'PY'
import sys
p, key = sys.argv[1], sys.argv[2]
lines = open(p).read().split('\n')
out = []
done = False
for l in lines:
    if not done and l.startswith(key + ' '):
        parts = l.split(' ')
        # make the VERTEX COUNT wrong and leave the rest alone: 24 -> 23
        i = parts.index('vertices')
        assert parts[i + 1] == '24', 'expected the agreeing key to be 24 vertices, got ' + parts[i + 1]
        parts[i + 1] = '23'
        l = ' '.join(parts)
        done = True
    out.append(l)
assert done, 'the plant did not land'
open(p, 'w').write('\n'.join(out))
PY
set +e
python3 "$cmp" "$diff/host/answers.txt" "$runs/redcontrol-port.txt" >"$runs/redcontrol-key.txt" 2>&1
rc=$?
set -e
echo "   \$ compare.py host port-with-$key-wrong   exit=$rc"
grep '^different: ' "$runs/redcontrol-key.txt" | sort > "$runs/redcontrol-key.keys"
grep -q "^different: $key" "$runs/redcontrol-key.keys" \
  || fail "the comparison did not report $key as different, so it would not catch a wrong $key"
echo "   the difference set GREW by exactly one key, and it is the one planted on:"
comm -13 "$runs/redcontrol-before.keys" "$runs/redcontrol-key.keys" | sed 's/^/   + /'
[ "$(comm -13 "$runs/redcontrol-before.keys" "$runs/redcontrol-key.keys" | wc -l | tr -d ' ')" = 1 ] \
  || fail "the plant changed more than one key"

echo "3. wrong value on an EXCLUDED line only: the difference set must not move at all"
cp "$diff/port/answers.txt" "$runs/redcontrol-port.txt"
python3 - "$runs/redcontrol-port.txt" <<'PY'
import sys
p = sys.argv[1]
lines = open(p).read().split('\n')
out, done = [], False
for l in lines:
    if not done and l.startswith('sanity '):
        # sanity is a measurement line the comparison documents itself as ignoring
        l = l.replace('-2.0000', '-9.0000').replace('2.0000', '9.0000', 1)
        done = True
    out.append(l)
assert done, 'no sanity line to plant on'
open(p, 'w').write('\n'.join(out))
PY
set +e
python3 "$cmp" "$diff/host/answers.txt" "$runs/redcontrol-port.txt" >"$runs/redcontrol-excluded.txt" 2>&1
rc=$?
set -e
echo "   \$ compare.py host port-with-sanity-wrong   exit=$rc"
grep '^different: ' "$runs/redcontrol-excluded.txt" | sort > "$runs/redcontrol-excluded.keys"
grep -m1 '^sanity' "$runs/redcontrol-port.txt" | sed 's/^/   the wrong value was really there: /'
if cmp -s "$runs/redcontrol-before.keys" "$runs/redcontrol-excluded.keys"; then
  echo "   the difference set is byte-identical to the baseline: the excluded line was ignored"
else
  fail "an excluded line changed the verdict, so the comparison is not ignoring what it claims to ignore"
fi

echo "4. the real answers are untouched, and still green"
cmp -s "$diff/port/answers.txt" "$runs/redcontrol-port.txt" \
  && fail "the scratch copy is identical to the planted one, so the plant never happened"
sh "$root/tests/backports/host/modelio/run.sh" >"$runs/redcontrol-restored.txt" 2>&1 || fail "run.sh is red on the real tree"
grep -E 'host keys|KNOWN OPEN' "$runs/redcontrol-restored.txt" | sed 's/^/   /'

echo "RED CONTROL PASSED: a wrong value on a key that agrees today is caught and named, and a wrong"
echo "value on an excluded measurement line leaves the verdict byte-identical. The comparison responds"
echo "to this key and to nothing else, and no real file was modified."
