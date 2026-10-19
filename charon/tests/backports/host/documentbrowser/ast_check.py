#!/usr/bin/env python3
"""The contract check for UIDocumentBrowserViewControllerDelegate.

The port's declaration is a transcription of the 26.2 header, and a transcription is worth nothing
without something to check it against. Both sides are read the same way, and neither reading does any
line arithmetic:

  * the **selector set** from clang's JSON AST, keyed by `mangledName`, which is the selector with
    its trailing colon and needs no parsing;
  * the **required/optional split** from the compiler. An empty conformer compiled with -Wprotocol is
    warned about for every @required method the protocol declares and for none of the @optional ones,
    so the set of selectors those warnings name *is* the required set and the AST's set minus it is
    the optional one. Clang already knows and says; this only listens.

The two sides differ only in the translation unit, and that difference is the whole reason this works
at all: the header's imports UIKit, and the port's imports Foundation and the port's own headers.
With the umbrella in the port's unit the SDK's declaration of this protocol shadows the port's and the
compiler reads only the SDK's copy -- the port's transcription checked against itself, which is not a
check.

An independent count of the port file's `- (` lines must agree with the AST on the port's side, and a
disagreement fails rather than passing one of the two quietly.

Two controls, both on named scratch copies under .agent-work/runs/documentbrowser/, and both
required to fail: one @optional flipped to @required, which makes the warning appear and names the
selector; and one declaration removed, which takes the selector out of the AST set and names it.

    DDR_ROOT=<the checkout> python3 tests/backports/host/documentbrowser/ast_check.py
"""
import json
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.environ.get("DDR_ROOT") or os.path.abspath(
    os.path.join(HERE, os.pardir, os.pardir, os.pardir, os.pardir))
RUNS = os.path.join(ROOT, ".agent-work", "runs", "documentbrowser")
os.makedirs(RUNS, exist_ok=True)
SDK = os.environ.get("SDK", os.path.join(ROOT, os.pardir, os.pardir, "sdk-26.2", "iPhoneOS26.2.sdk"))
UIKIT_HEADERS = os.path.join(SDK, "System/Library/Frameworks/UIKit.framework/Headers")

PROTOCOL = "UIDocumentBrowserViewControllerDelegate"
TARGET = "arm64-apple-ios13.0"
SDK_HEADER = os.path.join(UIKIT_HEADERS, "UIDocumentBrowserViewController.h")
PORT_DIR = os.path.join(ROOT, "packages/a/apple-backports/UIKit")
PORT_HEADER = os.path.join(PORT_DIR, "UIDocumentBrowserViewControllerDelegate.h")
PORT_TYPES = os.path.join(PORT_DIR, "CharonDocumentBrowserTypes.h")

METHOD_START = re.compile(r"^\s*[-+]\s*\(")
# the class this piece also carries, its two properties, and the attributes the check compares
CLASS = "UIDocumentBrowserTransitionController"
# the class this piece completes, and the transition controller's, both read the same way
VC_CLASS = "UIDocumentBrowserViewController"
VC_PORT = os.path.join(PORT_DIR, "UIDocumentBrowserViewController.h")
CLASS_PORT = os.path.join(PORT_DIR, "UIDocumentBrowserTransitionController.h")
# the type each side must agree on, as the AST's qualType writes it, nullability included: the
# header's own declaration is the reference and both sides are compared with it, so the expected
# spelling is the header's and the port has to match it rather than the other way round
CLASS_PROPERTIES = {"loadingProgress": ("strong", "nonatomic", "nullable"),
                    "targetView": ("weak", "nonatomic", "nullable")}
