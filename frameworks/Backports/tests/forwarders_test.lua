local tools = path.absolute(path.join(os.scriptdir(), "..", "tools"))
local skeleton = import("skeleton", {rootdir = tools, anonymous = true})
local sdkfiles = import("sdk", {rootdir = tools, anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})

local SYSTEM = [[
int FXValue = 42;
int FXAdd(int a, int b) { return a * 100 + b; }
void FXSetValue(int value) { FXValue = value; }
int FXGetValue(void) { return FXValue; }
]]

local DRIVER = [[
#include <stdio.h>
int FXAdd(int, int);
void FXSetValue(int);
int FXGetValue(void);
int FXMissing(int);
extern int FXValue;

int main(int argc, char **argv)
{
    if (argc > 1)
        return FXMissing(1);
    int sum = FXAdd(1, 2);
    FXSetValue(7);
    printf("%d %d %d\n", sum, FXValue, FXGetValue());
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
    }
end

local function generated(folder, image)
    local images = {FXAdd = image, FXMissing = image, FXSetValue = image, FXGetValue = image, FXVariadic = image, FXValue = image, FXTable = image}
    local framework = {name = "FXSkel", import = "", rows = rows(), unavailable = {}}
    local totals = skeleton.write(folder, {framework}, {}, images)
    return totals
end

local function built(out, folder, library)
    os.execv("xcrun", {"clang", "-dynamiclib", "-fobjc-arc", "-I", folder, "-I", sdkfiles.src_root(),
        path.join(folder, "FXSkel.m"), path.join(folder, "registrar.m"), "-o", library, "-install_name", library})
    assert(os.isfile(library), "no library " .. library .. " in " .. out)
end

local function driver(out, library, name)
    local source = path.join(out, name .. ".c")
    io.writefile(source, DRIVER)
    local program = path.join(out, name)
    os.execv("xcrun", {"clang", "-o", program, source, library})
    return program
end

function main()
    local work = path.join(workspace.scratch(), "backports-forwarders")
    os.tryrm(work)
    os.mkdir(work)

    local system = path.join(work, "libfxsystem.dylib")
    local source = path.join(work, "fxsystem.c")
    io.writefile(source, SYSTEM)
    os.execv("xcrun", {"clang", "-dynamiclib", "-o", system, source, "-install_name", system})

    local present = path.join(work, "present")
    local totals = generated(present, system)
    assert(totals.c == 4, "expected 4 forwarders, got " .. totals.c)
    assert(totals.c_unstubbed == 1, "expected the variadic FXVariadic not stubbed, got " .. totals.c_unstubbed)
    assert(totals.globals == 2 and totals.globals_uncopied == 1, "expected 2 globals and 1 uncopied array, got " .. totals.globals .. " and " .. totals.globals_uncopied)
    local text = io.readfile(path.join(present, "FXSkel.m"))
    assert(not string.find(text, "__typeof_unqual__", 1, true), "the skeleton still types a global with __typeof_unqual__")
    assert(not os.isfile(path.join(present, "FXSkel.c")), "the skeleton still writes a C file")
    assert(string.find(text, 'revenant_backports_c_target(&revenant_slot_1, "' .. system .. '", "FXAdd")', 1, true), "FXAdd does not look up its system symbol")

    local present_library = path.join(work, "libfxours_present.dylib")
    built("present", present, present_library)
    local present_program = driver(work, present_library, "driver_present")
    local ok = os.iorunv(present_program, {}):trim()
    assert(ok == "102 42 7", "with the system present, expected '102 42 7' (system FXAdd, copied FXValue, system FXSetValue), got '" .. ok .. "'")

    local missing = os.iorunv("sh", {"-c", "'" .. present_program .. "' missing 2>&1; echo status $?"})
    assert(string.find(missing, "not implemented: FXSkel.FXMissing", 1, true), "the fallback did not fail naming FXSkel.FXMissing: " .. missing)
    assert(not string.find(missing, "status 0", 1, true), "the fallback returned instead of failing: " .. missing)

    local absent = path.join(work, "absent")
    generated(absent, path.join(work, "no-such-system.dylib"))
    local absent_library = path.join(work, "libfxours_absent.dylib")
    built("absent", absent, absent_library)
    local absent_program = driver(work, absent_library, "driver_absent")
    local absent_run = os.iorunv("sh", {"-c", "'" .. absent_program .. "' 2>&1; echo status $?"})
    assert(string.find(absent_run, "not implemented: FXSkel.FXAdd", 1, true), "with no system image the fallback did not fail naming FXSkel.FXAdd: " .. absent_run)

    os.tryrm(work)
    print("forwarders tests passed: 4 forwarders, 1 variadic not stubbed, 1 array not copied")
end
