package("farmdec")
    set_homepage("https://github.com/okitec/farmdec")
    set_description("farmdec, the AArch64 decoder rellume lifts with: okitec's tree at a commit, with our decoding fix as a patch")
    set_license("BSD-3-Clause")

    local commit = "efff1d87ee125b58f6f88fede06812231dba4ee1"
    local patches = {"0001-Decode-UBFM-with-immr-0-and-imms-31-as-UBFX.patch",
                     "0002-Decode-the-ARMv8-Crypto-extension-AES-SHA-1-and-SHA-.patch"}
    add_urls("https://github.com/okitec/farmdec.git")
    add_versions("2022.02.08", commit)
    local digests = {"xmake.lua=" .. hash.sha256(path.join(os.scriptdir(), "xmake.lua"))}
    for _, name in ipairs(patches) do
        local file = path.join(os.scriptdir(), "patches", name)
        local digest = hash.sha256(file)
        add_patches("2022.02.08", file, digest)
        table.insert(digests, name .. "=" .. digest)
    end
    add_configs("recipe", {description = "The digest of this recipe and the patches it applies, so a changed patch is a different build.", default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

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
