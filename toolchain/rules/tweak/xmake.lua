rule("tweak")
    add_deps("@self/apple-ios")

    on_load(function (target)
        target:set("kind", "shared")
        target:set("prefixname", "")
        target:set("extension", ".dylib")
        target:add("packages", "ldid", "firmware-tools")
        local installed = target:values("charon.install") or "/Library/MobileSubstrate/DynamicLibraries"
        target:data_set("charon.install", installed)
        target:add("shflags", "-install_name", installed .. "/" .. target:filename(), {force = true})
    end)

    after_link(function (target)
        import("@self.apple.platform")
        platform.verify_packages(target)
        platform.verify_inputs(target)
        platform.verify_placed(target, target:data("charon.install") .. "/" .. target:filename())
    end)

    on_install(function (target)
        import("@self.apple.platform")
        local folder = path.join(target:installdir(), target:data("charon.install"))
        platform.install_placed(target, target:data("charon.install") .. "/" .. target:filename())
        local filter = target:values("tweak.filter")
        if filter then
            os.vcp(path.join(target:scriptdir(), filter), path.join(folder, target:basename() .. ".plist"))
        end
        platform.install_files(target)
    end)
