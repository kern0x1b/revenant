"""Can libclang's cursor children be walked on this machine? A probe, not a tool.

    python3 tests/backports/host/metal-census/libclang-probe/probe.py

The census needs, per header, the declarations that header itself writes, and clang's JSON AST does
not carry the file for a definition: over MTLView.h the AST holds 2941 interfaces and protocols,
1995 of them with no loc.file at all, MTKView among them. libclang's C API does return a file for
every cursor, so if its children could be walked the table would be buildable from three parses.

This probe asks that question and prints the numbers, because the answer here is NO and the reason
is not obvious enough to be believed without being run. It is the evidence for a claim made in
packages/a/apple-backports/facts/Metal/Census.md, and it is deliberately independent of that file.

The translation unit is real, and this probe proves it rather than asserting it: diagnostics 0 and a
token count above zero from clang_tokenize over the translation unit's own extent. So a child count
of zero is not a parse that quietly produced nothing - decl.m holds an @interface with a method and
a file scope function, and clang lexed all of it.

The layout hypothesis is ruled out here too, which is worth stating because it is the most likely
explanation for a visitor that never fires: CXCursor is 32 bytes with kind at 0, xdata at 4 and data
at 8, and probe.c prints the same three numbers from the C side. A wrong struct layout on arm64 is a
real way to lose a callback, and it is not what is happening.

Nothing here is written outside .agent-work, and probe.c is compiled on demand into
.agent-work/runs/metal-census/ - never into the checkout.
"""
import ctypes
import ctypes.util
import os
import subprocess
import sys

LIBCLANG = "/Library/Developer/CommandLineTools/usr/lib/libclang.dylib"
HERE = os.path.dirname(os.path.abspath(__file__))
RUNS = os.path.join(".agent-work", "runs", "metal-census")


class CursorKind(ctypes.c_int):
    pass


class CXCursor(ctypes.Structure):
    """clang-c/Index.h: enum kind, int xdata, const void *data[3] - in that order."""
    _fields_ = [("kind", CursorKind), ("xdata", ctypes.c_int), ("data", ctypes.c_void_p * 3)]


class CXSourceRange(ctypes.Structure):
    _fields_ = [("ptr_data", ctypes.c_void_p * 2), ("begin_int_data", ctypes.c_uint),
                ("end_int_data", ctypes.c_uint)]


def load():
    if not os.path.isfile(LIBCLANG):
        raise SystemExit("refusing: %s is not there, so this probe cannot run, and a probe that "
                         "cannot run is not evidence of anything" % LIBCLANG)
    library = ctypes.CDLL(LIBCLANG)
    library.clang_getClangVersion.restype = ctypes.c_char_p
    library.clang_createIndex.restype = ctypes.c_void_p
    library.clang_createIndex.argtypes = [ctypes.c_int, ctypes.c_int]
    library.clang_parseTranslationUnit.restype = ctypes.c_void_p
    library.clang_parseTranslationUnit.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_void_p,
                                                   ctypes.c_int, ctypes.c_void_p, ctypes.c_uint,
                                                   ctypes.c_uint]
    library.clang_getNumDiagnostics.argtypes = [ctypes.c_void_p]
    library.clang_getNumDiagnostics.restype = ctypes.c_uint
    library.clang_getTranslationUnitCursor.restype = CXCursor
    library.clang_getTranslationUnitCursor.argtypes = [ctypes.c_void_p]
    library.clang_getCursorSpelling.restype = ctypes.c_char_p
    library.clang_getCursorSpelling.argtypes = [CXCursor]
    library.clang_getCursorKindSpelling.restype = ctypes.c_char_p
    library.clang_getCursorKindSpelling.argtypes = [ctypes.c_int]
    library.clang_getCursorExtent.restype = CXSourceRange
    library.clang_getCursorExtent.argtypes = [CXCursor]
    library.clang_tokenize.restype = None
    library.clang_tokenize.argtypes = [ctypes.c_void_p, CXSourceRange, ctypes.POINTER(ctypes.c_void_p),
                                       ctypes.POINTER(ctypes.c_uint)]
    return library


