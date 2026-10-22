package("td")
    set_kind("library")
    set_homepage("https://core.telegram.org/tdlib")
    set_description("TDLib's tde2e and tdutils, the end-to-end encryption and utility libraries of Telegram's secret chats, as static libraries for armv7 iOS 6, at master commit e894536b (v1.8.0 plus 7675 commits) that Telegram vendors")
    set_license("BSL-1.0")

    add_urls("https://github.com/tdlib/td.git")
    add_versions("1.8.0-7675", "e894536b2f46caad93f997448d2daff9431b19dd")
    add_deps("revenant@libcxx", {alias = "libcxx"})
    add_deps("revenant@openssl", {alias = "openssl"})
    add_deps("revenant@zlib", {alias = "zlib"})
    add_deps("cmake", "ninja", {kind = "binary", host = true})
    add_links("tde2e", "tdutils")

    on_install("iphoneos", function (package)
        import("lib.detect.find_tool")
        local cmake = assert(find_tool("cmake"), "cmake is needed to build td")
        local ninja = assert(find_tool("ninja"), "ninja is needed to build td")
        local root = path.absolute(".")
        local native = path.absolute("native-build")
        os.mkdir(native)
        os.vrunv(cmake.program, {"-G", "Ninja", "-DCMAKE_MAKE_PROGRAM=" .. ninja.program, "-DTD_GENERATE_SOURCE_FILES=ON", root},
                 {curdir = native})
        os.vrunv(cmake.program, {"--build", native}, {curdir = native})

        local cmake_helper = import("@addon.revenant.apple.cmake", {anonymous = true})
        local openssl = package:dep("openssl"):installdir()
        local builddir = cmake_helper.install(package, {"-DOPENSSL_FOUND=1",
            "-DOPENSSL_CRYPTO_LIBRARY=" .. path.join(openssl, "lib", "libcrypto.a"),
            "-DOPENSSL_INCLUDE_DIR=" .. path.join(openssl, "include")},
            {deps = {"libcxx", "openssl", "zlib"}, cflags = {"-w"}, cxxflags = {"-w"}, targets = {"tde2e", "tdutils"},
             install = false, licenses = "LICENSE_1_0.txt"})

        local lib = package:installdir("lib")
        local headers = package:installdir("include", "td", "e2e")
        os.mkdir(lib)
        os.mkdir(headers)
        os.cp(path.join(builddir, "tde2e", "libtde2e.a"), lib)
        os.cp(path.join(builddir, "tdutils", "libtdutils.a"), lib)
        for _, header in ipairs({"e2e_api.h", "e2e_errors.h"}) do
            os.cp(path.join(root, "tde2e", "td", "e2e", header), headers)
        end
    end)

    on_test(function (package)
        for _, library in ipairs({"tde2e", "tdutils"}) do
            assert(os.isfile(path.join(package:installdir("lib"), "lib" .. library .. ".a")), "lib" .. library .. ".a is not installed")
        end
        for _, header in ipairs({"e2e_api.h", "e2e_errors.h"}) do
            assert(os.isfile(path.join(package:installdir("include"), "td", "e2e", header)), header .. " is not installed")
        end
    end)
