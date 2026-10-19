#!/usr/bin/env python3
"""Emit a call test for everything a registry says a framework implements.

The gate cannot see a member that has no accessor: `modules/apple/backports.lua`'s
`check_registry` marks a member built as soon as its *owner class* is exported, so a class with
twelve properties and no accessors at all is green. That is not a gap in the gate, it is what the
gate is for; it is a gap nothing else covers, and a review of the first Intents group found
exactly that. A generated call test closes it, and the way it closes it is the point:

  * every class the registry carries is looked up **by name** and must exist;
  * every selector the registry carries is asked for with `respondsToSelector:`, which must
    answer YES — this is the check a declaration, a synthesised property and a missing accessor
    do not all pass, and only one of the three is an implementation;
  * every one of them is then **called**, with neutral arguments of the declared type, and a
    crash is a failure;
  * every property the registry carries is read and written, the same way.

The selectors are called through `objc_msgSend` rather than by their declarations on purpose:
the test has to be able to *ask* whether a selector is there, and a call written against the
header cannot be missing, because the header is what declares it. The types of the arguments come
from the same Objective-C AST the backport's own generator reads, so the neutral value of a
parameter is of the type the header gives it: nil for an object, a block, a pointer or a Class; 0
for a number, an enumeration or a BOOL; a zeroed compound literal for a structure; and a real
error variable for an `NSError **`.

The output is one `.m` of case functions and a JSON manifest of what it calls, so the same
generated file runs unchanged on the host — where it binds the system's own framework and is the
oracle — and on `xmake emulate` at 6.1.3, where it binds the backport. What each run answers is
written as a digest the two are compared with; see compare.py.

Usage:
    tools/callgen/gen-calls.py --sdk <iPhoneOS*.sdk> --registry <dir>... \\
        --out <Calls.m> --manifest <calls.json> [--dump <ast.json>]

    --dump is the AST the generator reads, as tools/intents/gen-intents.py's --dump is; it is
    written beside the SDK once and reused (see dump.sh).
"""

import argparse
import json
import os
import re
import subprocess
import sys

# The frameworks whose headers name a class, for the AST the arguments are read from. A registry
# folder's name is the framework, which is what the umbrella imports.
def umbrella(sdk, frameworks):
    return "\n".join("#import <%s/%s.h>" % (name, name) for name in frameworks) + "\n"


def objects(text):
    decoder = json.JSONDecoder()
    index, length, out = 0, len(text), []
    while index < length:
        while index < length and text[index] in " \t\r\n":
            index += 1
        if index >= length:
            break
        node, index = decoder.raw_decode(text, index)
        out.append(node)
    return out


MACRO = re.compile(r"\b[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+\b")


def clean(text):
    text = re.sub(r"_\s*(Nonnull|Nullable)\b", "", text or "")
    while True:
        found = MACRO.search(text)
        if not found:
            return text.strip()
        end = found.end()
        if text[end:end + 1] == "(":
            depth, index = 0, end
            while index < len(text):
                if text[index] == "(":
                    depth += 1
                elif text[index] == ")":
                    depth -= 1
                    if depth == 0:
                        index += 1
                        break
                index += 1
            end = index
        text = text[:found.start()] + " " + text[end:]


def spelled(qual):
    return re.sub(r"\s+", " ", clean(qual)).strip() or "id"


def base_type(qual):
    text = spelled(qual)
    if text.startswith("void (^") or text.startswith("block"):
        return "block"
    text = re.sub(r"\bvoid\s*\(\s*\^[^)]*\)\s*\([^)]*\)", "block", text)
    text = re.sub(r"<[^<>]*>", "", text)
    text = text.replace("*", "")
    text = re.sub(r"\([^()]*\)", "", text)
    text = text.replace("const", "").replace("volatile", "").replace("struct", "").strip()
    return text.split()[0] if text.split() else text


# What a parameter of this type is called with, and what the call has to have beside it. A
# NSError ** and every other out-parameter is the one shape a plain literal cannot be.
SCALARS = {"void", "BOOL", "char", "short", "int", "long", "float", "double", "NSTimeInterval",
           "CGFloat", "NSInteger", "NSUInteger", "int32_t", "uint32_t", "int64_t", "uint64_t"}
STRUCTS = {"NSRange", "NSPoint", "NSSize", "NSRect", "CGRect", "CGPoint", "CGSize", "CGRange"}


