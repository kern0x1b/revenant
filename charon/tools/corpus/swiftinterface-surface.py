#!/usr/bin/env python3
"""Swift-only API of an SDK, from its .swiftinterface files: SwiftUI, Combine, SwiftData, the
overlays over C and Objective-C frameworks. clang never sees any of it: there is no header.

    swiftinterface-surface.py <sdk> [Module ...]      one line per declaration, tab separated:
        module  kind  api  introduced  deprecated  obsoleted  unavailable  via

`introduced`, `deprecated` and `obsoleted` are iOS versions from `@available(iOS ...)`; "deprecated"
alone (`@available(*, deprecated)`) prints `yes`. `unavailable` is `yes` when `@available(iOS,
unavailable)` or `@available(*, unavailable)` holds. `via` is `own` when the declaration carries
its own iOS version, `container` when it took the version of the type or extension it sits in (a floor:
the member arrived in that version or later),
`none` when no @available of iOS reaches it (the module's own baseline then applies, which the
interface does not state).

Also imported: swiftinterface-surface.py's `rows(sdk, module=None)` and `interfaces(sdk)`,
which sdk-introduced.py uses for its whole-SDK mode. Same row shape as sdk-introduced.py writes.

What it reads, and what it leaves out, on purpose:

- Only public API: `public` or `open` declarations, and the members of a protocol or the cases of
  an enum, which have no access keyword of their own. `internal`, `@usableFromInline` and
  `@_spi(...)` declarations are not API.
- Inlinable bodies (`@inlinable public func f() { ... }` is printed with its body) are skipped by
  brace matching, so a local `let` in a body is never taken for a declaration.
- Conformances (`extension X : P`) are not rows.
- `#if` blocks are read as if every branch held: the same declaration under two conditions is one
  row, the first one seen.
"""
import glob
import os
import re
import sys

DEPRECATED_NO_VERSION = (100000,)
VERSION = re.compile(r"\d+(?:\.\d+){0,2}")
ATTRIBUTE_START = re.compile(r"@[A-Za-z_][\w.]*")
OPERATOR = re.compile(r"[/=\-+!*%<>&|^~?.]+")
NAME = re.compile(r"\$?[^\W\d]\w*|`[^`]+`")
TYPE_KEYWORD = {"struct": "struct", "class": "class", "actor": "class", "enum": "enum", "protocol": "protocol"}
MODIFIERS = {"public", "open", "package", "internal", "private", "fileprivate", "final", "indirect", "static", "class",
             "mutating", "nonmutating", "override", "convenience", "required", "dynamic", "lazy", "weak", "unowned",
             "optional", "prefix", "postfix", "infix", "nonisolated", "isolated", "consuming", "borrowing", "distributed",
             "__consuming", "__owned", "__shared"}
# `class` and `static` lead a declaration as a modifier (`class func f`) or as its keyword (`class C`);
# it is the modifier when one of these follows.
MODIFIER_FOLLOWERS = MODIFIERS | {"func", "var", "let", "subscript", "init"}
DECL_KEYWORDS = {"struct", "class", "enum", "actor", "protocol", "extension", "typealias", "func", "var", "let", "init",
                 "subscript", "case", "associatedtype", "macro", "deinit"}


def parse_version(text):
    """(16, 0) for `16`: a version is always major and minor at least, as clang's are."""
    parts = [int(part) for part in text.split(".")]
    return tuple(parts + [0] * (2 - len(parts)))


def show_version(version):
    parts = list(version)
    while len(parts) > 2 and parts[-1] == 0:
        parts.pop()
    return ".".join(str(part) for part in parts)


def balanced(text, start):
    """Index just past the parenthesis group that opens at text[start], string literals aware."""
    depth = 0
    quoted = False
    index = start
    while index < len(text):
        char = text[index]
        if quoted:
            if char == "\\":
                index += 1
            elif char == '"':
                quoted = False
        elif char == '"':
            quoted = True
        elif char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                return index + 1
        index += 1
    return len(text)


