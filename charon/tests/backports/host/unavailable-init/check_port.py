#!/usr/bin/env python3
"""check_port.py - the port's -init and +new for every class of one framework, in the source and in the
compiled armv7 objects.

    python3 check_port.py <package dir> <compiled objects dir> <repository root> <framework> [...]

Held to expectations.tsv, which is the transcription of what Apple's own class was measured to do, so
nothing here is an expectation taken from the code under test. Where each row's answer came from is the
table's own `oracle` column: `host` for the host's framework, `ios16` for a class read out of a real
release's own cache. Both are measurements of Apple's class; neither is a reading of the header.

THE RULE, and it is per selector rather than per class: where Apple's own class defines -init, the port
defines -init with the measured body; where Apple's own class inherits +new, the port does not define
+new either. A definition where Apple's class has none would put the selector in the port's metadata
where Apple's has none, changing what the class IS and answering the caller exactly what NSObject's
already answers. That is the rule the coordinator settled on 2026-10-03
(coordination/wave-2026-10-03/QUEUE.md), and the three frameworks differ: SensorKit's classes define
both selectors, HealthKit's define -init and inherit +new, and AVFoundation's one class in this table
(AVCaptureDeviceDiscoverySession) defines -init with an answer of nil rather than a refusal and inherits
+new - the last new value of `port-init`, `nil`, next to `raise` and `none`.

THE ANSWER a measured -init gives is the table's `port-init` column, and there are four of them, because
four different bodies were measured out of the release's own code:

  raise     the macro raises the measured exception with the measured reason, and the object's own
            instance list carries -init;
  nil       the macro answers nil and the object carries -init - not the SensorKit shape and not the
            HealthKit one: six of HomeKit's own classes release the receiver and answer nil, which is a
            third body and is read out of the code rather than off the header;
  construct the class's block defines -init of its own, because the release builds the object here rather
            than refusing or answering nothing, and the object carries it;
  none      Apple's class carries the selector nowhere, so the port defines neither (unchanged).

For each class two things are asked, and they fail differently, which is why both are:

  * THE SOURCE. The class's @implementation block must carry the macro the table names for every selector
    the table says is owed, with the reason that was measured, and must not define a selector the table
    says is not owed. The macro's own body is read too, so a macro that stopped raising, or that raised
    something else, is caught. A source check alone would pass on a method the compiler dropped.

  * THE OBJECT. Every selector the table says is owed must be in the class's own list of the compiled
    object - -init in the instance list, +new in the metaclass list - and every selector the table says
    is not owed must NOT be there. An object check alone would pass on a pair that raises the wrong
    thing, so the two are asked together.

The class's method list is read with the repository's own reader, tools/corpus/objc-inventory.lua, which
is the one the corpus reads a built library with.
"""
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


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


def macro_definition(package, name):
    """A macro's own body, out of the headers of the package, so a macro that changed is part of the
    check. The body runs from the `#define` to the first line that does not end in a backslash."""
    for folder, _, files in os.walk(package):
        for entry in sorted(files):
            if not entry.endswith(".h"):
                continue
            lines = open(os.path.join(folder, entry), encoding="utf-8", errors="replace").read().split("\n")
            for index, line in enumerate(lines):
                if not re.match(r"#define %s\b" % re.escape(name), line):
                    continue
                body = [line]
                while body[-1].rstrip().endswith("\\") and index + 1 < len(lines):
                    index += 1
                    body.append(lines[index])
                return "\n".join(body)
    return None


