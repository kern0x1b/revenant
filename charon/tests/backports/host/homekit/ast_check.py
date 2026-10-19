#!/usr/bin/env python3
"""The AST contract check for the HomeKit rows.

The port's own headers import <HomeKit/HomeKit.h> from the iOS SDK, and the SDK's HomeKit types are
marked API_UNAVAILABLE(macos) - so nothing of the model compiles for this host, and there is no
HomeKit framework in any macOS SDK to ask. A probe that runs is therefore not available, and this check is
what runs instead: it compiles the port's source for **iOS** and compares the **port's** declarations
against the **header's**, from clang's AST, without executing anything.

For every class this piece carries, and for every property the header declares on it:

  * the port declares a member of that name;
  * with the same type, nullability included - the AST's qualType carries the _Nonnull/_Nullable the
    header wrote, and a port that declared the property nullable where the header does not would be
    answered differently by a caller;
  * with the same attributes: readonly, copy, nonatomic, weak;
  * and a property the header marks NS_UNAVAILABLE is absent from the port.

The attributes compared are the ones the header writes. `strong` is the default and is not written on a
property line, so it is not compared - what would be compared is a *changed* attribute, and a property
that lost `readonly` or `copy` is caught by the absence of the key rather than by its presence here.

The control: run against a scratch copy with one property's attribute flipped, and this must name it and
exit non-zero. A check that cannot fail is not a check.

The METHOD side reads the port's own source, not the declaration alone. This clang's JSON AST emits no
"body" key for a method definition, so a declaration and an implementation are the same kind of node and a
member whose body was taken away used to pass on the strength of the declaration beside it. Each such node
is now read against the bytes its own source range covers, and a member counts as bound only where those
bytes carry a brace: a declaration's range is a signature, an implementation's is the signature and the
body. The control for that half is a scratch 11.3 object whose -initWithURL: is declared and not written,
and it must go red naming the header line; with the brace test removed it does not.
"""
import json
import os
import re
import subprocess
import sys
import tempfile

SDK = os.environ.get(
    "SDK",
    os.path.expanduser(
        "~/Git/projects/ios/charon/.agent-work/sdk-26.2/iPhoneOS26.2.sdk"
    ),
)
HM_HEADERS = os.path.join(SDK, "System/Library/Frameworks/HomeKit.framework/Headers")
TARGET = ("arm64-apple-ios12.0", SDK)

# What each carried class must match, and the header line each member comes from. The lines are recorded so
# a failure names where the expectation was read from, not only what was expected.
EXPECTED = {
    "HMAccessoryProfile": {
        "uniqueIdentifier": "HMAccessoryProfile.h:27",
        "services": "HMAccessoryProfile.h:32",
        "accessory": "HMAccessoryProfile.h:37",
    },
    "HMAccessory": {
        "home": "HMAccessory.h:37",
        "cameraProfiles": "HMAccessory+Camera.h:28",
    },
    "HMCameraProfile": {
        "streamControl": "HMCameraProfile.h:33",
        "snapshotControl": "HMCameraProfile.h:38",
        "settingsControl": "HMCameraProfile.h:43",
        "speakerControl": "HMCameraProfile.h:48",
    },
}

ATTRIBUTES = ("readonly", "copy", "nonatomic", "weak")

# The two protocols, and the header each is declared in. Their selectors are read from the AST and their
# required/optional split from the header's own @optional / @required marker lines, because this clang's
# JSON dump carries no optional or required key anywhere in the subtree - measured over the whole dump, not
# assumed from a field name.
PROTOCOLS = {"HMHomeDelegate": "HMHome.h", "HMHomeManagerDelegate": "HMHomeManager.h"}


def protocol_members(source, protocol, port_file):
    """Every selector the AST says this protocol declares, as (selector, line, side). One dump of the
    port's file carries both sides - the header's declarations arrive through its import and are tagged
    with the SDK file by includedFrom, the port's are not - which is the same join the property check uses."""
    header, port_side = [], []

    def walk(node):
        if node.get("kind") == "ObjCMethodDecl" and "[" + protocol + " " in node.get("mangledName", ""):
            line = (node.get("loc") or {}).get("line")
            named = ((node.get("loc") or {}).get("includedFrom") or {}).get("file", "")
            from_sdk = bool(named) and os.path.realpath(named) != os.path.realpath(source)
            (header if from_sdk else port_side).append((node.get("name"), line))
        for child in node.get("inner", []):
            walk(child)

    for document in ast(source, protocol):
        walk(document)
    return header, port_side


PARAMETER = re.compile(r"\([^()]*\)\s*[A-Za-z_][A-Za-z0-9_]*")
MACROS = ("API_AVAILABLE", "API_UNAVAILABLE", "API_DEPRECATED", "NS_SWIFT_UNAVAILABLE",
          "NS_REFINED_FOR_SWIFT", "NS_SWIFT_NAME", "NS_SWIFT_SENDABLE", "NS_SWIFT_ASYNC_NAME")


def _strip_macros(line):
    """A declaration line with its availability macros removed, by scanning for each macro's name and then
    counting its parentheses. A macro is a name in caps, optionally followed by a parenthesised argument
    list whose parentheses nest: API_AVAILABLE(ios(11.0), watchos(4.0), tvos(11.0)) is three deep. The
    argument is skipped whole, so nothing of it can survive into a selector."""
    out = line
    index = 0
    while index < len(out):
        if not (out[index].isupper() and (index == 0 or not (out[index - 1].isalnum() or out[index - 1] == "_"))):
            index += 1
            continue
        start = index
        while index < len(out) and (out[index].isupper() or out[index].isdigit() or out[index] == "_"):
            index += 1
        name = out[start:index]
        end = index
        while end < len(out) and out[end] == " ":
            end += 1
        if end < len(out) and out[end] == "(":
            depth = 0
            while end < len(out):
                if out[end] == "(":
                    depth += 1
                elif out[end] == ")":
                    depth -= 1
                    if depth == 0:
                        end += 1
                        break
                end += 1
            index = end
        out = out[:start] + " " + out[index:]
        index = start + 1
    return out


def selector_in(line):
    """The selector on a declaration line: what is left after the return type, with each "(Type) name"
    dropped, the availability macros removed and the whitespace collapsed. The colon stays on every part,
    including the last, because that is the spelling the AST and the runtime both use.

    The macros are removed by SCANNING for the macro's name and then its balanced parentheses, not by a
    pattern. API_AVAILABLE(ios(11.0), watchos(4.0), tvos(11.0)) holds three of them, so a pattern over the
    macro's argument either stops at the first ")" and leaves ",watchos(4.0),tvos(11.0))" in the selector,
    or has to be written to allow nesting and then breaks on a bare name. Counting the parentheses is the
    one reading that is right for both, and it cannot be over-escaped into a literal backslash."""
    body = _strip_macros(line)
    after = body[body.index(")") + 1:]
    return PARAMETER.sub("", after).split(";")[0].replace(" ", "").strip()


def port_side_set(path, protocol):
    """(selector, optional) as the PORT's own file states it: its marker lines and the selector on each of
    its declaration lines, in order."""
    with open(path) as handle:
        lines = handle.read().split("\n")
    state = "required"
    inside = False
    out = set()
    for text in lines:
        stripped = text.strip()
        if re.match(r"^@protocol %s\b" % protocol, stripped):
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
            selector = selector_in(stripped)
            if selector:
                out.add((selector, state))
    return out


def declared_set(source, protocol, header_path, port_file):
    """(selector, optional) as one side declares it: the AST's selector joined, by line, to that side's own
    @optional/@required marker. The header's side is read from the SDK header and the port's from the port's
    file, so the two are read the same way and a difference between them is a real difference."""
    header, _ = protocol_members(source, protocol, port_file)
    header_split = protocol_split(header_path, protocol)
    header_set = set()
    for selector, line in header:
        header_set.add((selector, header_split.get(line, "unknown")))
    return header_set, port_side_set(port_file, protocol)


