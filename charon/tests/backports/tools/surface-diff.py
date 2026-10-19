import argparse
import collections
import glob
import json
import os
import re
import subprocess
import sys
import tempfile

LINE = re.compile(r"^([| ]*)[|`]-(\w+) 0x[0-9a-f]+ ?(.*)$")
PATH = re.compile(r"(/[^\s:<>,]+\.\w+):\d+:\d+")
ATTRIBUTE = re.compile(r"\b(ios|maccatalyst) (\d+(?:\.\d+){0,2}) \d+(?:\.\d+){0,2} \d+(?:\.\d+){0,2}( Unavailable)?")


def newest_sdk():
    found = sorted(glob.glob("/Library/Developer/CommandLineTools/SDKs/MacOSX*.sdk"), key=lambda path: [int(part) for part in re.findall(r"\d+", os.path.basename(path))])
    if not found:
        sys.exit("no macOS SDK found; pass --sdk")
    return found[-1]


def parse_version(text):
    return tuple(int(part) for part in text.split("."))


def show_version(version):
    parts = list(version)
    while len(parts) > 2 and parts[-1] == 0:
        parts.pop()
    return ".".join(str(part) for part in parts)


def member_name(kind, rest):
    match = re.search(r"(?:col:\d+|line:\d+:\d+|[\w/.+-]+:\d+:\d+)\s+(.*)$", rest)
    text = match.group(1) if match else rest
    if kind == "ObjCMethodDecl":
        parts = text.split(" ", 2)
        return parts[0], parts[1]
    return None, text.split(" ", 1)[0]


class Surface:
    def __init__(self, framework):
        self.framework = framework
        self.file = None
        self.rows = {}
        self.owner = None
        self.container = None
        self.container_version = None
        self.target = None
        self.target_depth = None

    def own(self, kind, name, api):
        return api

    def record(self, api, kind, version):
        if api not in self.rows or (self.rows[api][1] is None and version is not None):
            self.rows[api] = (kind, version)

    def finish_target(self):
        if self.target is None:
            return
        api, kind, versions = self.target
        chosen = min(versions) if versions else None
        if api is not None:
            self.record(api, kind, chosen if chosen is not None else (self.container_version if kind in ("method", "property") else None))
        if kind in ("class", "protocol"):
            self.container_version = chosen
        self.target = None

    def feed(self, lines):
        for line in lines:
            match = LINE.match(line)
            if not match:
                continue
            depth = len(match.group(1)) // 2
            kind = match.group(2)
            rest = match.group(3)
            for path in PATH.findall(rest):
                self.file = path
            owned = self.file is not None and (("/%s.framework/" % self.framework) in self.file or "/SubFrameworks/" in self.file)
            if kind == "AvailabilityAttr":
                if self.target is not None and depth == self.target_depth + 1:
                    found = ATTRIBUTE.search(rest)
                    if found and found.group(1) == "ios" and not found.group(3):
                        self.target[2].append(parse_version(found.group(2)))
                    elif found and found.group(1) == "ios":
                        self.target[2].append((999,))
                continue
            if depth == 0:
                self.finish_target()
                self.owner = None
                if not owned:
                    continue
                if kind in ("ObjCInterfaceDecl", "ObjCProtocolDecl"):
                    name = rest.split()[-1]
                    self.owner = name
                    self.container_version = None
                    self.target = (name, "class" if kind == "ObjCInterfaceDecl" else "protocol", [])
                    self.target_depth = 0
                    self.pending_class = True
                elif kind == "ObjCCategoryDecl":
                    self.owner = None
                    self.pending_category = True
                    self.container_version = None
                    self.target = (None, "category", [])
                    self.target_depth = 0
                elif kind == "VarDecl" and " extern" in rest:
                    name = rest.split("'")[0].split()[-1]
                    self.target = (name, "constant", [])
                    self.target_depth = 0
                elif kind == "FunctionDecl" and " static" not in rest and " inline" not in rest:
                    name = rest.split("'")[0].split()[-1]
                    self.target = (name + "()", "function", [])
                    self.target_depth = 0
                continue
            if depth == 1 and kind == "ObjCInterface" and getattr(self, "pending_category", False) and self.target and self.target[1] == "category":
                self.owner = rest.split("'")[1]
                self.pending_category = False
                continue
            if depth == 1 and kind in ("ObjCMethodDecl", "ObjCPropertyDecl") and self.owner and owned:
                self.finish_target()
                if kind == "ObjCMethodDecl" and " implicit " in rest.split("'")[0]:
                    self.target = None
                    continue
                if kind == "ObjCMethodDecl":
                    sign, name = member_name(kind, rest)
                    api = "%s[%s %s]" % (sign, self.owner, name)
                    self.target = (api, "method", [])
                else:
                    _, name = member_name(kind, rest)
                    self.target = ("%s.%s" % (self.owner, name), "property", [])
                self.target_depth = 1
                continue
        self.finish_target()


