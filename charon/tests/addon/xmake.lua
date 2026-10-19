add_repositories("charon ../..")
add_requires("ld64 956.6", "ldid 2.1.5-procursus7+23.gaf86971", "iphoneos-sdk 16.4", "llvm 23.1.1")
add_requires("swift 6.4.0", {system = false})

set_allowedplats("macosx")

local function suite(name)
    target(name)
        set_kind("phony")
        add_packages("ld64", "ldid", "iphoneos-sdk", "llvm", "swift")
        add_tests("default")
        on_test(function (target)
            local modules = path.join(os.projectdir(), "..", "..", "modules")
            local failures = import(target:name(), {rootdir = os.projectdir(), anonymous = true}).failures({
                modules = modules,
                ld64 = path.join(target:pkg("ld64"):installdir(), "bin", "ld"),
                ldid = path.join(target:pkg("ldid"):installdir(), "bin", "ldid"),
                clang = path.join(target:pkg("llvm"):installdir(), "bin", "clang"),
                swift = target:pkg("swift"):installdir(),
                sdk = os.dirs(path.join(target:pkg("iphoneos-sdk"):installdir(), "Developer.app", "Contents", "Developer", "Platforms",
                                        "iPhoneOS.platform", "Developer", "SDKs", "iPhoneOS*.sdk"))[1]
            })
            for _, failure in ipairs(failures) do
                cprint("${red}%s: %s", target:name(), failure)
            end
            return #failures == 0
        end)
    target_end()
end

-- A test that only reads the repository's own Lua needs none of the toolchain
-- packages, so it runs without building anything.
local function light(name)
    target(name)
        set_kind("phony")
        add_tests("default")
        on_test(function (target)
            local modules = path.join(os.projectdir(), "..", "..", "modules")
            local failures = import(target:name(), {rootdir = os.projectdir(), anonymous = true}).failures({modules = modules})
            for _, failure in ipairs(failures) do
                cprint("${red}%s: %s", target:name(), failure)
            end
            return #failures == 0
        end)
    target_end()
end

light("descriptions_test")
light("checkout_test")
light("sdkstubs_test")
light("digest_test")
light("dependency_test")
light("archive_language_test")
light("swift_rule_test")
light("firmware_test")
light("toolchain_check_test")

suite("architectures_test")
suite("macho_test")
suite("dyld_test")
suite("debian_test")
suite("device_test")
suite("emulator_test")
suite("checks_test")
suite("blocks_test")
suite("weak_test")
suite("port_test")
suite("tweak_test")
suite("callkit_screen_test")
suite("tls_test")
suite("atomics_test")
suite("swift_test")
suite("objc_test")
suite("carried_test")
suite("operators_test")
suite("shared_runtime_test")
suite("backports_test")
suite("registry_test")
suite("store_test")
suite("gdb_test")