def protocol_split(path, protocol):
    """The split a given file states: which of its method lines it puts after @optional and which after
    @required. The path is a parameter so the header, the port's own file and a scratch copy of the port
    are read by this one function - the reader is not re-implemented per side and cannot drift."""
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


PORT_INCLUDE = None  # the port's directory, set once the root is found, so a scratch copy can include it


def _worktree_root(here):
    while not os.path.isdir(os.path.join(here, "packages", "a", "apple-backports")):
        if os.path.dirname(here) == here:
            raise SystemExit("ast_check.py: no packages/a/apple-backports above %s" % here)
        here = os.path.dirname(here)
    return here


PORT_HEADER_DIR = None

HERE = os.path.dirname(os.path.abspath(__file__))
# this worktree's own run directory: a control's scratch copy is band output and belongs under
# .agent-work/runs/, never in a system temp path
RUNS = os.path.join(_worktree_root(HERE), ".agent-work", "runs", "homekit")
# made here, where it is named: a fresh worktree has no .agent-work/runs/ at all, and
# tempfile.TemporaryDirectory(dir=RUNS) then died with FileNotFoundError on the first control,
# which took the whole check down after its header contract had already been compared.
os.makedirs(RUNS, exist_ok=True)


PARSE_ERRORS = []


def ast(root, name):
    """clang's filtered AST for one class, as a list of documents."""
    command = [
        # ARC, because the port's own code uses __weak and a manual-reference-counting parse of it would
        # fail on the port's source rather than on anything the check is about.
        "xcrun", "clang", "-fsyntax-only", "-fobjc-arc", "-target", TARGET[0], "-isysroot", TARGET[1],
        "-I", HM_HEADERS, "-I", os.path.dirname(root), "-I", os.path.dirname(os.path.dirname(root)),
        # BOTH of these, and they are not the same variable: PORT_INCLUDE is where an object's FILE is
        # found, and a control redirects it at a scratch directory, while PORT_HEADER_DIR is the port's own
        # header directory, which a scratch copy still needs because it imports CharonHomeKitInternal.h.
        # Conflating them is what made every mutant's scratch file fail to compile and read as a check that
        # could not fail.
        *([ "-I", PORT_INCLUDE ] if PORT_INCLUDE else []),
        *([ "-I", PORT_HEADER_DIR ] if PORT_HEADER_DIR else []),
        "-Xclang", "-ast-dump=json", "-Xclang", "-ast-dump-filter=%s" % name, root,
    ]
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        # A parse that failed is RED, named by its first error line, and never a traceback and never a
        # missing member: ast() returning no documents for a file that would not parse looks exactly like
        # a class that binds nothing, and that is how a broken scratch copy gets read as a result.
        first = next((line for line in result.stderr.splitlines() if " error:" in line), None)
        PARSE_ERRORS.append((root, first or result.stderr.splitlines()[0]
                             if result.stderr.splitlines() else "clang failed with no diagnostic"))
        return []
    PARSE_ERRORS[:] = [e for e in PARSE_ERRORS if e[0] != root]
    raw = result.stdout
    decoder = json.JSONDecoder()
    documents = []
    index = 0
    while index < len(raw):
        while index < len(raw) and raw[index] in " \n\t\r":
            index += 1
        if index >= len(raw):
            break
        document, index = decoder.raw_decode(raw, index)
        documents.append(document)
    return documents


MACROS = ("API_AVAILABLE", "API_UNAVAILABLE", "API_DEPRECATED", "NS_SWIFT_UNAVAILABLE",
          "NS_REFINED_FOR_SWIFT", "NS_SWIFT_NAME", "NS_SWIFT_SENDABLE", "NS_SWIFT_ASYNC_NAME",
          "NS_EXTENSION_UNAVAILABLE_IOS", "API_DEPRECATED_WITH_REPLACEMENT")


def clean_type(text):
    """The property's own type, with the availability macros the header writes after it removed: they land
    in the AST's type string, and what is being compared is the type and its nullability, not the release
    annotation - which the registry row carries and the check reads from the header's own line."""
    out = text
    for macro in MACROS:
        while macro in out:
            head = out.index(macro)
            # the macro and its parenthesised argument, or the bare name
            if "(" in out[head:head + 80] and ")" in out[head:head + 120]:
                end = out.index(")", head) + 1
            else:
                end = head + len(macro)
            out = out[:head] + out[end:]
    return " ".join(out.split())


def properties(documents):
    """Every property in the dump, with the file it came from, so the header's and the port's can be told
    apart: the header's decls carry an includedFrom of the SDK."""
    found = {}

    def walk(node):
        if node.get("kind") in ("ObjCMethodDecl", "ObjCInstanceMethodDecl"):
            selector = node.get("name")
            if selector and ":" not in selector:
                source = (node.get("loc") or {}).get("includedFrom", {}).get("file", "")
                found.setdefault(selector, []).append(
                    {
                        "file": source,
                        "type": (node.get("type") or {}).get("qualType", ""),
                        "attrs": tuple(ATTRIBUTES),
                        "line": (node.get("loc") or {}).get("line"),
                        "accessor": True,
                    }
                )
        if node.get("kind") == "ObjCPropertyDecl":
            source = (node.get("loc") or {}).get("includedFrom", {}).get("file", "")
            found.setdefault(node.get("name"), []).append(
                {
                    "file": source,
                    "type": clean_type((node.get("type") or {}).get("qualType", "")),
                    "attrs": tuple(a for a in ATTRIBUTES if node.get(a)),
                    "line": (node.get("loc") or {}).get("line"),
                }
            )
        for child in node.get("inner", []):
            walk(child)

    for document in documents:
        walk(document)
    return found


def compare(name, expected, header_props, port_props):
    """The header's declaration against the port's, member by member."""
    failures = []
    for member, line in sorted(expected.items()):
        header = next((p for p in header_props.get(member, []) if p["file"].endswith(".h")), None)
        port_member = next((p for p in port_props.get(member, []) if not p["file"].endswith(".h")), None)
        if header is None:
            failures.append("%s.%s: the header declares no such property (%s)" % (name, member, line))
            continue
        if port_member is None:
            failures.append("%s.%s: the port declares no such property (%s)" % (name, member, line))
            continue
        if port_member.get("accessor"):
            # a hand-written accessor returns the type it names; compare it to the header's type with the
            # header's pointer spelling, since the AST writes a method's return type without the
            # property's own _Nonnull suffix
            if header["type"].replace(" _Nonnull", "") not in port_member["type"] and port_member["type"] not in header["type"]:
                failures.append(
                    "%s.%s: the accessor returns %s, the header declares %s (%s)"
                    % (name, member, port_member["type"], header["type"], line)
                )
        elif port_member["type"] != header["type"]:
            failures.append(
                "%s.%s: type %s in the port, %s in the header (%s)"
                % (name, member, port_member["type"], header["type"], line)
            )
        if port_member.get("accessor"):
            missing, extra = [], []
        else:
            missing = [a for a in header["attrs"] if a not in port_member["attrs"]]
            extra = [a for a in port_member["attrs"] if a not in header["attrs"]]
        if missing:
            failures.append(
                "%s.%s: the port is missing %s, which the header has (%s)"
                % (name, member, ", ".join(missing), line)
            )
        if extra:
            failures.append(
                "%s.%s: the port adds %s, which the header does not (%s)"
                % (name, member, ", ".join(extra), line)
            )
        print("  %-28s %-34s %-24s %s" % (name + "." + member, header["type"],
                                          ",".join(header["attrs"]) or "-", line))
    return failures


