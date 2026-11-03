package("ratex")
    set_kind("library")
    set_homepage("https://github.com/erweixin/RaTeX")
    set_description("RaTeX 0.1.14, the LaTeX math layout of react-native-enriched-markdown: the ratex-ffi staticlib built from the source archive for armv7 iOS 6.0 with the pinned nightly and build-std, with its C header. A patch adds the Cargo.lock the source archive ships without")
    set_license("MIT")

    add_urls("https://github.com/erweixin/RaTeX/archive/refs/tags/v$(version).tar.gz")
    add_versions("0.1.14", "2da907eb5dfcb464c7eef3b4c657fbdee144e3c6633e81efb1e56dcf1c76e01b")
    add_deps("revenant@rust nightly-2026-10-22", {alias = "rust", kind = "binary"})
    add_patches("0.1.14", path.join(os.scriptdir(), "patches", "0001-Add-the-Cargo.lock-the-source-archive-ships-without.patch"), "500af3482299bad66a6af45e3d8736a6f79187fe9569382a32fbc7eba6ba832b")
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path.", default = "2", readonly = true})

    on_install(function (package)
        local envs = package:dep("rust"):envs() or {}
        local bin = table.wrap(envs.REVENANT_RUST_BIN)[1] or raise("revenant@rust names no toolchain folder; reinstall it")
        local cargo_home = table.wrap(envs.REVENANT_RUST_CARGO_HOME)[1] or raise("revenant@rust names no cargo home; reinstall it")
        local spec = import("@addon.revenant.rust", {anonymous = true}).spec()
        os.vrunv(path.join(bin, "cargo"), {"rustc", "-p", "ratex-ffi", "--lib", "--crate-type", "staticlib", "--release", "--locked",
                                           "--config", "profile.release.lto=false", "--target", spec,
                                           "--target-dir", path.join(os.curdir(), "target"),
                                           "-Zbuild-std=core,alloc,std,panic_abort", "-Zjson-target-spec",
                                           "-j", tostring(os.default_njob())},
                 {envs = {PATH = bin .. path.envsep() .. os.getenv("PATH"), CARGO_HOME = cargo_home, RUSTFLAGS = "-Cembed-bitcode=no"}})
        local built = path.join("target", "armv7-apple-ios6", "release", "libratex_ffi.a")
        assert(os.isfile(built), "the build produced no libratex_ffi.a")
        os.mkdir(package:installdir("lib"))
        os.mkdir(package:installdir("include"))
        os.mkdir(package:installdir("licenses"))
        os.cp(built, package:installdir("lib"))
        os.cp(path.join("crates", "ratex-ffi", "include", "ratex.h"), package:installdir("include"))
        io.writefile(path.join(package:installdir("include"), "module.modulemap"), "module RaTeXFFI {\n    header \"ratex.h\"\n    export *\n}\n")
        os.cp("LICENSE", package:installdir("licenses"))
        local swift = path.join("platforms", "ios", "Sources", "Ratex")
        os.mkdir(package:installdir("swift"))
        for _, name in ipairs({"DisplayList.swift", "RaTeXEngine.swift", "RaTeXFontLoader.swift", "RaTeXRenderer.swift"}) do
            os.cp(path.join(swift, name), package:installdir("swift"))
        end
        os.mkdir(package:installdir("fonts"))
        for _, file in ipairs(os.files(path.join(swift, "Fonts", "*.ttf"))) do
            os.cp(file, package:installdir("fonts"))
        end
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libratex_ffi.a")), "libratex_ffi.a is not installed")
        assert(os.isfile(path.join(package:installdir("include"), "ratex.h")), "ratex.h is not installed")
    end)
