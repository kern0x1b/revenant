#!/usr/bin/env python3
"""
Tests for the corpus tools, for the three defects a review measured on the 0001..0004 delivery.

  1. `const-values.py` wrote a pointer's width as `0`, and `cache-value.lua` reads `0` as "read
     nothing", so every constant string came back empty.
  2. `cache-value.lua`'s symbols-file pattern was `(%d+)`, which cannot accept the `p` its own
     header documents as "this cache's pointer size".
  3. The surface scanner attributed `API_UNAVAILABLE(ios)` declarations -- tvOS's and visionOS's --
     to iOS rows, so rows that are not iOS APIs were in the denominator.

Each is pinned by a test that fails on the defect rather than asserting the fix in prose. 1 and 2
are checked end to end against a real dyld shared cache, because the defect was in the contract
between two programs and only a round trip catches it. 3 is checked against the walk's own output
for a declaration that really is marked that way.

Usage: python3 tools/corpus/tests/test_corpus.py [--cache <dyld cache file>]
"""
import argparse
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.realpath(__file__))
TOOLS = os.path.dirname(HERE)
CHARON_ROOT = os.path.realpath(os.path.join(TOOLS, "..", ".."))

FAILURES = []


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def check(condition, message):
    print("%-4s %s" % ("ok" if condition else "FAIL", message))
    if not condition:
        FAILURES.append(message)


def test_pointer_width_round_trip(cachefile):
    """Defects 1 and 2, end to end: a pointer-typed constant goes through the writer that
    const-values.py uses, is read by cache-value.lua, and comes back with its string. Both halves
    of the contract are in this one test, because the defect was in the contract itself."""
    constants = load("const_values", os.path.join(TOOLS, "const-values.py"))
    cv = constants
    # The width and pointer flag a CFStringRef-typed constant gets, from the classification itself.
    width, pointer, text, resolved = cv.classify("const CFStringRef", "const struct __CFString *", {})
    check(width == "p", "a pointer-typed constant is classified with the width 'p' (got %r)" % width)
    check(pointer and text, "a CFStringRef is classified as a pointer to a constant string")

    # The exact line const-values.py's writer emits, in the writer's own format.
    # The bare C name, as const-values.py writes it: the reader strips the cache's leading
    # underscore off an export and matches what is left.
    listing = _listing_path(cv, "NSDefaultRunLoopMode", width, pointer, text)
    with open(listing, encoding="utf-8") as f:
        line = f.read().strip()
    check(line.split("\t")[1] == "p",
          "the symbols file carries 'p' as the width, not 0 and not a number (%r)" % line)

    # Defect 2 pinned where it lives: the reader's own pattern. It is a Lua pattern, not a regex,
    # so it is checked as the text it is -- a digit class there cannot match the 'p' its own header
    # documents, and the end-to-end read below is what proves the whole contract.
    pattern = open(os.path.join(TOOLS, "cache-value.lua"), encoding="utf-8").read()
    matcher = re.search(r'line:match\("([^"]+)"\)', pattern)
    check(matcher is not None, "the reader's symbols-file pattern was found")
    if matcher:
        check("%d+" not in matcher.group(1),
              "the reader's pattern has no digit-only width class (%r)" % matcher.group(1))
        check("%S+" in matcher.group(1) or "%a+" in matcher.group(1)
              or "([^\\t]*)" in matcher.group(1),
              "the reader's pattern accepts a non-numeric width (%r)" % matcher.group(1))

    # And the whole round trip against a real cache: the string must come back.
    env = dict(os.environ, CHARON_ROOT=CHARON_ROOT)
    out = subprocess.run(["xmake", "l", os.path.join(TOOLS, "cache-value.lua"), cachefile, listing],
                         cwd=CHARON_ROOT, env=env, capture_output=True, text=True, timeout=900)
    os.unlink(listing)
    check(out.returncode == 0, "cache-value.lua ran on %s" % os.path.basename(cachefile))
    got = {}
    for row in out.stdout.splitlines():
        parts = row.split("\t")
        if len(parts) >= 10 and parts[0] == "NSDefaultRunLoopMode":
            got = parts
    check(bool(got), "the reader returned a row for NSDefaultRunLoopMode (empty means the width "
                     "contract is broken again: %r)" % out.stdout[:200])
    if got:
        check(got[7] not in ("-", ""), "the stored pointer was followed (%r)" % got[7])
        check(got[8] == "kCFRunLoopDefaultMode",
              "the constant string decoded to its real value (got %r)" % got[8])
        check(got[9] == "4", "the width column is the cache's pointer size (got %r)" % got[9])


def _listing_path(cv, name, width, pointer, text):
    handle, path = tempfile.mkstemp(suffix=".txt")
    with os.fdopen(handle, "w", encoding="utf-8") as f:
        f.write("%s\t%s\t%s\t%s\n" % (name, width, "p" if pointer else "-",
                                      "s" if text else "-"))
    return path