def top_level_split(text, separator=","):
    """text split at separator outside (), [], <>, {} and string literals."""
    parts = []
    depth = 0
    quoted = False
    current = []
    index = 0
    while index < len(text):
        char = text[index]
        if quoted:
            current.append(char)
            if char == "\\" and index + 1 < len(text):
                index += 1
                current.append(text[index])
            elif char == '"':
                quoted = False
        elif char == '"':
            quoted = True
            current.append(char)
        elif char in "([<{":
            # `->` and a comparison operator are not brackets
            depth += 1
            current.append(char)
        elif char in ")]>}":
            if not (char == ">" and index > 0 and text[index - 1] == "-"):
                depth -= 1
            current.append(char)
        elif char == separator and depth <= 0:
            parts.append("".join(current).strip())
            current = []
        else:
            current.append(char)
        index += 1
    tail = "".join(current).strip()
    if tail:
        parts.append(tail)
    return parts


def strip_code(line):
    """line without string literals and a trailing // comment, for brace counting."""
    out = []
    quoted = False
    index = 0
    while index < len(line):
        char = line[index]
        if quoted:
            if char == "\\":
                index += 1
            elif char == '"':
                quoted = False
        elif char == '"':
            quoted = True
        elif char == "/" and line[index:index + 2] == "//":
            break
        else:
            out.append(char)
        index += 1
    return "".join(out)


def leading_attributes(line):
    """(attributes, rest): the `@name(...)` attributes a line opens with, and what follows."""
    attributes = []
    rest = line.lstrip()
    while True:
        found = ATTRIBUTE_START.match(rest)
        if not found:
            return attributes, rest
        end = found.end()
        if rest[end:end + 1] == "(":
            end = balanced(rest, end)
        attributes.append(rest[:end])
        rest = rest[end:].lstrip()


def ios_availability(attribute):
    """(introduced, deprecated, obsoleted, unavailable) of one `@available(...)` for iOS, or None
    when the attribute says nothing about iOS."""
    inner = attribute[attribute.index("(") + 1:attribute.rindex(")")]
    introduced = deprecated = obsoleted = None
    unavailable = False
    platform = None
    for argument in top_level_split(inner):
        tokens = argument.split()
        if not tokens:
            continue
        if ":" not in argument:
            if tokens[0] in ("iOS", "*") and platform is None:
                # `iOS 13.0` (shorthand, with a version), `iOS` or `*` (labelled arguments follow)
                platform = tokens[0]
                if len(tokens) > 1 and VERSION.fullmatch(tokens[1]):
                    introduced = parse_version(tokens[1])
            elif tokens[0] == "unavailable":
                unavailable = True
            elif tokens[0] == "deprecated":
                deprecated = deprecated or DEPRECATED_NO_VERSION
            continue
        label, _, value = argument.partition(":")
        label = label.strip()
        value = value.strip()
        if label == "introduced" and VERSION.fullmatch(value):
            introduced = parse_version(value)
        elif label == "deprecated" and VERSION.fullmatch(value):
            # `deprecated: 100000.0` is the annotation for a deprecation with no version yet
            deprecated = parse_version(value) if parse_version(value)[0] < DEPRECATED_NO_VERSION[0] else DEPRECATED_NO_VERSION
        elif label == "obsoleted" and VERSION.fullmatch(value):
            obsoleted = parse_version(value)
    if platform is None:
        return None
    # `@available(*, unavailable)` holds for every platform, iOS included; `@available(*, introduced:
    # ...)` names no iOS version and says nothing about it.
    if platform == "*":
        return (None, deprecated, obsoleted, unavailable) if (deprecated or obsoleted or unavailable) else None
    return introduced, deprecated, obsoleted, unavailable