# ---------------------------------------------------------------------------------------------
# The setup family: METHODS, and one object per release.
#
# Everything above is property-shaped, and a class with no properties measures nothing -- which is
# exactly HMAccessorySetupPayload, the release declaring no property on it at all. So the same file now
# carries methods, and the comparison is per OBJECT rather than per class, because the band machinery
# refuses an object with the API of two releases: the 11.3 initialiser and the 13.0 one are two objects,
# and each must bind exactly its own release's members and nothing of the other's.
#
# The selector comes from the AST's mangledName rather than from `name`, and that is mechanical: for a
# selector with arguments, `name` is only the first piece ("initWithURL"), so a check built on it would
# compare the wrong string for every multi-argument method. The release and the NS_UNAVAILABLE mark come
# from the HEADER'S OWN LINE, read out of the SDK the check is already pointed at -- this clang's JSON
# dump carries availability as an api_avail number in the mangled name, and a check that decoded that
# would be reading an encoding rather than the release's declaration.

# "class" is the release the class itself arrived with, and it is STATED rather than inferred: a member
# whose header line carries no API_AVAILABLE of its own is a member of the class's release, and deriving
# that from the table (the first version took min() over the members' releases) made the expectation
# depend on whatever the table happened to hold, which a scratch copy can change.
SETUP_CLASSES = {
    "HMAccessorySetupPayload": {
        "class": "11.3",
        "11.3": "HMAccessorySetupPayload11_3.m",
        "13.0": "HMAccessorySetupPayload13_0.m",
    },
    "HMAccessorySetupManager": {
        "class": "15.0",
        "15.0": "HMAccessorySetupManager15_0.m",
    },
    "HMAccessorySetupRequest": {
        "class": "15.4",
        "15.4": "HMAccessorySetupRequest15_4.m",
    },
    "HMAccessorySetupResult": {
        "class": "15.4",
        "15.4": "HMAccessorySetupResult15_4.m",
    },
}

# The protocols each setup class conforms to, and what those protocols require of it. A protocol method
# is NOT a foreign member: the header's own class declaration says NSObject<NSCopying>, and a port that
# did not bind -copyWithZone: would not be conforming. A protocol's requirements are not ObjCMethodDecls
# of the class, so comparing method decls alone called the port's own -copyWithZone: a foreign member --
# and the first run over HMAccessorySetupResult went red on exactly the method its conformance demands.
SETUP_PROTOCOLS = {
    "HMAccessorySetupRequest": {"NSCopying": ("-copyWithZone:",)},
    "HMAccessorySetupResult": {"NSCopying": ("-copyWithZone:",)},
}

# Members the release declares and the port does NOT bind, each with the owner class and the reason.
# They are listed rather than left out, because a member the check does not mention is a member nothing
# looked at, and "absent because the hardware is not here" has to be re-checkable like any other row.
# The one entry is hardware: a real accessory has to be physically present, and the system's setup UI is
# what launches the pairing. matterPayload is NOT here -- it is storage, the port holds the object and
# reads it back, and drawing the line at the slot that holds a payload would leave a header property
# unsynthesised and a member of the release's surface answered with nothing.
# KEYED BY THE SIGNED SELECTOR AND NOTHING ELSE -- the same string `members` is keyed by, so that
# `expected -= absent` means anything. Two other forms were tried and both fail SILENTLY: the bare member
# name lacks the sign, and the documented "-[Cls member]" spelling carries a class name and a space. Both
# produce the same misleading symptom, which is an assertion saying the header does not declare a member
# the header plainly declares, while the dict consulted is the right one and only the key is wrong.
SETUP_ABSENT = {
    "-performAccessorySetupUsingRequest:completionHandler:": "HMAccessorySetupManager",
}

SETUP_ABSENT_WHY = {
    "-performAccessorySetupUsingRequest:completionHandler:":
        "HARDWARE: it adds an accessory that is physically present, over HomeKit's own transport to it",

}

HEADER_OF_CLASS = {
    "HMAccessorySetupPayload": "HMAccessorySetupPayload.h",
    "HMAccessorySetupManager": "HMAccessorySetupManager.h",
    "HMAccessorySetupRequest": "HMAccessorySetupRequest.h",
    "HMAccessorySetupResult": "HMAccessorySetupResult.h",
}

MANGLED_SELECTOR = re.compile(r"^[-+]\[[A-Za-z_][A-Za-z0-9_]*\s+")


def selector_of(mangled):
    """The selector out of a mangled method name, for every shape clang writes.

    -[Cls initWithURL:ownershipToken:]  and  -[Cls payload]  are spelled differently, and the difference
    is one space: a mangled name with a selector that takes arguments has a space after the class name,
    and one that takes none has a closing bracket in its place. A pattern that requires the space reads
    every argument-less selector as "payload]" -- with the bracket still on it -- and that is not a
    cosmetic difference, because the header's members are named by property_accessors() WITHOUT it: the
    two spellings of one member then disagree, the property-derived one is expected and never found, and
    a correct port is reported as binding nothing at all. The leading sign is kept, so a class method is
    not read as an instance one.

    A third shape carries the CATEGORY: -[Cls(Charon13_0) initWithURL:ownershipToken:]. The optional
    group below is what makes it a shape rather than a refusal, and refusing it was a blind spot with a
    cost: HMAccessorySetupPayload's 13.0 object is a category by design (a second @implementation of
    one class cannot be linked into one binary, so the 11.3 object holds the class and the 13.0 one adds
    the newer initialiser to it), so -initWithURL:ownershipToken: read as bound by NOBODY and the check
    reported the header's own 13.0 member missing from a port that binds it. What told the two apart is
    not the category but the member: a charon_ member is the port's own storage, and port_methods()
    filters those on their own spelling.
    """
    if not mangled:
        return None
    match = re.match(r"^[-+]\[[A-Za-z_][A-Za-z0-9_]*(?:\([A-Za-z_][A-Za-z0-9_]*\))?[\s\]]+(.*)$", mangled)
    if not match:
        return None
    body = match.group(1)
    if body.endswith("]"):
        body = body[:-1]
    return mangled[0] + body


def self_test_selector_of():
    """The helper's own control, on both spellings, printed so a run shows it was exercised."""
    cases = [
        ("-[HMAccessorySetupPayload initWithURL:ownershipToken:]", "-initWithURL:ownershipToken:"),
        ("-[HMAccessorySetupRequest payload]", "-payload"),
        ("+[HMAccessorySetupResult new]", "+new"),
        # the category shape, which is the one that used to read as no selector at all
        ("-[HMAccessorySetupPayload(Charon13_0) initWithURL:ownershipToken:]", "-initWithURL:ownershipToken:"),
        ("-[HMAccessorySetupResult(CharonHomeKitSetup) charon_initWithHomeIdentifier:]",
         "-charon_initWithHomeIdentifier:"),
        ("-[HMAccessorySetupResult(CharonHomeKitSetup) payload]", "-payload"),
        # and a name that is not a method at all, which must stay refused: this control compared only
        # the cases that wanted a selector, so a helper that answered None to everything passed it.
        ("", None),
        (None, None),
    ]
    wrong = []
    for mangled, want in cases:
        got = selector_of(mangled)
        if got != want:
            wrong.append("%s gave %s, wanted %s" % (mangled, got, want))
    print("  self-test: selector_of on a with-arguments and an argument-less name: %s"
          % ("ok" if not wrong else "; ".join(wrong)))
    return wrong


def header_line(header, line):
    """One line of one header, as written."""
    try:
        with open(os.path.join(HM_HEADERS, header), encoding="utf-8") as handle:
            return handle.read().split("\n")[line - 1]
    except (OSError, IndexError):
        return ""


