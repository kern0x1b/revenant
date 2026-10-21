if get_config("component") ~= "" or is_plat("iphoneos") then
    return
end

local host = {plat = "macosx", arch = "arm64"}
local llvm = "23.1.3"
add_requires("revenant@llvm " .. llvm, {alias = "llvm", configs = {libraries = true}})
add_requires("revenant@rellume 2026.09.10", table.join(host, {alias = "rellume", configs = {llvm = llvm}}))
add_requires("revenant@blocksruntime 2017.10.27", table.join(host, {alias = "blocksruntime"}))
add_requires("revenant@iphoneos-sdk 16.4", {alias = "iphoneos-sdk"})
add_requires("revenant@ld64 956.6", {alias = "ld64"})
add_requires("revenant@ldid", {alias = "ldid"})
add_requireconfs("llvm.iphoneos-sdk", {override = true, version = "16.4"})
add_requireconfs("rellume.llvm.iphoneos-sdk", {override = true, version = "16.4"})

rule("recompiler.llvm")
    on_config(function (target)
        local llvm = target:pkg("llvm")
        if llvm then
            local prefix = llvm:installdir()
            target:add("sysincludedirs", path.join(prefix, "include"))
            target:add("linkdirs", path.join(prefix, "lib"))
            target:add("rpathdirs", path.join(prefix, "lib"))
        end
        target:add("defines", "_GNU_SOURCE", "__STDC_CONSTANT_MACROS", "__STDC_FORMAT_MACROS", "__STDC_LIMIT_MACROS")
        target:add("cxxflags", "-fno-rtti")
    end)
rule_end()

set_plat("macosx")
set_arch("arm64")

target("xlate")
    set_kind("binary")
    set_languages("c++20")
    add_rules("recompiler.llvm")
    add_files("src/xlate/xlate.cpp", "src/xlate/macho.cpp", "src/xlate/objc.cpp", "src/xlate/exports.cpp", "src/xlate/tsd_scan.cpp")
    add_packages("llvm", "rellume")
    add_links("LLVM")
    on_config(function (target)
        local rellume = target:pkg("rellume")
        if rellume then
            target:add("rpathdirs", path.join(rellume:installdir(), "lib"))
        end
    end)

target("xlgen")
    set_kind("binary")
    set_languages("c++20")
    add_rules("recompiler.llvm")
    add_files("src/xlate/xlgen.cpp")
    add_packages("llvm")
    add_links("clang-cpp", "LLVM")

rule("recompiler.translated")
    on_build(function (target)
        local script = import(path.basename(target:values("recompiler.script")), {rootdir = path.join(target:scriptdir(), path.directory(target:values("recompiler.script"))), anonymous = true})
        script(path.join(target:targetdir(), target:name()))
    end)
rule_end()

for _, app in ipairs({{"recompiler_cxxinit", "tests/cxxinit/build.lua"}, {"recompiler_refrepro", "tests/refrepro/build.lua"},
                      {"recompiler_blockid", "tests/blockid/build.lua"}, {"recompiler_devtime", "tests/perf/build.lua"}}) do
    local name, script = app[1], app[2]
    target(name)
        set_kind("phony")
        set_default(false)
        add_deps("xlate", "xlgen")
        add_packages("blocksruntime", "iphoneos-sdk", "ld64", "ldid")
        add_rules("recompiler.translated")
        set_values("recompiler.script", script)
end

local function corpus(target, opt)
    local name = path.filename(opt.name)
    local check = import("check", {rootdir = path.join(target:scriptdir(), "tests", name), anonymous = true})
    local passed, errors = true, nil
    try {
        function () check(path.join(target:autogendir(), "tests", name), {host_only = true}) end,
        catch { function (raised) passed, errors = false, raised end }
    }
    if not passed then
        opt.errors = tostring(errors)
    end
    return passed
end

target("recompiler_corpus")
    set_kind("phony")
    set_default(false)
    add_deps("xlate", "xlgen")
    add_packages("blocksruntime", "iphoneos-sdk", "ld64", "ldid")
    add_tests("jumptable", "tsdscan", "tsdguard", "int128", "weakimport", "lse")
    on_test(corpus)
target_end()

if get_config("tests") == "device" then
    target("recompiler_device")
        set_kind("phony")
        set_default(false)
        set_group("device")
        add_deps("xlate", "xlgen")
        add_packages("blocksruntime", "iphoneos-sdk", "ld64", "ldid")
        add_tests("classpair", "ordinal")
        on_test(corpus)
    target_end()
end
