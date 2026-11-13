local workspace = import("@addon.revenant.workspace", {anonymous = true})
local device = import("@addon.revenant.device", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))

local function first(pattern)
    local values = os.files(pattern)
    return values[1] or raise("no file matches %s", pattern)
end

function main()
    local cache = os.getenv("REVENANT_CACHE") or raise("REVENANT_CACHE is unset")
    local packages = path.join(cache, "xmake-global", ".xmake", "packages")
    local sdk = os.dirs(path.join(packages, "i", "iphoneos-sdk", "26.2", "**", "Developer.app", "Contents", "Developer", "Platforms", "iPhoneOS.platform", "Developer", "SDKs", "iPhoneOS*.sdk"))[1]
    local clang = first(path.join(packages, "l", "llvm", "23.1.3", "**", "bin", "clang"))
    local linker = first(path.join(packages, "l", "ld64", "956.6", "**", "bin", "ld"))
    local ldid = first(path.join(packages, "l", "ldid", "2.1.5-procursus7+23.gaf86971", "**", "bin", "ldid"))
    local out = workspace.run("backports-tests", "LibSystemDispatchDevice")
    local library = path.join(backports, "..", "..", "build", "iphoneos", "armv7", "release", "libSystemBackports.dylib")
    local test_library = path.join(out, "libSystemBackports.dylib")
    os.cp(library, test_library)
    os.vrunv("xcrun", {"install_name_tool", "-id", "/var/tmp/revenant-libSystemBackports-dispatch.dylib", test_library})
    local fixtures = {
        {name = "data", source = "main.c", language = {"-x", "c", "-std=gnu11", "-fblocks"}, extra = {"-DREVENANT_DEVICE", "-Wno-unguarded-availability-new"}},
        {name = "classes", source = "classes.m", language = {"-x", "objective-c", "-fno-objc-arc"}, extra = {"-framework", "Foundation", "-lobjc"}},
    }
    local settings = device.bind(os.projectdir())
    local panics_before = device.run(settings, "find /Library/Logs/CrashReporter/Panics -type f -print 2>/dev/null", {capture = true})
    device.run(settings, "mkdir -p /var/tmp")
    device.copy(settings, test_library, "/var/tmp/revenant-libSystemBackports-dispatch.dylib")
    for _, fixture in ipairs(fixtures) do
        local binary = path.join(out, "libsystem_dispatch_" .. fixture.name)
        local arguments = {"-target", "armv7-apple-ios6.0", "-miphoneos-version-min=6.0", "-isysroot", sdk, "-Wall", "-Werror",
                           "-Wno-incompatible-sysroot", "-L", out, "-lSystemBackports", "-fuse-ld=" .. linker, "-Wl,-no_encryption"}
        table.join2(arguments, fixture.language, fixture.extra)
        table.join2(arguments, {"-o", binary, path.join(backports, "tests", "libsystem_dispatch", fixture.source)})
        os.vrunv(clang, arguments)
        os.vrunv(ldid, {"-S", binary})
        local remote = "/var/tmp/revenant-libsystem-dispatch-" .. fixture.name
        device.copy(settings, binary, remote)
        device.run(settings, "chmod 755 " .. remote .. " && " .. remote)
        device.run(settings, "rm -f " .. remote)
    end
    device.run(settings, "rm -f /var/tmp/revenant-libSystemBackports-dispatch.dylib")
    local panics_after = device.run(settings, "find /Library/Logs/CrashReporter/Panics -type f -print 2>/dev/null", {capture = true})
    assert(panics_after == panics_before, "the phone's kernel panic inventory changed after the libSystem dispatch fixtures")
end
