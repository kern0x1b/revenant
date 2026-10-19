package("farmdec")
    set_homepage("https://github.com/okitec/farmdec")
    set_description("farmdec, the AArch64 decoder rellume lifts with: okitec's tree at a commit, with our decoding fix as a patch")
    set_license("BSD-3-Clause")

    local commit = "efff1d87ee125b58f6f88fede06812231dba4ee1"
    local patches = {"0001-Decode-UBFM-with-immr-0-and-imms-31-as-UBFX.patch"}
    add_urls("https://github.com/okitec/farmdec.git")
    add_versions("2022.02.08", commit)
    for _, name in ipairs(patches) do
        local file = path.join(os.scriptdir(), "patches", name)
        add_patches("2022.02.08", file, hash.sha256(file))
    end

    on_install(function (package)
        io.writefile("xmake.lua", [[
add_rules("mode.release")
target("farmdec")
    set_kind("static")
    add_files("decode.c")
    add_headerfiles("farmdec.h")
]])
        import("package.tools.xmake").install(package)
        os.cp("LICENSE", package:installdir("licenses") .. "/")
    end)

    on_test(function (package)
        assert(package:has_cfuncs("fad_decode", {includes = {"stdint.h", "farmdec.h"}}))
    end)
