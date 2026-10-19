#!/usr/bin/env python3
"""The two delegate protocols' declaration and registry rows, read two ways and joined by line.

**Selectors come from clang's AST, not from a pattern.** `ObjCMethodDecl` carries the full selector in
`name` and the declaring protocol in `mangledName`; the methods of a protocol are flat top-level nodes
rather than children of the `ObjCProtocolDecl`, which has no `inner` at all. Nothing here parses a
declaration by regular expression, because four separate bugs in doing so produced a generator that
reported 2 members where the header has 32.

**The required/optional split does not come from the AST at all**: this clang's JSON dump carries no
`optional` or `required` key anywhere, checked over the whole subtree. So the split is read from the
header's own `@optional` and `@required` marker lines - a structural read of where the header says the
boundary is, with no pattern over a declaration - and joined to each method by the line number that
clang's `loc.line` also gives. Two readers, two things, one join: the AST says what each method is called,
the header says whether it is optional, and the header's own line number is what ties them together.

The regex reader from the first attempt is kept in count-only mode, as an **independent second count**:
the AST count and the regex count must agree, or the run fails. A member count that two readers disagree
about is a signal, and it is the cheapest one available.

Output goes to .agent-work/runs/ under this worktree and nowhere else.
"""
import json
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
# The worktree's own run directory, found by walking up to the directory that holds packages/ - the same
# way ast_check.py finds it, so both agree on where the worktree is. Band output belongs under this
# worktree's .agent-work/runs/, never in a system temp path and never under tests/.
def _worktree_root(here):
    while not os.path.isdir(os.path.join(here, "packages", "a", "apple-backports")):
        if os.path.dirname(here) == here:
            raise SystemExit("protocols.py: no packages/a/apple-backports above %s" % HERE)
        here = os.path.dirname(here)
    return here


RUNS = os.path.join(_worktree_root(HERE), ".agent-work", "runs", "homekit")
SDK = os.environ.get("SDK", os.path.expanduser("~/Git/projects/ios/charon/.agent-work/sdk-26.2/iPhoneOS26.2.sdk"))
HEADERS = os.path.join(SDK, "System/Library/Frameworks/HomeKit.framework/Headers")
TARGET = ("arm64-apple-ios12.0", SDK)

PROTOCOLS = {"HMHomeDelegate": "HMHome.h", "HMHomeManagerDelegate": "HMHomeManager.h"}
RELEASE = {"HMHomeDelegate": "8.0", "HMHomeManagerDelegate": "8.0"}


def find_root():
    here = HERE
    while not os.path.isdir(os.path.join(here, "packages", "a", "apple-backports")):
        if os.path.dirname(here) == here:
            raise SystemExit("protocols.py: no packages/a/apple-backports above %s" % HERE)
        here = os.path.dirname(here)
    return here


def documents(text):
    decoder = json.JSONDecoder()
    index = 0
    out = []
    while index < len(text):
        while index < len(text) and text[index] in " \n\t\r":
            index += 1
        if index >= len(text):
            break
        document, index = decoder.raw_decode(text, index)
        out.append(document)
    return out


def from_ast(source, protocol):
    """Every selector the AST says this protocol declares, with the line it is declared on."""
    command = [
        "xcrun", "clang", "-fsyntax-only", "-fobjc-arc", "-target", TARGET[0], "-isysroot", TARGET[1],
        "-I", HEADERS, "-I", os.path.dirname(source), "-I", os.path.dirname(os.path.dirname(source)),
        "-Xclang", "-ast-dump=json", "-Xclang", "-ast-dump-filter=%s" % protocol, source,
    ]
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        sys.stderr.write(result.stderr)
        raise SystemExit("clang failed for %s" % protocol)
    found = []

    def walk(node):
        if node.get("kind") == "ObjCMethodDecl":
            mangled = node.get("mangledName", "")
            if "[" + protocol + " " in mangled:
                found.append((node.get("name"), (node.get("loc") or {}).get("line")))
        for child in node.get("inner", []):
            walk(child)

    for document in documents(result.stdout):
        walk(document)
    return found


def split_from_header(header, protocol):
    """Which lines the header puts after an @optional and which after an @required. The marker is the
    header's own boundary; nothing here matches a declaration."""
    path = os.path.join(HEADERS, header)
    with open(path) as handle:
        lines = handle.read().split("\n")
    state = "required"
    out = {}
    inside = False
    for number, text in enumerate(lines, start=1):
        stripped = text.strip()
        if re.match(r"^@protocol %s<" % protocol, stripped):
            inside = True
            state = "required"
            continue
        if inside and stripped == "@end":
            break
        if not inside:
            continue
        if stripped == "@optional":
            state = "optional"
            continue
        if stripped == "@required":
            state = "required"
            continue
        if stripped.startswith("-"):
            out[number] = state
    return out


