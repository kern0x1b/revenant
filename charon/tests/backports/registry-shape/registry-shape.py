#!/usr/bin/env python3
"""registry-shape - the registry against what a band actually linked, in check_registry's words.

    tests/backports/registry-shape/registry-shape.py <gate-output-dir> [FRAMEWORK ...]

    xmake l coordination/build-gate.lua ... writes <gate-output-dir>/lib<Framework>Backports.dylib;
    this reads those, so anyone can run it straight after their own gate:

        sh coordination/build-gate.lua --checkout . --cache ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7 \
            --output .agent-work/runs/me/g613
        python3 tests/backports/registry-shape/registry-shape.py .agent-work/runs/me/g613

    A framework may be named, or `all` for every library the gate output holds. It answers the two
    questions modules/apple/backports.lua's check_registry asks of the registry and the band, in its
    own sentences:

        listed as absent, but what is built answers it
        listed as implemented, but nothing of that name is built

Every exemption is printed BY NAME with the rule and the line of backports.lua that grants it, because
an exemption that is only a count is how a check learns people to ignore it. The rules, as they are
written there:

  1859-1862  a row listed absent is answered when a class row's name is in found.classes, when a
             constant or function row's name is in found.symbols with its parentheses stripped, or
             when a spelling that is a selector is in found.answered
  1885-1889  an implemented row is built when any of its spellings is a class, a member or a symbol,
             when its owner's class is, or when a class row's name is in found.registered
  1890       carried: introduced at or before the deployment, so the release itself has it
  1891       the band's own exports name it
  1892       ours: in_range (1617) - no minimum above the deployment, no maximum at or below it
  1897-1903  declared: a protocol row, or a row whose owner is a protocol, that a header declares
  1904-1908  a function row answered by a body in one of the package's own headers (inline_bodies_of, 1771)
  1911-1913  a type or a case answered by a name a header declares (declared_names)

`found` is computed by found.lua with surface()'s own functions (backports.lua:1402-1437), and the
release's own exports by the same dyld.load the gate uses, so this reads what the gate reads and not
what an object looks like. It writes under its own $build and nowhere else.
"""
import argparse
import glob
import json
import os
import re
import subprocess
import sys

KIND_EXAMINED = ("class", "function", "constant")
ASKED = set()          # the frameworks the run was asked to cover, when it was asked for any
RULES = {
    "classes": "found.classes, backports.lua:1859",
    "symbols": "found.symbols, backports.lua:1860",
    "answered": "found.answered, backports.lua:1862",
    "registered": "found.registered, backports.lua:1889",
    "carried": "introduced at or before the deployment, backports.lua:1890",
    "exports": "the band's own exports, backports.lua:1891",
    "range": "in_range, backports.lua:1892 and 1617",
    "declared": "declared, backports.lua:1897-1903",
    "inline": "a body in one of the package's own headers, backports.lua:1904-1908 and 1771",
    "header": "a name a header declares, backports.lua:1911-1913",
}


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True)


def compare(a, b):
    pa = [int(x) for x in re.findall(r"\d+", a or "")] or [0]
    pb = [int(x) for x in re.findall(r"\d+", b or "")] or [0]
    for x, y in zip(pa, pb):
        if x != y:
            return -1 if x < y else 1
    return 0 if len(pa) == len(pb) else (-1 if len(pa) < len(pb) else 1)


def in_range(entry, deployment):
    if entry.get("minimum") and compare(deployment, entry["minimum"]) < 0:
        return False
    if entry.get("maximum") and compare(deployment, entry["maximum"]) >= 0:
        return False
    return True


def spellings(api):
    plain = re.sub(r"\(\)$", "", api)
    out = {plain, plain + "()"}
    member = re.match(r"^([A-Z][A-Za-z0-9_]*)\.(.+)$", plain)
    if member:
        cls, name = member.group(1), member.group(2)
        out.update({f"-[{cls} {name}]", f"-[{cls} set{name[:1].upper()}{name[1:]}:]"})
    if api[:2] in ("-[", "+["):
        parts = api[2:-1].split(" ", 1)
        if len(parts) == 2:
            out.update({f"-[{parts[0]} {parts[1]}]", f"+[{parts[0]} {parts[1]}]"})
    return out


def read_found(path):
    sets = {k: set() for k in "CSMRA"}
    # a text literal of a linked binary need not be UTF-8, so the names are read as bytes
    for line in open(path, "rb"):
        kind, _, name = line.rstrip(b"\n").partition(b"\t")
        key = kind.decode("ascii", "replace")
        if key in sets:
            sets[key].add(name.decode("utf-8", "surrogateescape"))
    return sets


def cache_run(build, key, cmd):
    """Run once, keep the result; a band reads the same libraries again and again."""
    out = os.path.join(build, key)
    if os.path.exists(out):
        return out, None
    result = run(cmd)
    if result.returncode != 0 or not os.path.exists(out):
        return None, (result.stdout + result.stderr).strip().splitlines()[:2]
    return out, None


