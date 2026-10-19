#!/usr/bin/env python3
"""Compare Apple's answers with the port's, kernel by kernel, and report what was refused."""
import sys


def kernels_in_source(path):
    """Every kernel the SOURCE declares, which is what a run must answer for.

    A hand-kept table is a list that can be one kernel behind the tree with nothing saying so: the
    positionKernel witness went missing from a run that reported 13 rows and said nothing about the
    fourteenth, because nothing compared the SOURCE with what was answered."""
    names = []
    for line in open(path):
        # A COMMENT that says "kernel void" is not a kernel: this fixture's comments say "a group of
        # EIGHT" and "above 30" right after the words, and a naive grep turns both into kernel names,
        # so a line that is a comment is not a declaration.
        code = line.split("//", 1)[0]
        if "kernel void" in code:
            names.append(code.split("kernel void", 1)[1].split("(")[0].strip())
    return names


def answers(path):
    """{kernel: values} and the names that appeared twice. A duplicate is a defect in the run, not a
    second opinion: a library can hold a specialised and a general copy of one kernel, so a harness
    that prints every function of the library prints that name twice, and a dict that keeps the last
    of them silently reports the second copy's answer as the kernel's."""
    out, duplicates = {}, []
    for line in open(path):
        if line.startswith("OUT "):
            parts = line.split()
            if parts[1] in out:
                duplicates.append(parts[1])
            out[parts[1]] = parts[2:]
    return out, duplicates


def refusals(path):
    out = []
    for line in open(path):
        if "REFUSED" in line:
            out.append(line.strip())
    return out


def kernels_of(path):
    """The kernels the GENERATED SOURCE's table names, which is what the port can look up.

    The table is in the generated C - `{ "sumKernel", air2cpu_sumKernel, 1, 0, 0 },` - and NOT in the
    tool's log, which is where this was looking. Every kernel was therefore read as untranslated, and a
    harness that cannot tell translated from refused is a harness that can let a mutant hide."""
    names = []
    for line in open(path):
        if "{ \"" in line and "air2cpu_" in line:
            names.append(line.split('"')[1])
    return names


source = sys.argv[5] if len(sys.argv) > 5 else None
expected = kernels_in_source(source) if source else []
theirs, theirDuplicates = answers(sys.argv[1])
ours, ourDuplicates = answers(sys.argv[2])
translatable = kernels_of(sys.argv[4]) if len(sys.argv) > 4 else []
checks = failures = 0

# A run that compared nothing must fail, and so must one that did not compare everything the tool
# could translate: a summary line that says "0 differ" over an empty run is a line that cannot fail,
# and that is how a hang in the port's encoder came out green.
for name in sorted(set(ourDuplicates)):
    print("FAIL the port's side answered for %s twice: a library can hold a specialised and a general copy of one kernel, and a harness that prints every function prints the name twice. The run is not a measurement of one answer" % name)
    failures += 1
for name in sorted(set(theirDuplicates)):
    print("FAIL Metal's side answered for %s twice, so the answer being compared is not one answer either" % name)
    failures += 1
if not ours:
    print("FAIL the port's side produced no answer at all: every kernel the tool translated is "
          "unaccounted for, which is a hang or a crash and not a match")
    failures += 1
for name in translatable:
    if name not in ours:
        print("FAIL %s was translated by the tool and the port did not answer for it" % name)
        failures += 1
for name, values in sorted(theirs.items()):
    mine = ours.get(name)
    checks += 1
    if mine is None:
        print("refused %-16s the port did not translate this kernel, so there is no answer to compare" % name)
        continue
    if mine == values:
        print("match   %-16s %d values agree with Metal" % (name, len(values)))
    else:
        failures += 1
        print("DIFFER  %-16s" % name)
        for index, (a, b) in enumerate(zip(values, mine)):
            if a != b:
                print("        [%d] Metal %s, the port %s" % (index, a, b))
for line in refusals(sys.argv[3]) if len(sys.argv) > 3 else []:
    print("        %s" % line)

# A kernel METAL answered and the tool REFUSED is not a match either: it is a kernel the differential
# is not testing, and it is where a mutant can hide. A refusal is the port's documented error, not a
# result. The control is at the end: a known-translatable kernel must never be counted here.
for name in sorted(theirs):
    if name not in translatable:
        print("FAIL %s: Metal answered for it and the tool REFUSED it, so this kernel is not under test; "
              "a refusal is the port's documented error, not a result" % name)
        failures += 1
# The control: at least one kernel Metal answered must be in the generated table, or every kernel
# above is being reported as refused because the table was never read at all.
control = [name for name in ("sumKernel", "indexKernel") if name in theirs]
if control and not any(name in translatable for name in control):
    print("FAIL the control kernel(s) %s are answered by Metal and are NOT in the generated table, so "
          "every refusal above is a parser failure and not a refusal" % ", ".join(control))
    failures += 1
for name in ("positionKernel",):
    if name in ours and name in theirs:
        print("dispatch as the kernel sees it, %s: group (%s, %s, %s) threads-per-group %s "
              "threads-per-grid %s index-in-group %s"
              % (name, theirs[name][0], theirs[name][1], theirs[name][2],
                 theirs[name][3], theirs[name][4], theirs[name][5]))
for name in expected:
    if name not in theirs or name not in ours:
        print("FAIL %s is a kernel in the source and NEITHER side answered for it: the library under "
              "test is stale, or the tool refused it, and a run that says nothing about a kernel in "
              "the tree is not a measurement of it" % name)
        failures += 1
print("compare: %d kernel(s) in the source, %d answered by Metal, %d in the table, %d compared, %d differ"
      % (len(expected),
         len(theirs), len(translatable), checks, failures))
sys.exit(1 if failures or not checks else 0)
