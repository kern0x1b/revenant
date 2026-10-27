import("fixtures")

local SHIM = path.join(os.scriptdir(), "..", "..", "src", "swift-runtime", "overlay", "os")

local SYMBOLS = {"_revenant_os_log_named", "_revenant_os_log_send", "_revenant_os_log_type_enabled"}

local PROBE = [[
#include "RevenantOSOverlayShims.h"
#include <stdio.h>

#ifdef STUBS
static char stub;
void *revenant_os_log_named(const char *subsystem, const char *category) { (void)subsystem; (void)category; return &stub; }
signed char revenant_os_log_type_enabled(void *log, uint8_t type) { (void)log; (void)type; return 1; }
void revenant_os_log_send(void *log, uint8_t type, const char *format, va_list arguments, int error) {
    (void)log; (void)type; (void)format; (void)arguments; (void)error;
}
#endif

int main(void) {
    printf("linked %d\n", revenant_os_log_linked());
    printf("recorded %d %d %d %d %d\n", revenant_os_log_recorded(0x00), revenant_os_log_recorded(0x01),
           revenant_os_log_recorded(0x02), revenant_os_log_recorded(0x10), revenant_os_log_recorded(0x11));
    printf("levels %d %d %d\n", revenant_os_log_asl_level(0x00), revenant_os_log_asl_level(0x10),
           revenant_os_log_asl_level(0x11));
    return 0;
}
]]

-- Each probe line is "label<TAB>text": the text the fallback renders for the format and arguments of that label.
-- The formats are the ones the os overlay forwards: the StaticString of an os_log call, with the specifiers the
-- release build understands. Privacy: %{public} prints, %{private} and %{sensitive} print <private>, and a string or
-- object without an annotation is private, a number is public.
local RENDER_PROBE = [[
#import "RevenantOSOverlayShims.h"
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>

static void show(const char *label, const char *format, int count, int error, ...) {
    va_list arguments;
    va_start(arguments, error);
    char *text = revenant_os_log_render_arguments(format, arguments, count, error);
    va_end(arguments);
    printf("%s\t%s\n", label, text ? text : "(failed)");
    free(text);
}

int main(void) {
    const void *object = (const void *)@"object text";
    const void *hidden = (const void *)@"hidden";
    const void *plain = (const void *)@"default object";
    const void *nothing = NULL;
    show("01", "%{public}s", 1, 0, "hello");
    show("02", "%{private}s", 1, 0, "secret");
    show("03", "%s", 1, 0, "plain");
    show("04", "%{public}d", 1, 0, 42);
    show("05", "%d", 1, 0, 7);
    show("06", "%{private}d", 1, 0, 99);
    show("07", "%{public}@", 1, 0, object);
    show("08", "%{private}@", 1, 0, hidden);
    show("09", "%@", 1, 0, plain);
    show("10", "%{public}08X", 1, 0, 0xBEEF);
    show("11", "%{public}lld", 1, 0, 1234567890123LL);
    show("12", "%{public}.2f", 1, 0, 3.14159);
    show("13", "%{public}5.1f|", 1, 0, 2.5);
    show("14", "%{public}-5d|", 1, 0, 42);
    show("15", "%{public}c", 1, 0, 'A');
    show("16", "100%%", 0, 0);
    show("17", "%{public}s and %{private}s", 2, 0, "a", "b");
    show("18", "%{public}d %{private}d %{public}s", 3, 0, 1, 2, "three");
    show("19", "%{public}s", 1, 0, (const char *)NULL);
    show("20", "%{public}s  ", 1, 0, "trailing");
    show("21", "%{public}u", 1, 0, 4294967295u);
    show("22", "%{public}i", 1, 0, -5);
    show("23", "%{public}ld", 1, 0, 123456L);
    show("24", "%{public}o", 1, 0, 8);
    show("25", "%{public}x", 1, 0, 255);
    show("26", "%{sensitive}s", 1, 0, "sens");
    show("27", "%{public}s", 1, 0, "tab\tand\x01" "control");
    show("28", "%m", 0, ENOENT);
    show("29", "%{private}@", 1, 0, nothing);
    show("30", "%{public}@", 1, 0, nothing);
    show("31", "%{private}.2s", 1, 0, "abcdef");
    show("32", "%{public}*d", 2, 0, 4, 7);
    show("33", "%{public}d", 0, 0);
    show("34", "%{public}s", 2, 0, "first", "second");
    show("35", "%{public}.3s", 1, 0, "abcdef");
    show("36", "%{public}5s|", 1, 0, "ab");
    show("37", "%{public}-5s|", 1, 0, "ab");
    show("38", "%{public}+d", 1, 0, 5);
    show("39", "%{public}e", 1, 0, 1.5);
    show("40", "%{public}g", 1, 0, 0.0001);
    show("41", "%{public}hhx", 1, 0, 0x1FF);
    show("42", "%{public}zd", 1, 0, 9L);
    return 0;
}
]]