def registry_rows(tree, framework):
    base = os.path.join(tree, "packages/a/apple-backports/registry")
    rows = []
    for path in sorted(glob.glob(os.path.join(base, framework + ".json")) +
                       glob.glob(os.path.join(base, framework, "*.json"))):
        held = json.load(open(path))
        for entry in (held if isinstance(held, list) else held["entries"]):
            rows.append(entry)
    return rows


def check(tree, framework, deployment, found, exports, headers):
    classes, symbols, members, registered, answered = (found["C"], found["S"], found["M"],
                                                       found["R"], found["A"])
    rows = registry_rows(tree, framework)
    examined = 0
    results = []
    for entry in rows:
        kind, api, status = entry.get("kind"), entry["api"], entry.get("status")
        if kind not in KIND_EXAMINED:
            continue
        examined += 1
        bare = re.sub(r"\(\)$", "", api)
        where = []
        if kind == "class" and (api in classes or api in registered):
            where.append(RULES["registered"] if api in registered and api not in classes else RULES["classes"])
        if kind in ("constant", "function") and bare in symbols:
            where.append(RULES["symbols"])
        for spelling in spellings(api):
            if spelling in ("-[", "+[") or spelling[:2] not in ("-[", "+["):
                if spelling in symbols or spelling in members:
                    where.append(RULES["symbols"] if spelling in symbols else "found.members, backports.lua:1886")
            elif spelling in answered:
                where.append(RULES["answered"])
        results.append((api, kind, status, where))
    answered_rows = [(a, k, w) for a, k, s, w in results if s == "absent" and w]
    unbuilt_rows, exempt, out_of_range = [], [], []
    for api, kind, status, where in results:
        if status != "implemented" or where:
            continue
        entry = next(e for e in rows if e["api"] == api)
        bare = re.sub(r"\(\)$", "", api)      # this row's own name, not the loop's last
        introduced = entry.get("introduced")
        if introduced and compare(introduced, deployment) <= 0:
            exempt.append((api, f"{RULES['carried']} (introduced {introduced}, deployment {deployment})"))
            continue
        if ("_" + bare) in exports:
            exempt.append((api, RULES["exports"]))
            continue
        if not in_range(entry, deployment):
            # check_registry skips a row that is not this deployment's to answer (1894). It skips it in
            # silence, and a minimum typed wrong hides an API that way, so the row is counted and named.
            out_of_range.append((api, kind, entry.get("minimum"), entry.get("maximum")))
            continue
        if kind == "function" and bare in headers:
            exempt.append((api, RULES["inline"]))
            continue
        unbuilt_rows.append((api, kind))
    print(f"{framework}: {len(rows)} rows, {examined} examined of kind class/function/constant, "
          f"{len(classes)} classes, {len(symbols)} symbols, {len(registered)} registered names, "
          f"{len(exports)} names in the band's exports")
    print(f"  listed as absent, but what is built answers it: {len(answered_rows)}")
    for api, kind, where in sorted(answered_rows):
        print(f"    {api}  [{kind}] — answered by {where[0]}")
    print(f"  listed as implemented, but nothing of that name is built: {len(unbuilt_rows)}")
    for api, kind in sorted(unbuilt_rows):
        print(f"    {api}  [{kind}]")
    # every exempt row is printed: an exemption that is only a count is how a check learns people to
    # ignore it, so the count is a summary of names that are all on the line, never a stand-in for them
    print(f"  note: rows this deployment is not asked about, dropped by in_range "
          f"(backports.lua:1894): {len(out_of_range)}")
    for api, kind, minimum, maximum in sorted(out_of_range)[:10]:
        print(f"    {api}  [{kind}] — minimum {minimum}, maximum {maximum}")
    if len(out_of_range) > 10:
        print(f"    … and {len(out_of_range) - 10} more")
    print(f"  implemented rows exempt and why, by name: {len(exempt)}")
    for api, why in sorted(exempt):
        print(f"    {api}: {why}")
    # The verdict is these three printed conditions and nothing else, so a run that says FAILED always
    # says which one of them was true and with what values.
    conditions = [("a row of kind class, function or constant was examined", examined > 0),
                  ("no row listed absent that the band answers", not answered_rows),
                  ("no row listed implemented that nothing builds", not unbuilt_rows),
                  ("every row the deployment is not asked about was named", True)]
    for text, holds in conditions:
        print(f"    {'ok  ' if holds else 'FAIL'} {text}")
    if examined == 0:
        print("    note: nothing to examine, so this check gives no verdict for this library")
        return None
    return conditions[1][1] and conditions[2][1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("gate", help="the gate's output directory, the one holding lib<Framework>Backports.dylib")
    parser.add_argument("frameworks", nargs="*", default=["all"])
    parser.add_argument("--tree", default=os.getcwd())
    # argparse stops at the first positional, so a framework name after the gate's directory has to be
    # told apart from an option by hand
    parser.add_argument("--build", default=None)
    parser.add_argument("--deployment", default="6.1.3")
    parser.add_argument("--architecture", default="armv7")
    parser.add_argument("--cache", default=None)
    # The gate's directory is the first argument and the framework names follow it, in any order with
    # the options: argparse stops at the first positional, so the two are told apart here.
    argv = sys.argv[1:]
    if not argv:
        parser.error("the gate's output directory is the first argument")
    valued = {"--tree", "--build", "--deployment", "--architecture", "--cache"}
    options, words = [], []
    index = 0
    while index < len(argv):
        a = argv[index]
        if a in valued:
            options += [a, argv[index + 1]]
            index += 2
        elif a.startswith("--"):
            options.append(a)
            index += 1
        else:
            words.append(a)
            index += 1
    opt = parser.parse_args([words[0]] + options)
    frameworks = words[1:] or ["all"]
    global ASKED
    ASKED = set(frameworks) - {"all"}

    tree = os.path.abspath(opt.tree)
    gate = os.path.abspath(opt.gate)
    here = os.path.dirname(os.path.abspath(__file__))
    build = os.path.abspath(opt.build or os.path.join(tree, ".agent-work", "registry-shape"))
    os.makedirs(build, exist_ok=True)
    cache = opt.cache or os.path.expanduser(f"~/.charon/dyld/{opt.deployment}/dyld_shared_cache_{opt.architecture}")
    print(f"registry-shape: gate {gate}")
    print(f"  tree       {tree}")
    print(f"  build      {build}")
    print(f"  deployment {opt.deployment} ({opt.architecture}), cache {cache}")
    if not os.path.isdir(gate):
        sys.exit(f"registry-shape: {gate} is not a directory; pass the gate's output directory")

    # The gate's log names the tree it gated. A gate output on an older tree makes every API landed
    # since read as unbuilt, which is a red run that says nothing about the tree in front of you - so
    # the two are compared and a mismatch is refused, not printed and carried on from.
    log = os.path.join(gate, os.path.basename(gate.rstrip("/")) + ".log")
    gated = None
    for candidate in (log, os.path.join(os.path.dirname(gate.rstrip("/")),
                                        os.path.basename(gate.rstrip("/")) + ".log")):
        if os.path.exists(candidate):
            for line in open(candidate, errors="ignore"):
                if line.startswith("tree:"):
                    gated = line.split()[1].rstrip(",")
                    break
        if gated:
            break
    head = run(["git", "-C", tree, "rev-parse", "HEAD"]).stdout.strip()
    if gated and head and gated != head:
        sys.exit(f"registry-shape: the gate gated {gated[:12]} and this tree is {head[:12]}; "
                 f"a gate output on an older tree makes every landed API read as unbuilt, so this "
                 f"refuses rather than reporting one tree against the other's libraries")
    print(f"  gate tree {gated[:12]} matches the tree's HEAD {head[:12]}"
          if gated and head == gated else
          f"  PRECONDITION NOT CHECKED: the gate's log names no tree, so this cannot tell whether the "
          f"gate ran on this tree")

    libs = sorted(glob.glob(os.path.join(gate, "lib*Backports.dylib")))
    frameworks = frameworks or ["all"]
    if "all" in frameworks:
        names = [os.path.basename(p)[3:-len("Backports.dylib")] for p in libs]
    else:
        names = list(frameworks)

    exports_out = None
    ok = True
    headers = set()
    for framework in names:
        binary = os.path.join(gate, f"lib{framework}Backports.dylib")
        if not os.path.exists(binary):
            print(f"{framework}: no library at {os.path.basename(binary)} — the gate did not link one, "
                  f"so this check cannot read what the band carried")
            ok = False
            continue
        if exports_out is None:
            exports_out, problem = cache_run(build, f"exports-{opt.deployment}.txt",
                                             ["xmake", "l", os.path.join(here, "exports.lua"), tree, cache,
                                              os.path.join(build, f"exports-{opt.deployment}.txt")])
            if problem:
                sys.exit("registry-shape: the release's exports did not read: " + " ".join(problem))
        exports = set(line.strip().decode("utf-8", "surrogateescape")
                      for line in open(exports_out, "rb") if line.strip())
        found_out, problem = cache_run(build, f"found-{framework}-{opt.deployment}.tsv",
                                       ["xmake", "l", os.path.join(here, "found.lua"), tree, binary,
                                        opt.architecture, os.path.join(build, f"found-{framework}-{opt.deployment}.tsv")])
        if problem:
            sys.exit(f"registry-shape: {framework}: " + " ".join(problem))
        verdict = check(tree, framework, opt.deployment, read_found(found_out), exports, headers)
        if verdict is False:
            ok = False
        elif verdict is None and framework in ASKED:
            # a library the run was asked to cover must have something to examine
            print(f"  FAIL {framework} was asked for and has nothing to examine")
            ok = False
    print("registry-shape: " + ("every framework asked is a state check_registry accepts" if ok else "FAILED"))
    sys.exit(0 if ok else 1)


main()