def fold(attributes):
    """The availability of one declaration, out of all its @available attributes."""
    introduced = deprecated = obsoleted = None
    unavailable = False
    found = False
    for attribute in attributes:
        if not attribute.startswith("@available"):
            continue
        one = ios_availability(attribute)
        if one is None:
            continue
        found = True
        if one[0] and (introduced is None or one[0] < introduced):
            introduced = one[0]
        if one[1] and (deprecated is None or one[1] < deprecated):
            deprecated = one[1]
        if one[2] and (obsoleted is None or one[2] < obsoleted):
            obsoleted = one[2]
        unavailable = unavailable or one[3]
    return {"introduced": introduced, "deprecated": deprecated, "obsoleted": obsoleted, "unavailable": unavailable, "found": found}


def strip_generics(text):
    """text with every balanced <...> removed."""
    out = []
    depth = 0
    for char in text:
        if char == "<":
            depth += 1
        elif char == ">" and depth:
            depth -= 1
        elif not depth:
            out.append(char)
    return "".join(out)


def function_name(text):
    """`foo(a:b:)` for `func foo<T>(_ x: T, a: Int, b y: Int) -> ...`, `init(a:)` for an initializer;
    text starts at the keyword."""
    keyword = re.match(r"[a-z]+", text).group(0)
    after = text[len(keyword):].lstrip()
    if keyword == "init":
        name = "init" + (after[0] if after[:1] in ("?", "!") else "")
        after = after.lstrip("?!").lstrip()
        if after.startswith("<"):
            after = skip_generics(after)
    elif keyword == "subscript":
        name = "subscript"
        if after.startswith("<"):
            after = skip_generics(after)
    else:
        word = NAME.match(after)
        operator = OPERATOR.match(after)
        found = word or operator
        name = found.group(0).strip("`") if found else "?"
        after = after[found.end():].lstrip() if found else after
        if word and after.startswith("<"):
            after = skip_generics(after)
    if not after.startswith("("):
        return name
    end = balanced(after, 0)
    labels = []
    for parameter in top_level_split(after[1:end - 1]):
        first = leading_attributes(parameter)[1].split(":", 1)[0].split()
        labels.append((first[0] if first else "_") + ":")
    return "%s(%s)" % (name, "".join(labels))


def skip_generics(text):
    """text after its leading <...> generic clause."""
    depth = 0
    for index, char in enumerate(text):
        if char == "<":
            depth += 1
        elif char == ">" and text[index - 1] != "-":
            depth -= 1
            if depth == 0:
                return text[index + 1:].lstrip()
    return ""


def declaration(rest):
    """(keyword, modifiers, text): what a declaration line, with its attributes cut off, declares, and
    the line from the keyword on; None when it is no declaration."""
    modifiers = set()
    text = rest
    while True:
        found = re.match(r"([A-Za-z_]\w*)(?:\((?:safe|unsafe)\))?\s*", text)
        if not found or found.group(1) not in MODIFIERS:
            break
        if found.group(1) == "class":
            following = re.match(r"[A-Za-z_]\w*", text[found.end():])
            if not following or following.group(0) not in MODIFIER_FOLLOWERS:
                break
        modifiers.add(found.group(1))
        text = text[found.end():]
    keyword = re.match(r"[A-Za-z_]+", text)
    if not keyword or keyword.group(0) not in DECL_KEYWORDS:
        return None
    return keyword.group(0), modifiers, text


