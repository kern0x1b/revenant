local component = get_config("component")
if is_plat("iphoneos") or (component ~= "" and component ~= "neon") then
    return
end

target("neon_vsqrt")
    set_kind("binary")
    set_default(false)
    add_files("tests/vsqrt_test.c")
    add_includedirs("include")
    add_tests("vsqrt")
    on_test(function (target, opt)
        return import("@addon.revenant.host_test", {anonymous = true}).run(target, opt)
    end)
target_end()

target("neon_vfma")
    set_kind("binary")
    set_default(false)
    add_files("tests/fma_test.c")
    add_includedirs("include")
    add_tests("vfma")
    on_test(function (target, opt)
        return import("@addon.revenant.host_test", {anonymous = true}).run(target, opt)
    end)
target_end()