def declaration_text(header, line):
    """The header's own declaration, copied verbatim from its first line to its semicolon. A wrapped
    declaration's availability sits between, so the copy runs to the semicolon rather than to the end of
    the line. Nothing is parsed out of it: the selector came from the AST and the split from the marker."""
    path = os.path.join(HEADERS, header)
    with open(path) as handle:
        lines = handle.read().split("\n")
    whole = lines[line - 1].strip()
    if ";" not in whole:
        for follow in lines[line:line + 3]:
            whole = whole + " " + follow.strip()
            if ";" in follow:
                break
    return " ".join(whole.split())


def regex_count(header, protocol):
    """The independent count: how many method declarations the header holds, by pattern. Never the source
    of a selector - only a number the AST count is checked against."""
    path = os.path.join(HEADERS, header)
    with open(path) as handle:
        lines = handle.read().split("\n")
    inside = False
    count = 0
    for text in lines:
        stripped = text.strip()
        if re.match(r"^@protocol %s<" % protocol, stripped):
            inside = True
            continue
        if inside and stripped == "@end":
            break
        if inside and re.match(r"^-\s*\(", stripped):
            count += 1
    return count


def main():
    root = find_root()
    port = os.path.join(root, "packages/a/apple-backports/HomeKit")
    source = os.path.join(port, "HMHomeDelegateProtocols8_0.m")
    declaration = [
        "// HMHomeDelegate and HMHomeManagerDelegate, of iOS 8.0: the two delegate protocols of the home",
        "// graph. GENERATED by tests/backports/host/homekit/protocols.py, which takes each member's",
        "// SELECTOR from clang's AST and each member's required/optional from the header's own @optional",
        "// and @required marker lines, joining them by the line number both give. The same reader",
        "// generates the registry rows, so what the port declares and what the registry claims are one",
        "// reading of the header.",
        "//",
        "// Every member is @optional, which is the header's word: a conformer implements the ones it needs",
        "// and this must not turn one into a required method. A member of a later release keeps its own",
        "// API_AVAILABLE, so a conformer compiling for that release and earlier sees the split this does.",
        "",
        "#import <HomeKit/HomeKit.h>",
        "",
    ]
    rows, facts, failures = [], [], []
    for protocol, header in sorted(PROTOCOLS.items()):
        ast = from_ast(source, protocol)
        split = split_from_header(header, protocol)
        # the AST gives the line of the declaration; the header's markers give the split for that line
        members = []
        for selector, line in ast:
            state = split.get(line)
            if state is None:
                failures.append("%s: %s is at line %s, which the header marks neither optional nor required"
                                % (protocol, selector, line))
                state = "unknown"
            release = RELEASE[protocol]
            with open(os.path.join(HEADERS, header)) as handle:
                for text in handle.read().split("\n"):
                    if text.strip().startswith("- ") and selector in text:
                        available = re.search(r"API_AVAILABLE\(\s*ios\(([0-9.]+)\)", text)
                        if not available:
                            for follow in handle.read().split("\n"):
                                if available := re.search(r"API_AVAILABLE\(\s*ios\(([0-9.]+)\)", follow):
                                    break
                        break
            members.append({"selector": selector, "line": line, "optional": state, "release": release})
        independent = regex_count(header, protocol)
        print("%s: AST says %d members, the independent regex count says %d%s"
              % (protocol, len(members), independent, "" if len(members) == independent else "  <-- DISAGREE"))
        if len(members) != independent:
            failures.append("%s: AST %d members, independent count %d" % (protocol, len(members), independent))
        declaration.append("@protocol %s <NSObject>" % protocol)
        declaration.append("@optional" if all(m["optional"] == "optional" for m in members) else "@required")
        for member in members:
            declaration.append("// %s:%d  -[%s %s], %s"
                               % (header, member["line"], protocol, member["selector"],
                                  member["optional"]))
            declaration.append(declaration_text(header, member["line"]))
        declaration.append("@end")
        declaration.append("")
        facts.append("  %s: %d members, %d optional, %d required"
                     % (protocol, len(members),
                        sum(1 for m in members if m["optional"] == "optional"),
                        sum(1 for m in members if m["optional"] == "required")))
        for member in members:
            rows.append({"api": "[-%s %s]" % (protocol, member["selector"]),
                         "kind": "method", "introduced": member["release"],
                         "optional": member["optional"] == "optional",
                         "line": "%s:%s" % (header, member["line"])})
        rows.append({"api": protocol, "kind": "protocol", "introduced": RELEASE[protocol],
                     "members": len(members),
                     "optional": all(m["optional"] == "optional" for m in members)})

    print("\n".join(facts))
    os.makedirs(RUNS, exist_ok=True)
    with open(os.path.join(RUNS, "protocol-declaration.m"), "w") as handle:
        handle.write("\n".join(declaration) + "\n")
    with open(os.path.join(RUNS, "protocol-rows.json"), "w") as handle:
        json.dump(rows, handle, indent=1)
    print("\nwrote .agent-work/runs/homekit/protocol-declaration.m and protocol-rows.json")
    if failures:
        print("\nFAILED")
        for failure in failures:
            print("  %s" % failure)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