def methods(obj, root):
    """The object's own selectors, instance and class, keyed by class name.

    Read with the repository's own reader - tools/corpus/objc-inventory.lua, the same one the corpus
    reads a built library with - and not with a second opinion parsed out of `otool -ov` here: a class's
    own method list is the question, and one reader that answers it is enough.
    """
    env = dict(os.environ, CHARON_ROOT=root)
    done = subprocess.run(["xmake", "l", os.path.join(root, "tools", "corpus", "objc-inventory.lua"),
                           obj, "armv7"], cwd=root, env=env, capture_output=True, text=True)
    # An object the reader cannot read carries no selector this check can find, which is the answer the
    # row needs - not a crash: the control of this harness IS an empty object, and a check that died on
    # it would have proved that it runs, not that it notices.
    found = {}
    if done.returncode != 0:
        return found
    for line in done.stdout.split("\n"):
        parts = line.rstrip("\n").split("\t")
        if len(parts) != 7 or parts[0] != "class":
            continue
        found[parts[1]] = {"instance": set(parts[4].split(",")) - {""},
                           "class": set(parts[5].split(",")) - {""}}
    return found


def block_of(text, cls):
    """The class's own @implementation block, never a category's."""
    # The class's own @implementation, never a category's, and with the ivar block on the same line as
    # the name - which is how this package writes a class that has ivars.
    match = re.search(r"^@implementation %s(?!\s*\()[^\n]*\n(.*?)^@end" % re.escape(cls), text, re.S | re.M)
    return match.group(1) if match else None


def check_source(body, row, package, problems):
    """Both selectors of one class, in the source, against what the table says is owed."""
    for selector, sign, owed in (("init", "-", row["port-init"]), ("new", "+", row["port-new"])):
        defined_by_hand = re.search(r"^\s*[-+]\s*\(instancetype\)\s*%s\b" % selector, body, re.M)
        if owed == "none":
            if defined_by_hand:
                problems.append("%s is defined here and Apple's own class carries neither: a definition "
                                "would answer the caller what NSObject's already answers" % selector)
            continue
        # A body the release builds is written in the class, not in a macro: what the release does there
        # is its own construction, and the port's answer is the port's own construction.
        if owed == "construct":
            if selector == "init" and not defined_by_hand:
                problems.append("the table says the release builds the object in -init and the block does "
                                "not define one")
            continue
        if row["port-macro"] == "-":
            problems.append("the table says %s is owed and names no macro for it" % selector)
            continue
        # Which selector the macro defines is read out of the macro's own body, not guessed here: the
        # macro is one pair for SensorKit and one method for HealthKit, and the table says per selector.
        definition = macro_definition(package, row["port-macro"])
        if definition is None:
            problems.append("%s is owed but %s is defined nowhere under %s"
                            % (selector, row["port-macro"], package))
            continue
        macro_has = re.search(re.escape("%s(instancetype)%s" % (sign, selector)), definition)
        if not macro_has:
            problems.append("%s is owed but %s does not define %s"
                            % (selector, row["port-macro"], selector))
            continue
        if not re.search(r"\b%s\b" % re.escape(row["port-macro"]), body):
            problems.append("%s is owed and the block does not answer with %s"
                            % (selector, row["port-macro"]))
            continue
        if owed == "nil":
            # The measured body answers nil: `[self release]; return nil` in the release's own code, and
            # the port answers nil. A macro that raised here would be a different body, and a macro that
            # forwarded to [super init] would be NSObject's answer, which is the third thing it is not.
            if "raise" in definition or "NSException" in definition:
                problems.append("the measured body answers nil and the macro raises")
            if not re.search(r"\breturn\s+nil\s*;", definition):
                problems.append("the measured body answers nil and the macro does not return nil")
            if "[super init]" in definition:
                problems.append("the measured body answers nil and the macro forwards to NSObject's -init")
            continue
        if row["exception"] not in definition:
            problems.append("the measured exception is %s and the macro raises something else"
                            % row["exception"])
        # The measured reason, in whichever of the two forms it was measured in: a literal has to appear
        # at the call site or in the macro, and a template - a reason the framework builds from the class
        # name - has to appear as the macro's format string with the class read off the receiver, because
        # that is how the six HealthKit classes produce six different sentences from one line.
        if row.get("reason-template"):
            if ('@"' + row["reason-template"] + '"') not in definition:
                problems.append("the measured reason is built as %r and the macro carries no such "
                                "format string" % row["reason-template"])
            # Which value fills the template is the measurement's own: HealthKit's six sentences name the
            # class, so the macro has to read it off the receiver; HomeKit's two name the selector, so
            # the macro has to read the selector instead. A sentence that names the class is the half that
            # tells them apart, and the table's reason column is that sentence.
            if row["class"] in row["reason"] and "NSStringFromClass([self class])" not in definition:
                problems.append("the measured reason names the class and the macro does not read it")
            if row["class"] not in row["reason"] and "NSStringFromSelector(_cmd)" not in definition:
                problems.append("the measured reason does not name the class and the macro does not read "
                                "the selector, which is what fills it")
        elif row["reason"] and ('@"' + row["reason"] + '"') not in body \
                and ('@"' + row["reason"] + '"') not in definition:
            problems.append("the reason measured is %r and neither the block nor the macro carries it"
                            % row["reason"])