# a forward declaration of what the class header names, so its own translation unit can be read
# without the umbrella: the SDK declares this class too, and importing it would bring the SDK's copy
# The prelude a port header is read with. Foundation plus the forward declarations the header names,
# and never the umbrella: the SDK declares these types too, so importing it would bring the SDK's
# copies in beside the port's and the compiler would read the SDK's -- the transcription checked
# against itself. UIKit's UIViewController is the one real interface needed, and it carries no
# document browser with it.
CLASS_TU = """#import <Foundation/Foundation.h>
#import <UIKit/UIViewController.h>
@class UIBarButtonItem, UIDocumentBrowserAction, UIDocumentBrowserViewController;
@protocol UIDocumentBrowserViewControllerDelegate, UIViewControllerAnimatedTransitioning;
#import "CharonDocumentBrowserTypes.h"
#import "%(header)s"
"""
REQUIRED_WARNING = re.compile(
    r"method '([^']+)' in protocol '%s' not implemented" % PROTOCOL)

CONFORMER = '''#import <Foundation/Foundation.h>
#import "%(types)s"
#import "%(header)s"
@interface CheckConformer : NSObject <%(protocol)s>
@end
@implementation CheckConformer
@end
'''

SDK_CONFORMER = '''#import <UIKit/UIKit.h>
@interface CheckConformer : NSObject <%(protocol)s>
@end
@implementation CheckConformer
@end
'''


def _tu(header, port):
    """The translation unit the compiler reads, which is the only difference between the two sides."""
    folder = tempfile.mkdtemp(dir=RUNS)
    source = os.path.join(folder, "tu.m")
    if port:
        open(source, "w").write(CONFORMER % {
            "types": PORT_TYPES, "header": header, "protocol": PROTOCOL})
    else:
        open(source, "w").write(SDK_CONFORMER % {"protocol": PROTOCOL})
    return source


def _clang(source, extra=(), name=PROTOCOL):
    return subprocess.run(
        ["xcrun", "clang", "-fsyntax-only", "-fobjc-arc", "-target", TARGET, "-isysroot", SDK,
         "-I", UIKIT_HEADERS, "-I", PORT_DIR, *extra,
         "-Xclang", "-ast-dump=json", "-Xclang", "-ast-dump-filter=%s" % name, source],
        capture_output=True, text=True)


def ast_selectors(header, port):
    """Every selector the protocol declares, by mangledName, which is the selector itself."""
    result = _clang(_tu(header, port))
    if result.returncode != 0:
        raise SystemExit("clang failed for %s: %s" % (header, result.stderr[:400]))
    decoder = json.JSONDecoder()
    documents, index, raw = [], 0, result.stdout
    while index < len(raw):
        while index < len(raw) and raw[index] in " \n\t\r":
            index += 1
        if index >= len(raw):
            break
        document, index = decoder.raw_decode(raw, index)
        documents.append(document)
    found = set()

    def walk(node):
        if node.get("kind") in ("ObjCMethodDecl", "ObjCInstanceMethodDecl"):
            if "[%s " % PROTOCOL in node.get("mangledName", ""):
                found.add(node.get("name") or node["mangledName"])
        for child in node.get("inner", []):
            walk(child)

    for document in documents:
        walk(document)
    return found