-- The expected text per label. None of these lines has been compared with macOS `log show` yet, so they are the
-- release-build rules above, not a recorded os_log run.
local RENDER = {
    {"01", "hello"}, {"02", "<private>"}, {"03", "<private>"}, {"04", "42"}, {"05", "7"}, {"06", "<private>"},
    {"07", "object text"}, {"08", "<private>"}, {"09", "<private>"}, {"10", "0000BEEF"}, {"11", "1234567890123"},
    {"12", "3.14"}, {"13", "  2.5|"}, {"14", "42   |"}, {"15", "A"}, {"16", "100%"}, {"17", "a and <private>"},
    {"18", "1 <private> three"}, {"19", "(null)"}, {"20", "trailing"}, {"21", "4294967295"}, {"22", "-5"},
    {"23", "123456"}, {"24", "10"}, {"25", "ff"}, {"26", "<private>"}, {"27", "tab\tand\\^Acontrol"},
    {"28", "No such file or directory"}, {"29", "<private>"}, {"30", "(null)"}, {"31", "<private>"},
    {"32", "   7"}, {"33", "<decode: missing data>"}, {"34", "first"}, {"35", "abc"}, {"36", "   ab|"},
    {"37", "ab   |"}, {"38", "+5"}, {"39", "1.500000e+00"}, {"40", "0.0001"}, {"41", "ff"}, {"42", "9"},
}

local MODES = {
    {name = "absent", stubs = false, linked = "linked 0"},
    {name = "present", stubs = true, linked = "linked 1"},
}

local WANT = {"recorded 1 0 0 1 1", "levels 5 3 2"}

local function probe_failures(folder, mode, found)
    local source = path.join(folder, mode.name .. ".c")
    local binary = path.join(folder, mode.name)
    io.writefile(source, PROBE)
    local argv = {"--sdk", "macosx", "clang", "-std=c11", "-Wall", "-Werror", "-Wno-deprecated-declarations", "-I", SHIM}
    if mode.stubs then
        table.insert(argv, "-DSTUBS")
    end
    table.join2(argv, {source, "-o", binary})
    if not mode.stubs then
        for _, symbol in ipairs(SYMBOLS) do
            table.join2(argv, {"-Wl,-U," .. symbol})
        end
    end
    if os.execv("xcrun", argv, {try = true, stdout = path.join(folder, mode.name .. ".log"), stderr = path.join(folder, mode.name .. ".log")}) ~= 0 then
        table.insert(found, string.format("the %s probe does not compile and link: %s", mode.name, io.readfile(path.join(folder, mode.name .. ".log")) or ""))
        return
    end
    local output = os.iorunv(binary, {})
    local lines = "\n" .. output
    for _, line in ipairs(table.join({mode.linked}, WANT)) do
        if not lines:find("\n" .. line .. "\n", 1, true) then
            table.insert(found, string.format("with the three symbols %s, the probe printed %s and not \"%s\"",
                                              mode.name, output:gsub("\n", " | "), line))
        end
    end
end

local function render_failures(folder, found)
    local source = path.join(folder, "render.m")
    local binary = path.join(folder, "render")
    local log = path.join(folder, "render.log")
    io.writefile(source, RENDER_PROBE)
    local argv = {"--sdk", "macosx", "clang", "-std=c11", "-Wall", "-Werror", "-Wno-deprecated-declarations", "-fno-objc-arc",
                  "-framework", "Foundation", "-I", SHIM, source, "-o", binary}
    if os.execv("xcrun", argv, {try = true, stdout = log, stderr = log}) ~= 0 then
        table.insert(found, "the render probe does not compile and link: " .. (io.readfile(log) or ""))
        return
    end
    local output = os.iorunv(binary, {})
    local rendered = {}
    for line in output:gmatch("[^\n]+") do
        local label, text = line:match("^(%d%d)\t(.*)$")
        if label then
            rendered[label] = text
        end
    end
    for _, case in ipairs(RENDER) do
        local label, want = case[1], case[2]
        if rendered[label] ~= want then
            table.insert(found, string.format("format %s rendered %q and not %q", label, tostring(rendered[label]), want))
        end
    end
end

function failures(opt)
    local found = {}
    local folder = fixtures.scratch()
    for _, mode in ipairs(MODES) do
        probe_failures(folder, mode, found)
    end
    render_failures(folder, found)
    os.tryrm(folder)
    return found
end