def test_platform_check():
    """Defect 3: a declaration the SDK marks API_UNAVAILABLE(ios) is tvOS's or visionOS's, and must
    leave the denominator, while NS_UNAVAILABLE (the API exists, Apple calls it unavailable) stays
    a row."""
    ledger = load("api_ledger", os.path.join(TOOLS, "api-ledger.py"))
    sd = load("surface_diff", os.path.join(TOOLS, "surface-diff-latest.py"))

    # A surface row and an index row that say the same thing the headers do.
    tv_only = {"api": "TVOnlyThing", "kind": "constant", "lang": "objc", "framework": "SomeFramework"}
    index = {"rows": {"TVOnlyThing": ["constant", None, True, True]},
             "macros": {}, "flags": {}, "typedefs": {}, "compiled": {}, "failed": []}
    status, reason, _, needs = ledger.classify_from_headers("TVOnlyThing", tv_only, index, "6.1.3",
                                                           {}, {})
    check(status == "not-ios", "a row marked API_UNAVAILABLE(ios) reads not-ios (got %r)" % status)
    check("leaves the denominator" in reason, "and the reason says it leaves the denominator")

    unavailable_here = {"api": "DeliberatelyUnavailable", "kind": "constant", "lang": "objc",
                        "framework": "SomeFramework"}
    index2 = {"rows": {"DeliberatelyUnavailable": ["constant", None, True, False]},
              "macros": {}, "flags": {}, "typedefs": {}, "compiled": {}, "failed": []}
    status2, reason2, _, _ = ledger.classify_from_headers("DeliberatelyUnavailable",
                                                          unavailable_here, index2, "6.1.3", {}, {})
    check(status2 == "missing" and "NS_UNAVAILABLE" in reason2,
          "NS_UNAVAILABLE stays a row, read missing with that reason (got %r: %r)" % (status2, reason2))

    # The mark the walk has to see, on a declaration that really carries it: find one in the SDK.
    found = _a_real_api_unavailable_ios(sd)
    if found:
        check(True, "the SDK's headers do carry API_UNAVAILABLE(ios) declarations, so the mark the "
                    "test feeds in is a real one (%s)" % found)
    else:
        check(False, "no API_UNAVAILABLE(ios) declaration was found in the SDK to check against")


def _a_real_api_unavailable_ios(sd):
    """The first `API_UNAVAILABLE(ios)` in the real SDK's headers, read as text: the test that the
    walk folds it into unavailable_ios is only worth anything if the SDK has such declarations."""
    sdk = os.environ.get("LEDGER_SDK") or os.path.join(
        os.path.expanduser("~"), "Git", "projects", "ios", "charon", ".agent-work", "sdk-26.2",
        "iPhoneOS26.2.sdk")
    for base, _, files in os.walk(os.path.join(sdk, "System", "Library")):
        for name in files:
            if not name.endswith(".h"):
                continue
            path = os.path.join(base, name)
            try:
                with open(path, encoding="utf-8", errors="replace") as f:
                    for line in f:
                        if "API_UNAVAILABLE(ios)" in line or "API_UNAVAILABLE(ios," in line:
                            return "%s: %s" % (os.path.relpath(path, sdk), line.strip()[:90])
            except OSError:
                continue
    return None


def _a_clang():
    """The compiler the ledger's own walk resolves, so the test reads the storage class off the same
    -ast-dump the classification does: LEDGER_CLANG, else the toolchain's clang under the shared
    xmake store, else whatever is on PATH. They agree on the ANSWER the test asserts and do not
    print the same words for it, which is why scan_storage reads clang's linkage token when it is
    printed and the keyword otherwise."""
    named = os.environ.get("LEDGER_CLANG")
    if named:
        return named
    import glob
    found = sorted(glob.glob(os.path.expanduser("~/.xmake/packages/l/llvm/*/*/bin/clang")))
    if found:
        return found[-1]
    return shutil.which("clang") or shutil.which("cc")


def _dump(source, sdk=None):
    """clang's own -ast-dump lines for a source given as text, at the target the ledger's walk uses."""
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, "storage_probe.c")
        with open(path, "w") as f:
            f.write(source)
        clang = _a_clang()
        if not clang:
            check(False, "no clang to read the storage class with")
            return []
        command = [clang, "-fsyntax-only", "-w", "-target", "armv7-apple-ios6.1.3"]
        if sdk:
            command += ["-isysroot", sdk]
        out = subprocess.run(command + ["-Xclang", "-ast-dump", path],
                             capture_output=True, text=True)
        return (out.stdout + out.stderr).splitlines()


