if get_config("component") ~= "" or is_plat("iphoneos") then
    return
end

local addon = path.join(os.scriptdir(), "addon")
local toolchain = path.directory(os.scriptdir())
add_requires("revenant@ld64 956.6", {alias = "ld64"})
add_requires("revenant@ldid 2.1.5-procursus7+23.gaf86971", {alias = "ldid"})
add_requires("revenant@iphoneos-sdk 26.2", {alias = "iphoneos-sdk"})
add_requires("revenant@llvm 23.1.3", {alias = "llvm", configs = {libraries = true}})

local light = {"assets_extract_test", "binding_test", "checkout_test", "compat_test", "descriptions_test", "digest_test", "emulator_source_test", "firmware_test",
               "data_test", "locale_order_test", "lock_test", "rust_test", "sdk_rule_test", "sdk_store_test", "sdkstubs_test", "retention_test", "store_race_test", "store_test", "swift_rule_test", "workspace_test"}

local packaged = {"architectures_test", "atomics_test", "backports_package_test", "blocks_test", "carried_test", "checks_test", "device_test",
                  "debian_test", "dyld_test", "gdb_test", "macho_test", "objc_bool_test", "objc_test", "operators_test",
                  "optimisation_test", "order_file_test", "shared_runtime_test", "tls_test", "toolchain_check_test", "weak_test"}

local device = {"callkit_screen_test", "compat_device_test", "emulator_test", "port_test", "swift_test", "tweak_test"}

if get_config("tests") == "device" then
    add_requires("revenant@swift 6.4.0", {alias = "swift", system = false})
end

local install_hints = {
    ["iphoneos-sdk"] = "configure the project with ./xmakew f -P . first, which installs it",
}

local function suites(name, list, packages, group)
    target(name)
        set_kind("phony")
        set_default(false)
        if group then
            set_group(group)
        end
        if #packages > 0 then
            add_packages(table.unpack(packages))
        end
        for _, suite in ipairs(list) do
            add_tests(suite)
        end
        on_test(function (target, opt)
            local suite = path.filename(opt.name)
            for _, name in ipairs(packages) do
                if not target:pkg(name) then
                    raise("%s is not installed on this machine, so %s cannot run; %s", name, suite,
                          install_hints[name] or "install it from the requirement of that name in toolchain/tests/xmake.lua")
                end
            end
            local arguments = {modules = path.join(toolchain, "modules")}
            if #packages > 0 then
                table.join2(arguments, {
                    ld64 = path.join(target:pkg("ld64"):installdir(), "bin", "ld"),
                    ldid = path.join(target:pkg("ldid"):installdir(), "bin", "ldid"),
                    clang = path.join(target:pkg("llvm"):installdir(), "bin", "clang"),
                    sdk = os.dirs(path.join(target:pkg("iphoneos-sdk"):installdir(), "Developer.app", "Contents", "Developer",
                                            "Platforms", "iPhoneOS.platform", "Developer", "SDKs", "iPhoneOS*.sdk"))[1]
                })
            end
            if target:pkg("swift") then
                arguments.swift = target:pkg("swift"):installdir()
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

local packages = {"ld64", "ldid", "iphoneos-sdk", "llvm"}

suites("toolchain_light", light, {})
suites("toolchain_packages", packaged, packages)
if get_config("tests") == "device" then
    suites("toolchain_device", device, table.join(packages, {"swift"}), "device")

    local bench = path.join(os.scriptdir(), "bench")
    local workloads = {"msgsend", "alloc", "collections", "strings", "compute"}
    target("bench")
        set_kind("phony")
        set_default(false)
        set_group("device")
        add_packages(table.unpack(packages))
        for _, name in ipairs(workloads) do
            add_tests(name)
        end
        on_test(function (target, opt)
            local name = path.filename(opt.name)
            local sdk = os.dirs(path.join(target:pkg("iphoneos-sdk"):installdir(), "Developer.app", "Contents", "Developer",
                                          "Platforms", "iPhoneOS.platform", "Developer", "SDKs", "iPhoneOS*.sdk"))[1]
            local failures = import("run", {rootdir = bench, anonymous = true}).check(name, {
                clang = path.join(target:pkg("llvm"):installdir(), "bin", "clang"),
                ld64 = path.join(target:pkg("ld64"):installdir(), "bin", "ld"),
                ld64_version = import("core.project.project").required_package("ld64"):requirestr():match("%s(%S+)$"),
                ldid = path.join(target:pkg("ldid"):installdir(), "bin", "ldid"),
                sdk = sdk
            })
            for _, failure in ipairs(failures) do
                cprint("${red}bench/%s: %s", name, failure)
            end
            return #failures == 0
        end)
    target_end()
end
