#!/usr/bin/env python3
"""plants.py - the mutations that must turn check_port.py red, chosen from the table.

    python3 plants.py <expectations.tsv> <package dir> <framework>...

Prints one TSV line per plant: label, framework, file (relative to the package), needle, replacement,
with a newline in either of the last two written as the two characters \n so that one plant is one line.
Nothing here
is written by hand: the file is the one the table names for the class, the needle is that class's own
call of the macro the table names, and the replacement is the mistake. A plant written by hand stops
applying the moment a row moves, and a plant that does not apply proves nothing.

Four mistakes, one per answer a measured -init was found to give:

  1. a class that must refuse is left to NSObject instead - the macro's call commented out;
  2. a class that must NOT be defined gets a definition anyway - the macro's call added;
  3. the macro raises an exception that was not measured - the name in its own raise replaced;
  4. a class whose measured -init answers nil raises instead, or forwards to NSObject's - the macro's
     call replaced with the raise that is not its body. HomeKit is where that body was measured (six of
     its classes: the body is `[self release]; return nil`), so without it a nil-shaped answer would
     never be proved able to turn this check red.
"""
import os
import re
import sys


def rows_of(path):
    header, rows = None, []
    for line in open(path, encoding="utf-8"):
        if line.startswith("#") or not line.strip():
            continue
        fields = line.rstrip("\n").split("\t")
        if header is None:
            header = fields
            continue
        rows.append(dict(zip(header, fields)))
    return rows


def anchor_line(source, cls):
    """The two lines a definition goes between: the class's own @implementation line and the one after
    it, or the brace that closes its ivar block and the one after that, because a macro inside the
    braces is not a method.

    TWO lines and not one, because a one-line needle of a closing brace matches the first brace in the
    file rather than this class's - measured: a plant anchored on `}` rewrote an unrelated brace and the
    mutant did not build, which is not the same as the check noticing."""
    lines = open(source, encoding="utf-8").read().split("\n")
    for index, line in enumerate(lines):
        if not line.startswith("@implementation %s" % cls):
            continue
        if not line.rstrip().endswith("{"):
            return line + "\n" + lines[index + 1]
        depth = 1
        scan = index + 1
        while scan < len(lines) and depth:
            depth += lines[scan].count("{") - lines[scan].count("}")
            scan += 1
        if scan >= len(lines):
            return None
        pair = lines[scan - 1] + "\n" + lines[scan]
        # The pair has to be in the file as it stands, or the needle matches nothing and the plant
        # reports that it did not apply rather than quietly checking nothing.
        return pair if pair in "\n".join(lines) else lines[scan]
    return None


def macro_takes_argument(package, macro):
    """Whether the macro is defined with a parameter, read off its own #define line and not off the row.

    The call as a class writes it depends on it: `#define M(x)` is called `M(@"reason")` and `#define M`
    is called bare, and a needle built from the row alone gets that wrong in both directions - measured:
    picking "bare" whenever the measured reason is empty made SensorKit's plant replace
    `CHARON_SENSORKIT_UNCREATABLE_NEW_AND_INIT(@"Use initWithSensor:")` with the bare name, and the mutant
    did not build, which is not the same as the check noticing (2026-10-03)."""
    for folder, _, files in os.walk(package):
        for entry in sorted(files):
            if not entry.endswith(".h"):
                continue
            for line in open(os.path.join(folder, entry), encoding="utf-8", errors="replace"):
                match = re.match(r"#define %s(\(|$)" % re.escape(macro), line)
                if match:
                    return match.group(1) == "("
    return False


def call_of(row, package):
    """The macro's name as THIS class writes it, or None when the row names no macro."""
    name = row["port-macro"]
    if not name or name == "-":
        return None
    if not macro_takes_argument(package, name):
        return name
    return name + '(@"%s")' % row["reason"]


def block_of(text, cls):
    """The class's own @implementation block, never a category's - the same rule check_port.py reads the
    source with, and needed here for the same reason: a file may hold two classes and one macro (measured:
    HealthKit/HKClinicalRecord120.m holds HKClinicalRecord and HKFHIRResource, and both call
    CHARON_HEALTHKIT_UNCREATABLE_INIT), so "how often does this needle occur in the file" is the wrong
    question and "how often in THIS class's block" is the right one."""
    match = re.search(r"^@implementation %s(?!\s*\()[^\n]*\n(.*?)^@end" % re.escape(cls), text, re.S | re.M)
    return match.group(1) if match else None


def header_of(package, macro):
    """The header that defines the macro, so the third plant edits the macro's own body."""
    for folder, _, files in os.walk(package):
        for entry in sorted(files):
            if not entry.endswith(".h"):
                continue
            path = os.path.join(folder, entry)
            if re.search(r"^#define %s\b" % re.escape(macro), open(path, encoding="utf-8").read(), re.M):
                return os.path.relpath(path, package)
    return None


def raise_line(package, header, exception):
    """The macro's raise, as the one piece of it that is on one line: `raise:<exception>`.

    Not the whole statement - a raise spans two or three continued lines in these macros, and a needle
    that swallowed the continuations would not compile when it was replaced. The exception name is the
    part the check reads, so it is the part the plant moves.
    """
    body = open(os.path.join(package, header), encoding="utf-8").read()
    needle = "raise:%s" % exception
    return needle if needle in body else None