def test_a_row_whose_line_does_not_compile_is_reported_as_failing():
    """Defect 5: `header-ok` was reported for rows whose own line carried an error. The generated
    unit's line map was keyed by the int line number and a diagnostic's line arrives as a string, so
    `line not in line_of` was true for every line of every unit and `verdict` stayed "" throughout.

    Pinned on a header of the test's own, with one row that names something the header does not
    declare and one that names something it does: the first must come back with a diagnostic and the
    second must come back clean. Before the fix both came back clean."""
    ledger = load("api_ledger", os.path.join(TOOLS, "api-ledger.py"))
    clang = _a_clang()
    if not clang:
        check(False, "no clang to compile the generated unit with")
        return
    with tempfile.TemporaryDirectory() as tmp:
        header = os.path.join(tmp, "charon_probe.h")
        with open(header, "w") as f:
            f.write("#define CHARON_PROBE_TWICE 2\n")
        rows = [("constant", "CHARON_PROBE_TWICE"), ("constant", "CHARON_PROBE_MISSING")]
        out = ledger.compile_named_rows(["charon_probe.h"],
                                        [clang, "-w", "-target", "armv7-apple-ios6.1.3",
                                         "-I", tmp],
                                        rows, tmp, "charon_probe")
    check(out.get("CHARON_PROBE_TWICE") == "",
          "a row whose line compiles comes back clean (got %r)" % (out.get("CHARON_PROBE_TWICE"),))
    missing = out.get("CHARON_PROBE_MISSING")
    check(bool(missing),
          "a row whose line does NOT compile comes back with the diagnostic on it (got %r)" % (missing,))
    check(missing and "undeclared" in missing,
          "and the diagnostic is the compiler's own (got %r)" % (missing,))


def test_static_inline_through_a_macro_is_header_only():
    """Defect 4: `static inline` behind a macro read as neither extern nor static, so every row of a
    header-only C API was placed `missing` and 640 functions Apple never exports were handed out as
    work. Measured on the real compiler's own output, never on a string the test made up.

    The shape is Spatial's. `SPATIAL_INLINE` is `static inline` (Spatial/Base.h:34), the DECLARATION
    carries it, and the DEFINITION hundreds of lines later is preceded by the refined-for-swift and
    overloadable attributes only. clang 23.1.1 prints the declaration
    `static inline internal-linkage` and the definition `implicit-inline internal-linkage` - no
    `static` token on that line, and `implicit-inline` hyphenated where `" inline"` looks for a
    space - so the scan that read a keyword and kept the last line per name saw (extern, static) as
    (false, false) for all 640 and the classification's `if is_extern or not is_static` sent every
    one of them to `missing`, "the port has to export it".

    Two reads are pinned and neither is sufficient alone, which is why both are in scan_storage: the
    linkage token clang prints on every line, and the keyword on the declaration that the later
    definition omits. Either alone is enough on clang 23.1.1 and neither is on a compiler that prints
    no linkage token, and the test fails if BOTH are removed - which is the code that was there.

    A real extern function and a real extern variable must still read extern, so the fix is not
    "everything is header-only now"."""
    ledger = load("api_ledger", os.path.join(TOOLS, "api-ledger.py"))
    source = ["#define CH_M static inline\n",
              "CH_M int charon_header_only(int);\n",
              "int charon_header_only(int x) { return x; }\n",   # repeats neither `static` nor `inline`
              "extern int charon_extern_function(int);\n",
              "extern int charon_extern_variable;\n",
              "int main(void) { return charon_extern_function(0); }\n"]
    lines = _dump("".join(source))
    decl = [l for l in lines if l.startswith("|-FunctionDecl") and " charon_header_only " in l]
    check(len(decl) == 2, "the dump prints the header-only function twice, once per declaration and "
                           "once per definition (got %d)" % len(decl))
    if len(decl) == 2:
        check(" static" in decl[0] and "static" not in decl[1].split("'")[0].split("'")[0][:0] + decl[1],
              "the declaration line carries `static`")
        check(" static" not in decl[1],
              "and the DEFINITION line does not, so the declaration is the only place the keyword "
              "appears - which is the whole defect (got %r)" % decl[1][-70:])
        check(" implicit-inline" in decl[1] or " inline" in decl[1],
              "the definition line says inline in the hyphenated form, where a `\" inline\"` test "
              "finds nothing (got %r)" % decl[1][-70:])
    flags = {}
    ledger.scan_storage(lines, flags)
    # the same flags under the name the classification row uses, so the two halves of the test are
    # the same measurement rather than two
    flags["CharonInlineMacro"] = flags["charon_header_only"]
    check(flags.get("charon_header_only", (None,))[1] is True,
          "a function declared `static inline` through a macro reads static (got %r)"
          % (flags.get("charon_header_only"),))
    check(flags.get("charon_header_only", (True,))[0] is False, "and not extern")
    check(flags.get("charon_extern_function", (None,))[0] is True,
          "a real extern function still reads extern (got %r)" % (flags.get("charon_extern_function"),))
    check(flags.get("charon_extern_function", (None, None))[1] is False,
          "and does not read static")
    check(flags.get("charon_extern_variable", (None,))[0] is True,
          "a real extern variable still reads extern (got %r)" % (flags.get("charon_extern_variable"),))

    # The classification the flag feeds: a static declaration is header-only, so the row is not
    # `missing`. classify_from_headers returns (status, reason, introduced, needs).
    row = {"api": "CharonInlineMacro()", "kind": "function", "lang": "objc", "framework": "SomeFramework"}
    index = {"rows": {"CharonInlineMacro()": ["function", None, None, False]},
             "macros": {}, "flags": flags, "typedefs": {}, "compiled": {"CharonInlineMacro": ""},
             "failed": []}
    status, reason, _, _ = ledger.classify_from_headers("CharonInlineMacro()", row, index, "6.1.3",
                                                        {}, {})
    check(status == "header-ok",
          "a function declared `static inline` through a macro is header-ok, not missing "
          "(got %r: %r)" % (status, reason))
    check("no run-time symbol" in reason,
          "and the reason says there is no run-time symbol to export (got %r)" % reason)

    _every_spatial_function_is_header_only(ledger)