def release_of(text):
    """(release, unavailable) from a header declaration line: the ios version API_AVAILABLE names, and
    whether the line also carries NS_UNAVAILABLE. A line with no API_AVAILABLE is the class's own
    release -- every member the header declares without one arrived with the class."""
    unavailable = "NS_UNAVAILABLE" in text
    match = re.search(r"API_AVAILABLE\s*\(\s*ios\s*\(\s*([0-9]+(?:\.[0-9]+)?)\s*\)", text)
    return (match.group(1) if match else None), unavailable


def stage(scratch, class_name):
    """Copy every object of one class into a scratch directory and point the lookup at it.

    EVERY object, not the one being mutated: the lookup finds each object's file in PORT_INCLUDE, so a
    scratch directory holding only the mutated copy makes the OTHER object's lookup fail on a missing
    file -- and a missing file reads as a check that cannot fail rather than as a broken mutant.
    """
    global PORT_INCLUDE
    source = PORT_HEADER_DIR or PORT_INCLUDE
    # EVERY class's objects, not just the one being mutated: compare_setup runs over all of them, and a
    # scratch directory holding only the mutated class's objects leaves the other classes' lookups failing
    # on a missing file -- which reads as a check that cannot fail rather than as a broken mutant.
    for name in sorted({o for c in SETUP_CLASSES for o in objects_of(c).values()}):
        with open(os.path.join(source, name)) as handle:
            with open(os.path.join(scratch, name), "w") as out:
                out.write(handle.read())
    PORT_INCLUDE = scratch
    return scratch


def method_text(text, signature_start):
    """One method's own source, from the line its signature starts to the line that closes it.

    A mutant has to move a method, and finding its end by the next '@end' is wrong: a class extension
    above the @implementation has an @end of its own, so an insertion aimed there lands in an
    @interface and the scratch file does not compile -- which is how a mutant that proves nothing ends
    up looking like a check that cannot fail. A method's body ends at a closing brace in the first
    column, and that is what this finds.
    """
    start = text.index(signature_start)
    end = text.index("\n}\n", start) + len("\n}")
    return text[start:end]


def append_to_implementation(text, method):
    """The same file with one method's source put at the end of its @implementation."""
    return text[:text.rindex("@end")] + method + "\n\n" + text[text.rindex("@end"):]


def source_of(path):
    """One file's own text, or "" when it cannot be read.

    Empty is the safe direction on purpose: a file this cannot read leaves every method of it unbound,
    which the comparison reports as a missing member. The other direction - reading nothing and calling
    every declaration an implementation - is the defect this replaces.
    """
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read()
    except OSError:
        return ""


def writes_a_body(text, node):
    """Whether the port's own source gives this method a BODY, and not only a declaration of it.

    This clang's JSON AST emits no "body" key for a method definition, so a declaration and an
    implementation are the same kind of node and filtering on a body finds nothing at all. What the dump
    does carry is the node's own source RANGE, and that is enough: a definition's range runs from the
    signature's leading - or + through the brace that opens its body, and a declaration's range stops at
    the last token of the declaration - a parameter's type, a __attribute__, the semicolon - which is
    source that cannot hold a brace. So the test is whether the range's own bytes contain one.

    Measured on HMAccessoryProfile10_0.m, arm64-apple-ios12.0, -ast-dump=json: the port's two
    charon_ declarations are 198 and 335 bytes with no brace, and its five definitions are 59 to 799
    bytes with one each. It is the range and not the line, because the two shapes share a line too: a
    category's declaration and its definition can sit a few lines apart, and reading the line alone
    would accept whatever happens to be written there.
    """
    span = node.get("range") or {}
    begin = (span.get("begin") or {}).get("offset")
    end = (span.get("end") or {}).get("offset")
    if begin is None or end is None or not 0 <= begin <= end <= len(text):
        return False
    return "{" in text[begin:end]


def self_test_writes_a_body():
    """writes_a_body()'s own control, on both shapes of node out of one real dump, printed so a run
    shows it was exercised.

    HMAccessoryProfile10_0.m is the file that carries both shapes of one selector: it declares
    +charon_profileInStore:identifier:accessory: in a category interface above the @implementation and
    defines it below, and the dump emits an ObjCMethodDecl for each. A control that only fed it a
    definition would pass a helper that answered YES to everything, so the declaration half is the one
    that decides, and both are named here.
    """
    path = os.path.join(PORT_INCLUDE, "HMAccessoryProfile10_0.m")
    text = source_of(path)
    seen = {}
    for document in ast(path, "HMAccessoryProfile"):
        for node in walk_methods(document):
            selector = selector_of(node.get("mangledName", ""))
            if selector == "+charon_profileInStore:identifier:accessory:":
                seen[len(seen)] = node
    wrong = []
    if len(seen) != 2:
        wrong.append("the dump carried %d nodes of the one selector that has both shapes, wanted 2"
                     % len(seen))
    else:
        for index, want in ((0, False), (1, True)):
            got = writes_a_body(text, seen[index])
            if got != want:
                wrong.append("node %d of the pair read %s, wanted %s" % (index, got, want))
    # and a node with no range at all, which must be refused rather than counted
    if writes_a_body(text, {}):
        wrong.append("a node with no range read as a definition")
    print("  self-test: writes_a_body on a declaration and on a definition: %s"
          % ("ok" if not wrong else "; ".join(wrong)))
    return wrong


def walk_methods(node):
    """Every method decl under one node, in the dump's own order."""
    if isinstance(node, list):
        for item in node:
            yield from walk_methods(item)
        return
    if not isinstance(node, dict):
        return
    if node.get("kind") in ("ObjCMethodDecl", "ObjCInstanceMethodDecl", "ObjCClassMethodDecl"):
        yield node
    for child in node.get("inner", []):
        yield from walk_methods(child)


def from_sdk(loc):
    """Whether a decl arrived through one of the SDK's own headers, which is what tells the header's
    members from the port's -- the same join the property check documents, and the same one the protocol
    check above uses. A method definition in the port's own file has no includedFrom at all."""
    source = (loc.get("includedFrom") or {}) if isinstance(loc.get("includedFrom"), dict) else {}
    name = source.get("file", "")
    return bool(name) and os.path.realpath(name).startswith(os.path.realpath(HM_HEADERS) + os.sep)


def objects_of(class_name):
    """The object files of one class, and the oldest first: the header's own members are read through the
    oldest object, so a class whose oldest object a scratch copy has replaced still reads the header from
    a real file."""
    objects = SETUP_CLASSES[class_name]
    return {k: v for k, v in objects.items() if k != "class"}


def property_accessors(name, text, readonly):
    """The selectors a header @property requires: its getter, and unless it is readonly its setter.

    Two things make this necessary rather than clever, and both were measured on this clang's JSON dump
    rather than assumed. A property's GETTER is emitted as an ObjCMethodDecl of the class, so a check on
    method decls alone already sees it; its SETTER is not emitted at all unless something calls it. So the
    setter of a readwrite property is a member the port must bind and the header's AST never mentions,
    and comparing method decls alone calls it a FOREIGN member -- which is how -setSuggestedAccessoryName:
    came to be reported on HMAccessorySetupRequest as something the port had no business binding. The
    names are the property's own with a custom getter=/setter= read off the header line, because that is
    where the header writes them: this clang carries no getterName or setterName key for either.
    """
    getter = re.search(r"getter\\s*=\\s*([A-Za-z_][A-Za-z0-9_]*)", text)
    setter = re.search(r"setter\\s*=\\s*([A-Za-z_][A-Za-z0-9_]*:?)", text)
    selectors = ["-" + (getter.group(1) if getter else name)]
    if not readonly:
        selectors.append("-" + (setter.group(1) if setter else "set%s:" % (name[0].upper() + name[1:])))
    return selectors


