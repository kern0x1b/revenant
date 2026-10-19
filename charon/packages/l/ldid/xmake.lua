package("ldid")
    set_kind("binary")
    set_homepage("https://github.com/ProcursusTeam/ldid")
    set_description("Signs Mach-O binaries with a code signature and entitlements, the way a jailbroken device accepts them")
    set_license("AGPL-3.0-or-later")

    add_urls("https://github.com/ProcursusTeam/ldid/archive/$(version).tar.gz", {version = function (version)
        return ({["2.1.5-procursus7+23.gaf86971"] = "af86971ae72ec3ed3d0a699107c4e882324c941b"})[tostring(version)]
    end})
    add_versions("2.1.5-procursus7+23.gaf86971", "26be4e97a9c0bf608e1b7b301bf1e51cdb77e6069bf20981f615923cc080b1b1")
    add_patches("2.1.5-procursus7+23.gaf86971", "patches/openssl-4-const-and-opaque-strings.patch")
    add_deps("charon@libplist 2.7.0", "charon@openssl 4.0.2")

    on_install("@macosx", function (package)
        local cflags, ldflags = {}, {}
        for _, name in ipairs({"libplist", "openssl"}) do
            local fetched = package:dep(name):fetch()
            for _, folder in ipairs(fetched.includedirs or fetched.sysincludedirs or {}) do
                table.insert(cflags, "-I" .. folder)
            end
            for _, define in ipairs(fetched.defines or {}) do
                table.insert(cflags, "-D" .. define)
            end
            for _, folder in ipairs(fetched.linkdirs or {}) do
                table.insert(ldflags, "-L" .. folder)
            end
            for _, link in ipairs(fetched.links or {}) do
                table.insert(ldflags, "-l" .. link)
            end
        end
        os.vrunv("make", {"ldid", "LIBPLIST_INCLUDES=", "LIBPLIST_LIBS=", "LIBCRYPTO_INCLUDES=", "LIBCRYPTO_LIBS="},
                 {envs = {CPPFLAGS = table.concat(cflags, " "), LDFLAGS = table.concat(ldflags, " ")}})
        os.cp("ldid", package:installdir("bin"))
        os.cp("COPYING", package:installdir("licenses"))
    end)

    on_test(function (package)
        os.vrunv("ldid", {"-h"}, {try = true})
    end)
