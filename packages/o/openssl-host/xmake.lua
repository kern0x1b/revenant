package("openssl-host")
    set_homepage("https://www.openssl.org")
    set_description("OpenSSL for the host, the copy the ldid signing tool links: under its own name, because a project holds one openssl and the armv7 engine needs its own")
    set_license("Apache-2.0")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/openssl/openssl.git")
    add_versions("4.0.2", "f089acdf4bc7ba94a79f4bf6eb7362c3e7d14aa9")
    add_patches("4.0.2", path.join(os.scriptdir(), "..", "openssl", "patches", "arm-xlate-ios32-hidden-extern-data.patch"))
    add_links("ssl", "crypto")

    local targets = {arm64 = "darwin64-arm64-cc", x86_64 = "darwin64-x86_64-cc"}

    on_install("macosx", function (package)
        local target = targets[package:arch()]
        if not target then
            raise("OpenSSL has no macosx Configure target for %s", package:arch())
        end
        local options = {target, "CC=cc", "no-shared", "no-dso", "no-tests", "no-docs", "no-apps", "no-ui-console",
                         "no-engine", "no-async"}
        local envs = {SOURCE_DATE_EPOCH = os.iorunv("git", {"log", "-1", "--format=%ct"}):trim()}
        os.vrunv("./Configure", options, {envs = envs})
        import("@addon.revenant.parallel", {anonymous = true}).hold(nil, function (width)
            os.vrunv("make", {"-j" .. width, "build_libs"}, {envs = envs})
        end)
        os.cp("libcrypto.a", package:installdir("lib"))
        os.cp("libssl.a", package:installdir("lib"))
        os.cp("include/openssl", package:installdir("include"))
        os.cp("LICENSE.txt", package:installdir("licenses"))
    end)

    on_test(function (package)
        assert(package:has_cfuncs("OPENSSL_version_major", {includes = "openssl/crypto.h"}))
    end)