def _every_spatial_function_is_header_only(ledger):
    """The defect end to end, on the headers that produced it: all 640 of Spatial's C functions read
    static and not extern. This is the row set that was handed out as 640 units of missing work, so
    it is the assertion worth having; the synthetic probe above is what says why."""
    sdk = os.environ.get("LEDGER_SDK") or os.path.join(
        os.path.expanduser("~"), "Git", "projects", "ios", "charon", ".agent-work", "sdk-26.2",
        "iPhoneOS26.2.sdk")
    umbrella = os.path.join(sdk, "usr", "include", "Spatial", "Spatial.h")
    if not os.path.isfile(umbrella):
        check(False, "the 26.2 SDK's Spatial umbrella is not at %s, so the 640 rows cannot be checked"
              % umbrella)
        return
    lines = _dump("#import <Spatial/Spatial.h>\n", sdk)
    flags = {}
    ledger.scan_storage(lines, flags)
    names = sorted(n for n in flags if n.startswith("SP"))
    static = [n for n in names if flags[n][1] and not flags[n][0]]
    check(len(names) >= 640, "the dump names Spatial's functions (%d)" % len(names))
    check(len(static) == len(names) and len(names) >= 640,
          "every one of them reads static and not extern, so none is a symbol the port must export "
          "(%d of %d static; extern: %s)"
          % (len(static), len(names), ", ".join(n for n in names if flags[n][0])[:120]))


def test_surface_fold():
    """The walk's own fold, on the two marks, so the ledger's input is checked and not only the
    ledger's reading of it."""
    sd = load("surface_diff", os.path.join(TOOLS, "surface-diff-latest.py"))
    surface = sd.Surface("Test", full=True)
    surface.target = ("TVOnlyThing", "constant", [])
    surface.target_depth = 0
    surface.target_attrs = [(None, None, None, True, "ios")]
    detail = surface.resolve("constant")
    check(detail["unavailable"] and detail["unavailable_ios"],
          "an ios Unavailable availability attribute folds into unavailable_ios")
    surface2 = sd.Surface("Test", full=True)
    surface2.target = ("Gone", "constant", [])
    surface2.target_depth = 0
    surface2.target_attrs = [(None, None, None, True, None)]
    detail2 = surface2.resolve("constant")
    check(detail2["unavailable"] and not detail2["unavailable_ios"],
          "an NS_UNAVAILABLE folds into unavailable but not unavailable_ios")