def neutral(qual):
    """(the value to pass, the declarations the call needs) for a parameter of this type."""
    text = spelled(qual)
    base = base_type(qual)
    if base == "block":
        return "nil", []
    if base in ("id", "Class", "SEL", "IMP"):
        if base == "Class":
            return "[CharonCallNeutral objectClass]", []
        if base == "SEL":
            return "@selector(description)", []
        return "nil", []
    if text.rstrip().endswith("**"):
        return "(&charon_call_error)", ["NSError *charon_call_error = nil;"]
    if text.rstrip().endswith("*"):
        return "nil", []
    if base in STRUCTS:
        return "(%s){0}" % base, []
    if base in ("NSZone",):
        return "nil", []
    return "0", []


def has_attr(node, kind):
    return any(child.get("kind") == kind for child in node.get("inner") or [])


def parameters_of(method):
    return [((c.get("type") or {}).get("qualType") or "id", c.get("name") or "value")
            for c in method.get("inner") or [] if c.get("kind") == "ParmVarDecl"]


def keywords(selector):
    return selector.split(":")[:-1] if ":" in selector else []


def enumeration_parameter(node):
    """Whether a parameter is an enumeration, which the AST tells by its sugar.

    A parameter declared as an NS_ENUM typedef has no pointer in its qualType and desugars to an
    integer, and that is the shape of every enumeration in the framework: the harness can see it
    without a table, and it has to, because 0 is the one value these APIs refuse - the system
    re-forms a success carrying it as a notRequired - so a harness that always passed 0 could not
    tell a resolved value from a refused one.
    """
    qual = (node.get("type") or {}).get("qualType") or ""
    desugared = (node.get("type") or {}).get("desugaredQualType") or ""
    if "*" in qual or qual in SCALARS or qual.startswith("instancetype"):
        return False
    return desugared in ("int", "long", "long long", "NSInteger", "NSUInteger", "unsigned",
                         "short", "unsigned short", "char", "unsigned char")


def selector_arguments(method):
    """The neutral value of each parameter, in the selector's own order."""
    arguments, declarations = [], []
    parameters = parameters_of(method)
    for index in range(len(keywords(method.get("name") or ""))):
        kind, _ = parameters[index] if index < len(parameters) else ({}, "value")
        value, needed = neutral((kind.get("type") or {}).get("qualType") or "id")
        if enumeration_parameter(parameters[index][0] if index < len(parameters) else {}):
            # A non-zero value for an enumeration: 0 is what the system re-forms, so 0 would
            # make a real resolution and a refused one look the same.
            value, needed = "1", []
        arguments.append(value)
        declarations.extend(needed)
    return arguments, declarations


class Declared:
    def __init__(self, name, kind, methods, properties):
        self.name = name
        self.kind = kind
        self.methods = methods          # selector -> node
        self.properties = properties    # name -> (selector, setter, readonly)


def collect(dump, classes, wanted_classes, wanted_methods):
    """The declarations of the names the registry lists, out of the AST."""
    found = {name: Declared(name, "class", {}, {}) for name in classes}
    protocols = {}
    for node in objects(open(dump, "r", errors="replace").read()):
        kind, name = node.get("kind"), node.get("name")
        inner = node.get("inner") or []
        if kind == "TranslationUnitDecl":
            collect_into(found, protocols, inner, wanted_classes, wanted_methods)
        else:
            collect_into(found, protocols, [node], wanted_classes, wanted_methods)
    return found, protocols


def collect_into(found, protocols, nodes, wanted_classes, wanted_methods):
    for node in nodes:
        kind, name = node.get("kind"), node.get("name")
        inner = node.get("inner") or []
        if kind == "ObjCInterfaceDecl" and inner and name in found:
            for member in inner:
                if member.get("kind") == "ObjCMethodDecl":
                    selector = member.get("name") or ""
                    if selector in wanted_methods.get(name, ()):
                        found[name].methods[selector] = member
                elif member.get("kind") == "ObjCPropertyDecl" and member.get("name") in wanted_classes.get(name, ()):
                    found[name].properties[member["name"]] = member
        elif kind == "ObjCCategoryDecl" and name in found:
            owner = (node.get("interface") or {}).get("name")
            if owner in found:
                for member in inner:
                    if member.get("kind") == "ObjCMethodDecl" and \
                            (member.get("name") or "") in wanted_methods.get(owner, ()):
                        found[owner].methods[member["name"]] = member
                    elif member.get("kind") == "ObjCPropertyDecl" and \
                            member.get("name") in wanted_classes.get(owner, ()):
                        found[owner].properties[member["name"]] = member
        elif kind == "ObjCProtocolDecl" and name in wanted_methods:
            protocols[name] = node


