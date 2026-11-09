local tools = path.absolute(path.join(os.scriptdir(), "..", "tools"))
local skeleton = import("skeleton", {rootdir = tools, anonymous = true})
local sdkfiles = import("sdk", {rootdir = tools, anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})

local SYSTEM = [[
int FXValue = 42;
int FXGapValue = 55;
int FXQualifiedStore = 5;
int *const FXQualified = &FXQualifiedStore;
int FXExported = 3;
int FXAdd(int a, int b) { return a * 100 + b; }
void FXSetValue(int value) { FXValue = value; }
int FXGetValue(void) { return FXValue; }
]]

local LAZY = [[
#include <stdarg.h>
#include <stdio.h>
__attribute__((constructor)) static void fx_lazy_loaded(void)
{
    fputs("lazy image loaded\n", stderr);
}
int FXHidden(int a) { return a + 1; }
int FXVariadic(const char *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    va_arg(arguments, int);
    int second = va_arg(arguments, int);
    va_end(arguments);
    return 1000 + second;
}
]]

local FALLBACK = [[
#include "revenant_impl.h"
int BACKPORT_IMPL(FXHidden)(int a) { return a + 500; }
int BACKPORT_IMPL(FXGapValue) = 9;
]]

local DRIVER = [[
#include <pthread.h>
#include <stdio.h>
#include <string.h>
int FXAdd(int, int);
void FXSetValue(int);
int FXGetValue(void);
int FXMissing(int);
int FXVariadic(const char *, ...);
int FXHidden(int);
extern int FXValue;
extern int FXGapValue;
extern int *const FXQualified;
extern int FXExported;

static void *hammer(void *slot)
{
    long *total = slot;
    for (int index = 0; index < 2000; index++)
        *total += FXHidden(1);
    return NULL;
}

int main(int argc, char **argv)
{
    if (argc > 1 && strcmp(argv[1], "missing") == 0)
        return FXMissing(1);
    if (argc > 1 && strcmp(argv[1], "variadic") == 0) {
        printf("%d\n", FXVariadic("x", 7, 8));
        return 0;
    }
    if (argc > 1 && strcmp(argv[1], "lazy") == 0) {
        printf("main\n");
        fflush(stdout);
        printf("%d %d\n", FXHidden(1), FXGapValue);
        return 0;
    }
    if (argc > 1 && strcmp(argv[1], "threads") == 0) {
        pthread_t threads[8];
        long totals[8] = {0};
        for (int index = 0; index < 8; index++)
            pthread_create(&threads[index], NULL, hammer, &totals[index]);
        long total = 0;
        for (int index = 0; index < 8; index++) {
            pthread_join(threads[index], NULL);
            total += totals[index];
        }
        printf("%ld\n", total);
        return 0;
    }
    int sum = FXAdd(1, 2);
    FXSetValue(7);
    printf("%d %d %d %d %d\n", sum, FXValue, FXGetValue(), *FXQualified, FXExported);
    return 0;
}
]]

local function member(kind, name, signature)
    return {module = "FXSkel", kind = kind, container = "", name = name, symbol = name, signature = signature, intro = nil, flags = ""}
end

local function rows()
    return {
        member("C function", "FXAdd", "int (int, int)"),
        member("C function", "FXMissing", "int (int)"),
        member("C function", "FXSetValue", "void (int)"),
        member("C function", "FXGetValue", "int (void)"),
        member("C function", "FXVariadic", "int (const char *, ...)"),
        member("global variable", "FXValue", "int"),
        member("global variable", "FXTable", "const unsigned char[]"),
        member("global variable", "FXQualified", "FXConstKey"),
        member("global variable", "FXExported", "FX_EXTERN int"),
    }
end

