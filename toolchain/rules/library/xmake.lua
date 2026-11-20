rule("library")
    add_deps("@self/apple-ios")

    on_load(function (target)
        target:set("kind", "shared")
        target:add("shflags", "-Wl,-headerpad_max_install_names", {force = true})
    end)

    after_link(function (target)
        import("@self.apple.platform")
        platform.verify_packages(target)
        platform.verify_inputs(target)
        platform.verify(target, target:targetfile(), {imports = false})
    end)

    on_install(function (target)
    end)
