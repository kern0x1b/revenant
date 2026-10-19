local host = {plat = "macosx", arch = "arm64"}
local llvm = "23.1.3"
add_requires("charon@llvm " .. llvm, table.join(host, {alias = "llvm", configs = {libraries = true}}))
add_requires("hades-third-party@rellume 2026.09.10", table.join(host, {alias = "rellume", configs = {llvm = llvm}}))
add_requires("hades-third-party@blocksruntime 2017.10.27", table.join(host, {alias = "blocksruntime"}))
add_requires("charon@iphoneos-sdk 16.4", table.join(host, {alias = "iphoneos-sdk"}))
add_requires("charon@ld64 956.6", table.join(host, {alias = "ld64"}))
add_requires("charon@ldid", table.join(host, {alias = "ldid"}))
add_requireconfs("llvm.iphoneos-sdk", {override = true, version = "16.4"})
add_requireconfs("rellume.llvm.iphoneos-sdk", {override = true, version = "16.4"})

rule("katabasis.llvm")
    on_config(function (target)
        local prefix = target:pkg("llvm"):installdir()
        target:add("sysincludedirs", path.join(prefix, "include"))
        target:add("linkdirs", path.join(prefix, "lib"))
        target:add("rpathdirs", path.join(prefix, "lib"))
        target:add("defines", "_GNU_SOURCE", "__STDC_CONSTANT_MACROS", "__STDC_FORMAT_MACROS", "__STDC_LIMIT_MACROS")
        target:add("cxxflags", "-fno-rtti")
    end)
rule_end()

set_plat("macosx")
set_arch("arm64")

target("xlate")
    set_kind("binary")
    set_languages("c++20")
    add_rules("katabasis.llvm")
    add_files("xlate/src/xlate.cpp", "xlate/src/macho.cpp", "xlate/src/objc.cpp", "xlate/src/exports.cpp", "xlate/src/tsd_scan.cpp")
    add_packages("llvm", "rellume")
    add_links("LLVM")
    on_config(function (target)
        target:add("rpathdirs", path.join(target:pkg("rellume"):installdir(), "lib"))
    end)

target("xlgen")
    set_kind("binary")
    set_languages("c++20")
    add_rules("katabasis.llvm")
    add_files("xlate/src/xlgen.cpp")
    add_packages("llvm")
    add_links("clang-cpp", "LLVM")

rule("katabasis.translated")
    on_build(function (target)
        local script = import(path.basename(target:values("katabasis.script")), {rootdir = path.join(target:scriptdir(), path.directory(target:values("katabasis.script"))), anonymous = true})
        script(path.join(target:targetdir(), target:name()))
    end)
rule_end()

for _, app in ipairs({{"katabasis_cxxinit", "corpus/cxxinit/build.lua"}, {"katabasis_refrepro", "corpus/refrepro/build.lua"},
                      {"katabasis_devtime", "perf/build.lua"}}) do
    local name, script = app[1], app[2]
    target(name)
        set_kind("phony")
        set_default(false)
        add_deps("xlate", "xlgen")
        add_packages("blocksruntime", "iphoneos-sdk", "ld64", "ldid")
        add_rules("katabasis.translated")
        set_values("katabasis.script", script)
end

target("katabasis_corpus")
    set_kind("phony")
    set_default(false)
    add_deps("xlate", "xlgen")
    add_packages("blocksruntime", "iphoneos-sdk", "ld64", "ldid")
    add_tests("jumptable", "tsdscan", "tsdguard", "int128", "ordinal", "weakimport", "classpair", "lse")
    on_test(function (target, opt)
        local name = path.filename(opt.name)
        local check = import("check", {rootdir = path.join(target:scriptdir(), "corpus", name), anonymous = true})
        local ok, errors = try { function () check(path.join(target:autogendir(), "tests", name), {host_only = true}); return true end,
                                 catch { function (errors) return false, errors end } }
        if not ok then
            opt.errors = tostring(errors)
        end
        return ok
    end)
