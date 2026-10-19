package("xz")
    set_homepage("https://tukaani.org/xz/")
    set_description("xz 5.8.4 (liblzma), unmodified, as the subset the LZMA codec of the Compression backport needs: the LZMA1 and LZMA2 coders, the xz container, and the CRC32, CRC64 and SHA-256 checks. A static library whose every symbol is hidden.")
    set_license("0BSD")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/tukaani-project/xz.git")
    add_versions("v5.8.4", "d3e650e63c110e830fd5391e7f8b45df0b91d3da")
    add_links("xzcodec")

    local recipe = os.scriptdir()
    local digest = {hash.sha256(path.join(recipe, "xmake.lua")), hash.sha256(path.join(recipe, "config.h"))}
    add_configs("recipe", {description = "The digest of this recipe and its config.h, so a changed flag is a different library.", default = hash.strhash128(table.concat(digest, ";")), type = "string", readonly = true})

    local FLAGS = {"-Os", "-fvisibility=hidden", "-fno-strict-aliasing", "-DLZMA_API_STATIC", "-DHAVE_CONFIG_H"}
    local SOURCES = {
        "src/liblzma/common/block_buffer_decoder.c", "src/liblzma/common/block_buffer_encoder.c", "src/liblzma/common/block_decoder.c",
        "src/liblzma/common/block_encoder.c", "src/liblzma/common/block_header_decoder.c", "src/liblzma/common/block_header_encoder.c",
        "src/liblzma/common/block_util.c", "src/liblzma/common/common.c", "src/liblzma/common/easy_buffer_encoder.c",
        "src/liblzma/common/easy_decoder_memusage.c", "src/liblzma/common/easy_encoder.c", "src/liblzma/common/easy_encoder_memusage.c",
        "src/liblzma/common/easy_preset.c", "src/liblzma/common/filter_buffer_decoder.c", "src/liblzma/common/filter_buffer_encoder.c",
        "src/liblzma/common/filter_common.c", "src/liblzma/common/filter_decoder.c", "src/liblzma/common/filter_encoder.c",
        "src/liblzma/common/filter_flags_decoder.c", "src/liblzma/common/filter_flags_encoder.c", "src/liblzma/common/hardware_cputhreads.c",
        "src/liblzma/common/hardware_physmem.c", "src/liblzma/common/index.c", "src/liblzma/common/index_decoder.c",
        "src/liblzma/common/index_encoder.c", "src/liblzma/common/index_hash.c", "src/liblzma/common/stream_buffer_decoder.c",
        "src/liblzma/common/stream_buffer_encoder.c", "src/liblzma/common/stream_decoder.c", "src/liblzma/common/stream_encoder.c",
        "src/liblzma/common/stream_flags_common.c", "src/liblzma/common/stream_flags_decoder.c", "src/liblzma/common/stream_flags_encoder.c",
        "src/liblzma/common/string_conversion.c", "src/liblzma/common/vli_decoder.c", "src/liblzma/common/vli_encoder.c",
        "src/liblzma/common/vli_size.c",
        "src/liblzma/check/check.c", "src/liblzma/check/crc32_fast.c", "src/liblzma/check/crc64_fast.c", "src/liblzma/check/sha256.c",
        "src/liblzma/lz/lz_decoder.c", "src/liblzma/lz/lz_encoder.c", "src/liblzma/lz/lz_encoder_mf.c",
        "src/liblzma/rangecoder/price_table.c",
        "src/liblzma/lzma/fastpos_table.c", "src/liblzma/lzma/lzma2_decoder.c", "src/liblzma/lzma/lzma2_encoder.c",
        "src/liblzma/lzma/lzma_decoder.c", "src/liblzma/lzma/lzma_encoder.c", "src/liblzma/lzma/lzma_encoder_optimum_fast.c",
        "src/liblzma/lzma/lzma_encoder_optimum_normal.c", "src/liblzma/lzma/lzma_encoder_presets.c",
        "src/common/tuklib_cpucores.c", "src/common/tuklib_physmem.c",
    }

    on_install("iphoneos", function (package)
        local toolchain = assert(package:toolchains(), "xz is built with the apple-ios toolchain")[1]
        toolchain:load()
        local target = {"-target", package:arch() .. "-apple-ios", "-miphoneos-version-min=" .. toolchain:config("deployment"),
                        "-isysroot", toolchain:config("sdkdir"), "-I" .. recipe, "-I" .. os.curdir(),
                        "-Isrc/liblzma/api", "-Isrc/liblzma/common", "-Isrc/liblzma/check", "-Isrc/liblzma/lz", "-Isrc/liblzma/lzma",
                        "-Isrc/liblzma/rangecoder", "-Isrc/liblzma/simple", "-Isrc/liblzma/delta", "-Isrc/common"}
        local objects = {}
        for _, source in ipairs(SOURCES) do
            local object = path.absolute(path.join("objects", (source:gsub("/", "_")) .. ".o"))
            os.mkdir(path.directory(object))
            os.vrunv(toolchain:tool("cc"), table.join(target, FLAGS, {"-c", source, "-o", object}))
            table.insert(objects, object)
        end
        os.vrunv("xcrun", table.join({"libtool", "-static", "-o", path.join(package:installdir("lib"), "libxzcodec.a")}, objects))
        os.mkdir(package:installdir("include", "lzma", "lzma"))
        os.vcp("src/liblzma/api/lzma.h", package:installdir("include", "lzma"))
        for _, header in ipairs(os.files("src/liblzma/api/lzma/*.h")) do
            os.vcp(header, package:installdir("include", "lzma", "lzma"))
        end
        os.vcp("COPYING.0BSD", package:installdir("licenses"))
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libxzcodec.a")))
        assert(os.isfile(path.join(package:installdir("include"), "lzma", "lzma.h")))
    end)
