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

local MODES = {
    {name = "absent", stubs = false, linked = "linked 0"},
    {name = "present", stubs = true, linked = "linked 1"},
}

local WANT = {"recorded 1 0 0 1 1", "levels 5 3 2"}

local function probe_failures(folder, mode, found)
    local source = path.join(folder, mode.name .. ".c")
    local binary = path.join(folder, mode.name)
    local log = path.join(folder, mode.name .. ".log")
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
    if os.execv("xcrun", argv, {try = true, stdout = log, stderr = log}) ~= 0 then
        table.insert(found, string.format("the %s probe does not compile and link: %s", mode.name, io.readfile(log) or ""))
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

function failures(opt)
    local found = {}
    local folder = fixtures.scratch()
    for _, mode in ipairs(MODES) do
        probe_failures(folder, mode, found)
    end
    os.tryrm(folder)
    return found
end
