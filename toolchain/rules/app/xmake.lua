rule("app")
    add_deps("@self/apple-ios")

    on_load(function (target)
        target:set("kind", "binary")
        target:add("packages", "ldid", "firmware-tools")
    end)

    before_link(function (target)
        local package = target:pkg("backports")
        if not package then
            return
        end
        local links = {}
        for _, group in ipairs(target:get_from("links", "*") or {}) do
            table.join2(links, group)
        end
        local backports = import("@self.apple.backports")
        for _, order in ipairs(backports.link_orders(table.wrap(package:get("links")), links)) do
            target:add("linkorders", order)
        end
    end)

    after_link(function (target)
        import("@self.apple.platform")
        platform.verify_packages(target)
        platform.verify_inputs(target)
        platform.verify(target, target:targetfile(), {imports = false})
    end)

    after_build(function (target)
        import("@self.apple.platform")
        target:data_set("revenant.bundle", platform.application(target))
    end)

    on_install(function (target)
        import("@self.apple.platform")
        local built = path.join(target:targetdir(), target:basename() .. ".app")
        if not os.isdir(built) then
            built = platform.application(target)
        end
        local folder = path.join(target:installdir(), target:values("revenant.install") or "/Applications")
        os.mkdir(folder)
        os.vcp(built, folder .. "/")
        platform.install_files(target)
    end)
