"""portshape -- what the PORT's built library binds, and with what argument types.

Two questions, one instrument, because they are read from the same place: is this selector bound, and
is it bound with the types the release has. The types matter -- a method that takes the right number of
arguments of the wrong kinds is a different method -- and comparing them needs care, which the raw dump
shows:

    the host, arm64:            v32@0:8@16@?24
    this port's object, armv7:   v16@0:4@8@?12

Four-byte pointers against eight, and the frame offsets differ with them. **The rule is to remove every
digit, not to keep the letters**: `v32@0:8@16@?24` and `v16@0:4@8@?12` both become `v@:@@?`, and a
completion typed as a block (`@?`) becomes `@:` -- a SEL -- which is exactly the difference the
comparison has to see. Keeping only the letters loses the `:` and compares the wrong thing, which is
what the first version of this did.
"""
import os
import sys


def letters(encoding):
    """The type encoding with every digit removed: the return type and the argument types, in order,
    with the frame offsets gone."""
    return "".join(c for c in encoding if not c.isdigit())


def methods_of(library):
    """(selector, kind) for every method in a built binary's own method lists, and the types with it.

    The layout, read from the raw dump rather than assumed:

        name    0x17a4 saveCredentialIdentities:completion:
        types   0x1b70 v16@0:4@8@?12
        imp     0x9e0 -[ASCredentialIdentityStore saveCredentialIdentities:completion:]

    `name` / `types` / `imp` per method, in that order, each with an address and then its text, and a
    `baseMethods` line opening each list. A class's own list and its metaclass's are both called
    `baseMethods`, and which is which is in the symbol the line names.
    """
    import subprocess
    out = subprocess.run(["otool", "-ov", library], capture_output=True, text=True).stdout
    bound, types = {}, {}
    current = None
    inMethods = False
    methodsAreClass = False
    lastName = None
    for line in out.split("\n"):
        stripped = line.strip()
        if not stripped:
            continue
        parts = stripped.split(None, 2)
        # A class-list entry is two bare addresses and then the class symbol; the isa and superclass
        # lines are named, which is what tells a class from a pointer to one.
        if len(parts) >= 3 and not parts[0].isalpha() and parts[2].startswith("_OBJC_"):
            symbol = parts[2]
            if symbol.startswith("_OBJC_METACLASS_$_"):
                current, inMetaclass = symbol[len("_OBJC_METACLASS_$_"):], True
            elif symbol.startswith("_OBJC_CLASS_$_"):
                current, inMetaclass = symbol[len("_OBJC_CLASS_$_"):], False
            continue
        if stripped.startswith("baseMethods"):
            inMethods = True
            methodsAreClass = "CLASS_METHODS" in stripped
            lastName = None
            continue
        if stripped.startswith(("baseProtocols", "ivars", "baseProperties", "baseClassMethods",
                                "layout", "weakIvarLayout", "ro")):
            inMethods = False
            lastName = None
            continue
        if not current or not inMethods:
            continue
        if stripped.startswith("name") and len(parts) == 3 and parts[1].startswith("0x"):
            lastName = parts[2]
            bound.setdefault(current, set()).add((lastName, "class" if methodsAreClass else "instance"))
        elif stripped.startswith("types") and lastName and len(parts) == 3 and parts[1].startswith("0x"):
            # The types text may be quoted; the quotes are not part of it.
            text = parts[2].strip('"')
            types.setdefault(current, {})[(lastName, "class" if methodsAreClass else "instance")] = letters(text)
    globals()["_last_types"] = types
    return bound


def one_method(library, className, selectorName):
    """The types of ONE method of ONE class, printed. A separate path so that "the types come out" can
    be seen on its own before anything depends on it."""
    bound = methods_of(library)
    for kind in ("instance", "class"):
        if (selectorName, kind) in bound.get(className, set()):
            encoded = globals()["_last_types"].get(className, {}).get((selectorName, kind), "")
            if not encoded:
                raise SystemExit("%s binds -%s but no types line was read for it" % (className, selectorName))
            print("%s %s -%s types %s" % (className, kind, selectorName, encoded))
            return 0
    raise SystemExit("%s binds no -%s" % (className, selectorName))


def main(argv):
    if len(argv) == 4:
        return one_method(argv[1], argv[2], argv[3])
    if len(argv) != 3:
        raise SystemExit("usage: portshape <library> <cases-file>\n"
                         "       portshape <library> <class> <selector>    one method's types")
    library, cases_file = argv[1], argv[2]
    if not os.path.isfile(library):
        sys.stderr.write("no built library at %s: point BUILT at a build of this worktree's sources\n" % library)
        return 1
    bound = methods_of(library)
    types = globals().get("_last_types", {})
    print("class\tselector\tkind\tstate\tport\tportTypes")
    asked = missing = 0
    for line in open(cases_file):
        if not line.strip():
            continue
        fields = line.rstrip("\n").split("\t")
        className, selector, kind, state = fields[0], fields[1], fields[2], fields[3]
        asked += 1
        present = (selector, kind) in bound.get(className, set())
        if not present:
            missing += 1
        print("%s\t%s\t%s\t%s\t%s\t%s" % (className, selector, kind, state,
                                             "yes" if present else "no",
                                             types.get(className, {}).get((selector, kind), "")))
    sys.stderr.write("portshape: %d cases, %d the library does not bind (a verdict is the comparison's "
                     "to give, not this one's)\n" % (asked, missing))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