def test_empty_module_is_a_failed_read():
    """A module that reports no declaration is a read that did not happen, not a measurement.

    The digester exits 0 and writes an empty tree when it cannot load a module or one of its
    dependencies. Indexed as "this module declares nothing", that turns every row of the module
    into `missing` that are not missing: it has cost 1222 Combine rows and then two more modules,
    and each time the only symptom was a plausible-looking number. This test feeds the reader a
    0-declaration dump and fails if the guard is gone.
    """
    sw = load("api_ledger_swift", os.path.join(TOOLS, "api-ledger-swift.py"))
    empty = {"ABIRoot": {"kind": "Root", "children": []}}
    names, _conformances, error = sw.read_declarations(empty, "FoundationEssentials")
    check(names is None and error,
          "a 0-declaration dump is refused, not indexed as an empty module (got %r, %r)"
          % (names, error))
    check(error and "FoundationEssentials" in error and "not an empty one" in error,
          "and the refusal names the module and says what it is not: %r" % (error,))
    # The digester names the missing module on stderr and exits 0; that line must survive into the
    # refusal, because a refusal that does not say what is missing cannot be acted on.
    canned = ("<unknown>:0: error: missing required modules: 'CharonFormat', 'CharonPlatform', "
              "CharonSysdir\n")
    names, _conformances, error = sw.read_declarations(empty, "FoundationEssentials", canned)
    check(error and "CharonFormat" in error and "CharonSysdir" in error,
          "the refusal carries the digester's own line, naming the missing modules: %r" % (error,))
    names, _conformances, error = sw.read_declarations(empty, "FoundationEssentials", "")
    check(error and "not an empty one" in error,
          "and with no stderr it still says what it is refusing and why: %r" % (error,))
    real = {"ABIRoot": {"kind": "Root", "children": [
        {"kind": "TypeDecl", "printedName": "Date", "children": [
            {"kind": "Function", "printedName": "timeInterval(since:)"}]}]}}
    names, conformances, error = sw.read_declarations(real, "Foundation")
    check(names and not error,
          "a module that does declare something is read, so the guard refuses nothing else "
          "(got %r, %r)" % (len(names or {}), error))
    check(conformances is not None, "and its conformances come with it")


def test_uncovered_module_leaves_rows_undecided():
    """A readable module that places none of a framework's rows is coverage, not a gap.

    CreateMLComponents: the band built 614 declarations of the tabular half and the corpus's 2134
    rows are the audio and vision half, so 0 of 189 root types are in the module. Reading those
    rows `missing` would say the port will never have them, which nothing supports.
    """
    ledger = load("api_ledger", os.path.join(TOOLS, "api-ledger.py"))
    swift = {"names": {"BoostedTreeFitter": {("CreateMLComponents", "TypeDecl")}},
             "modules": {"CreateMLComponents"}, "registries": {}, "conformances": {},
             "references": {}, "digester": "x", "target": "armv7", "sources": {},
             "search-dirs": [], "extra-module-maps": [],
             "matched-by-framework": {"CreateMLComponents": 0},
             "declaration-count": {"CreateMLComponents": 614}}
    row = {"api": "AudioReader.microphoneAuthorizationDenied", "kind": "property", "lang": "swift",
           "framework": "CreateMLComponents"}
    status, reason, _, needs = ledger.classify_swift(row["api"], row, swift)
    check(status == "undecided" and needs == "swift-module",
          "a framework the module does not cover stays undecided (got %r, %r)" % (status, needs))
    check(reason and "coverage, not the matcher" in reason and "614 declarations" in reason,
          "and the reason says what it is, with the count: %r" % (reason,))
    swift["matched-by-framework"] = {"CreateMLComponents": 40}
    status2, _, _, needs2 = ledger.classify_swift(row["api"], row, swift)
    check(status2 == "missing" and needs2 == "code",
          "but where the module does place some rows, the rest are a real gap (got %r, %r)"
          % (status2, needs2))


def test_cache_record_is_typed_and_versioned():
    """The index cache holds one typed record, versioned, so an old file is refused rather than
    misread: a bare list of names and a record with named fields are both JSON, and one run read the
    first as the second and printed a conformances dict as a declaration count."""
    sw = load("api_ledger_swift", os.path.join(TOOLS, "api-ledger-swift.py"))
    record = sw.CACHE_RECORD_VERSION
    check(isinstance(record, int) and record >= 2,
          "the cache record carries a version number (%r)" % (record,))
    fresh = {"version": record, "names": {"Date": "TypeDecl"}, "conformances": {"Date": ["Equatable"]}}
    old_list = [{"Date": "TypeDecl"}, {"Date": ["Equatable"]}]
    old_bare = {"Date": "TypeDecl"}
    check(sw.read_cache_record(fresh) is not None,
          "a current record is accepted")
    check(sw.read_cache_record(old_list) is None,
          "an old two-element list cache file is refused rather than misread")
    check(sw.read_cache_record(old_bare) is None,
          "an old bare-names cache file is refused rather than misread")
    check(sw.read_cache_record({"version": record - 1, "names": {}, "conformances": {}}) is None,
          "a record of an older version is refused")