def main():
    table, package = sys.argv[1], sys.argv[2]
    wanted = sys.argv[3:] or sorted({r["framework"] for r in rows_of(table)})
    for framework in wanted:
        mine = [r for r in rows_of(table) if r["framework"] == framework]
        # `nil` is owed exactly as `raise` is: the class's own -init exists in Apple's metadata and in the
        # port's, and what it answers - a refusal or nil - is the row's `answer`, not whether it is owed.
        owes = [r for r in mine if r["port-init"] in ("raise", "nil")]
        none = [r for r in mine if r["port-init"] == "none"]
        nils = [r for r in mine if r["port-init"] == "nil"]
        if not owes and not none and not nils:
            continue
        macro = owes[0]["port-macro"] if owes else "-"
        # The call as the class writes it: with the literal reason when the measurement gave one.
        call = None
        for row in owes:
            # The call as the class writes it, decided by the MACRO's own #define line and not by the row:
            # a macro that takes a reason is called with the measured reason - a row whose measured reason
            # is the empty string still writes `MACRO(@"")`, because that is the reason that was measured -
            # and a macro that takes none is written bare, which is the case for the two whose reason the
            # framework builds from the class name and for the one whose answer is not a refusal at all.
            candidate = call_of(row, package)
            if candidate is None:
                continue
            source = os.path.join(package, row["port-source"])
            body = block_of(open(source, encoding="utf-8").read(), row["class"])
            # Exactly once in THAT class's own block, or this plant does not run. The needle is the macro's
            # name, and a name can occur where the macro is not called - measured on this tree, where the
            # replacement landed in a comment that named the macro, the call stayed, the object kept its
            # -init, and check_port.py went green on the mutant (2026-10-03). str.replace with no count is
            # the silent no-op this table's own readers are careful about, and a plant is the same edit.
            if body is not None and body.count(candidate) == 1:
                call, owner = candidate, row
                break
            if body is not None and candidate in body:
                sys.exit("%s holds %d copies of %s in the @implementation of %s, so a plant written on it"
                         " could replace the wrong one" % (row["port-source"], body.count(candidate),
                                                          candidate, row["class"]))
        if call:
            # Commented out rather than deleted: a delete leaves a file the compiler is then asked about
            # for a different reason, and a mutant that does not build has proved nothing about the
            # check. What the check has to notice is that the class no longer answers with the macro.
            print("\t".join(["a class that must refuse is left to NSObject instead", framework,
                             owner["port-source"].split("/")[-1], call, "/* %s */" % call]))
        if none:
            anchor = anchor_line(os.path.join(package, none[0]["port-source"]), none[0]["class"])
            # The anchor is two lines of the file's own, and it has to be there: a plant whose needle does
            # not occur is a plant that checks nothing, which plants.py reports as no line at all.
            # The mistake is "a class that must NOT be defined gets a definition anyway", so the definition
            # is written the way THAT class's own file writes one. Where that file already calls the refusal
            # macro, that macro is what a mistaken author reaches for; where it calls nothing - measured on
            # SensorKit/SensorKit260.m, whose SRAcousticSettings block has no macro call and where the macro
            # is not in scope at that point either, so the planted mutant did not build and the check never ran
            # (a pre-existing red on main, measured here on 2026-10-03 with main's own plants.py) - the
            # definition is NSObject's own, spelled out, which needs nothing in scope.
            target = open(os.path.join(package, none[0]["port-source"]), encoding="utf-8").read()
            insert = (call_of(owes[0], package)
                      if owes and call_of(owes[0], package) in target else
                      "-(instancetype)init { return [super init]; }")
            if anchor:
                print("\t".join(["a class that must NOT be defined gets a definition anyway", framework,
                                 none[0]["port-source"].split("/")[-1],
                                 anchor.replace("\n", "\\n"),
                                 (anchor + "\n" + insert).replace("\n", "\\n")]))
        # The nil-shaped answer proved able to turn the check red: the macro's own call replaced with the
        # raise of another framework's shape, which is the mistake this check has to notice.
        for row in nils:
            call = row["port-macro"]
            source = os.path.join(package, row["port-source"])
            if call in open(source, encoding="utf-8").read():
                # A whole method, because the macro is used where a method goes: a replacement that is a
                # bare statement does not compile there, and a mutant that does not build has proved
                # nothing about the check.
                print("\t".join(["a class whose measured -init answers nil raises instead", framework,
                                 row["port-source"].split("/")[-1], call,
                                 "- (instancetype)init { [NSException raise:"
                                 "NSInternalInconsistencyException format:@\"raised\"]; return nil; }"]))
                break
        if not owes:
            continue
        header = header_of(package, macro)
        other = "NSGenericException" if owes[0]["exception"] != "NSGenericException" else "NSRangeException"
        line = raise_line(package, header, owes[0]["exception"]) if header else None
        if header and line:
            print("\t".join(["the macro raises an exception that was not measured", framework,
                             os.path.basename(header), line, "raise:" + other]))


main()
