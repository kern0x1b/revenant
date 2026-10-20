package("rellume")
    set_homepage("https://github.com/aengelke/rellume")
    set_description("Rellume, the machine code to LLVM IR lifter xlate is built on: aengelke's tree at a commit, its AArch64 front end only, with our fixes as patches")
    set_license("LGPL-2.1-or-later")

    local commit = "62a32d40154ef4735c2ee230ee090c12375e695b"
    local patches = {"0001-Include-cstdint-before-the-decoder-headers.patch",
                     "0002-Lift-reads-of-TPIDRRO_EL0-on-AArch64.patch",
                     "0003-Map-a-calling-convention-only-to-the-architectures-b.patch",
                     "0004-Lift-AArch64-without-the-x86-64-decoder.patch",
                     "0005-Lift-the-AArch64-LSE-atomic-memory-operations.patch"}
    add_urls("https://github.com/aengelke/rellume.git", {submodules = false})
    add_versions("2026.09.10", commit)
    local digests = {"xmake.lua=" .. hash.sha256(path.join(os.scriptdir(), "xmake.lua"))}
    for _, name in ipairs(patches) do
        local file = path.join(os.scriptdir(), "patches", name)
        local digest = hash.sha256(file)
        add_patches("2026.09.10", file, digest)
        table.insert(digests, name .. "=" .. digest)
    end
    add_configs("recipe", {description = "The digest of this recipe and the patches it applies, so a changed patch is a different build.", default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    add_configs("llvm", {description = "The version of revenant's llvm package, with its libraries, that rellume is built against.", default = "23.1.3", type = "string"})

    add_deps("revenant-third-party@farmdec 2022.02.08", {alias = "farmdec"})
    on_load(function (package)
        package:add("deps", "revenant@llvm " .. package:config("llvm"), {alias = "llvm", configs = {libraries = true}})
    end)
    add_configs("shared", {description = "Build rellume as a shared library, which its licence asks of a program that links it.", default = true, type = "boolean", readonly = true})
    add_links("rellume")
    add_includedirs("include", "include/rellume")

    on_install("macosx", function (package)
        import("core.base.json")
        local llvm = package:dep("llvm"):installdir()

        local function cpustruct(input, output, private)
            local entries = json.loadfile(input)
            local offset = 0
            for _, entry in ipairs(entries) do
                if offset % entry.size ~= 0 then
                    raise("misaligned cpu struct entry at offset %d in %s", offset, input)
                end
                entry.offset = offset
                offset = offset + entry.size
            end
            local macros
            if private then
                macros = {{"RELLUME_MAPPED_REG", function (entry) return entry.reg end, function (entry)
                              return format("RELLUME_MAPPED_REG(%s, %d, ArchReg::%s, Facet::%s)", entry.name:upper(), entry.offset, entry.reg[1], entry.reg[2])
                          end},
                          {"RELLUME_NAMED_REG", function (entry) return entry.name end, function (entry)
                              return format("RELLUME_NAMED_REG(%s, %s, %d, %d)", entry.name, entry.name:upper(), entry.size, entry.offset)
                          end}}
            else
                macros = {{"RELLUME_PUBLIC_REG", function (entry) return entry.reg and entry.export end, function (entry)
                              return format("RELLUME_PUBLIC_REG(%s, %s, %d, %d)", entry.name, entry.name:upper(), entry.size, entry.offset)
                          end}}
            end
            local lines = {}
            for _, macro in ipairs(macros) do
                table.insert(lines, "#ifdef " .. macro[1])
                for _, entry in ipairs(entries) do
                    if macro[2](entry) then
                        table.insert(lines, macro[3](entry))
                    end
                end
                table.insert(lines, "#endif")
            end
            io.writefile(output, table.concat(lines, "\n") .. "\n")
        end
        local generated = path.join("generated", "rellume")
        os.mkdir(generated)
        cpustruct("data/rellume/cpustruct-aarch64.json", path.join(generated, "cpustruct-aarch64.inc"), false)
        cpustruct("data/rellume/cpustruct-aarch64.json", path.join(generated, "cpustruct-aarch64-private.inc"), true)

        io.writefile("xmake.lua", [[
add_rules("mode.release")
option("llvm")
    set_default("")
    set_showmenu(true)
option_end()
option("farmdec")
    set_default("")
    set_showmenu(true)
option_end()
target("rellume")
    set_kind("shared")
    set_languages("c++17")
    add_files("src/basicblock.cc", "src/callconv.cc", "src/facet.cc", "src/function.cc", "src/lldecoder.cc",
              "src/lifter-base.cc", "src/regfile.cc", "src/rellume.cc", "src/a64/main.cc", "src/a64/simd.cc")
    add_includedirs("include", "generated", "src")
    add_sysincludedirs("$(llvm)/include", "$(farmdec)/include")
    add_linkdirs("$(llvm)/lib", "$(farmdec)/lib")
    add_links("farmdec", "LLVM")
    add_defines("RELLUME_WITH_AARCH64")
    add_cxflags("-fvisibility=hidden", "-fno-exceptions", "-fno-unwind-tables", "-fno-rtti")
    add_headerfiles("include/rellume/rellume.h", "generated/rellume/cpustruct-aarch64.inc", {prefixdir = "rellume"})
]])
        import("package.tools.xmake").install(package, {llvm = llvm, farmdec = package:dep("farmdec"):installdir()})
        os.cp("LICENSE", package:installdir("licenses") .. "/")
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "librellume.dylib")))
        assert(package:has_cincludes({"rellume/rellume.h", "cpustruct-aarch64.inc"},
                                     {configs = {includedirs = path.join(package:dep("llvm"):installdir(), "include")}}))
    end)
