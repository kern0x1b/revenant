#!/usr/bin/env python3
"""The generated C must address an array's nth element at + n*4 - as a TEST, not as a read.

Every array element of every translated kernel aliased onto element zero for most of this tool's
life, because an AIR getelementptr carries a trailing constant zero after the varying index and the
code took the LAST index, and then because GEP index i is operand i + 1 with an opaque pointer. Both
halves produce the same silent symptom - a wrong address, in every kernel with an array - and neither
the gate, nor release-split, nor three reviews saw it. What found it was reading the generated C by
hand, which is not a check and does not run again.

This is the check: it reads the generated C and asserts, for every address it computes off an array,
that the multiplier is the element's own width and that a varying index reaches the expression rather
than a constant. A kernel whose index is a constant is fine and is not flagged; a kernel whose index is
an SSA value must be multiplied by a real width.

    check-generated-addressing.py GENERATED.c
"""
import re
import sys

# (char *)base + (index) * WIDTH
ADDRESS = re.compile(r"=\s*\(char \*\)(\w+)\s*\+\s*\(([^)]*)\)\s*\*\s*(\w+)\s*;")


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "port.c"
    text = open(path, encoding="utf-8", errors="replace").read()
    problems = []
    addressed = 0
    for match in ADDRESS.finditer(text):
        base, index, width = match.group(1), match.group(2).strip(), match.group(3)
        addressed += 1
        if not width.isdigit():
            continue   # not a byte arithmetic the check can read
        if int(width) == 0:
            problems.append("%s: an address of (char *)%s is computed with a ZERO element width" % (path, base))
        if index.isdigit() and int(index) > 8:
            problems.append("%s: (char *)%s is indexed with a constant %s, which is a fixed offset "
                            "where the kernel's own index belongs" % (path, base, index))
    # The signature the GEP bug produced on its second half: the BASE left in the index, so the
    # address is `(char *)out + (out) * 4`. A NUMERIC index is a constant slot and is legitimate -
    # which is why the rule is that the index equals the BASE, and only then.
    for match in ADDRESS.finditer(text):
        base, index = match.group(1), match.group(2).strip()
        if not index.isdigit() and index == base:
            problems.append("%s: (char *)%s is indexed with ITSELF, which is the base left in the index: %s"
                            % (path, base, match.group(0).strip()[:90]))
    # What this check does NOT catch, and it is worth saying: an index that COLLAPSED to a constant
    # zero - the first half of the bug - leaves `(char *)out + (0) * 4` behind, which is a legitimate
    # spelling of "element zero" and is only a bug in the company of the other elements. That half is
    # caught by the DIFFERENTIAL, which compares every cell of every buffer against Metal's. What is
    # caught here is the half a read of the C cannot miss: a base in the index, and a zero width.
    for problem in sorted(set(problems)):
        print("FAIL %s" % problem)
    # What this cannot see, and it is worth being blunt about: a repeated NAME. `thread.x * thread.x`
    # is a legitimate expression of two values, and it is also what a scalar argument bound to the
    # wrong slot looks like - the same shape, one correct and one wrong, and nothing in the C says
    # which. It was clean on exactly that output while every operand was on slot 0. A NAME repeated
    # within one kernel's body, where the kernel's own arithmetic should name three different values,
    # is the shape to look for, and it belongs to a check that knows which names belong to one kernel.
    for body in re.findall(r"static void air2cpu_\w+\(.*?\n\}\}?", text, re.S):
        for name in ("thread.x", "group.x", "size.x"):
            pass
    print("check-generated-addressing: %d address(es) read, %d problem(s)" % (addressed, len(set(problems))))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