def declared(sdk, framework, target):
    scratch = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", ".agent-work", "runs", "surface-diff"))
    os.makedirs(scratch, exist_ok=True)
    handle, source = tempfile.mkstemp(suffix=".m", dir=scratch)
    with os.fdopen(handle, "w") as stream:
        stream.write("#import <%s/%s.h>\n" % (framework, framework))
    try:
        command = ["xcrun", "clang", "-x", "objective-c", "-target", target, "-isysroot", sdk, "-w", "-fsyntax-only", "-Xclang", "-ast-dump"]
        support = os.path.join(sdk, "System", "iOSSupport", "System", "Library", "Frameworks")
        if target.endswith("macabi"):
            command += ["-iframework", support]
        command.append(source)
        dump = subprocess.run(command, capture_output=True, text=True, errors="replace")
        if not dump.stdout:
            sys.exit("clang produced no AST for %s: %s" % (framework, dump.stderr[:400]))
    finally:
        os.unlink(source)
    surface = Surface(framework)
    surface.feed(dump.stdout.splitlines())
    return surface.rows


def registry_names(root, framework):
    """Every name the registry of a framework gives a status, from registry/<Framework>.json and from
    registry/<Framework>/*.json. A name in two of them is refused: whichever is read last would decide the
    status, so a name built and listed implemented in one file would be listed absent in the other and every
    row that reads the status would answer about the last one."""
    names, told = {}, {}
    for path in glob.glob(os.path.join(root, framework, "*.json")) + glob.glob(os.path.join(root, framework + ".json")):
        with open(path) as stream:
            data = json.load(stream)
        for entry in data["entries"] if isinstance(data, dict) else data:
            if entry["api"] in told:
                sys.exit("%s is named by both %s and %s" % (entry["api"], told[entry["api"]], path))
            told[entry["api"]] = path
            names[entry["api"]] = (entry.get("status", ""), parse_version(entry["introduced"]) if entry.get("introduced") else None)
    return names


class Release:
    def __init__(self, release):
        path = os.path.join(os.path.expanduser("~"), ".charon", "dyld", release, "classes_armv7.json")
        if not os.path.exists(path):
            sys.exit("no class inventory of iOS %s at %s" % (release, path))
        with open(path) as stream:
            self.classes = json.load(stream)["classes"]

    def selectors(self):
        if not hasattr(self, "_selectors"):
            found = set()
            for entry in self.classes.values():
                found.update(entry.get("instance") or [])
                found.update(entry.get("class") or [])
            self._selectors = found
        return self._selectors

    def protocols(self):
        if not hasattr(self, "_protocols"):
            found = set()
            for entry in self.classes.values():
                found.update(entry.get("protocols") or [])
            self._protocols = found
        return self._protocols

    def knows_selector(self, api, kind):
        found = re.match(r"^[-+]\[\w+ (.+)\]$", api)
        if found:
            return found.group(1) in self.selectors()
        if kind == "property":
            name = api.split(".", 1)[1]
            return name in self.selectors()
        return False

    def has(self, api, kind):
        if kind == "class":
            return api in self.classes
        found = re.match(r"^([-+])\[(\w+) (.+)\]$", api)
        if found:
            side = "instance" if found.group(1) == "-" else "class"
            selector, owner = found.group(3), found.group(2)
        elif kind == "property":
            owner, name = api.split(".", 1)
            selectors = [name, "set" + name[0].upper() + name[1:] + ":"]
            side = "instance"
            return self.answers(owner, side, selectors[0])
        else:
            return False
        return self.answers(owner, side, selector)

    def answers(self, owner, side, selector):
        seen = set()
        while owner in self.classes and owner not in seen:
            seen.add(owner)
            entry = self.classes[owner]
            if selector in (entry.get(side) or []):
                return True
            owner = entry.get("superclass")
        return False