def read_registry(paths):
    """Every class, method and property a registry calls implemented, per framework."""
    classes, methods, properties, frameworks = {}, {}, {}, set()
    for path in paths:
        for root, _, files in os.walk(path):
            for name in sorted(files):
                if not name.endswith(".json"):
                    continue
                document = json.load(open(os.path.join(root, name)))
                framework = document.get("framework") or os.path.basename(root)
                frameworks.add(framework)
                for entry in document.get("entries", document.get("entries") or []):
                    if entry.get("status") != "implemented":
                        continue
                    api, kind = entry["api"], entry.get("kind")
                    if kind == "class":
                        classes[api] = framework
                    elif kind == "method":
                        found = re.match(r"^([-+])\[([A-Za-z_0-9]+) (.+)\]$", api)
                        if not found:
                            continue
                        sign, owner, selector = found.groups()
                        methods.setdefault(owner, set()).add(("%s[%s %s]" % (sign, owner, selector), selector))
                    elif kind == "property":
                        owner, _, property_name = api.partition(".")
                        properties.setdefault(owner, set()).add(property_name)
    return classes, methods, properties, sorted(frameworks)


BANNER = """//
//  %s
//  Generated by tools/callgen/gen-calls.py from %s
//  and the Objective-C declarations of the SDK's own headers. Do not edit: change the
//  generator and run it again.
//
//  %d classes and %d members are called here. Every class is looked up by name and must
//  exist, every selector is asked for with respondsToSelector: and must answer YES, and
//  every one of them is called with neutral arguments of the type its declaration gives.
//  The calls go through objc_msgSend and not through the declarations, because a call
//  written against the header cannot be missing: the header is what declares it.
//
"""

PROLOGUE = """
#import "harness.h"

#import <objc/message.h>
#import <objc/runtime.h>
#include <string.h>

// One case: the label that names it in the report, and the function that performs it. The same
// shape main.m walks, so the generated file and the harness agree on it by construction.
typedef struct {
    const char *label;
    void (*run)(CharonCallLog *log);
} CharonCallEntry;
"""


def mangle(selector):
    """A selector as one C identifier, which is all a case function's name has to be."""
    cleaned = re.sub(r"[^A-Za-z0-9]", "_", selector)
    return cleaned if cleaned and not cleaned[0].isdigit() else "_" + cleaned


def returns_structure(method):
    """Whether a method returns a structure, which objc_msgSend cannot return on its own."""
    returns = (method.get("returnType") or {}).get("qualType") or "id"
    base = base_type(returns)
    return base in STRUCTS or (base not in SCALARS and not returns.rstrip().endswith("*")
                               and base not in ("id", "instancetype", "SEL", "Class", "IMP",
                                                "block") and not base.startswith("NS"))


