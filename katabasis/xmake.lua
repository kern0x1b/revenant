option("katabasis_llvm")
    set_default("/opt/homebrew/opt/llvm")
    set_showmenu(true)
    set_description("The prefix of the LLVM 23 xlate and xlgen link against and translations compile with (headers, libLLVM, libclang-cpp, clang, llvm-extract, llvm-split)")
option_end()

local host = {plat = "macosx", arch = "arm64"}
add_requires("hades-third-party@rellume 2026.09.10", table.join(host, {alias = "rellume", configs = {llvm = get_config("katabasis_llvm")}}))
add_requires("hades-third-party@blocksruntime 2017.10.27", table.join(host, {alias = "blocksruntime"}))
add_requires("charon@iphoneos-sdk 16.4", table.join(host, {alias = "iphoneos-sdk"}))
add_requires("charon@ld64 956.6", table.join(host, {alias = "ld64"}))
add_requires("charon@ldid", table.join(host, {alias = "ldid"}))

rule("katabasis.llvm")
    on_load(function (target)
        local prefix = get_config("katabasis_llvm")
        local header = path.join(prefix, "include", "llvm", "Config", "llvm-config.h")
        local major = os.isfile(header) and io.readfile(header):match("#define LLVM_VERSION_MAJOR (%d+)")
        if major ~= "23" then
            raise("katabasis_llvm=%s is not an LLVM 23 prefix (%s has major %s): pass --katabasis_llvm=<prefix>", prefix, header, tostring(major))
        end
        target:add("sysincludedirs", path.join(prefix, "include"))
        target:add("linkdirs", path.join(prefix, "lib"))
        target:add("rpathdirs", path.join(prefix, "lib"))
        target:add("defines", "_GNU_SOURCE", "__STDC_CONSTANT_MACROS", "__STDC_FORMAT_MACROS", "__STDC_LIMIT_MACROS")
    end)
rule_end()

set_plat("macosx")
set_arch("arm64")

target("xlate")
    set_kind("binary")
    set_languages("c++20")
    add_rules("katabasis.llvm")
    add_files("xlate/src/xlate.cpp", "xlate/src/macho.cpp", "xlate/src/objc.cpp", "xlate/src/exports.cpp", "xlate/src/tsd_scan.cpp")
    add_packages("rellume")
    add_links("LLVM")
    on_config(function (target)
        target:add("rpathdirs", path.join(target:pkg("rellume"):installdir(), "lib"))
    end)

target("xlgen")
    set_kind("binary")
    set_languages("c++20")
    add_rules("katabasis.llvm")
    add_files("xlate/src/xlgen.cpp")
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
