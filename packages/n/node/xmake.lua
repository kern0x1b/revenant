package("node")
    set_kind("binary")
    set_homepage("https://nodejs.org")
    set_description("Node.js 26.13.0, the JavaScript runtime the build runs its JavaScript tools with, as the node binary of the official darwin-arm64 release")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    add_urls("https://nodejs.org/dist/v$(version)/node-v$(version)-darwin-arm64.tar.gz")
    add_versions("26.13.0", "d38bd5e5a2ddce6bbb5ce45e46e208337da4d51fffe611e567fd32073d6439f6")

    on_install("@macosx|arm64", function (package)
        local root = os.isfile(path.join("bin", "node")) and "." or os.dirs("node-v*-darwin-arm64")[1]
        os.cp(path.join(root, "bin", "node"), package:installdir("bin"))
        os.cp(path.join(root, "LICENSE"), package:installdir("licenses"))
    end)

    on_test(function (package)
        local version = os.iorunv(path.join(package:installdir("bin"), "node"), {"-p", "process.versions.node"}):trim()
        assert(version == package:version_str(), "node reports " .. version .. ", not " .. package:version_str())
    end)