def header_methods(class_name, header):
    """{selector: {"release", "unavailable", "line"}} for one class, from the header's own lines.

    The header is compiled for the check's own target, so the members arrive through the port file's
    import tagged with the SDK file by includedFrom -- the same join the property check above uses, and
    the same reason: one dump carries both sides and the file each came from is what tells them apart.

    A @property contributes its accessors as members in their own right, at the property's own line, so
    that a setter the header's AST does not emit is still something the port has to bind and the check
    has to name.
    """
    found = {}

    def walk(node):
        if node.get("kind") == "ObjCPropertyDecl":
            # The property side of the join, and it has to come FIRST: a property's accessors are members
            # of the class, and a class whose members the check cannot name is a class nothing looked at.
            loc = node.get("loc") or {}
            source = ((loc.get("includedFrom") or {}).get("file", "") if isinstance(
                loc.get("includedFrom"), dict) else "")
            name = node.get("name")
            if name and loc.get("line") and source and os.path.realpath(source).startswith(
                    os.path.realpath(HM_HEADERS) + os.sep):
                text = header_line(header, loc["line"])
                release, unavailable = release_of(text)
                for selector in property_accessors(name, text, bool(node.get("readonly"))):
                    found.setdefault(selector, []).append(
                        {"release": release, "unavailable": unavailable, "line": loc["line"],
                         "accessor_of": name})
        if node.get("kind") in ("ObjCMethodDecl", "ObjCInstanceMethodDecl", "ObjCClassMethodDecl"):
            selector = selector_of(node.get("mangledName", ""))
            loc = node.get("loc") or {}
            # Which SIDE a decl is on, by the same join the property check above uses: a decl that came
            # through the SDK's headers carries an includedFrom under them, and a port implementation
            # carries none. The header's own decls name the umbrella HomeKit.h rather than the class
            # header their line was read from, so the test is "somewhere under the SDK's headers" and not
            # the class header's name -- matching the class header's name found nothing, which is how a
            # check comes to pass with no rows at all.
            source = ((loc.get("includedFrom") or {}).get("file", "") if isinstance(
                loc.get("includedFrom"), dict) else "")
            if selector and loc.get("line") and source and os.path.realpath(source).startswith(
                    os.path.realpath(HM_HEADERS) + os.sep):
                line = loc["line"]
                release, unavailable = release_of(header_line(header, line))
                found.setdefault(selector, []).append(
                    {"release": release, "unavailable": unavailable, "line": line})
        for child in node.get("inner", []):
            walk(child)

    # The header's members arrive through the port file's own import, so the dump that carries both
    # sides is the 11.3 object's -- the oldest of the two, so the class's own release is the one in it.
    # The header's members are read through ONE of the port's own files, and it is the OLDEST object of
    # the class -- whichever release that object happens to be called. Hardcoding the payload's own "11.3"
    # found the other three classes' objects nowhere, and a class whose header cannot be read is a class
    # the comparison says nothing about.
    oldest = sorted(objects_of(class_name).items())[0][1]
    for document in ast(os.path.join(PORT_INCLUDE, oldest), class_name):
        walk(document)
    return {selector: entries[0] for selector, entries in found.items()}


def header_properties(class_name):
    """{name: {"line", "readonly", "text"}} for the header's own properties of one class."""
    header = HEADER_OF_CLASS.get(class_name)
    found = {}
    if not header:
        return found

    def walk(node):
        if node.get("kind") == "ObjCPropertyDecl" and from_sdk(node.get("loc") or {}):
            loc = node.get("loc") or {}
            if node.get("name") and loc.get("line"):
                found[node["name"]] = {"line": loc["line"], "readonly": bool(node.get("readonly")),
                                       "text": header_line(header, loc["line"])}
        for child in node.get("inner", []):
            walk(child)

    oldest = sorted(objects_of(class_name).items())[0][1]
    for document in ast(os.path.join(PORT_INCLUDE, oldest), class_name):
        walk(document)
    return found


def port_methods(class_name, object_name):
    """{selector: line} for the members ONE OBJECT binds, from that object's own file.

    Only members whose own implementation is in that file count. A port file imports the internal header,
    and that header declares categories and extensions for other classes; a method the object did not
    write is not a member it binds, and counting one would make the per-object comparison pass for the
    wrong reason.
    """
    found = {}

    # The header's properties, read BEFORE the walk: an ObjCPropertyImplDecl names its property, and a
    # property is where "readonly" and a custom getter= or setter= actually live -- but the header's
    # property decls are emitted AFTER the @implementation in the dump, so collecting them in the same
    # walk leaves the map empty at the moment it is needed and every synthesised accessor is silently
    # dropped. Read first, then walk.
    declared = header_properties(class_name)
    # This object's own text, read once, for the body test below: a method counts as bound only where
    # the file writes its body, and the file is the only thing that says so.
    source = source_of(os.path.join(PORT_INCLUDE, object_name))

    def walk(node):
        if node.get("kind") == "ObjCPropertyImplDecl":
            # A @synthesize -- explicit or automatic -- IS the binding. This is the port-side twin of the
            # header-side gap: clang emits a property's getter only where something references it, and the
            # accessor methods themselves are absent from the dump for a synthesised property nothing
            # calls, so reading only ObjCMethodDecl called two of the request's four setters and the
            # result's readonly getter "not bound" on a port that binds them. The SAME property_accessors
            # the header side uses derives the names, so the two sides cannot drift apart, and a property
            # with no header declaration contributes nothing: a member counts as bound only through an
            # ObjCPropertyImplDecl of THIS object or an explicit method below.
            decl = node.get("propertyDecl") or {}
            name = decl.get("name") or node.get("name")
            info = declared.get(name)
            if name and info is not None:
                line = (node.get("loc") or {}).get("line")
                for selector in property_accessors(name, info["text"], info["readonly"]):
                    found.setdefault(selector, line)
        if node.get("kind") in ("ObjCMethodDecl", "ObjCInstanceMethodDecl", "ObjCClassMethodDecl"):
            selector = selector_of(node.get("mangledName", ""))
            loc = node.get("loc") or {}
            # The PORT's side is a decl that came through no SDK header at all AND whose own source
            # carries a body: the declaration and the definition of one method are the same kind of node
            # here, so the file's own text is what tells them apart (writes_a_body). Without that half a
            # member whose body was emptied still passes, on the strength of the declaration beside it.
            # And a charon_ member is the port's own storage, which CharonHomeKitInternal.h says is not
            # part of the release's surface.
            if (selector and loc.get("line") and not from_sdk(loc)
                    and not selector.lstrip("-+").startswith("charon_")
                    and writes_a_body(source, node)):
                found[selector] = loc["line"]
        for child in node.get("inner", []):
            walk(child)

    for document in ast(os.path.join(PORT_INCLUDE, object_name), class_name):
        walk(document)
    return found