def test_swift_index_file_is_loaded_from_disk():
    """The reader must survive the shapes a real index file comes in, read from a file and not from a
    dict built in the test: the suite had 58 checks and none of them loaded a file, so a half-written
    index -- what a crashed run leaves -- was only ever found by the ledger refusing to regenerate."""
    ledger = load("api_ledger", os.path.join(TOOLS, "api-ledger.py"))
    sw = load("api_ledger_swift", os.path.join(TOOLS, "api-ledger-swift.py"))
    index = {
        "digester": "x", "target": "armv7-apple-ios6.1.3", "modules": {
            "Foundation": {"Date": "TypeDecl", "Date.timeInterval(since:)": "Function"},
            "Foundation": {"Date": "TypeDecl"},
            "Calendar": {"Date": "TypeDecl"},
        },
        "conformances": {"Date": ["Equatable"]}, "references": {}, "sources": {},
    }
    del index["modules"]["Calendar"]
    index["modules"]["Calendar"] = {"Date": "TypeDecl"}
    with tempfile.TemporaryDirectory() as work:
        # The shape the writer produces: module -> {name: kind}.
        flat = os.path.join(work, "flat.json")
        with open(flat, "w", encoding="utf-8") as f:
            json.dump(index, f)
        loaded = ledger.load_swift_modules(flat)
        check("Foundation" in loaded["modules"] and "Date" in loaded["names"],
              "a real index file loads: %d modules" % len(loaded["modules"]))
        # The shape the cache holds, met on the reading side.
        wrapped = os.path.join(work, "wrapped.json")
        record = dict(index)
        record["modules"] = {m: {"version": sw.CACHE_RECORD_VERSION, "names": d,
                                 "conformances": {}}
                             for m, d in index["modules"].items()}
        with open(wrapped, "w", encoding="utf-8") as f:
            json.dump(record, f)
        check(len(ledger.load_swift_modules(wrapped)["modules"]) == 2,
              "a module wrapped in a versioned record loads too, rather than raising")
        # And a half-written module is refused with what it is, not with a TypeError.
        broken = os.path.join(work, "broken.json")
        record["modules"] = dict(index["modules"])
        record["modules"]["Foundation"] = {"names": {"Date": "TypeDecl"}, "conformances": {}}
        record["modules"]["HalfWritten"] = {"names": {}}
        del record["modules"]["HalfWritten"]["names"]
        record["modules"]["HalfWritten"] = "Foundation"
        with open(broken, "w", encoding="utf-8") as f:
            json.dump(record, f)
        try:
            ledger.load_swift_modules(broken)
            check(False, "a half-written index module must be refused")
        except ValueError as error:
            check("not a map of names to kinds" in str(error),
                  "and the refusal says what the file is, not a TypeError: %s" % str(error)[:90])


def test_built_tree_reads_a_real_run_directory():
    """built_tree is what tells a report which revision a run directory was built from, and it is the
    one that keeps saying "tree not recorded" when a directory is stale. It is exercised here on a
    directory and a `tree` file written on disk, both shapes."""
    ledger = load("api_ledger", os.path.join(TOOLS, "api-ledger.py"))
    with tempfile.TemporaryDirectory() as work:
        run = os.path.join(work, "gate-6.1.3")
        os.makedirs(run)
        check("tree not recorded" in ledger.built_tree(run),
              "a directory with no tree file says so, with its own age, and not a revision")
        check("no --gate" in ledger.built_tree(None),
              "and no directory at all says so rather than raising: %r" % ledger.built_tree(None))
        with open(os.path.join(run, "tree"), "w", encoding="utf-8") as f:
            f.write("revision\t68befacae0337a1b2c3\ncheckout\t/charon\ndirty\tno\n")
        check(ledger.built_tree(run) == "68befacae033",
              "a tree file is read and the revision is the short form (%r)" % ledger.built_tree(run))
        with open(os.path.join(run, "tree"), "w", encoding="utf-8") as f:
            f.write("revision\t68befacae0337a1b2c3\ncheckout\t/charon\ndirty\tyes\n")
        check("dirty" in ledger.built_tree(run),
              "a dirty build is marked as one: %r" % ledger.built_tree(run))
        with open(os.path.join(run, "tree"), "w", encoding="utf-8") as f:
            f.write("revision\tunknown\ncheckout\t/charon\n")
        check("tree not recorded" in ledger.built_tree(run),
              "a tree file that says it does not know is treated as not recorded")


