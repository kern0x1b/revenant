if get_config("component") ~= "" or is_plat("iphoneos") then
    return
end

local addon = path.join(os.scriptdir(), "addon")
local toolchain = path.directory(os.scriptdir())
local host = {plat = "macosx", arch = "arm64"}

add_requires("revenant@ld64 956.6", table.join(host, {alias = "ld64"}))
add_requires("revenant@ldid 2.1.5-procursus7+23.gaf86971", table.join(host, {alias = "ldid"}))
add_requires("revenant@iphoneos-sdk 16.4", table.join(host, {alias = "iphoneos-sdk"}))
add_requires("revenant@llvm 23.1.3", table.join(host, {alias = "llvm", configs = {libraries = true}}))
add_requires("revenant@swift 6.4.0", table.join(host, {alias = "swift", system = false}))

local light = {"assets_extract_test", "cache_sweep_test", "checkout_test", "compat_test",
               "descriptions_test", "digest_test", "firmware_test", "locale_order_test", "lock_test", "sdk_verbatim_test",
               "sdkstubs_test", "swift_rule_test", "workspace_test"}

local packaged = {"architectures_test", "atomics_test", "blocks_test", "callkit_screen_test", "carried_test", "checks_test", "device_test",
                  "debian_test", "dyld_test", "gdb_test", "macho_test", "objc_test", "operators_test", "port_test",
                  "shared_runtime_test", "tls_test", "toolchain_check_test", "tweak_test", "weak_test"}

local device = {"emulator_test", "swift_test"}

local function suites(name, list, with_packages, group)
    target(name)
        set_kind("phony")
        set_default(false)
        if group then
            set_group(group)
        end
        if with_packages then
            add_packages("ld64", "ldid", "iphoneos-sdk", "llvm", "swift")
        end
        for _, suite in ipairs(list) do
            add_tests(suite)
        end
        on_test(function (target, opt)
            local suite = path.filename(opt.name)
            local arguments = {modules = path.join(toolchain, "modules")}
            if with_packages then
                table.join2(arguments, {
                    ld64 = path.join(target:pkg("ld64"):installdir(), "bin", "ld"),
                    ldid = path.join(target:pkg("ldid"):installdir(), "bin", "ldid"),
                    clang = path.join(target:pkg("llvm"):installdir(), "bin", "clang"),
                    swift = target:pkg("swift"):installdir(),
                    sdk = os.dirs(path.join(target:pkg("iphoneos-sdk"):installdir(), "Developer.app", "Contents", "Developer",
                                            "Platforms", "iPhoneOS.platform", "Developer", "SDKs", "iPhoneOS*.sdk"))[1]
                })
            end
            local failures = {}
            try {
                function ()
                    failures = import(suite, {rootdir = addon, anonymous = true}).failures(arguments)
                end,
                catch {
                    function (raised)
                        failures = {"the suite raised an error: " .. tostring(raised)}
                    end
                }
            }
            for _, failure in ipairs(failures) do
                cprint("${red}%s: %s", suite, failure)
            end
            return #failures == 0
        end)
    target_end()
end

suites("toolchain_light", light, false)
suites("toolchain_packages", packaged, true)
if get_config("tests") == "device" then
    suites("toolchain_device", device, true, "device")
end
