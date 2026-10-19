package("swift-bootstrap")
    set_kind("toolchain")
    set_homepage("https://www.swift.org")
    set_description("The swift.org compiler of a release, cut to what it takes to build the same release from source: the driver, the frontend and their host libraries")
    set_license("Apache-2.0 WITH Swift-exception")

    add_urls("https://download.swift.org/swift-$(version)-release/xcode/swift-$(version)-RELEASE/swift-$(version)-RELEASE-osx.pkg")
    add_versions("6.4.0", "8fd03185b98fe27f54a54631c2449decf75d5b466ce8e34abbd414141063c6aa")

    add_configs("recipe", {description = "The digest of this recipe, which decides what is kept from the toolchain, so a changed recipe is a different package.",
                           default = hash.strhash128("xmake.lua=" .. hash.sha256(path.join(os.scriptdir(), "xmake.lua"))), type = "string", readonly = true})

    local kept = {
        "usr/bin/swift-frontend", "usr/bin/swift-driver", "usr/bin/swift-package", "usr/lib/swift/host", "usr/lib/swift/shims",
        "usr/lib/swift/apinotes", "usr/lib/swift/module.modulemap", "usr/lib/swift/pm", "usr/lib/swift/macosx", "usr/lib/clang",
        -- The package manager of this release builds through SwiftBuild, which reads its own resource bundles from share/pm.
        "usr/share/pm"
    }

    on_download(function (package, opt)
        import("net.http")
        local staging = opt.sourcedir .. ".tmp"
        os.tryrm(staging)
        os.mkdir(staging)

        local archive = path.join(staging, "toolchain.pkg")
        http.download(opt.url, archive)
        local digest = hash.sha256(archive)
        if digest ~= package:sourcehash(opt.url_alias) then
            raise("%s has sha256 %s, not the %s this package was written against", opt.url, digest, tostring(package:sourcehash(opt.url_alias)))
        end
        local expanded = path.join(staging, "expanded")
        os.vrunv("pkgutil", {"--expand-full", archive, expanded})
        local payload = os.dirs(path.join(expanded, "*.pkg", "Payload"))[1]
        if not payload then
            raise("%s holds no package payload", opt.url)
        end
        local toolchain = path.join(staging, "toolchain")
        for _, item in ipairs(kept) do
            local from = path.join(payload, item)
            if not os.exists(from) then
                raise("the swift.org %s toolchain has no %s", package:version_str(), item)
            end
            os.mkdir(path.directory(path.join(toolchain, item)))
            os.vcp(from, path.join(toolchain, item), {symlink = true})
        end
        os.ln("swift-driver", path.join(toolchain, "usr", "bin", "swiftc"))
        -- swift-package is the Swift package manager under every name it answers to; the driver of the release is built with it.
        os.ln("swift-package", path.join(toolchain, "usr", "bin", "swift-build"))
        local clang = path.filename(assert(os.dirs(path.join(toolchain, "usr", "lib", "clang", "*"))[1], "the toolchain has no clang resource folder"))
        os.ln(path.join("..", "clang", clang), path.join(toolchain, "usr", "lib", "swift", "clang"))
        os.tryrm(archive)
        os.tryrm(expanded)

        os.tryrm(opt.sourcedir)
        os.mv(staging, opt.sourcedir)
    end)

    on_install("@macosx", function (package)
        -- A download that holds one directory is entered by the build, so the toolchain is either here or below.
        local base = os.isdir(path.join("toolchain", "usr")) and "toolchain" or "."
        os.vcp(path.join(base, "usr", "*"), package:installdir() .. "/", {symlink = true})
        assert(os.isfile(path.join(package:installdir("bin"), "swift-frontend")),
               "the swift.org toolchain was not laid down: " .. os.curdir())
    end)

    on_test(function (package)
        local version = os.iorunv(path.join(package:installdir("bin"), "swiftc"), {"--version"})
        local release = "swift-" .. package:version():major() .. "." .. package:version():minor() .. "-RELEASE"
        assert(version:find(release, 1, true), "swiftc of the swift-bootstrap package reports " .. version)
    end)