def emit_method(owner, selector, sign, method):
    """One member: the respondsToSelector: check, then the call, then what it answered."""
    arguments, declarations = selector_arguments(method)
    receiver = "self" if sign == "-" else "cls"
    first = receiver
    returns = "id" if not returns_structure(method) else "void"
    sender = "objc_msgSend_stret" if returns_structure(method) else "objc_msgSend"
    pointer = returns + " (*)(id, SEL" + "".join(", id" for _ in arguments) + ")"
    label = ("%s[%s %s]" % (sign, owner, selector)).encode("utf-8").decode("latin-1")
    name = "charon_case_%s_%s_%s" % (owner, "class" if sign == "+" else "instance",
                                    mangle(selector))
    lines = ["static void %s(CharonCallLog *log)" % name, "{",
             "    Class cls = CharonCallClass(log, @\"%s\");" % owner,
             "    if (!cls) return;"]
    indent = len(lines)
    for declaration in dict.fromkeys(declarations):
        lines.append("    " + declaration)
    if sign == "-":
        # An instance method: the receiver is an object of the class, made the way the header
        # allows (-init where it is available, -alloc alone where it is marked unavailable).
        lines += ["    id self = CharonCallInstance(log, cls);",
                  "    if (!self) return;",
                  "    if (!CharonCallSelector(log, cls, self, @selector(%s))) return;" % selector]
    else:
        # A class method: the receiver is the class object itself, which is already in hand.
        lines.append("    if (!CharonCallSelector(log, cls, cls, @selector(%s))) return;" % selector)
    if returns_structure(method):
        # A structure comes back through the caller-provided buffer objc_msgSend_stret writes.
        lines.append("    %s %s_storage;" % (returns, "charon_call_value"))
        lines.append("    memset(&charon_call_value_storage, 0, sizeof(charon_call_value_storage));")
        lines.append("    ((void (*)(id, SEL, %s *,%s))objc_msgSend_stret)(%s, @selector(%s),"
                     % (returns, "".join(", id" for _ in arguments), receiver, selector))
        lines.append("        %s;" % (", ".join(arguments) + ""))
        lines.append("        &charon_call_value_storage);")
        lines.append("    CharonCallNoted(log, cls, @selector(%s), (id)0);" % selector)
    else:
        lines.append("    __unsafe_unretained %s value = ((%s)objc_msgSend)(%s, @selector(%s)%s);"
                     % (returns, pointer, receiver, selector,
                        "".join(", " + argument for argument in arguments)))
        lines.append("    CharonCallNoted(log, cls, @selector(%s), value);" % selector)
    # The call is inside @try: a member that refuses the neutral value it was given answers by
    # raising, and that is a fact about the API worth having rather than a crash to hide.
    lines = lines[:indent] + ["    @try {"] + lines[indent:] + [
        "    } @catch (NSException *raised) {",
        "        CharonCallRaised(log, cls, @selector(%s), raised);" % selector,
        "    }"]
    lines += ["}", ""]
    return name, label, lines


def emit_property(owner, name, member):
    """One property, by the accessor its declaration names.

    A property is called through its getter and not through its name: INPerson's
    contactSuggestion is declared `getter=isContactSuggestion`, and asking for the name is a
    question no caller asks. The setter is asked for too, and a writable property is written and
    read back, which the getter-only half of a test never touches.
    """
    label = ("%s.%s" % (owner, name))
    function = "charon_case_%s_property_%s" % (owner, mangle(name))
    getter = ((member or {}).get("getter") or {}).get("name") or name
    declared_setter = (member or {}).get("setter") or {}
    setter = declared_setter.get("name") if declared_setter.get("name") else None
    if member is not None and member.get("readonly"):
        setter = None
    lines = ["static void %s(CharonCallLog *log)" % function, "{",
             "    Class cls = CharonCallClass(log, @\"%s\");" % owner,
             "    if (!cls) return;",
             "    id self = CharonCallInstance(log, cls);",
             "    if (!self) return;",
             "    CharonCallProperty(log, cls, self, @\"%s\", @\"%s\", %s);"
             % (name, getter, "nil" if setter is None else "@\"%s\"" % setter),
             "}", ""]
    return function, label, lines