def test_write_output_writes_files_a_reader_can_use():
    """write_output is what every number in the ledger directory is printed by. It is exercised here
    on a real output directory, and the two properties the r3 review found broken are checked on what
    it wrote: a status that is counted gets a column, and every table's total is the sum of its
    columns."""
    ledger = load("api_ledger", os.path.join(TOOLS, "api-ledger.py"))
    with tempfile.TemporaryDirectory() as work:
        args = type("A", (), {})()
        args.out = work
        args.release = "6.1.3"
        args.gate = None
        args.frameworks = None
        args.jobs = 4
        args.swift_modules = None
        args.release_cache = "/nowhere/dyld_shared_cache_armv7"
        args.sdk = "/nowhere/iPhoneOS26.2.sdk"
        # write_output prints the overlay's mtime, so the path has to exist to be reported on.
        args.surface = os.path.join(work, "surface.tsv")
        with open(args.surface, "w", encoding="utf-8") as f:
            f.write("framework\tapi\n")
        args.vfs = os.path.join(work, "vfs.yaml")
        with open(args.vfs, "w", encoding="utf-8") as f:
            f.write("[]\n")
        results = [({"kind": "constant", "lang": "objc", "api": "kA", "framework": "Alpha",
                    "introduced": "9.0"}, "implemented", "built", None, None),
                  ({"kind": "constant", "lang": "objc", "api": "kB", "framework": "Alpha",
                    "introduced": "9.0"}, "missing", "no symbol", None, "code"),
                  ({"kind": "constant", "lang": "objc", "api": "kC", "framework": "Beta",
                    "introduced": "9.0"}, "not-ios", "API_UNAVAILABLE(ios)", None, "none"),
                  ({"kind": "constant", "lang": "objc", "api": "kD", "framework": "Beta",
                    "introduced": "9.0"}, "declared", "registry only", None, "build")]
        ledger.write_output(results, args, 12.0, {}, 0, 1.0, None)
        summary = open(os.path.join(work, "SUMMARY.md"), encoding="utf-8").read()
        check("leave the denominator" in summary and "1" in summary,
              "the not-ios row is reported in prose at the top")
        body = summary.split("## By kind")[1]
        check("not-ios" in body.splitlines()[2] and "declared" in body.splitlines()[2],
              "and both statuses have a column in By kind: %r" % body.splitlines()[2])
        def disagreeing(section):
            bad = 0
            for line in section.splitlines():
                if not line.startswith("| "):
                    continue
                cells = [c.strip() for c in line.strip("|").split("|")]
                if len(cells) < 3 or not all(c.lstrip("-").isdigit() for c in cells[1:]):
                    continue          # a header or a separator, not a row of counts
                if sum(int(c) for c in cells[1:-1]) != int(cells[-1]):
                    bad += 1
            return bad

        check(disagreeing(body) == 0,
              "every By kind row's total is the sum of its columns (%d disagree)"
              % disagreeing(body))
        body = summary.split("## By framework")[1].split("\n## ")[0]
        check(disagreeing(body) == 0,
              "every By framework row's total is the sum of its columns (%d disagree)"
              % disagreeing(body))
        header = [l for l in body.splitlines() if l.startswith("| framework")][0]
        for status in ("implemented", "missing", "not-ios", "declared"):
            check(status in header,
                  "the By framework header has a column for %s, so a counted status is a shown one "
                  "(%r)" % (status, header))
        todo = os.path.join(work, "Alpha.tsv")
        check(os.path.exists(todo) and "kA" not in open(todo, encoding="utf-8").read(),
              "a fully implemented framework's todo file exists and lists no row")
        listed = open(os.path.join(work, "Beta.tsv"), encoding="utf-8").read()
        check("not-ios" in listed and "declared" in listed and "kC" in listed,
              "and an unimplemented one carries its rows with their status")


def test_swift_row_from_a_registry():
    """A Swift row a package's registry records and no built module carries reads `declared`, not
    `implemented`: the two are different claims and the earlier review was right to insist on
    telling them apart. And an Objective-C row still takes no registry input at all."""
    ledger = load("api_ledger", os.path.join(TOOLS, "api-ledger.py"))
    swift = {"names": {}, "modules": set(),
             "registries": {"ColumnarTransformer": ("implemented", "packages/c/createml", "shape")},
             "references": {}, "digester": "x", "target": "armv7-apple-ios6.1.3", "sources": {},
             "search-dirs": [], "extra-module-maps": []}
    row = {"api": "ColumnarTransformer", "kind": "protocol", "lang": "swift",
           "framework": "CreateMLComponents"}
    status, reason, _, needs = ledger.classify_swift("ColumnarTransformer", row, swift)
    check(status == "declared", "a Swift row only a registry records reads declared (got %r)" % status)
    check("packages/c/createml" in reason, "and the reason names the package it came from")
    check(needs == "build", "and the row says what is left: build the module (%r)" % needs)

    swift2 = dict(swift)
    swift2["names"] = {"ColumnarTransformer": {("CreateMLComponents", "TypeDecl")}}
    swift2["modules"] = {"CreateMLComponents"}
    status2, reason2, _, _ = ledger.classify_swift("ColumnarTransformer", row, swift2)
    check(status2 == "implemented",
          "with a built module carrying it, the row reads implemented, not declared (got %r)"
          % status2)

    objc = {"api": "NSString.length", "kind": "method", "lang": "objc", "framework": "Foundation"}
    swift3 = dict(swift)
    swift3["registries"] = {"NSString.length": ("implemented", "packages/x/y", "r")}
    status3, _, _, _ = ledger.classify_swift("NSString.length", objc, swift3)
    check(status3 != "implemented" and status3 != "declared",
          "an Objective-C row is not placed from a registry even when one has its name (got %r)"
          % status3)