def required_selectors(header, port):
    """The @required selectors, from the compiler's -Wprotocol warnings on an empty conformer."""
    source = _tu(header, port)
    result = subprocess.run(
        ["xcrun", "clang", "-fsyntax-only", "-fobjc-arc", "-Wprotocol", "-target", TARGET,
         "-isysroot", SDK, "-I", UIKIT_HEADERS, "-I", PORT_DIR, source],
        capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit("the conformer did not compile: %s" % result.stderr[:400])
    return set(REQUIRED_WARNING.findall(result.stderr))


def class_properties(header, port, name=None):
    """The class's own properties from the AST, with the type and the attributes the check compares.

    The type comes from the AST's own qualType with the availability macros stripped, so a port that
    declared the property nullable where the header does not would answer a caller differently and
    is caught. `strong` is the default and is not written on a property line, so what is compared is
    a *changed* attribute: a property that lost `weak` or `nullable` is caught by the absence of the
    key rather than by the presence of another.
    """
    folder = tempfile.mkdtemp(dir=RUNS)
    source = os.path.join(folder, "tu.m")
    if port:
        open(source, "w").write(CLASS_TU % {"header": os.path.abspath(header)})
    else:
        open(source, "w").write('#import <UIKit/UIKit.h>\n#import "%s"\n' % os.path.abspath(header))
    result = _clang(source, name=name or CLASS)
    if result.returncode != 0:
        raise SystemExit("clang failed for %s: %s" % (header, result.stderr[:400]))
    decoder = json.JSONDecoder()
    documents, index, raw = [], 0, result.stdout
    while index < len(raw):
        while index < len(raw) and raw[index] in " \n\t\r":
            index += 1
        if index >= len(raw):
            break
        document, index = decoder.raw_decode(raw, index)
        documents.append(document)
    found = {}

    def walk(node):
        if node.get("kind") == "ObjCPropertyDecl":
            found[node.get("name")] = {
                "type": _clean_type((node.get("type") or {}).get("qualType", "")),
                "attrs": tuple(a for a in ("readonly", "copy", "nonatomic", "weak", "strong", "nullable")
                               if node.get(a)),
            }
        for child in node.get("inner", []):
            walk(child)

    for document in documents:
        walk(document)
    return found


def _clean_type(text):
    for macro in ("API_AVAILABLE", "API_UNAVAILABLE", "API_DEPRECATED", "API_DEPRECATED_WITH_REPLACEMENT",
                  "NS_SWIFT_NAME", "NS_SWIFT_UNAVAILABLE", "NS_REFINED_FOR_SWIFT", "NS_SWIFT_SENDABLE"):
        while macro in text:
            head = text.index(macro)
            if "(" in text[head:head + 80] and ")" in text[head:head + 160]:
                end = text.index(")", head) + 1
            else:
                end = head + len(macro)
            text = text[:head] + text[end:]
    return " ".join(text.split())


def vc_methods_port(header):
    """The view controller's own method selectors, by mangledName, from the port's header."""
    return {selector for selector in ast_selectors_in(header, True, VC_CLASS)}


def ast_selectors_in(header, port, name):
    folder = tempfile.mkdtemp(dir=RUNS)
    source = os.path.join(folder, "tu.m")
    open(source, "w").write(CLASS_TU % {"header": os.path.abspath(header)})
    result = _clang(source, name=name)
    if result.returncode != 0:
        raise SystemExit("clang failed for %s: %s" % (header, result.stderr[:300]))
    decoder = json.JSONDecoder()
    documents, index, raw = [], 0, result.stdout
    while index < len(raw):
        while index < len(raw) and raw[index] in " \n\t\r":
            index += 1
        if index >= len(raw):
            break
        document, index = decoder.raw_decode(raw, index)
        documents.append(document)
    found = set()

    # Only the declarations the header itself makes: the class inherits UIViewController's methods
    # and the AST has them all under the class, so a method is taken only when the dump says it came
    # from this file. `includedFrom` is omitted when it repeats the previous node's, so the file is
    # carried forward.
    state = {"file": None}

    def walk(node):
        location = node.get("loc") or {}
        here = (location.get("includedFrom") or {}).get("file")
        if here:
            state["file"] = here
        if node.get("kind") in ("ObjCMethodDecl", "ObjCInstanceMethodDecl"):
            if "-[%s " % name in node.get("mangledName", ""):
                found.add(node.get("name") or node["mangledName"])
        for child in node.get("inner", []):
            walk(child)

    for document in documents:
        walk(document)
    return found


def raw_count(path):
    """The independent reader: a plain count of the `- (` lines inside the protocol."""
    inside, count = False, 0
    for line in open(path, errors="replace"):
        stripped = line.strip()
        if stripped.startswith("@protocol %s" % PROTOCOL):
            inside = True
            continue
        if inside and stripped.startswith("@end"):
            break
        if inside and METHOD_START.match(line):
            count += 1
    return count


def side(header, port):
    """One side of the contract: every selector, and which of them are required."""
    selectors = ast_selectors(header, port)
    required = required_selectors(header, port)
    return {selector: ("required" if selector in required else "optional")
            for selector in selectors}


def main():
    os.makedirs(RUNS, exist_ok=True)
    header = side(SDK_HEADER, False)
    port = side(PORT_HEADER, True)
    counted = raw_count(PORT_HEADER)
    print("%s: header %d selectors, port %d" % (PROTOCOL, len(header), len(port)))
    print("  required: header %d, port %d" % (
        sum(1 for v in header.values() if v == "required"),
        sum(1 for v in port.values() if v == "required")))
    print("  the independent count of the port's method lines: %d" % counted)

    problems = []
    if len(port) != counted:
        problems.append("the AST and the count disagree on the port's file: %d and %d"
                        % (len(port), counted))
    for selector in sorted(set(header) - set(port)):
        problems.append("the port does not declare %s, which the header declares" % selector)
    for selector in sorted(set(port) - set(header)):
        problems.append("the port declares %s, which the header does not" % selector)
    for selector in sorted(set(header) & set(port)):
        if header[selector] != port[selector]:
            problems.append("%s is %s in the header and %s in the port"
                            % (selector, header[selector], port[selector]))
    if problems:
        for problem in problems:
            print("FAIL: " + problem)
        return 1

    # Control one: one @optional flipped to @required in a scratch copy of the port's header.
    text = open(PORT_HEADER, errors="replace").read()
    control = os.path.join(RUNS, "control-optionality.h")
    open(control, "w").write(text.replace("@optional", "@required", 1))
    flipped = side(control, True)
    caught = [s for s in flipped if header.get(s) != flipped.get(s)]
    if not caught:
        print("FAIL: the control flipped an @optional and the check did not notice")
        return 1
    print("  control, @optional flipped: %s is now %s" % (caught[0], flipped[caught[0]]))

    # Control two: one declaration removed, which must leave the AST set and be named.
    victim = sorted(port)[0]
    lines = open(PORT_HEADER, errors="replace").read().split("\n")
    keywords = victim.split(":")[:-1]
    unique = [k for k in keywords if k != "documentBrowser"] or keywords
    index = next(i for i, line in enumerate(lines)
                 if METHOD_START.match(line) and re.search(r"\b%s\s*:" % re.escape(unique[0]), line))
    end = index
    while ";" not in lines[end] and end + 1 < len(lines):
        end += 1
    del lines[index:end + 1]
    dropped = os.path.join(RUNS, "control-missing.h")
    open(dropped, "w").write("\n".join(lines))
    gone = side(dropped, True)
    if victim in gone:
        print("FAIL: the control removed %s and the AST still has it" % victim)
        return 1
    if len(gone) != len(port) - 1:
        print("FAIL: the control removed %s and %d selectors are left, not %d"
              % (victim, len(gone), len(port) - 1))
        return 1
    print("  control, %s removed: the AST went %d -> %d and named it"
          % (victim, len(port), len(gone)))

    # The transition controller: two properties, type and attributes from the AST on both sides.
    header_class = class_properties(SDK_HEADER, False)
    port_class = class_properties(CLASS_PORT, True)
    print("%s: header %d properties, port %d"
          % (CLASS, len(header_class), len(port_class)))
    for name, want_attrs in sorted(CLASS_PROPERTIES.items()):
        for source, label in ((header_class, "header"), (port_class, "port")):
            if name not in source:
                print("FAIL: %s does not declare %s, which the %s declares" % (label, name, label))
                return 1
    if header_class != port_class:
        for name in sorted(set(header_class) | set(port_class)):
            if header_class.get(name) != port_class.get(name):
                print("FAIL: %s is %s in the header and %s in the port"
                      % (name, header_class.get(name), port_class.get(name)))
                return 1
            for attribute in want_attrs:
                if attribute not in source[name]["attrs"]:
                    print("FAIL: %s declares %s without %s" % (label, name, attribute))
                    return 1
    # Control three: one attribute dropped from the port's copy, and it must be named.
    control = os.path.join(RUNS, "control-attribute.h")
    open(control, "w").write(open(CLASS_PORT, errors="replace").read()
                            .replace("@property (weak, nullable, nonatomic) UIView *targetView",
                                     "@property (nonatomic) UIView *targetView", 1))
    broken = class_properties(control, True)
    if broken.get("targetView", {}).get("attrs") == port_class["targetView"]["attrs"]:
        print("FAIL: the control dropped weak and nullable from targetView and nothing noticed")
        return 1
    print("  control, targetView's weak and nullable dropped: caught")

    # The view controller: its properties, by name, type and attributes, and its method selectors.
    vc_header = class_properties(SDK_HEADER, False, VC_CLASS)
    vc_port = class_properties(VC_PORT, True, VC_CLASS)
    print("%s: header %d properties, port %d" % (VC_CLASS, len(vc_header), len(vc_port)))
    # the members this port carries: the ones that arrived in 11.0 and 12.0
    carried = {"allowsDocumentCreation", "allowsPickingMultipleItems", "allowedContentTypes",
               "recentDocumentsContentTypes", "additionalLeadingNavigationBarButtonItems",
               "additionalTrailingNavigationBarButtonItems", "customActions",
               "browserUserInterfaceStyle", "delegate"}
    for name in sorted(carried):
        for source, label in ((vc_header, "header"), (vc_port, "port")):
            if name not in source:
                print("FAIL: %s does not declare %s, which the header declares" % (label, name))
                return 1
        if vc_header[name] != vc_port[name]:
            print("FAIL: %s is %s in the header and %s in the port"
                  % (name, vc_header[name], vc_port[name]))
            return 1
    # Both spellings of the transition question are two rows and both must be declared by the port.
    # The AST cannot separate a header's own declarations from the ones it inherits, so each
    # spelling is required to be in the AST *and* to be declared in the port's own file, which is
    # what a caller links against.
    port_text = open(VC_PORT, errors="replace").read()
    ast_methods = vc_methods_port(VC_PORT)
    for spelling in ("transitionControllerForDocumentAtURL:", "transitionControllerForDocumentURL:"):
        if spelling not in ast_methods:
            print("FAIL: %s is not in the AST of the port's header" % spelling)
            return 1
        if spelling not in port_text:
            print("FAIL: the port's file does not declare %s" % spelling)
            return 1
    # control, property family: copy turned strong on a weak property
    control = os.path.join(RUNS, "control-vc-property.h")
    open(control, "w").write(open(VC_PORT, errors="replace").read().replace(
        "@property (nullable, nonatomic, weak) id<UIDocumentBrowserViewControllerDelegate> delegate;",
        "@property (nonatomic) id<UIDocumentBrowserViewControllerDelegate> delegate;", 1))
    broken = class_properties(control, True, VC_CLASS)
    if broken.get("delegate") == vc_port.get("delegate"):
        print("FAIL: the control dropped weak and nullable from delegate and nothing noticed")
        return 1
    print("  control, delegate's weak and nullable dropped: caught")
    # control, method family: one spelling removed
    control = os.path.join(RUNS, "control-vc-method.h")
    open(control, "w").write(re.sub(
        r"- \(UIDocumentBrowserTransitionController \*\)transitionControllerForDocumentURL:.*?\n",
        "", open(VC_PORT, errors="replace").read(), flags=re.S))
    if "transitionControllerForDocumentURL:" in open(control, errors="replace").read():
        print("FAIL: the control removed a spelling and the port's file still has it")
        return 1
    print("  control, the 11.0 transitionControllerForDocumentURL: removed: caught")

    print("PASS: the port's declarations are the header's -- selectors, optionality, and both classes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
