package("boringssl")
    set_kind("library")
    set_homepage("https://boringssl.googlesource.com/boringssl")
    set_description("BoringSSL at master-with-bazel commit cf686573 (2024-03-06), the snapshot Telegram vendors, as libcrypto and libssl for armv7 iOS 6 with its 32-bit ARM assembly: target.h keeps the assembly on Apple, the ios32 perlasm output is generated into apple-arm/ and listed by CMake, and the system random source reads /dev/urandom where CCRandomGenerateBytes is absent")
    set_license("OpenSSL")

    add_urls("https://github.com/google/boringssl.git")
    add_versions("2024.03.06", "cf6865731655cf49f473732aa87e0804f6011a25")
    add_patches("2024.03.06", "patches/0001-target-h-keep-apple-arm32-asm.patch", "24f496e7b803a7a1e4a582f572bd117b33963e9834adfb6c0d3234e885c8bf4d")
    add_patches("2024.03.06", "patches/0002-cmake-apple-armv7-ios32-assembly.patch", "384213742b2e4a6d50823094ccfe3717dac974cf902dd87775d2b1629742ce87")
    add_patches("2024.03.06", "patches/0003-urandom-where-ccrandom-is-absent.patch", "81fe3447a7fc99c95dcf43251feabba903caff41b7dc707dc0603b88bfc25f83")
    add_links("ssl", "crypto")
    if is_plat("iphoneos") then
        add_deps("revenant@libcxx", {alias = "libcxx"})
    end

    on_install("iphoneos", "macosx", function (package)
        if package:is_plat("iphoneos") and package:is_arch("armv7") then
            for _, item in ipairs({
                {"apple-arm/crypto/chacha/chacha-armv4-apple.S", "src/crypto/chacha/asm/chacha-armv4.pl"},
                {"apple-arm/crypto/fipsmodule/aesv8-armv7-apple.S", "src/crypto/fipsmodule/aes/asm/aesv8-armx.pl"},
                {"apple-arm/crypto/fipsmodule/armv4-mont-apple.S", "src/crypto/fipsmodule/bn/asm/armv4-mont.pl"},
                {"apple-arm/crypto/fipsmodule/bsaes-armv7-apple.S", "src/crypto/fipsmodule/aes/asm/bsaes-armv7.pl"},
                {"apple-arm/crypto/fipsmodule/ghash-armv4-apple.S", "src/crypto/fipsmodule/modes/asm/ghash-armv4.pl"},
                {"apple-arm/crypto/fipsmodule/ghashv8-armv7-apple.S", "src/crypto/fipsmodule/modes/asm/ghashv8-armx.pl"},
                {"apple-arm/crypto/fipsmodule/sha1-armv4-large-apple.S", "src/crypto/fipsmodule/sha/asm/sha1-armv4-large.pl"},
                {"apple-arm/crypto/fipsmodule/sha256-armv4-apple.S", "src/crypto/fipsmodule/sha/asm/sha256-armv4.pl"},
                {"apple-arm/crypto/fipsmodule/sha512-armv4-apple.S", "src/crypto/fipsmodule/sha/asm/sha512-armv4.pl"},
                {"apple-arm/crypto/fipsmodule/vpaes-armv7-apple.S", "src/crypto/fipsmodule/aes/asm/vpaes-armv7.pl"},
                {"apple-arm/crypto/test/trampoline-armv4-apple.S", "src/crypto/test/asm/trampoline-armv4.pl"}}) do
                os.mkdir(path.directory(item[1]))
                os.vrunv("perl", {item[2], "ios32", item[1]})
            end
        end
        local configs = {"-DCMAKE_POLICY_VERSION_MINIMUM=3.5", "-DBUILD_TESTING=OFF", "-DBUILD_SHARED_LIBS=OFF"}
        if package:is_plat("iphoneos") then
            local cmake = import("@addon.revenant.apple.cmake", {anonymous = true})
            local builddir = cmake.install(package, configs,
                {deps = {"libcxx"}, targets = {"crypto", "ssl"}, install = false, licenses = "LICENSE"})
            os.cp(path.join(builddir, "libcrypto.a"), package:installdir("lib"))
            os.cp(path.join(builddir, "libssl.a"), package:installdir("lib"))
        else
            local builddir = path.absolute("build_revenant")
            import("package.tools.cmake").build(package, configs, {builddir = builddir})
            os.cp(path.join(builddir, "libcrypto.a"), package:installdir("lib"))
            os.cp(path.join(builddir, "libssl.a"), package:installdir("lib"))
        end
        os.cp("src/include/openssl", package:installdir("include"))
    end)

    on_test(function (package)
        for _, library in ipairs({"crypto", "ssl"}) do
            assert(os.isfile(path.join(package:installdir("lib"), "lib" .. library .. ".a")), "lib" .. library .. ".a is not installed")
        end
        assert(os.isfile(path.join(package:installdir("include"), "openssl", "ssl.h")), "openssl/ssl.h is not installed")
    end)
