#!/usr/bin/env python3
"""Which of the registry's implemented rows the host differential actually measures.

The registry's `source` field says what backs a row, and for a long time it said one blanket thing
about all of them, which was false: the review of this series measured it with a grep and found the
differential touching no gesture at all. A blanket is not a source, so every row gets the one that is
true, and this is the script that decides which of the two it is.

The rule, and it is deliberately crude so that it cannot overclaim: a row is *covered* when a check
subject in the differential names the row - its leaf, or the part after the first dot of a member,
with Swift's argument labels stripped. Everything else is `declaration only`: the declaration is
there and the swiftregistry check holds it to a name, and nothing measures its behaviour.

A row can be covered and still not be *well* covered, and the table shows the subject that matched,
so a reader can judge that for themselves rather than take this script's word.

    usage: coverage.py <registry.json>... > coverage.txt
"""
import json
import os
import re
import sys

# The differential whose subjects decide it, and the other suite that measures the SceneKit backports
# rather than these rows.
DIFFERENTIAL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "main.swift")

# check("subject", ...) - the first string literal, and the line it is on
SUBJECT = re.compile(r'check\(\s*"((?:[^"\\]|\\.)*)"')


def subjects(path):
    if not os.path.isfile(path):
        return []
    out = []
    for number, line in enumerate(open(path, encoding="utf-8"), 1):
        for found in SUBJECT.findall(line):
            out.append((number, found.replace('\\"', '"')))
    return out


def tokens(api):
    """The names a check subject could use for this row."""
    body = api.split(".")[-1]
    body = re.sub(r"\(.*", "", body)          # drop the argument labels: (rawValue), (lhs:rhs:)
    body = re.sub(r"[:].*$", "", body)         # and anything after a colon
    body = body.strip()
    if not body:
        return []
    words = [body]
    if "." in api:                              # a member: try the part after the first dot too
        words.append(api.split(".", 1)[1])
    if body.endswith("()"):                    # a method: its bare name reads better in a subject
        words.append(body[:-2])
    return [w for w in dict.fromkeys(words) if len(w) > 3]


COVERED = ("measured by the host differential, tests/backports/host/realityfoundation, the check "
           "at main.swift:%s: %s")
DECLARATION = ("the declaration in packages/s/swift-runtime/files/, which "
               "tests/backports/host/swiftregistry holds to a name, and the interface line it was "
               "read from. No check in this series measures it")
# a `source` that claims a measurement the loop did not find: the blanket the first review caught
CLAIMS_A_MEASUREMENT = ("host differential", "the differential")


def what_this_row_should_say(hit):
    if hit[0] == "covered":
        return COVERED % (hit[1], hit[2][:58])
    return DECLARATION


def main(argv):
    if not argv:
        sys.exit("usage: coverage.py <registry.json>...")
    if not os.path.isfile(DIFFERENTIAL):
        sys.exit("coverage.py: no differential at %s" % DIFFERENTIAL)
    checks = subjects(DIFFERENTIAL)
    check_only = "--check" in argv
    write = "--write" in argv
    registries = [a for a in argv if not a.startswith("--")]
    if check_only and not registries:
        sys.exit("usage: coverage.py --check <registry.json>...")
    if not registries:
        sys.exit("usage: coverage.py [--check|--write] <registry.json>...")
    covered = declaration_only = wrong = 0
    for registry in registries:
        document = json.load(open(registry, encoding="utf-8"))
        entries_by_api = {e["api"]: e for e in document["entries"]}
        entries = [e for e in document["entries"] if e.get("status") == "implemented"]
        print("# %s: %d implemented rows, against %d check subjects in %s"
              % (os.path.basename(registry), len(entries), len(checks), os.path.basename(DIFFERENTIAL)))
        for entry in entries:
            hit = None
            for token in tokens(entry["api"]):
                for number, subject in checks:
                    if token.lower() in subject.lower():
                        # (verdict, line, subject) - the token is the report's business, not the
                        # guard's, and putting it in slot 0 is what made the covered branch dead
                        hit = ("covered", number, subject)
                        break
                if hit:
                    break
            if hit:
                covered += 1
                print("covered  %-64s by check at main.swift:%d  %s" % (entry["api"][:64], hit[1], hit[2][:58]))
            else:
                declaration_only += 1
                print("decl only %-64s -" % entry["api"][:64])
            if check_only or write:
                said = entry.get("source", "")
                should = what_this_row_should_say(hit if hit else ("decl only", None, None))
                if write and said != should:
                    # the generator, so the guard's control - a hand-edited row - is regenerated
                    # rather than only complained about
                    entries_by_api[entry["api"]]["source"] = should
                elif check_only and said != should:
                    wrong += 1
                    print("  MISMATCH %s\n    says: %s\n    should be: %s"
                          % (entry["api"][:64], said[:110], should[:110]))
                if check_only and said != should and any(
                        claim in said for claim in CLAIMS_A_MEASUREMENT) and hit is None:
                    print("  AND IT CLAIMS A MEASUREMENT for a row the differential does not name")
        print()
        if write:
            with open(registry, "w", encoding="utf-8") as handle:
                json.dump(document, handle, indent=4)
                handle.write("\n")
            print("# wrote the sources %s" % os.path.basename(registry))
    print("# covered %d, declaration only %d" % (covered, declaration_only))
    if check_only and wrong:
        print("# %d row(s) whose source is not what this loop decides - see MISMATCH above" % wrong)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