def compare_setup(verbose=True):
    """Each object against the header members of its own release. Returns (failures, rows)."""
    failures, rows = [], []
    for class_name, objects in sorted(SETUP_CLASSES.items()):
        header = HEADER_OF_CLASS[class_name]
        members = header_methods(class_name, header)
        class_release = objects["class"]
        for release, object_name in sorted((r, o) for r, o in objects.items() if r != "class"):
            before = len(PARSE_ERRORS)
            bound = port_methods(class_name, object_name)
            if len(PARSE_ERRORS) > before:
                # The object's own file did not parse. Every member would now read as missing, which is
                # a claim about a file clang refused to read, so the parse is the only thing reported.
                for path, first in PARSE_ERRORS[before:]:
                    failures.append("the parse of %s failed, so no member of %s was measured: %s"
                                    % (os.path.basename(path), class_name, first))
                continue
            # A member the header line gives no API_AVAILABLE of its own arrived with the class, and an
            # object owns the members of its own release and of no other.
            expected = {s for s, m in members.items()
                        if not m["unavailable"] and (m["release"] or class_release) == release}
            # A protocol requirement is a member too, and it has no line in the class's own header: the
            # conformance is on the @interface line and the protocol is named in the table.
            expected |= {sel for reqs in SETUP_PROTOCOLS.get(class_name, {}).values() for sel in reqs}
            # And a member the port does not carry LEAVES the expected set and joins the forbidden one, so
            # its absence is measured rather than merely unmentioned, and the reason travels with it.
            absent = {sel for sel, owner in SETUP_ABSENT.items() if owner == class_name}
            # And the form is asserted, not assumed: a key in SETUP_ABSENT that no header member answers
            # to is a typo, and a typo here is invisible -- it subtracts nothing and the member is
            # reported as missing, which reads like a port defect rather than like a table defect.
            for sel in absent:
                if sel not in members:
                    failures.append("SETUP_ABSENT names %s, which the header of %s does not declare"
                                    % (sel, class_name))
            expected -= absent
            forbidden = {s for s, m in members.items() if m["unavailable"]} | absent
            for selector in sorted(expected):
                if selector not in members:
                    protocol = next((name for name, reqs in SETUP_PROTOCOLS.get(class_name, {}).items()
                                     if selector in reqs), "a protocol")
                    if selector not in bound:
                        failures.append("%s (%s): the port binds no %s, which %s requires of this class"
                                        % (class_name, release, selector, protocol))
                    continue
                if selector in bound:
                    rows.append((object_name, selector, release, header, members[selector]["line"]))
                else:
                    failures.append("%s (%s): the header declares %s at %s:%d, and the object binds no such method"
                                    % (class_name, release, selector, header, members[selector]["line"]))
            for selector in sorted(bound):
                if selector in forbidden:
                    failures.append("%s:%d binds %s, which the header marks NS_UNAVAILABLE at %s:%d"
                                    % (object_name, bound[selector], selector, header,
                                       members[selector]["line"]))
                elif selector not in expected:
                    failures.append("%s:%d binds %s, which is not a member of %s at %s"
                                    % (object_name, bound[selector], selector, release, header))
        # The unavailable members are NAMED, not merely absent. A check that prints nothing about -init
        # and +new cannot be read as having looked at them, and they are the two members of this class the
        # release refuses to let a caller use -- so each one is printed with whichever object binds it, and
        # "no object" is the answer this port wants.
        if verbose:
            for selector, member in sorted(members.items()):
                if member["unavailable"]:
                    holders = [o for _, o in sorted(objects_of(class_name).items())
                               if selector in port_methods(class_name, o)]
                    print("  %-36s %-34s %-14s %s:%d" % (
                        ",".join(holders) or "no object binds it", selector, "NS_UNAVAILABLE",
                        header, member["line"]))
    if verbose:
        for object_name, selector, release, row_header, line in rows:
            print("  %-36s %-34s %-6s %s" % (object_name, selector, release,
                                             "%s:%d" % (row_header, line) if line else row_header))
        # The unavailable members are NAMED, not merely absent: a check that says nothing about -init and
        # +new cannot be read as having looked at them, and they are the two members of this class the
        # release refuses to let a caller use.

    return failures, rows


