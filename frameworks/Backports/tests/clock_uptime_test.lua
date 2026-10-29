local lowered = import("@addon.revenant.apple.lowered", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local fixture = path.join(backports, "tests", "clock_uptime", "use.c")

function main()
    local sdk = workspace.sdk()
    local out = workspace.run("backports-tests", "ClockUptime")
    local vfs = lowered.overlay(sdk, path.join(out, "overlay"))
    local include = lowered.include_directory(path.join(out, "overlay"))
    local object = path.join(out, "use.o")
    os.vrunv("clang", {"-target", "armv7-apple-ios6.0", "-isysroot", sdk, "-ivfsoverlay", vfs, "-I", include,
                       "-Werror", "-Wunguarded-availability", "-c", "-o", object, fixture})
    local imported = {}
    for line in os.iorunv("nm", {"-u", object}):gmatch("[^\n]+") do
        imported[line:match("(%S+)%s*$")] = true
    end
    assert(imported["_revenant_clock_gettime_nsec_np"], "clock_gettime_nsec_np does not bind to the revenant backport")
    assert(not imported["_clock_gettime_nsec_np"], "clock_gettime_nsec_np is still imported from libSystem")
end
