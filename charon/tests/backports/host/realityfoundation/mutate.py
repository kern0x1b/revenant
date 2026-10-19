#!/usr/bin/env python3
"""Replace a line of a source file, refusing anything that is not there exactly once.

The suite's mutants are the two things this family's own commits name as worth breaking: the clamp's
composition, and the pose a limit is held to. A mutation that does not compile is not a mutation - it is
a build failure, which proves nothing about the differential - so the edit here has to be one that still
builds, and the run that drives it checks that the *suite* went red and not merely the compiler.
"""
import sys

path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
if text.count(old) != 1:
    sys.exit("mutate.py: %r appears %d times in %s, so the mutation would not be a mutation"
             % (old, text.count(old), path))
open(path, "w").write(text.replace(old, new, 1))