local function generated(folder, system, lazy)
    local images = {FXAdd = system, FXMissing = system, FXSetValue = system, FXGetValue = system, FXValue = system,
        FXTable = system, FXGapValue = system, FXQualified = system, FXExported = system, FXVariadic = lazy, FXHidden = lazy}
    local framework = {name = "FXSkel", import = "typedef int *const FXConstKey;\n#define FX_EXTERN extern", rows = rows(), unavailable = {}}
    local markers = {FXHidden = "FXSkel", FXGapValue = "FXSkel"}
    local definitions = {FXHidden = {kind = "function"}, FXGapValue = {kind = "global", type = "int", array = false}}
    return skeleton.write(folder, {framework}, {}, images, markers, definitions)
end

local function built(out, folder, library, fallback)
    os.execv("xcrun", {"clang", "-dynamiclib", "-fobjc-arc", "-I", folder, "-I", sdkfiles.src_root(),
        path.join(folder, "FXSkel.m"), path.join(folder, "registrar.m"), fallback, "-o", library, "-install_name", library})
    assert(os.isfile(library), "no library " .. library .. " in " .. out)
end

local function driver(out, library, name)
    local source = path.join(out, name .. ".c")
    io.writefile(source, DRIVER)
    local program = path.join(out, name)
    os.execv("xcrun", {"clang", "-o", program, source, library, "-lpthread"})
    return program
end

local function run(program, mode)
    return os.iorunv("sh", {"-c", "'" .. program .. "' " .. mode .. " 2>&1; echo status $?"})
end

local function image(work, name, source)
    local file = path.join(work, "lib" .. name .. ".dylib")
    local text = path.join(work, name .. ".c")
    io.writefile(text, source)
    os.execv("xcrun", {"clang", "-dynamiclib", "-o", file, text, "-install_name", file})
    return file
end

local function object(folder, arch, sdk, flags)
    local output = path.join(folder, "FXSkel_" .. arch .. ".o")
    local arguments = sdk == "macosx" and {"--sdk", sdk, "clang", "-arch", arch} or {"clang", "-arch", arch}
    table.join2(arguments, flags)
    table.join2(arguments, {"-fobjc-arc", "-I", folder, "-I", sdkfiles.src_root(), "-c", path.join(folder, "FXSkel.m"), "-o", output})
    os.execv("xcrun", arguments)
    return output
end

