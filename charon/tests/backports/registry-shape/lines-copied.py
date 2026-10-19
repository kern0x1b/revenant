#!/usr/bin/env python3
"""Do the copies in found.lua still say what modules/apple/backports.lua says?

    tests/backports/registry-shape/lines-copied.py <checkout>

A copy of a local function cannot be imported, so it is copied - and a copy goes stale the moment
backports.lua changes its filter. This reads both sides out of the current tree by function name and
compares them with the comments and whitespace folded away, so a backports.lua that moves a line or
changes a predicate is caught here rather than answered from a copy nobody looks at again. It is RED,
naming the function, when a pair differs.

Two pairs are compared and each is named in the output:

  defined_symbols   backports.lua:220 against found.lua's copy, compared whole apart from ONE
                    substitution, named here and applied to the copy: the copy calls the exported
                    backports.symbols_of where backports calls its local symbols_where (:187), which
                    is the same function with a memo. Everything else - the signature, the `hidden`
                    argument, the kind test and the label argument - is compared as it stands, so a
                    change to any of them has to show up here.
  internal_symbol   backports.lua:164 against the test inside found.lua's exported_symbols, compared
                    whole.
"""
import os
import re
import sys


def normalise(text):
    text = re.sub(r"--\[\[[^\]]*\]\]", " ", text)
    text = re.sub(r"--[^\n]*", " ", text)
    return re.sub(r"\s+", "", text)


def body_of(path, name):
    """The WHOLE of `local function name(...)`, up to the `end` that closes it.

    Closing by nesting depth and not by the first `end` it meets: defined_symbols holds an inner
    `function (kind)`, whose `end` is followed by the label argument, and a comparison that stopped
    there would leave the argument out of the region compared - the one piece of it that names which
    symbol set is being asked for.
    """
    text = re.sub(r"--\[\[.*?\]\]", " ", open(path, errors="ignore").read(), flags=re.S)
    text = re.sub(r"--[^\n]*", " ", text)
    start = text.find(f"local function {name}(")
    if start < 0:
        start = text.find(f"function {name}(")
    if start < 0:
        return None
    depth, i = 0, start
    while i < len(text):
        word = re.match(r"\b(function|if|for|while)\b", text[i:])
        end = re.match(r"\bend\b", text[i:])
        if word:
            depth += 1
            i += word.end()
        elif end:
            depth -= 1
            i += end.end()
            if depth == 0:
                return text[start:i]
        else:
            i += 1
    return None


def predicate(body):
    """The `kind` test inside a defined_symbols body, folded the way the copy states it."""
    match = re.search(r"return (kind[^)]*\))\s*,", body, re.S) or re.search(r"(kind *&.*)", body, re.S)
    if not match:
        return None
    text = re.sub(r"\((hidden)\s+or\s+", "(", match.group(0))
    # backports wraps the hidden case in parentheses the copy does not need, with hidden folded false
    text = text.replace("and((", "and(").replace(")))", "))")
    return normalise(text).rstrip(",)")


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    tree = os.path.abspath(sys.argv[1])
    backports = os.path.join(tree, "modules/apple/backports.lua")
    found = os.path.join(tree, "tests/backports/registry-shape/found.lua")
    # the copy's callee is the exported one; backports' is the local that wraps it in a memo
    def whole(b):
        return normalise(b).replace("backports.symbols_of", "symbols_where")

    pairs = [("defined_symbols", whole),
             ("internal_symbol", lambda b: normalise(re.sub(r"^.*?function internal_symbol", "", b, flags=re.S)))]
    ok = True
    for name, extract in pairs:
        theirs = body_of(backports, name)
        mine = body_of(found, name)
        if theirs is None or mine is None:
            print(f"  FAIL {name}: one side has no function by that name "
                  f"(backports.lua {'has' if theirs else 'has no'} it, found.lua {'has' if mine else 'has no'} it)")
            ok = False
            continue
        a, b = extract(theirs), extract(mine)
        if a is None or b is None:
            print(f"  FAIL {name}: the predicate could not be read out of one side, so nothing was compared")
            ok = False
            continue
        if a == b:
            print(f"  ok   {name}: the copy says what backports.lua says")
        else:
            print(f"  FAIL {name}: the copy and backports.lua differ")
            print(f"        backports.lua: {a[:160]}")
            print(f"        the copy:       {b[:160]}")
            ok = False
    print("lines-copied: " + ("every copy matches the current backports.lua" if ok else "FAILED"))
    sys.exit(0 if ok else 1)


main()
