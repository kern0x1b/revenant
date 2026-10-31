local root = path.absolute(path.join(os.scriptdir(), ".."))
local src = path.join(root, "src", "libSystem")
local workspace = import("@addon.revenant.workspace", {anonymous = true})

local DRIVER = [[
#include <stdio.h>
#include <sys/select.h>
#include "RevenantFDSet.h"

int __darwin_check_fd_set_overflow(int, const void *, int);

int main(void)
{
    fd_set set;
    FD_ZERO(&set);
    int ok = revenant_fd_set_in_range(-1) == 0 && revenant_fd_set_in_range(0) == 1
             && revenant_fd_set_in_range(FD_SETSIZE - 1) == 1 && revenant_fd_set_in_range(FD_SETSIZE) == 0
             && __darwin_check_fd_set_overflow(3, &set, 0) == 1;
    printf("%d\n", ok);
    return ok ? 0 : 1;
}
]]

function main()
    local out = workspace.run("backports-tests", "libSystem")
    local object = path.join(out, "RevenantFDSet.o")
    local driver = path.join(out, "driver.c")
    local program = path.join(out, "driver")
    io.writefile(driver, DRIVER)
    os.execv("xcrun", {"clang", "-c", "-Wall", "-Werror", "-fvisibility=hidden", "-I", src, path.join(src, "RevenantFDSet.c"), "-o", object})
    local dylib = path.join(out, "libRevenantFDSet.dylib")
    os.execv("xcrun", {"clang", "-dynamiclib", "-Wall", "-Werror", "-fvisibility=hidden", "-I", src, path.join(src, "RevenantFDSet.c"), "-o", dylib})
    local exports = os.iorunv("nm", {"-gU", dylib})
    assert(exports:find("___darwin_check_fd_set_overflow", 1, true), "the library does not export __darwin_check_fd_set_overflow: " .. exports)
    assert(not exports:find("revenant_fd_set_in_range", 1, true), "revenant_fd_set_in_range is exported, so it is not kept inside the library: " .. exports)
    os.execv("xcrun", {"clang", "-Wall", "-Werror", "-I", src, driver, object, "-o", program})
    os.execv(program, {})
end