function main()
    local work = path.join(workspace.scratch(), "backports-forwarders")
    os.tryrm(work)
    os.mkdir(work)
    local fallback = path.join(work, "fallback.m")
    io.writefile(fallback, FALLBACK)

    local system = image(work, "fxsystem", SYSTEM)
    local lazy = image(work, "fxlazy", LAZY)

    local present = path.join(work, "present")
    local totals = generated(present, system, lazy)
    assert(totals.c == 4, "expected 4 forwarders, got " .. totals.c)
    assert(totals.trampolines == 2, "expected the variadic FXVariadic and the src-only FXHidden as trampolines, got " .. totals.trampolines)
    assert(totals.src_only == 2, "expected 2 names implemented in src and absent from the facts, got " .. totals.src_only)
    assert(totals.globals == 5 and totals.globals_uncopied == 1, "expected 5 globals and 1 uncopied array, got " .. totals.globals .. " and " .. totals.globals_uncopied)
    local text = io.readfile(path.join(present, "FXSkel.m"))
    for name in string.gmatch(text, "__typeof_unqual__%(([%w_]*)%)") do
        assert(string.find(name, "^revenant_type_"), "the skeleton types a global with __typeof_unqual__ of " .. name .. " and not of the facts type")
    end
    assert(string.find(text, "typedef FXConstKey revenant_type_FXQualified;", 1, true), "the facts type of FXQualified is not the type of its placeholder")
    assert(string.find(text, "__typeof_unqual__(revenant_type_FXQualified) revenant_global_FXQualified", 1, true), "a global whose type is a const typedef is not stored unqualified")
    assert(not os.isfile(path.join(present, "FXSkel.c")), "the skeleton still writes a C file")
    assert(string.find(text, 'revenant_backports_c_target(&revenant_slot_1, "' .. system .. '", "FXAdd")', 1, true), "FXAdd does not look up its system symbol")
    assert(string.find(text, "__atomic_store_n(entry->slot", 1, true), "the trampoline resolver does not store the resolved address")

    local present_library = path.join(work, "libfxours_present.dylib")
    built(present, present, present_library, fallback)
    local present_program = driver(work, present_library, "driver_present")
    local ok = os.iorunv(present_program, {}):trim()
    assert(ok == "102 42 7 5 3", "with the system present, expected '102 42 7 5 3' (system FXAdd, copied FXValue, system FXSetValue, copied const typedef FXQualified, copied FXExported typed with an export macro), got '" .. ok .. "'")
    assert(string.find(text, "typedef int revenant_type_FXExported;", 1, true), "the export macro of FXExported stayed in the type of its placeholder")

    local missing = run(present_program, "missing")
    assert(string.find(missing, "not implemented: FXSkel.FXMissing", 1, true), "the fallback did not fail naming FXSkel.FXMissing: " .. missing)
    assert(not string.find(missing, "status 0", 1, true), "the fallback returned instead of failing: " .. missing)

    local lazy_run = run(present_program, "lazy")
    local before_main = string.find(lazy_run, "main", 1, true)
    local loaded = string.find(lazy_run, "lazy image loaded", 1, true)
    assert(before_main and loaded and before_main < loaded, "the lazy image was loaded before the first call: " .. lazy_run)
    assert(string.find(lazy_run, "2 55", 1, true), "the lazy image and the src global did not resolve to the system values: " .. lazy_run)

    local variadic_run = run(present_program, "variadic")
    assert(string.find(variadic_run, "1008", 1, true), "the variadic trampoline did not forward its arguments to the system: " .. variadic_run)

    local threads_run = run(present_program, "threads")
    assert(string.find(threads_run, "32000", 1, true), "concurrent first calls did not all reach the system: " .. threads_run)

    local arm = object(present, "armv7", "iphoneos", {"-miphoneos-version-min=6.0", "-isysroot", sdkfiles.sdk_folder()})
    local arm_symbols = os.iorunv("nm", {arm})
    assert(string.find(arm_symbols, " _FXVariadic", 1, true) and string.find(arm_symbols, " _FXHidden", 1, true), "the armv7 object does not export the trampolines")
    local arm_code = os.iorunv("otool", {"-tv", arm})
    assert(string.find(arm_code, "bx", 1, true) and string.find(arm_code, "cmp", 1, true), "the armv7 trampoline does not check its slot and branch through it")
    local x86 = object(present, "x86_64", "macosx", {"-mmacosx-version-min=10.9"})
    assert(string.find(os.iorunv("nm", {x86}), " _FXVariadic", 1, true), "the x86_64 object does not export the trampoline")

    local absent = path.join(work, "absent")
    generated(absent, path.join(work, "no-such-system.dylib"), path.join(work, "no-such-lazy.dylib"))
    local absent_library = path.join(work, "libfxours_absent.dylib")
    built(absent, absent, absent_library, fallback)
    local absent_program = driver(work, absent_library, "driver_absent")
    local absent_run = run(absent_program, "")
    assert(string.find(absent_run, "not implemented: FXSkel.FXAdd", 1, true), "with no system image the fallback did not fail naming FXSkel.FXAdd: " .. absent_run)

    local absent_lazy = run(absent_program, "lazy")
    assert(string.find(absent_lazy, "501 9", 1, true), "without the system the src fallbacks did not answer: " .. absent_lazy)

    local absent_variadic = run(absent_program, "variadic")
    assert(string.find(absent_variadic, "not implemented: FXSkel.FXVariadic", 1, true), "a variadic without a fallback did not fail naming it: " .. absent_variadic)
    assert(not string.find(absent_variadic, "status 0", 1, true), "the variadic without a fallback returned: " .. absent_variadic)

    local absent_threads = run(absent_program, "threads")
    assert(string.find(absent_threads, "8016000", 1, true), "concurrent first calls did not all reach the fallback: " .. absent_threads)

    os.tryrm(work)
    print("forwarders tests passed: 4 forwarders, 2 trampolines, 2 src-only names, lazy resolution, fallbacks, loud failure, concurrent first call, armv7 and x86_64 objects")
end
