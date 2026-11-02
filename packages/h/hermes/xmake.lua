package("hermes")
    set_homepage("https://hermesengine.dev")
    set_description("Hermes 250829098.0.17, the JavaScript engine React Native 0.86.3 runs by default (its V1 line, the one the hermes-compiler it ships is built from), as libhermesvm and libjsi for armv7 iOS 6.0: JSI is compiled from the react-native package's own sources, the host hermesc is built from the same commit so the bytecode it writes is the bytecode the engine reads, and Intl uses the Foundation backend, so no ICU is needed.")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/facebook/hermes.git")
    add_versions("250829098.0.17", "3477757eb2475555cf8d8df24bfb1deb0613880d")
    add_patches("250829098.0.17", path.join(os.scriptdir(), "patches", "sysroot-from-toolchain.patch"), "05ad39c3cae3f864853c8da08c7a87bdf016f97012835c1e2cbdc852f3b5cc0b")
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path.", default = "1", readonly = true})

    on_load("iphoneos", function (package)
        package:add("deps", "revenant@libcxx", {alias = "libcxx"})
        package:add("deps", "revenant@react-native", {alias = "react-native"})
        package:add("frameworks", "Foundation")
    end)

    add_links("hermesvm", "jsi")

    local PUBLIC_HEADERS = {
        {"API/hermes", "hermes"},
        {"public/hermes/Public", "hermes/Public"},
        {"API/hermes/cdp", "hermes/cdp"},
        {"API/hermes/inspector", "hermes/inspector"},
        {"API/hermes/inspector/chrome", "hermes/inspector/chrome"},
    }

    on_install("iphoneos", function (package)
        import("lib.detect.find_tool")
        local cmake = assert(find_tool("cmake"), "cmake is needed to build hermes")
        local ninja = assert(find_tool("ninja"), "ninja is needed to build hermes")
        local source = path.absolute(".")
        local jsi = package:dep("react-native"):installdir("src", "react-native", "ReactCommon", "jsi")
        local host = path.absolute("build_host_hermesc")
        local clang = os.iorunv("xcrun", {"--sdk", "macosx", "--find", "clang"}):trim()
        local clangxx = os.iorunv("xcrun", {"--sdk", "macosx", "--find", "clang++"}):trim()
        local sysroot = os.iorunv("xcrun", {"--sdk", "macosx", "--show-sdk-path"}):trim()
        os.mkdir(host)
        os.vrunv(cmake.program, {"-G", "Ninja", "-S", source, "-B", host,
                                 "-DCMAKE_MAKE_PROGRAM=" .. ninja.program,
                                 "-DCMAKE_BUILD_TYPE=Release",
                                 "-DCMAKE_C_COMPILER=" .. clang,
                                 "-DCMAKE_CXX_COMPILER=" .. clangxx,
                                 "-DCMAKE_OSX_SYSROOT=" .. sysroot,
                                 "-DJSI_DIR=" .. jsi,
                                 "-DHERMES_ENABLE_TEST_SUITE=OFF"},
                 {envs = {SDKROOT = sysroot, IPHONEOS_DEPLOYMENT_TARGET = ""}})
        os.vrunv(cmake.program, {"--build", host, "--target", "hermesc", "--parallel"},
                 {envs = {SDKROOT = sysroot}})
        local cmakefile = path.join(host, "ImportHostCompilers.cmake")
        assert(os.isfile(cmakefile), "hermesc did not export ImportHostCompilers.cmake")

        local cross = import("@addon.revenant.apple.cmake", {anonymous = true})
        local build = cross.install(package, {
            "-DJSI_DIR=" .. jsi,
            "-DIMPORT_HOST_COMPILERS=" .. cmakefile,
            "-DHERMES_IS_MOBILE_BUILD=ON",
            "-DHERMES_ALLOW_BOOST_CONTEXT=0",
            "-DHERMES_ENABLE_INTL=ON",
            "-DHERMES_ENABLE_TEST_SUITE=OFF",
            "-DHERMES_ENABLE_DEBUGGER=OFF",
            "-DHERMES_BUILD_SHARED_JSI=OFF",
            "-DHERMES_BUILD_APPLE_FRAMEWORK=OFF",
        }, {targets = {"hermesvm_a", "jsi"}, install = false, sourcedir = source, licenses = {"LICENSE"}})

        local installdir = package:installdir()
        os.mkdir(path.join(installdir, "lib"))
        os.cp(path.join(build, "lib", "libhermesvm_a.a"), path.join(installdir, "lib", "libhermesvm.a"))
        os.cp(path.join(build, "jsi", "libjsi.a"), path.join(installdir, "lib", "libjsi.a"))
        for _, entry in ipairs(PUBLIC_HEADERS) do
            local folder, destination = entry[1], path.join(installdir, "include", entry[2])
            os.mkdir(destination)
            for _, header in ipairs(os.files(path.join(source, folder, "*.h"))) do
                os.cp(header, destination)
            end
        end
    end)