def interfaces(sdk):
    """module -> path of the .swiftinterface to read: arm64 first, arm64e otherwise, the framework
    bundles before usr/lib/swift, System/Library before the cryptex overlay."""
    found = {}
    roots = [os.path.join(sdk, "System", "Library", "Frameworks"),
             os.path.join(sdk, "System", "Cryptexes", "OS", "System", "Library", "Frameworks"),
             os.path.join(sdk, "Developer", "Library", "Frameworks")]
    directories = []
    for root in roots:
        directories += sorted(glob.glob(os.path.join(root, "*.framework", "Modules", "*.swiftmodule")))
    directories += sorted(glob.glob(os.path.join(sdk, "usr", "lib", "swift", "*.swiftmodule")))
    for directory in directories:
        module = os.path.basename(directory)[:-len(".swiftmodule")]
        if module in found:
            continue
        for name in ("arm64-apple-ios.swiftinterface", "arm64e-apple-ios.swiftinterface"):
            path = os.path.join(directory, name)
            if os.path.isfile(path):
                found[module] = path
                break
    return found


def qualified(owner, name):
    return owner + "." + name if owner else name


def unqualified(name, modules):
    """name without a leading module component: `Swift.Array` is `Array`, `Foundation.Locale.Region`
    is `Locale.Region`."""
    head, dot, tail = name.partition(".")
    return tail if dot and head in modules else name


def parse(path, module, modules=(), problems=None):
    """The public declarations of one .swiftinterface, as row dicts. modules names every module of
    the SDK, so that `extension SwiftUI.View` and the `View` declared in SwiftUICore are one owner.
    A file whose braces do not close (or close more than they opened) is a parse gone wrong: it is named
    in `problems`, a list, when the caller passes one."""
    underflow = 0
    rows = {}
    stack = []  # scopes: {"kind": "type"|"protocol"|"enum"|"extension"|"body", "name": str, "detail": {...}}
    pending = []
    with open(path, encoding="utf-8", errors="replace") as stream:
        lines = stream.read().splitlines()
    for raw in lines:
        line = raw.strip()
        if not line or line.startswith("//") or line.startswith("#"):
            continue
        code = strip_code(line)
        net = code.count("{") - code.count("}")
        scope = stack[-1] if stack else None
        if scope is not None and scope["kind"] == "body":
            # inside an inlinable body or accessor: only the braces count
            for _ in range(max(net, 0)):
                stack.append({"kind": "body"})
            for _ in range(max(-net, 0)):
                stack.pop()
            pending = []
            continue
        attributes, rest = leading_attributes(line)
        pending += attributes
        if not rest:
            continue
        decl = declaration(rest)
        if decl is None:
            for _ in range(max(net, 0)):
                stack.append({"kind": "body"})
            for _ in range(max(-net, 0)):
                if stack:
                    stack.pop()
                else:
                    underflow += 1
            pending = []
            continue
        keyword, modifiers, text = decl
        own = fold(pending)
        spi = any(a.startswith("@_spi") for a in pending)
        usable = any(a.startswith("@usableFromInline") for a in pending)
        pending = []
        container = scope["detail"] if scope is not None and scope.get("detail") else None
        in_kind = scope["kind"] if scope is not None else "top"
        public = "public" in modifiers or "open" in modifiers
        implicit_public = in_kind == "protocol" or (in_kind == "enum" and keyword == "case")
        emit = (public or implicit_public) and not spi and not usable and "internal" not in modifiers \
            and "private" not in modifiers and "fileprivate" not in modifiers and "package" not in modifiers
        if keyword == "extension":
            target = strip_generics(text[len("extension"):].strip())
            target = unqualified(re.split(r"\s*:\s*|\s+where\s+|\s*\{", target, maxsplit=1)[0].strip(), modules)
            detail = combine(own, container)
            if net > 0:
                stack.append({"kind": "extension", "name": target, "detail": detail})
            continue
        owner = ".".join(s["name"] for s in stack if s.get("name") and s["kind"] in ("type", "protocol", "enum", "extension")) if stack else ""
        if keyword in TYPE_KEYWORD:
            after = text[len(keyword):].strip()
            found = NAME.match(after)
            name = found.group(0).strip("`") if found else "?"
            detail = combine(own, container)
            if emit:
                add(rows, module, TYPE_KEYWORD[keyword], qualified(owner, name), detail)
            if net > 0:
                stack.append({"kind": "protocol" if keyword == "protocol" else "enum" if keyword == "enum" else "type", "name": name, "detail": detail})
            continue
        if keyword in ("func", "init", "subscript", "macro"):
            api_name = function_name(text)
            kind = "method" if in_kind != "top" else "function"
            if keyword == "macro":
                kind = "function"
            if emit:
                add(rows, module, kind, qualified(owner, api_name), combine(own, container))
            if net > 0:
                stack.append({"kind": "body"})
            continue
        if keyword in ("var", "let"):
            after = text[len(keyword):].strip()
            found = NAME.match(after)
            name = found.group(0).strip("`") if found else "?"
            if emit:
                add(rows, module, "property" if in_kind != "top" else "constant", qualified(owner, name), combine(own, container))
            if net > 0:
                stack.append({"kind": "body"})
            continue
        if keyword == "typealias":
            after = text[len(keyword):].strip()
            found = NAME.match(after)
            name = found.group(0).strip("`") if found else "?"
            if emit:
                add(rows, module, "typealias", qualified(owner, name), combine(own, container))
            continue
        if keyword == "case":
            detail = combine(own, container)
            after = text[len(keyword):].strip()
            for item in top_level_split(after):
                found = NAME.match(item)
                if found and emit:
                    add(rows, module, "constant", qualified(owner, found.group(0).strip("`")), detail)
            continue
        # associatedtype, deinit: not API rows
        if net > 0:
            stack.append({"kind": "body"})
    if problems is not None and (stack or underflow):
        problems.append("%s: %d scope(s) open at the end of the file, %d closing brace(s) with none open" % (module, len(stack), underflow))
    return list(rows.values())


