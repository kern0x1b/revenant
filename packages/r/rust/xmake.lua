package("rust")
    set_kind("binary")
    set_homepage("https://www.rust-lang.org")
    set_description("The Rust toolchain that builds armv7 iOS 6 staticlibs: a pinned nightly with rust-src for -Zbuild-std, installed for the host by rustup, whose own installer is pinned by version and checksum")
    set_license("Apache-2.0 OR MIT")

    add_configs("channel", {description = "The pinned nightly channel. Its date names the compiler; build-std needs its rust-src component.", default = "nightly-2026-10-22", type = "string", readonly = true})

    if is_host("macosx") then
        if os.arch() == "arm64" then
            add_urls("https://static.rust-lang.org/rustup/archive/1.29.2/aarch64-apple-darwin/rustup-init")
            add_versions("nightly-2026-10-22", "f7c7e11eb2e07f006e532a8aaac77b32f4527d305ac386c0c633ca6133d35ca9")
        else
            add_urls("https://static.rust-lang.org/rustup/archive/1.29.2/x86_64-apple-darwin/rustup-init")
            add_versions("nightly-2026-10-22", "b9610730ddeef52765723847866fd1e3540b2bf7d5ab0c324aa143a5edf25ba0")
        end
    end

    on_install("@macosx", function (package)
        local host = os.arch() == "arm64" and "aarch64-apple-darwin" or "x86_64-apple-darwin"
        local downloaded = path.join(package:cachedir(), package:name() .. "-" .. package:version_str())
        local installer = path.join(package:installdir("bin"), "rustup-init")
        os.cp(downloaded, installer)
        os.runv("chmod", {"755", installer})
        local envs = {RUSTUP_HOME = package:installdir("rustup"), CARGO_HOME = package:installdir("cargo")}
        os.vrunv(installer, {"-y", "--no-modify-path", "--profile", "minimal", "-c", "rust-src", "--default-toolchain", package:config("channel")},
                 {envs = envs})
        package:setenv("REVENANT_RUST_BIN", path.join(package:installdir("rustup"), "toolchains", package:config("channel") .. "-" .. host, "bin"))
        package:setenv("REVENANT_RUST_CARGO_HOME", package:installdir("cargo"))
    end)

    on_test(function (package)
        local host = os.arch() == "arm64" and "aarch64-apple-darwin" or "x86_64-apple-darwin"
        local bin = path.join(package:installdir("rustup"), "toolchains", package:config("channel") .. "-" .. host, "bin")
        os.vrunv(path.join(bin, "cargo"), {"--version"})
        local spec = path.join(package:scriptdir(), "..", "..", "..", "toolchain", "src", "rust", "armv7-apple-ios6.json")
        local cfg = os.iorunv(path.join(bin, "rustc"), {"-Zunstable-options", "--print", "cfg", "--target", spec})
        assert(cfg:find('target_os="ios"', 1, true) and cfg:find('target_arch="arm"', 1, true), "the armv7 iOS 6 spec does not load under the pinned nightly")
    end)
