package("ld64")
    set_kind("toolchain")
    set_homepage("https://github.com/tpoechtrager/cctools-port")
    set_description("Apple's ld64 from cctools-port, the linker that still inserts branch islands for armv7")
    set_license("APSL-2.0")

    add_urls("https://github.com/tpoechtrager/cctools-port/archive/$(version).tar.gz", {version = function (version)
        return ({["956.6"] = "904de2a71d4da6a9b30d2efaf912a10ddc7d9ddb"})[tostring(version)]
    end})
    add_versions("956.6", "6809ba18b6b4f4646b17b1baba48f9a0cb94425cc334272918ba944fd7399b32")
    add_resources("956.6", "libtapi",
                  "https://github.com/tpoechtrager/apple-libtapi/archive/fa9443738c1a18accef4244732ec6d6ee97a8133.tar.gz",
                  "cf939c661aa288da773e59acf8ab916bb6c322bf7abe9130c09a66bcc98fdc5a")
    on_load(function (package)
        if not import("@addon.revenant.prebuilt", {anonymous = true}).wanted(package) then
            package:add("deps", "cmake", "ninja", {kind = "binary"})
        end
    end)

    local inputs = os.files(path.join(os.scriptdir(), "patches", "*.patch"))
    table.sort(inputs)
    local digests = {}
    for _, file in ipairs(inputs) do
        table.insert(digests, path.filename(file) .. "=" .. hash.sha256(file))
    end
    add_configs("patches", {description = "The digest of this package's patches, so a changed linker is a different package: every armv7 link in the fleet links with it, and a rebuild in place would change all of them at once.", default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    on_fetch(function (package, opt)
        if opt.system then
            return false
        end
    end)

    on_install("@macosx", function (package)
        local prebuilt = import("@addon.revenant.prebuilt", {anonymous = true})
        if prebuilt.install(package) then
            return
        end
        import("lib.detect.find_tool")
        local llvm_config = find_tool("llvm-config", {paths = {"$(env LLVM_PREFIX)/bin", "/opt/homebrew/opt/llvm/bin", "/usr/local/opt/llvm/bin"}})
        if not llvm_config then
            raise("ld64 links libLTO, and cctools' configure finds it through llvm-config; install a full LLVM, such as brew install llvm")
        end
        local llvm = os.iorunv(llvm_config.program, {"--prefix"}):trim()
        local tapi = assert(os.dirs(path.join(package:resourcedir("libtapi"), "apple-libtapi-*"))[1])
        os.vrunv("patch", {"-p2", "-d", tapi, "-i", path.join(package:scriptdir(), "patches", "libtapi-without-darwin-linker-version-helper.patch")})
        os.vrunv("patch", {"-p2", "-i", path.join(package:scriptdir(), "patches", "inlined-text-stub-before-search-paths.patch")})
        os.vrunv("patch", {"-p2", "-i", path.join(package:scriptdir(), "patches", "ordinal-for-dylib-that-only-a-reexport-reaches.patch")})
        os.vrunv("patch", {"-p2", "-i", path.join(package:scriptdir(), "patches", "link-snapshot-beside-the-output.patch")})

        local tapi_version = "1600.0.11.8"
        local tapi_build = path.absolute("tapi-build")
        local tapi_install = path.absolute("tapi-install")
        os.mkdir(tapi_build)
        os.vrunv("cmake", {"-G", "Ninja", path.join(tapi, "src", "llvm"), "-DCMAKE_BUILD_TYPE=Release",
                           "-DCMAKE_INSTALL_PREFIX=" .. tapi_install, "-DLLVM_ENABLE_PROJECTS=tapi;clang",
                           "-DLLVM_TARGETS_TO_BUILD=host", "-DLLVM_INCLUDE_TESTS=OFF", "-DLLVM_INCLUDE_EXAMPLES=OFF",
                           "-DLLVM_INCLUDE_BENCHMARKS=OFF", "-DLLVM_INCLUDE_DOCS=OFF", "-DLLVM_BUILD_TOOLS=OFF",
                           "-DCLANG_BUILD_TOOLS=OFF", "-DTAPI_REPOSITORY_STRING=" .. tapi_version,
                           "-DTAPI_FULL_VERSION=" .. tapi_version}, {curdir = tapi_build})
        os.vrunv("cmake", {"--build", ".", "--target", "clangBasic", "vt_gen"}, {curdir = tapi_build})
        os.vrunv("cmake", {"--build", ".", "--target", "libtapi"}, {curdir = tapi_build})
        os.vrunv("cmake", {"--build", ".", "--target", "install-libtapi", "install-tapi-headers"}, {curdir = tapi_build})

        local cctools = path.absolute("cctools")
        local install = path.absolute("cctools-install")
        os.vrunv("./configure", {"--prefix=" .. install, "--target=arm-apple-darwin11", "--with-libtapi=" .. tapi_install,
                                 "--with-llvm-config=" .. llvm_config.program},
                 {curdir = cctools, envs = {CPPFLAGS = "-I" .. path.join(llvm, "include")}})
        local parallel = import("@addon.revenant.parallel", {anonymous = true})
        for _, part in ipairs({"ld64/src/3rd", "ld64/src/mach_o", "ld64/src/ld"}) do
            parallel.hold(nil, function (width)
                os.vrunv("make", {"-C", part, "-j" .. width}, {curdir = cctools})
            end)
        end
        os.vrunv("make", {"-C", "ld64/src/ld", "install-binPROGRAMS"}, {curdir = cctools})

        local ld = path.join(package:installdir("bin"), "arm-apple-darwin11-ld")
        os.vcp(path.join(install, "bin", "arm-apple-darwin11-ld"), ld)
        os.vcp(path.join(tapi_install, "lib", "libtapi.dylib"), package:installdir("lib"))
        os.vcp(path.join(cctools, "ld64", "APPLE_LICENSE"), package:installdir("licenses", "ld64"))
        os.vcp(path.join(tapi, "src", "LICENSE.txt"), package:installdir("licenses", "libtapi"))
        os.ln("arm-apple-darwin11-ld", path.join(package:installdir("bin"), "ld"))
        os.vrunv("install_name_tool", {"-rpath", path.join(tapi_install, "lib"), "@executable_path/../lib", ld})
        prebuilt.pack(package)
    end)

    on_test(function (package)
        os.vrunv(path.join(package:installdir("bin"), "ld"), {"-v"})
    end)