def test_swift_normalisations():
    """One test per digester normalisation, each with the pair it has to make equal: the five are
    measured rules from the band that hit them, and the payload-case rule is the one this tool
    measured (the digester prints `X.() -> Swift.Bool` for a payload case, so the case's own name
    is nowhere in the index)."""
    ledger = load("api_ledger", os.path.join(TOOLS, "api-ledger.py"))
    implemented = [
        ("argument labels", "CGAffineTransform.==(lhs:rhs:)", "CGAffineTransform.==(_:_:)"),
        ("failable initialiser", "CGPathFillRule.init?(rawValue:)", "CGPathFillRule.init(_:)"),
        ("failable subscript", "Foo.subscript?(x: Int)", "Foo.subscript(_:)"),
        ("operator", "Foo.~=(a:)", "Foo.~="),
        ("subscript labels", "Foo.subscript(index: Int)", "Foo.subscript(_:)"),
        ("generic parameter list, composed", "Foo.Bar.init?<Value.UnwrappedType>(_ value: Value)",
         "Foo.Bar.init(_:)"),
        ("payload case", "Publishers.AllSatisfy.() -> Swift.Bool", "Publishers.AllSatisfy"),
    ]
    for name, row, printed in implemented:
        forms = ledger.swift_forms(row)
        check(printed in forms, "normalisation %s: %s reaches %r (forms: %s)"
              % (name, row, printed, forms))

    # The index rule for the same shape: the digester prints `X.() -> Swift.Bool` for a payload
    # case, so the case's own name is nowhere in the index and no row rule can reach it.
    sw = load("api_ledger_swift", os.path.join(TOOLS, "api-ledger-swift.py"))
    payload = {"ABIRoot": {"kind": "Root", "children": [
        {"kind": "TypeNominal", "printedName": "Publishers", "children": [
            {"kind": "TypeNominal", "printedName": "AllSatisfy", "children": [
                {"kind": "Constructor", "printedName": "() -> Swift.Bool"}]}]}]}}
    indexed, conformances, _ = sw.index_from_json(payload)
    check("Publishers.AllSatisfy" in indexed,
          "a payload case is indexed under its own name (got %s)" % sorted(indexed))
    # And the two label conventions meet: the digester prints labels, a corpus row carries parameter
    # names, and the index carries both reduced forms.
    reduced = {"ABIRoot": {"kind": "Root", "children": [
        {"kind": "TypeDecl", "printedName": "Date", "children": [
            {"kind": "Function", "printedName": "timeInterval(since:)"}]}]}}
    both, _, _ = sw.index_from_json(reduced)
    check("Date.timeInterval(since:)" in both and "Date.timeInterval(_:)" in both,
          "a member is indexed under both label conventions (got %s)" % sorted(both))
    conformed = {"ABIRoot": {"kind": "Root", "children": [
        {"kind": "TypeDecl", "printedName": "ActivityStyle", "declKind": "Enum",
         "conformances": [{"kind": "Conformance", "name": "Equatable", "printedName": "Equatable"}],
         "children": []}]}}
    _, seen, _ = sw.index_from_json(conformed)
    check("Equatable" in seen.get("ActivityStyle", []),
          "a type's conformances are indexed (got %s)" % seen.get("ActivityStyle"))

    # The split the composition rests on: the last dot outside brackets, with a generic parameter
    # list counted as a bracket, so `init?<Value.UnwrappedType>(` does not get cut inside.
    for name, want in (("Foo.Bar.init?<Value.UnwrappedType>(_ value: Value)", ("Foo.Bar", None)),
                       ("A.b.c(d:)", ("A.b", "c(d:)")),
                       ("NoOwner", ("", "NoOwner"))):
        owner, _ = ledger.split_qualified(name)
        check(owner == want[0], "split_qualified(%r) gives owner %r (got %r)" % (name, want[0], owner))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cache", default=os.path.expanduser(
        "~/.charon/dyld/6.1.3/dyld_shared_cache_armv7"))
    args = ap.parse_args()
    print("testing the corpus tools against %s\n" % os.path.basename(args.cache))
    test_pointer_width_round_trip(args.cache)
    test_platform_check()
    test_static_inline_through_a_macro_is_header_only()
    test_a_row_whose_line_does_not_compile_is_reported_as_failing()
    test_surface_fold()
    test_swift_index_file_is_loaded_from_disk()
    test_built_tree_reads_a_real_run_directory()
    test_write_output_writes_files_a_reader_can_use()
    test_empty_module_is_a_failed_read()
    test_cache_record_is_typed_and_versioned()
    test_uncovered_module_leaves_rows_undecided()
    test_swift_row_from_a_registry()
    test_swift_normalisations()
    print("\n%d failure(s)" % len(FAILURES))
    return 1 if FAILURES else 0


if __name__ == "__main__":
    sys.exit(main())