def emit_class(name, designated):
    """The class case: the class, and the object every case of that class calls on.

    The object is made with the initialiser the header marks as the class's own, called with
    neutral arguments, because that is the object the API says is formed - and because the
    system's own response classes are not readable through one the runtime merely allocated
    (measured on the host: reading -code of an -alloc'd
    INGetUserCurrentRestaurantReservationBookingsIntentResponse takes the process down).
    """
    label = name
    function = "charon_case_%s" % name
    lines = ["static void %s(CharonCallLog *log)" % function, "{",
             "    Class cls = CharonCallClass(log, @\"%s\");" % name,
             "    if (!cls) return;",
             "    CharonCallNoted(log, cls, @selector(class), cls);"]
    if designated is not None:
        selector = designated.get("name")
        arguments, declarations = selector_arguments(designated)
        lines += ["    id instance = [cls alloc];"]
        for declaration in dict.fromkeys(declarations):
            lines.append("    " + declaration)
        lines += ["    if (instance && [instance respondsToSelector:@selector(%s)]) {" % selector,
                  "        @try {",
                  "            instance = ((id (*)(id, SEL%s))objc_msgSend)(instance, @selector(%s)%s);"
                  % ("".join(", id" for _ in arguments), selector,
                     "".join(", " + argument for argument in arguments)),
                  "            CharonCallNoted(log, cls, @selector(%s), instance);" % selector,
                  "        } @catch (NSException *raised) {",
                  "            CharonCallRaised(log, cls, @selector(%s), raised);" % selector,
                  "            instance = nil;",
                  "        }",
                  "    }"]
    else:
        lines += ["    id instance = CharonCallInstance(log, cls);"]
    lines += ["    CharonCallRemember(log, cls, instance);", "}", ""]
    return function, label, lines


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--sdk", required=True)
    parser.add_argument("--registry", action="append", required=True)
    parser.add_argument("--dump", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--manifest", required=True)
    options = parser.parse_args()

    classes, methods, properties, frameworks = read_registry(options.registry)
    if not os.path.isfile(options.dump):
        build_dump(options.sdk, frameworks, options.dump)
    declared, _ = collect(options.dump, classes, properties, methods)

    cases, manifest = [], {"classes": [], "members": []}
    for name in sorted(classes):
        entry = declared.get(name)
        manifest["classes"].append(name)
        designated = None
        for candidate in entry.methods.values() if entry else ():
            if not candidate.get("name", "").startswith("init") or ":" not in (candidate.get("name") or ""):
                continue
            if has_attr(candidate, "ObjCDesignatedInitializerAttr"):
                designated = candidate
                break
            if designated is None:
                designated = candidate
        cases.append(("class", name, None, None, designated, classes[name]))
        for selector, _ in sorted(methods.get(name, ())):
            sign = "-" if selector.startswith("-[") else "+"
            bare = re.match(r"^[-+]\[[A-Za-z_0-9]+ (.+)\]$", selector).group(1)
            member = (entry.methods.get(bare) if entry else None)
            if member is None:
                # A member the registry carries whose declaration the headers do not spell: the
                # call is still made, with no parameters, and the test says what it found.
                arguments, _ = [], []
                member = {"name": bare, "inner": []}
            cases.append(("method", name, bare, sign, member, classes[name]))
            manifest["members"].append("%s[%s %s]" % (sign, name, bare))
        for property_name in sorted(properties.get(name, ())):
            node = entry.properties.get(property_name) if entry else None
            cases.append(("property", name, property_name, "-", node, classes[name]))
            manifest["members"].append("%s.%s" % (name, property_name))

    out = [BANNER % (os.path.basename(options.out), ", ".join(options.registry),
                     len(classes), len(manifest["members"])), PROLOGUE]
    entries = []
    for kind, owner, member, sign, node, framework in cases:
        if kind == "class":
            function, label, lines = emit_class(owner, node)
        elif kind == "property":
            function, label, lines = emit_property(owner, member, node)
        else:
            function, label, lines = emit_method(owner, member, sign, node)
        out.extend(lines)
        entries.append((label, function))
    out.append("const CharonCallEntry charon_call_cases[] = {")
    for label, function in entries:
        out.append("    { \"%s\", %s }," % (label.replace("\\", "\\\\").replace('"', '\\"'), function))
    out.append("    { NULL, NULL }")
    out.append("};")
    out.append("const unsigned charon_call_case_count = %d;" % len(entries))

    with open(options.out, "w") as handle:
        handle.write("\n".join(out) + "\n")
    with open(options.manifest, "w") as handle:
        json.dump(manifest, handle, indent=1, sort_keys=True)
        handle.write("\n")
    print("%s: %d classes, %d members called" % (options.out, len(classes), len(manifest["members"])))
    return 0


def build_dump(sdk, frameworks, path):
    """The AST the arguments are read from, written once beside the SDK and reused."""
    umbrella_path = path + ".umbrella.m"
    with open(umbrella_path, "w") as handle:
        handle.write(umbrella(sdk, frameworks))
    version = os.path.basename(sdk).replace("iPhoneOS", "").replace(".sdk", "")
    command = ["xcrun", "clang", "-target", "arm64-apple-ios%s" % version, "-isysroot", sdk,
               "-fsyntax-only", "-x", "objective-c", "-Wno-everything",
               "-Xclang", "-ast-dump=json", umbrella_path]
    print("callgen: reading the AST of %s" % ", ".join(frameworks), file=sys.stderr)
    with open(path, "w") as handle:
        subprocess.run(command, stdout=handle, check=True)


if __name__ == "__main__":
    raise SystemExit(main() or 0)