def main():
    # tests/backports/host/homekit -> the repository root, found by walking up to the one holding
    # packages/ rather than by counting levels, so a moved directory cannot silently point elsewhere.
    here = os.path.abspath(os.path.dirname(__file__))
    root = here
    while not os.path.isdir(os.path.join(root, "packages", "a", "apple-backports")):
        if os.path.dirname(root) == root:
            raise SystemExit("ast_check.py: no packages/a/apple-backports above %s" % here)
        root = os.path.dirname(root)
    port = os.path.join(root, "packages/a/apple-backports/HomeKit")
    global PORT_INCLUDE, PORT_HEADER_DIR
    PORT_INCLUDE = port
    PORT_HEADER_DIR = port
    source = os.path.join(port, "HMAccessoryProfile10_0.m")

    print("self-test: the helpers this check's own answers depend on")
    failures = self_test_selector_of()
    failures.extend(self_test_writes_a_body())
    print("\nheader contract, from clang's AST of the SDK and of the port, for %s" % TARGET[0])
    for name, expected in sorted(EXPECTED.items()):
        # each class's own file: the properties arrive through that file's import, tagged with the SDK
        # header they came from, and the port's own declaration of them is in the same dump
        path = os.path.join(port, "HMAccessoryHome10_0.m") if name == "HMAccessory" else source
        both = properties(ast(path, name))
        header_props = {k: v for k, v in both.items()}
        port_props = {k: [p for p in v if not p["file"].endswith(".h")] for k, v in both.items()}
        failures.extend(compare(name, expected, header_props, port_props))

    # The setup family: methods, and one object per release. This is here because the check above is
    # property-shaped and HMAccessorySetupPayload declares no property at all, so without this section
    # two initialisers and two unavailable members would be measured by nothing.
    print("\nthe setup family: methods, one object per release, from %s"
          % ", ".join(sorted(HEADER_OF_CLASS[c] for c in SETUP_CLASSES)))
    setup_failures, _ = compare_setup()
    failures.extend(setup_failures)

    # A SYNTHETIC class: one the header does not declare at all. The host has no HomeKit framework and so
    # no instance to ask, and a control has to be real rather than a check that cannot fail -- so the
    # control is a class that exists only in a scratch file, registered in the same table so the SAME
    # comparison runs over it, and it has to come back red naming what it bound.
    print("\ncontrol: a synthetic class in a scratch file that the header does not declare")
    with tempfile.TemporaryDirectory(dir=RUNS) as scratch:
        synthetic = "HMAccessorySetupPayloadSynthetic11_3.m"
        with open(os.path.join(scratch, synthetic), "w") as handle:
            handle.write(
                "#import <Foundation/Foundation.h>\n"
                "@interface HMAccessorySetupPayloadSynthetic : NSObject\n@end\n"
                "@implementation HMAccessorySetupPayloadSynthetic\n"
                "- (void)setupPayloadWithSomethingNoHeaderDeclares:(id)thing { (void)thing; }\n"
                "@end\n")
        saved = (SETUP_CLASSES.get("HMAccessorySetupPayloadSynthetic"),
                 HEADER_OF_CLASS.get("HMAccessorySetupPayloadSynthetic"), PORT_INCLUDE)
        try:
            # and the table holds ONLY the synthetic class for the duration: the payload's own object is
            # in the port's directory, and a lookup pointed at the scratch directory would not find it --
            # which is a failure of the control's setup, not of the check.
            saved_table = dict(SETUP_CLASSES)
            SETUP_CLASSES.clear()
            SETUP_CLASSES["HMAccessorySetupPayloadSynthetic"] = {"class": "11.3", "11.3": synthetic}
            HEADER_OF_CLASS["HMAccessorySetupPayloadSynthetic"] = "HMAccessorySetupPayload.h"
            # PORT_INCLUDE is where an object's file is found, so the control's object is only found if
            # the lookup goes where the control wrote it: pointing it at the scratch directory, and
            # putting it back afterwards, is the whole of the substitution.
            PORT_INCLUDE = scratch
            synthetic_failures, _ = compare_setup(verbose=False)
        finally:
            PORT_INCLUDE = saved[2]
            SETUP_CLASSES.clear()
            SETUP_CLASSES.update(saved_table)
            if saved[0] is None and saved[1] is None:
                HEADER_OF_CLASS.pop("HMAccessorySetupPayloadSynthetic", None)
        if synthetic_failures:
            print("  control caught: %s" % "; ".join(synthetic_failures))
        else:
            print("  control NOT caught: a class the header does not declare went through unchecked")
            failures.append("the synthetic-class control was not caught")

    # The mutant pair, and the two halves are the point. A change that moves BYTES and not the API split
    # must stay green: a method relocated between the two objects without changing its release is still
    # bound, still by the same release, and a check that went red on it would be reading the file rather
    # than the contract. A 13.0 initialiser that lands in the 11.3 object must go red, by file and line.
    print("\nmutant: bytes changed, nothing bound changed -- a comment added inside the 13.0 object")
    with tempfile.TemporaryDirectory(dir=RUNS) as scratch:
        thirteen = os.path.join(scratch, SETUP_CLASSES["HMAccessorySetupPayload"]["13.0"])
        with open(os.path.join(port, SETUP_CLASSES["HMAccessorySetupPayload"]["13.0"])) as handle:
            text = handle.read()
        stage(scratch, "HMAccessorySetupPayload")
        with open(thirteen, "w") as handle:
            handle.write("// a mutant: bytes, and nothing else.\n" + text)
        original = (SETUP_CLASSES["HMAccessorySetupPayload"]["13.0"], PORT_INCLUDE)
        try:
            SETUP_CLASSES["HMAccessorySetupPayload"]["13.0"] = os.path.basename(thirteen)
            inert, _ = compare_setup(verbose=False)
        finally:
            # The lookup root goes back too, not just the table: a scratch directory that the enclosing
            # `with` then deletes is the root every LATER mutant reads through, so leaving it behind is
            # how one mutation's result becomes the next one's input.
            SETUP_CLASSES["HMAccessorySetupPayload"]["13.0"], PORT_INCLUDE = original
        if inert:
            print("  RED, which is WRONG: the bytes moved and no member changed")
            print("    %s" % "; ".join(inert))
            failures.append("a change that bound nothing went red")
        else:
            print("  green, which is right: no member changed, so no row of the contract moved")

    # A relocation BETWEEN the two objects, and what it turned out to be: the mutation does not compile.
    # The 11.3 object's body writes `_charon_setupPayloadURL`, the ivar that object synthesises, and the
    # 13.0 object declares the same property @dynamic -- so a file carrying both cannot be built at all.
    # That is a fact about the port rather than about the check, and it is printed as one: a scratch
    # copy that does not compile is not a check result, and reporting it as green or red would be a lie
    # in either direction. It is also why the per-object rule is not violated by accident here.
    print("\nmutant: the 11.3 initialiser's body moved into the 13.0 object, its release unchanged")
    with tempfile.TemporaryDirectory(dir=RUNS) as scratch:
        stage(scratch, "HMAccessorySetupPayload")
        thirteen = os.path.join(scratch, SETUP_CLASSES["HMAccessorySetupPayload"]["13.0"])
        with open(os.path.join(port, SETUP_CLASSES["HMAccessorySetupPayload"]["11.3"])) as handle:
            body = handle.read()
        moved = method_text(body, "- (instancetype)initWithURL:(NSURL *)setupPayloadURL")
        with open(os.path.join(port, SETUP_CLASSES["HMAccessorySetupPayload"]["13.0"])) as handle:
            thirteen_text = handle.read()
        with open(thirteen, "w") as handle:
            handle.write(append_to_implementation(thirteen_text, moved))
        original = (SETUP_CLASSES["HMAccessorySetupPayload"]["13.0"], PORT_INCLUDE)
        try:
            SETUP_CLASSES["HMAccessorySetupPayload"]["13.0"] = os.path.basename(thirteen)
            PORT_INCLUDE = scratch
            relocation_failures, _ = compare_setup(verbose=False)
        except SystemExit:
            relocation_failures = None
        finally:
            SETUP_CLASSES["HMAccessorySetupPayload"]["13.0"], PORT_INCLUDE = original
        if relocation_failures is None:
            print("  the scratch copy does not compile, and that is a fact about the port, not a verdict")
            print("  on the check: the 11.3 body writes the ivar only that object synthesises")
        else:
            print("  %s" % ("; ".join(relocation_failures) or "green"))

    print("\nmutant: the 13.0 initialiser in the 11.3 object")
    with tempfile.TemporaryDirectory(dir=RUNS) as scratch:
        stage(scratch, "HMAccessorySetupPayload")
        eleven_scratch = os.path.join(scratch, SETUP_CLASSES["HMAccessorySetupPayload"]["11.3"])
        # The whole 13.0 object, standing where the 11.3 one stands. It compiles -- the class extension
        # and the @dynamic come with it -- and it is the mistake a person actually makes: the newer
        # object copied over the older one, so the 11.3 release loses its member and gains a 13.0 one.
        with open(os.path.join(port, SETUP_CLASSES["HMAccessorySetupPayload"]["13.0"])) as handle:
            with open(eleven_scratch, "w") as out:
                out.write(handle.read())
        original = (SETUP_CLASSES["HMAccessorySetupPayload"]["11.3"], PORT_INCLUDE)
        try:
            SETUP_CLASSES["HMAccessorySetupPayload"]["11.3"] = os.path.basename(eleven_scratch)
            PORT_INCLUDE = scratch
            misplaced, _ = compare_setup(verbose=False)
        except SystemExit:
            misplaced = None
        finally:
            SETUP_CLASSES["HMAccessorySetupPayload"]["11.3"], PORT_INCLUDE = original
        if misplaced is None:
            print("  the scratch copy does not compile, so this proves nothing either way")
            failures.append("the 13.0-in-11.3 scratch copy did not compile, so the mutant proved nothing")
        elif misplaced:
            print("  caught: %s" % "; ".join(misplaced))
        else:
            print("  NOT caught: a 13.0 initialiser standing in for the 11.3 one went through unchecked")
            failures.append("the 13.0-in-11.3 mutant was not caught")

    # The control this whole piece exists for: a member the object DECLARES and does not implement. The
    # 11.3 object's -initWithURL: loses its body and gains a declaration of itself, which is what a person
    # writes when they mean to implement it and do not. It compiles -- the header already declares the
    # method, so the scratch copy is legal -- and the declaration is an ObjCMethodDecl in the port's own
    # file, exactly like the definition was. Reading the decl alone cannot tell the two apart, so this is
    # the mutation that says which of the two the check is reading; before the body test it went through
    # as green, because a node of the right kind in the right file was all it took.
    print("\ncontrol: an 11.3 member declared and not implemented")
    with tempfile.TemporaryDirectory(dir=RUNS) as scratch:
        stage(scratch, "HMAccessorySetupPayload")
        eleven_scratch = os.path.join(scratch, SETUP_CLASSES["HMAccessorySetupPayload"]["11.3"])
        with open(os.path.join(port, SETUP_CLASSES["HMAccessorySetupPayload"]["11.3"])) as handle:
            text = handle.read()
        definition = method_text(text, "- (instancetype)initWithURL:(NSURL *)setupPayloadURL")
        # The declaration goes ABOVE the @implementation: an @interface inside one does not parse, and a
        # scratch copy that does not compile would say nothing about the check either way.
        declaration = ("@interface HMAccessorySetupPayload (Charon11_3DeclaredOnly)\n"
                       "- (instancetype)initWithURL:(NSURL *)setupPayloadURL;\n"
                       "@end\n\n"
                       "@implementation HMAccessorySetupPayload\n")
        broken = text.replace(definition + "\n", "").replace(
            "@implementation HMAccessorySetupPayload\n", declaration, 1)
        if definition not in text or declaration not in broken:
            print("  the mutation did not apply, so it proves nothing")
            failures.append("the declared-only control did not apply to the 11.3 object")
        else:
            with open(eleven_scratch, "w") as out:
                out.write(broken)
            original = (SETUP_CLASSES["HMAccessorySetupPayload"]["11.3"], PORT_INCLUDE)
            try:
                SETUP_CLASSES["HMAccessorySetupPayload"]["11.3"] = os.path.basename(eleven_scratch)
                PORT_INCLUDE = scratch
                declared_only, _ = compare_setup(verbose=False)
            except SystemExit:
                declared_only = None
            finally:
                SETUP_CLASSES["HMAccessorySetupPayload"]["11.3"], PORT_INCLUDE = original
            if declared_only is None:
                print("  the scratch copy does not compile, so this proves nothing either way")
                failures.append("the declared-only control did not compile, so it proved nothing")
            elif declared_only:
                print("  control caught: %s" % "; ".join(declared_only))
            else:
                print("  control NOT caught: a member that is only DECLARED counted as bound")
                failures.append("the declared-only control was not caught")

    # The control: a scratch copy with one attribute flipped. This must be caught, or nothing above is.
    # A missing member, not a flipped attribute: this port writes its accessors out by hand, and a method
    # carries no attributes for the AST to compare, so deleting the accessor is the failure this piece
    # could actually have.
    print("\ncontrol: the same check with HMAccessory's cameraProfiles accessor removed")
    control_failures = []
    with tempfile.TemporaryDirectory(dir=RUNS) as scratch:
        broken = os.path.join(scratch, "HMAccessoryHome10_0.m")
        with open(os.path.join(port, "HMAccessoryHome10_0.m")) as handle:
            text = handle.read()
        with open(broken, "w") as handle:
            handle.write(text.replace("- (NSArray<HMCameraProfile *> *)cameraProfiles",
                                      "- (NSArray<HMCameraProfile *> *)charon_cameraProfilesRemoved"))
        seen = properties(ast(broken, "HMAccessory"))
        for member, line in sorted(EXPECTED["HMAccessory"].items()):
            header = next((x for x in seen.get(member, []) if x["file"].endswith(".h")), None)
            port = next((x for x in seen.get(member, []) if not x["file"].endswith(".h")), None)
            if header and port is None:
                control_failures.append("%s: the port declares no such member" % member)
        if control_failures:
            print("  control caught: %s" % "; ".join(control_failures))
        else:
            print("  control NOT caught: this piece's check cannot fail")
            failures.append("the HMAccessory control was not caught")

    print("\ncontrol: the same check with HMCameraProfile's weak removed from streamControl")
    with tempfile.TemporaryDirectory(dir=RUNS) as scratch:
        broken = os.path.join(scratch, "HMAccessoryProfile10_0.m")
        with open(source) as handle:
            text = handle.read()
        with open(broken, "w") as handle:
            handle.write(text.replace("@property (nullable, nonatomic, readonly, strong) HMCameraStreamControl *streamControl;",
                                      "@property (nullable, atomic, readonly, strong) HMCameraStreamControl *streamControl;"))
        control = properties(ast(broken, "HMCameraProfile"))
        caught = []
        for member, line in sorted(EXPECTED["HMCameraProfile"].items()):
            header = next((p for p in control.get(member, []) if p["file"].endswith(".h")), None)
            port_member = next((p for p in control.get(member, []) if not p["file"].endswith(".h") and not p.get("accessor")), None)
            if port_member and header and [a for a in header["attrs"] if a not in port_member["attrs"]]:
                caught.append("%s: %s" % (member, ", ".join(a for a in header["attrs"] if a not in port_member["attrs"])))
        if caught:
            print("  control caught: %s" % "; ".join(caught))
        else:
            print("  control NOT caught: the check cannot fail, so it is not a check")
            failures.append("the control was not caught")

    # The two protocols: the selector set the port declares against the one the header declares, and the
    # split, which is the part that matters here - an optional method turned required would make a
    # conformer that legitimately omits it fail to compile.
    print("\nthe two delegate protocols, of 8.0:")
    port_dir = os.path.dirname(source)
    port_protocols = os.path.join(port_dir, "HMHomeDelegateProtocols8_0.m")
    for protocol, header in sorted(PROTOCOLS.items()):
        header_path = os.path.join(HM_HEADERS, header)
        header_set, port_set = declared_set(port_protocols, protocol, header_path, port_protocols)
        if not port_set or not header_set:
            failures.append("%s: the comparison read %d from the header and %d from the port - one side is "
                            "empty, so every member would differ and the check would pass for the wrong "
                            "reason" % (protocol, len(header_set), len(port_set)))
        print("  %-24s header %d, port %d, %d optional in the header"
              % (protocol, len(header_set), len(port_set),
                 sum(1 for _, state in header_set if state == "optional")))
        for difference in sorted(header_set ^ port_set):
            side, state = difference
            where = "the port has the header does not" if difference in port_set else "missing from the port"
            failures.append("%s: %s is %s (%s where the header says %s)"
                            % (protocol, side, where, state,
                               dict(header_set).get(side, "nothing")))

    # Control 1, per protocol: an @optional flipped to @required on a scratch copy. The split is the whole
    # point of these two, so a port that required a method the header calls optional must be caught.
    print("\ncontrol: one @optional flipped to @required in the port, per protocol")
    import shutil
    for protocol, header in sorted(PROTOCOLS.items()):
        header_path = os.path.join(HM_HEADERS, header)
        scratch_dir = os.path.join(RUNS, "scratch")
        os.makedirs(scratch_dir, exist_ok=True)
        broken = os.path.join(scratch_dir, "%s-optional-flipped.m" % protocol)
        shutil.copyfile(port_protocols, broken)
        with open(broken) as handle:
            text = handle.read()
        block = text.index("@protocol %s " % protocol)
        marker = text.index("@optional", block)
        with open(broken, "w") as handle:
            handle.write(text[:marker] + "@required" + text[marker + len("@optional"):])
        header_set, port_set = declared_set(broken, protocol, header_path, broken)
        differing = sorted(header_set ^ port_set)
        if differing:
            print("  %-24s control caught: %s" % (protocol, "; ".join(
                "%s is %s where the header says %s" % (side, state, dict(header_set).get(side, "nothing"))
                for side, state in differing[:3])))
        else:
            print("  %-24s control NOT caught" % protocol)
            failures.append("%s: the required/optional control was not caught" % protocol)

    # Control 2, per protocol: a selector removed from the scratch copy, which the set comparison must
    # notice as the port declaring fewer than the header.
    print("\ncontrol: one declaration deleted from the port, per protocol")
    for protocol, header in sorted(PROTOCOLS.items()):
        header_path = os.path.join(HM_HEADERS, header)
        scratch_dir = os.path.join(RUNS, "scratch")
        os.makedirs(scratch_dir, exist_ok=True)
        broken = os.path.join(scratch_dir, "%s-selector-deleted.m" % protocol)
        with open(port_protocols) as handle:
            lines = handle.read().split("\n")
        block = next(i for i, line in enumerate(lines) if line.startswith("@protocol %s " % protocol))
        first = next(i for i in range(block, len(lines)) if lines[i].strip().startswith("-"))
        victim = next((n for n in range(first, len(lines))
                       if lines[n].strip().startswith("-") and "]" not in lines[n]), None)
        end = victim
        while ";" not in lines[end]:
            end += 1
        removed = [line for line in lines[:victim - 1] if line.strip().startswith("//")]
        kept = lines[:victim - 1] + removed + lines[end + 1:]
        with open(broken, "w") as handle:
            handle.write("\n".join(kept))
        header_set, port_set = declared_set(broken, protocol, header_path, broken)
        missing = sorted(s for s, _ in header_set - port_set)
        if missing:
            print("  %-24s control caught: %s is missing from the port (%d in the header, %d in the port)"
                  % (protocol, missing[0], len(header_set), len(port_set)))
        else:
            print("  %-24s control NOT caught: deleting one declaration changed nothing" % protocol)
            failures.append("%s: the deleted-selector control was not caught" % protocol)

    if failures:
        print("\nFAILED")
        for failure in failures:
            print("  %s" % failure)
        return 1
    print("\nok: every declared member matches the header's type, nullability and attributes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