def check_object(carried, row, selector, problems):
    """The selector is either owed or not, and `owed` is what the row's answer was: `raise` for the classes
    whose own -init refuses, `nil` for the classes whose own -init answers nil and raises nothing, `construct` for a
    class whose own -init builds the object, `none` for a selector Apple's own class does not define and every
    class inherits. The four are the same question with four answers, so they are one branch."""
    kind = "instance" if selector == "init" else "class"
    there = ("-" + selector) in carried[kind]
    # Every answer that is a definition asks for the selector in the object's own list: raise, nil and
    # construct all mean the port defines the method, and which body it has is what the source check and
    # the plants are about.
    owed = row["port-" + selector]
    if owed in ("raise", "nil", "construct") and not there:
        problems.append("%s is not in the class's %s list of %s, and the measured answer is %s"
                        % (selector, kind, row["port-object"], owed))
    elif owed == "none" and there:
        problems.append("%s is in the class's %s list of %s, and Apple's own class carries neither"
                        % (selector, kind, row["port-object"]))


def main():
    if len(sys.argv) < 5:
        sys.exit("check_port.py: pass the package directory, the compiled objects directory, the "
                 "repository root and at least one framework")
    package, objdir, root = sys.argv[1:4]
    wanted = sys.argv[4:]
    rows = [r for r in rows_of(os.path.join(HERE, "expectations.tsv")) if r["framework"] in wanted]
    if not rows:
        sys.exit("check_port.py: expectations.tsv holds no row for %s" % ", ".join(wanted))
    failures, ok = [], 0
    for row in rows:
        name, problems = row["class"], []
        source = os.path.join(package, row["port-source"])
        obj = os.path.join(objdir, row["port-object"])
        body = block_of(open(source, encoding="utf-8").read(), name) \
            if os.path.exists(source) else None
        if body is None:
            problems.append("no @implementation %s in %s" % (name, row["port-source"]))
        else:
            check_source(body, row, package, problems)
        carried = {}
        if not os.path.exists(obj):
            problems.append("%s does not exist" % obj)
        else:
            carried = methods(obj, root).get(name, {"instance": set(), "class": set()})
            check_object(carried, row, "init", problems)
            check_object(carried, row, "new", problems)
        print("%-44s source: init=%-5s new=%-5s   object: %s"
              % (name, row["port-init"], row["port-new"],
                 ("agrees" if not [p for p in problems if "list of" in p or "does not exist" in p]
                  else "DIFFERS")))
        if problems:
            failures.extend("%s: %s" % (name, problem) for problem in problems)
        else:
            ok += 1
    for failure in failures:
        print("FAIL " + failure)
    print("unavailable-init-port %s: %d of %d classes as measured, in the source and in the object, "
          "%d failures%s" % (",".join(wanted), ok, len(rows), len(failures),
                             "" if not failures else "  <- SEE FAIL"))
    return 1 if failures else 0


sys.exit(main())
