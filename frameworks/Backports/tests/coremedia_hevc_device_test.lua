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
    local out = workspace.run("backports-tests", "CoreMediaHEVCDevice")
    local library = path.join(backports, "..", "..", "build", "iphoneos", "armv7", "release", "libCoreMediaBackports.dylib")
    local test_library = path.join(out, "libCoreMediaBackports.dylib")
    os.cp(library, test_library)
    os.vrunv("xcrun", {"install_name_tool", "-id", "/var/tmp/revenant-libCoreMediaBackports-tg-hevc.dylib", test_library})
    local binary = path.join(out, "hevc_format")
    local fixture = path.join(backports, "tests", "CoreMedia", "hevc_format_test.c")
    os.vrunv(clang, {"-target", "armv7-apple-ios6.0", "-miphoneos-version-min=6.0", "-isysroot", sdk, "-DREVENANT_DEVICE",
                     "-std=gnu11", "-Wall", "-Werror", "-Wno-incompatible-sysroot",
                     "-L", out, "-lCoreMediaBackports", "-fuse-ld=" .. linker, "-Wl,-undefined,dynamic_lookup",
                     "-Wl,-no_encryption", "-o", binary, fixture})
    os.vrunv(ldid, {"-S", binary})
    local settings = device.bind(os.projectdir())
    local panics_before = device.run(settings, "find /Library/Logs/CrashReporter/Panics -type f -print 2>/dev/null", {capture = true})
    device.run(settings, "mkdir -p /var/tmp")
    device.copy(settings, test_library, "/var/tmp/revenant-libCoreMediaBackports-tg-hevc.dylib")
    device.copy(settings, binary, "/var/tmp/revenant-hevc-format-tg-hevc")
    device.run(settings, "chmod 755 /var/tmp/revenant-hevc-format-tg-hevc && /var/tmp/revenant-hevc-format-tg-hevc")
    local panics_after = device.run(settings, "find /Library/Logs/CrashReporter/Panics -type f -print 2>/dev/null", {capture = true})
    assert(panics_after == panics_before, "the phone's kernel panic inventory changed after the HEVC format fixture")
    device.run(settings, "rm -f /var/tmp/revenant-libCoreMediaBackports-tg-hevc.dylib /var/tmp/revenant-hevc-format-tg-hevc")
end