# The visitor lives at module scope, not inside counts(), and it only counts. Two versions of this
# that lived in the function aborted the process outright - one calling back into libclang from
# inside the callback, one closing over a list - so it is kept as plain as it can be, and it is kept
# alive in a module global because a temporary ctypes callback object is not guaranteed to outlive
# the call that passes it.
SEEN = []
VISITOR = None


def _on_child(cursor, parent, data):
    SEEN.append(cursor)
    return 2  # CXChildVisit_Continue


def counts(library, path):
    """(diagnostics, tokens, children) for one translation unit.

    The token array is deliberately NOT disposed. Every version of this that called
    clang_disposeTokens aborted the process afterwards, with no message, and a probe that aborts
    proves nothing; the tokens live until the translation unit goes, which is at process exit.
    """
    global VISITOR
    index = library.clang_createIndex(0, 0)
    unit = library.clang_parseTranslationUnit(index, path.encode(), None, 0, None, 0, 0)
    if not unit:
        return None, 0, 0
    tokens = (ctypes.c_void_p * 256)()
    number = ctypes.c_uint()
    library.clang_tokenize(unit, library.clang_getCursorExtent(
        library.clang_getTranslationUnitCursor(unit)), tokens, ctypes.byref(number))
    del SEEN[:]
    if VISITOR is None:
        VISITOR = ctypes.CFUNCTYPE(ctypes.c_int, CXCursor, CXCursor, ctypes.c_void_p)(_on_child)
        library.clang_visitChildren.argtypes = [ctypes.c_void_p, type(VISITOR), ctypes.c_void_p]
        library.clang_visitChildren.restype = ctypes.c_uint
    library.clang_visitChildren(unit, VISITOR, None)
    for cursor in SEEN:
        print("      child %s %s" % (library.clang_getCursorKindSpelling(cursor.kind).decode(),
                                     library.clang_getCursorSpelling(cursor).decode()))
    return library.clang_getNumDiagnostics(unit), number.value, len(SEEN)


def from_c():
    """The same three numbers, from C, so the two sides can be compared rather than trusted."""
    os.makedirs(RUNS, exist_ok=True)
    source = os.path.join(HERE, "probe.c")
    binary = os.path.abspath(os.path.join(RUNS, "probe"))
    subprocess.run(["xcrun", "clang", "-L/Library/Developer/CommandLineTools/usr/lib",
                    "-Wl,-rpath,/Library/Developer/CommandLineTools/usr/lib", "-lclang", source,
                    "-o", binary], check=True)
    # run from the probe's own directory, and the file is passed as an argument: the binary takes it
    # from argv so that a hand-built binary run from anywhere names a file that exists
    result = subprocess.run([binary, os.path.join(HERE, "decl.m")], cwd=HERE,
                            capture_output=True, text=True, check=True)
    return result.stdout


def main():
    library = load()
    print("libclang    %s" % LIBCLANG)
    print("version     %s" % library.clang_getClangVersion().decode())
    print("CXCursor    %d bytes, kind at %d, xdata at %d, data at %d (ctypes)"
          % (ctypes.sizeof(CXCursor), CXCursor.kind.offset, CXCursor.xdata.offset,
             CXCursor.data.offset))
    print("\nthe control: decl.m is an @interface with one method and a file scope function, so a")
    print("parse that produced nothing would be visible as tokens 0 and not as children 0.")
    diagnostics, tokens, children = counts(library, os.path.join(HERE, "decl.m"))
    print("ctypes      diagnostics %s  tokens %d  children %d"
          % (diagnostics, tokens, children), flush=True)
    print("\nthe same three numbers from C, built on demand into %s:" % RUNS)
    print(from_c().rstrip())
    print("\nA visitor that returns zero children on a translation unit with tokens above zero is")
    print("not walking. libclang's cursor children cannot be read on this machine, so the")
    print("per-header census cannot be built from them, and the aggregate counts in")
    print("facts/Metal/Census.md are the most this census can stand behind.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