def combine(own, container):
    """own availability with the container's underneath: the introduced version of the enclosing
    type or extension where the declaration names none, and its unavailability and obsoletion."""
    result = dict(own)
    result["via"] = "own" if own["introduced"] else "none"
    if container is not None:
        if own["introduced"] is None and container["introduced"] is not None:
            result["introduced"] = container["introduced"]
            result["via"] = "container"
        if not own["found"]:
            result["obsoleted"] = container["obsoleted"]
            result["unavailable"] = container["unavailable"]
    return result


def add(rows, module, kind, api, detail):
    """One row per name; a second declaration of the same name (an overload with the same labels,
    both branches of an #if) only lowers the version the row says it arrived in."""
    if api in rows:
        row = rows[api]
        if detail["introduced"] and (row["introduced"] is None or detail["introduced"] < row["introduced"]):
            row["introduced"] = detail["introduced"]
            row["via"] = detail["via"]
        return
    rows[api] = {"api": api, "framework": module, "kind": kind, "lang": "swift",
                 "introduced": detail["introduced"], "deprecated": detail["deprecated"], "obsoleted": detail["obsoleted"],
                 "unavailable": detail["unavailable"], "via": detail["via"]}


def rows(sdk, module=None, problems=None):
    found = interfaces(sdk)
    modules = set(found) | {os.path.basename(path)[:-len(".framework")] for path in
                            glob.glob(os.path.join(sdk, "System", "Library", "Frameworks", "*.framework"))}
    for name, path in sorted(found.items()):
        if module and name not in module:
            continue
        for row in parse(path, name, modules, problems):
            yield row


def show(version):
    return "" if version is None else "yes" if version == DEPRECATED_NO_VERSION else show_version(version)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    sdk = sys.argv[1]
    only = set(sys.argv[2:]) or None
    problems = []
    for row in rows(sdk, only, problems):
        print("\t".join([row["framework"], row["kind"], row["api"], show(row["introduced"]), show(row["deprecated"]),
                         show(row["obsoleted"]), "yes" if row["unavailable"] else "", row["via"]]))
    for problem in problems:
        print("swiftinterface-surface.py: " + problem, file=sys.stderr)


if __name__ == "__main__":
    main()
