-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

option("emulator_guest_rootfs")
    set_showmenu(true)
    set_description("Extracted iPhoneOS root filesystem the guest probes link against and install into")
option_end()

option("emulator_armv6_ld")
    set_showmenu(true)
    set_description("cctools ld64 with ARMv6 output, for the guest probes")
option_end()

local rootfs = get_config("emulator_guest_rootfs")
local ld = get_config("emulator_armv6_ld")
if get_config("component") == "" and not is_plat("iphoneos") and rootfs and ld and os.isfile(ld) and os.isfile(path.join(rootfs, "usr", "lib", "libSystem.B.dylib")) then
    target("emulator_guest_dns_probe")
        set_kind("phony")
        on_build(function (target)
            import("lib.detect.find_tool")
            import("core.project.depend")
            local clang = assert(find_tool("clang"), "the guest probe needs clang")
            local rootfs = get_config("emulator_guest_rootfs")
            local outputdir = path.join(target:targetdir(), "guest")
            local output = path.join(outputdir, "dns_async_probe")
            local sources = {"armv6_crt.S", "dns_async_probe.c", "system_configuration_probe.c", "runtime_initializers.c"}
            local libraries = {path.join(rootfs, "System", "Library", "Frameworks", "SystemConfiguration.framework", "SystemConfiguration"),
                               path.join(rootfs, "System", "Library", "Frameworks", "CoreFoundation.framework", "CoreFoundation"),
                               path.join(rootfs, "usr", "lib", "libSystem.B.dylib")}
            local inputs = {}
            for _, source in ipairs(table.join(sources, {"system_configuration_probe.h", "runtime_initializers.h"})) do
                table.insert(inputs, path.join(target:scriptdir(), source))
            end
            depend.on_changed(function ()
                os.mkdir(outputdir)
                local objects = {}
                for _, source in ipairs(sources) do
                    local object = path.join(outputdir, path.basename(source) .. ".o")
                    local flags = {"-target", "armv6-apple-ios1.0", "-march=armv6", "-marm"}
                    if path.extension(source) == ".c" then
                        table.join2(flags, {"-Oz", "-ffreestanding", "-fno-stack-protector", "-fno-builtin"})
                    end
                    os.vrunv(clang.program, table.join(flags, {"-c", path.join(target:scriptdir(), source), "-o", object}))
                    table.insert(objects, object)
                end
                os.vrunv(get_config("emulator_armv6_ld"), table.join({"-arch", "armv6", "-execute", "-e", "_start",
                    "-syslibroot", rootfs, "-iphoneos_version_min", "1.0", "-no_pie", "-segalign", "0x1000",
                    "-bind_at_load", "-no_uuid", "-no_function_starts", "-no_data_in_code_info", "-no_encryption",
                    "-o", output}, objects, libraries))
            end, {files = table.join(inputs, libraries), dependfile = target:dependfile(output)})
        end)
end
