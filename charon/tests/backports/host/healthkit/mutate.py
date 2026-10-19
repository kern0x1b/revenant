#!/usr/bin/env python3
"""mutate.py FILE FROM TO: one source of the port changed from FROM to TO, for the host differential's
mutant check - a change the test has to notice, so that a test that passes means something."""
import sys

path, before, after = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
if before not in text:
    print("MUTANT DID NOT APPLY: %s: %r" % (path, before[:60]))
    sys.exit(1)
open(path, "w").write(text.replace(before, after))