def covered(api, kind, version, registry):
    if api in registry:
        return True
    owner = re.match(r"^[-+]\[(\w+) ", api)
    owner = owner.group(1) if owner else (api.split(".")[0] if kind == "property" else None)
    if kind == "property":
        name = api.split(".", 1)[1]
        setter = "set" + name[0].upper() + name[1:] + ":"
        for candidate in ("-[%s %s]" % (owner, name), "-[%s %s]" % (owner, setter)):
            if candidate in registry:
                return True
    entry = registry.get(owner)
    if entry and entry[0] in ("absent", "ignored"):
        return True
    if entry and entry[0] == "implemented" and entry[1] and version and version <= entry[1]:
        return True
    return False


def main():
    parser = argparse.ArgumentParser(description="Diff the API an SDK declares against the registry of the backports. A row is decided when the registry lists it, or its class as absent or ignored, or its class as implemented with the release the row arrived in; a gap is API nobody has decided about, which is absent by default.")
    parser.add_argument("frameworks", nargs="+")
    parser.add_argument("--sdk", default=None, help="a macOS SDK with System/iOSSupport (Mac Catalyst), or an iPhoneOS SDK")
    parser.add_argument("--target", default=None, help="default: iOS 26 Catalyst for a macOS SDK, iOS 16.4 for an iPhoneOS one")
    parser.add_argument("--registry", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "packages", "a", "apple-backports", "registry"))
    parser.add_argument("--above", default="6.0", help="only what arrived after this release")
    parser.add_argument("--up-to", default=None, help="only what arrived up to and including this release")
    parser.add_argument("--release", default=None, help="a release whose classes the release itself carries, from ~/.charon/dyld/<release>/classes_armv7.json: what it answers is not a gap")
    parser.add_argument("--list", action="store_true", help="print every gap")
    parser.add_argument("--rows", default=None, help="write every declared row, tab separated, to this file")
    options = parser.parse_args()
    sdk = options.sdk or newest_sdk()
    target = options.target or ("arm64-apple-ios26.0-macabi" if "MacOSX" in os.path.basename(sdk) else "arm64-apple-ios16.4")
    above = parse_version(options.above)
    up_to = parse_version(options.up_to) if options.up_to else None
    print("SDK %s, target %s, API that arrived after iOS %s%s" % (os.path.basename(sdk), target, options.above, " up to %s" % options.up_to if up_to else ""))
    inventory = Release(options.release) if options.release else None
    written = open(options.rows, "w") if options.rows else None
    for framework in options.frameworks:
        rows = declared(sdk, framework, target)
        if written:
            for api, (kind, version) in sorted(rows.items()):
                written.write("%s\t%s\t%s\t%s\n" % (framework, kind, api, show_version(version) if version and version != (999,) else ""))
        registry = registry_names(options.registry, framework)
        totals = collections.Counter()
        gaps = collections.Counter()
        carried = collections.Counter()
        listed = []
        unversioned = []
        for api, (kind, version) in sorted(rows.items()):
            if version is None:
                owner = re.match(r"^[-+]\[(\w+) ", api)
                owner = owner.group(1) if owner else api.split(".")[0]
                gone = owner not in inventory.classes and owner not in inventory.protocols() if inventory else False
                if inventory and kind in ("method", "property") and not covered(api, kind, None, registry) and not inventory.knows_selector(api, kind) and gone:
                    unversioned.append((api, kind))
                continue
            if version <= above or version == (999,) or (up_to and version[:2] > up_to + (0,) * (2 - len(up_to)) and version > up_to):
                continue
            release = "%d" % version[0]
            totals[release] += 1
            if not covered(api, kind, version, registry) and inventory and inventory.has(api, kind):
                carried[release] += 1
            elif not covered(api, kind, version, registry):
                gaps[release] += 1
                listed.append((version, api, kind))
        print("\n%s: %d declared after iOS %s, %d not decided%s" % (framework, sum(totals.values()), options.above, sum(gaps.values()),
              ", %d of the rest carried by iOS %s itself" % (sum(carried.values()), options.release) if inventory else ""))
        for release in sorted(totals, key=int):
            print("  iOS %-3s declared %5d   decided %5d%s   gap %5d" % (release, totals[release], totals[release] - gaps[release] - carried[release],
                  "   carried by the release %5d" % carried[release] if inventory else "", gaps[release]))
        if inventory:
            print("  no recorded availability: %d members of a class or protocol iOS %s does not have, that no class of it answers and the registry does not decide" % (len(unversioned), options.release))
        if options.list:
            for version, api, kind in sorted(listed):
                print("    %-6s %-9s %s" % (show_version(version), kind, api))
            for api, kind in unversioned:
                print("    %-6s %-9s %s" % ("?", kind, api))


if __name__ == "__main__":
    main()
