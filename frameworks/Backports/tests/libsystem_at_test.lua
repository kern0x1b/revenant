local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))

function main()
    local out = workspace.run("backports-tests", "LibSystemAt")
    local source = path.join(backports, "src", "libSystem")
    local compat = path.join(backports, "..", "..", "toolchain", "src", "apple-compat")
    local fixture = path.join(backports, "tests", "libsystem_at", "main.c")
    local binary = path.join(out, "libsystem_at")
    os.vrunv("xcrun", {"clang", "-std=gnu11", "-Wall", "-Werror", "-I", path.join(backports, "src"), "-I", source,
                        "-I", path.join(compat, "include"),
                        "-o", binary, fixture, path.join(source, "RevenantAtPath.c"), path.join(source, "RevenantAtPaths.c"),
                        path.join(source, "RevenantAttributeTimes.c"), path.join(source, "RevenantClockGetRes.c"),
                        path.join(compat, "src", "clock_getres.c")})
    local tree = path.join(out, "tree")
    os.tryrm(tree)
    os.vrunv(binary, {tree})
end
