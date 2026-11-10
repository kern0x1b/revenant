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
    local out = workspace.run("backports-tests", "LibSystemAtDevice")
    local library = path.join(backports, "..", "..", "build", "iphoneos", "armv7", "release", "libSystemBackports.dylib")
    local test_library = path.join(out, "libSystemBackports.dylib")
    os.cp(library, test_library)
    os.vrunv("xcrun", {"install_name_tool", "-id", "/var/tmp/revenant-libSystemBackports-tg-sys.dylib", test_library})
    local binary = path.join(out, "libsystem_at")
    local fixture = path.join(backports, "tests", "libsystem_at", "main.c")
    os.vrunv(clang, {"-target", "armv7-apple-ios6.0", "-miphoneos-version-min=6.0", "-isysroot", sdk, "-DREVENANT_DEVICE",
                     "-std=gnu11", "-Wall", "-Werror", "-Wno-incompatible-sysroot",
                     "-L", out, "-lSystemBackports", "-fuse-ld=" .. linker,
                     "-Wl,-no_encryption", "-o", binary, fixture})
    os.vrunv(ldid, {"-S", binary})
    local settings = device.bind(os.projectdir())
    device.run(settings, "if [ -d /var/tmp/revenant-at-tg-sys ]; then rm -f /var/tmp/revenant-at-tg-sys/link /var/tmp/revenant-at-tg-sys/file /var/tmp/revenant-at-tg-sys/host-file /var/tmp/revenant-at-tg-sys/host-link && rmdir /var/tmp/revenant-at-tg-sys; fi")
    local panics_before = device.run(settings, "find /Library/Logs/CrashReporter/Panics -type f -print 2>/dev/null", {capture = true})
    device.run(settings, "mkdir -p /var/tmp")
    device.copy(settings, test_library, "/var/tmp/revenant-libSystemBackports-tg-sys.dylib")
    device.copy(settings, binary, "/var/tmp/revenant-libsystem-at-tg-sys")
    device.run(settings, "chmod 755 /var/tmp/revenant-libsystem-at-tg-sys && /var/tmp/revenant-libsystem-at-tg-sys /var/tmp/revenant-at-tg-sys")
    local panics_after = device.run(settings, "find /Library/Logs/CrashReporter/Panics -type f -print 2>/dev/null", {capture = true})
    assert(panics_after == panics_before, "the phone's kernel panic inventory changed after the libSystem API fixture")
    device.run(settings, "rm -f /var/tmp/revenant-libSystemBackports-tg-sys.dylib /var/tmp/revenant-libsystem-at-tg-sys && if [ -d /var/tmp/revenant-at-tg-sys ]; then rmdir /var/tmp/revenant-at-tg-sys; fi")
end
