#!/usr/bin/env python3
"""Write a mutant of the generated collection factory: one element fewer than the host's answer."""

import sys

source, out = sys.argv[1], sys.argv[2]
text = open(source).read()
needle = "    return results;\n}"
replacement = ("    if (results.count > 1) {\n"
               "        [results removeLastObject];   // THE MUTATION: one element fewer\n"
               "    }\n"
               "    return results;\n}")
mutated = text.replace(needle, replacement)
if mutated == text:
    raise SystemExit("the mutation did not apply: the generated body has no 'return results;\\n}'")
open(out, "w").write(mutated)
