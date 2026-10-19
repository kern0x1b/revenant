#!/usr/bin/env python3
"""Replaces one line of a source file, refusing anything that is not there exactly once. The three
mutations run.sh asks for are the three ways the sheet's lines can be wrong: a different certificate
than the trust's, a verdict that is not the one SecTrustEvaluate gave, and a chain line that is not
marked as one."""
import sys

path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
if text.count(old) != 1:
    sys.exit("mutate.py: %r appears %d times in %s, so the mutation would not be a mutation"
             % (old, text.count(old), path))
open(path, "w").write(text.replace(old, new, 1))
