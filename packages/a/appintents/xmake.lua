package("appintents")
    set_homepage("https://github.com/kern0x1b/revenant/tree/main/toolchain")
    set_description("The AppIntents framework of iOS 16, as one Swift module a port writes `import AppIntents` for, built against the revenant@swift-runtime a port carries. The API, the protocols, the parameters, the entities, the queries, the results and in-process `perform` are the port's own; what the framework leaves to a system service - Siri, Shortcuts, Spotlight, a widget, a live activity - is the seam this README and facts/AppIntents say it is, and the API surface for it exists either way")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    local digests = {}
    local inputs = table.join({path.join(os.scriptdir(), "xmake.lua")}, os.files(path.join(os.scriptdir(), "..", "..", "..", "frameworks", "Backports", "src", "AppIntents", "**.swift")))
    table.sort(inputs)
    for _, file in ipairs(inputs) do
        table.insert(digests, path.relative(file, os.scriptdir()) .. "=" .. hash.sha256(file))
    end
    add_configs("sources", {description = "The digest of this recipe and the module's sources, so a changed declaration is a different package.", default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    add_configs("shared", {description = "Compile against a shared swift-runtime and its packaged libc++, for a port that requires them so.", default = false, type = "boolean"})
    add_configs("backports", {description = "Compile against the swift-runtime built with the backports, for a port that requires it so.", default = false, type = "boolean"})
    add_configs("backports_uikit", {description = "With backports: the runtime whose UIKit overlay is linked to the UIKit backports, for an application.", default = false, type = "boolean"})

    on_load("iphoneos", function (package)
        package:add("deps", "revenant@swift-runtime", {alias = "swift-runtime", configs = {shared = package:config("shared") or nil,
                    backports = package:config("backports") or nil, backports_uikit = package:config("backports_uikit") or nil}})
        package:add("links", "AppIntents")
        package:add("frameworks", "Foundation", "CoreFoundation")
    end)

    on_install("iphoneos", function (package)
        local swift = import("@addon.revenant.apple.swift", {anonymous = true})
        local toolchain = assert(package:toolchains(), "AppIntents is built with the apple-ios toolchain")[1]
        toolchain:load()
        local runtime = assert(package:dep("swift-runtime"), "AppIntents is compiled against revenant@swift-runtime")
        local swiftc = assert(table.wrap((runtime:envs() or {}).SWIFT_EXEC)[1], "swift-runtime names no compiler; reinstall it")
        local minimum = toolchain:config("deployment")
        local sdk = toolchain:config("sdkdir")
        local swiftdir = path.join(package:installdir("lib"), "swift", "iphoneos")
        local objects = path.absolute("objects")
        local probe_dir = path.absolute("probe")
        os.mkdir(objects)
        os.mkdir(swiftdir)
        os.mkdir(probe_dir)

        local overlays, defs = {}, {}
        local port_headers = table.wrap((runtime:envs() or {}).REVENANT_SWIFT_PORT_HEADERS)[1]
        if port_headers then
            table.insert(overlays, port_headers)
            table.insert(defs, "-DREVENANT_APPINTENTS_PORT_HEADERS")
        end
        local overlay_flags = {}
        for _, overlay in ipairs(overlays) do
            table.insert(overlay_flags, "-Xcc")
            table.insert(overlay_flags, "-ivfsoverlay")
            table.insert(overlay_flags, "-Xcc")
            table.insert(overlay_flags, overlay)
        end

        local sources, carries = {}, false
        for _, file in ipairs(os.files(path.join(package:scriptdir(), "..", "..", "..", "frameworks", "Backports", "src", "AppIntents", "**.swift"))) do
            if path.filename(file) ~= "LocalizedStringResource.swift" then
                table.insert(sources, file)
            end
        end
        local platform_resource = path.join(probe_dir, "localized.swift")
        io.writefile(platform_resource, "import Foundation\npublic func probe() -> LocalizedStringResource { return LocalizedStringResource(\"\") }")
        local has = try {function ()
            os.vrunv(swiftc, table.join(swift.runtime_flags({
                architecture = package:arch(), deployment = minimum, sdk = sdk,
                resources = path.join(runtime:installdir(), "lib", "swift"),
                plugins = table.wrap((runtime:envs() or {}).SWIFT_PLUGIN_PATH)[1],
                module = "RevenantAppIntentsProbe", optimize = "none", prefix_map = os.curdir() .. "=/appintents"}),
                {"-I", path.join(runtime:installdir(), "lib", "swift", "iphoneos"), "-typecheck", platform_resource}))
            return true
        end}
        os.tryrm(platform_resource)
        if has then
            carries = true
            table.insert(defs, "-DREVENANT_APPINTENTS_CARRIES_LOCALIZED_STRING")
            print("%s: this runtime's Foundation has LocalizedStringResource, the module uses the platform's and carries none",
                  package:name())
        else
            table.insert(sources, path.join(package:scriptdir(), "..", "..", "..", "frameworks", "Backports", "src", "AppIntents", "LocalizedStringResource.swift"))
            print("%s: this runtime's Foundation has no LocalizedStringResource, the module carries it (AppIntents' whole API is written in it)",
                  package:name())
        end

        local probes = {
            {flag = "REVENANT_APPINTENTS_ATTRIBUTED_STRING", name = "AttributedString",
             body = "import Foundation\npublic func probe() -> AttributedString { return AttributedString(\"x\") }"},
            {flag = "REVENANT_APPINTENTS_MEASUREMENT", name = "Measurement",
             body = "import Foundation\npublic func probe() -> Measurement { return Measurement(value: 1, unit: UnitLength.meters) }"},
            {flag = "REVENANT_APPINTENTS_RECURRENCE_RULE", name = "Calendar.RecurrenceRule",
             body = "import Foundation\npublic func probe() -> Calendar.RecurrenceRule { return Calendar.RecurrenceRule(weekOfMonth: 1, weekOfYear: 2, month: 3, dayOfWeek: 4) }"}}
        for _, probe in ipairs(probes) do
            local source = path.join(probe_dir, "probe.swift")
            io.writefile(source, probe.body)
            local ok = try {function ()
                os.vrunv(swiftc, table.join(swift.runtime_flags({
                    architecture = package:arch(), deployment = minimum, sdk = sdk,
                    resources = path.join(runtime:installdir(), "lib", "swift"),
                    plugins = table.wrap((runtime:envs() or {}).SWIFT_PLUGIN_PATH)[1],
                    module = "RevenantAppIntentsProbe", optimize = "none", prefix_map = os.curdir() .. "=/appintents"}),
                    {"-I", path.join(runtime:installdir(), "lib", "swift", "iphoneos"), "-typecheck", source}))
                return true
            end}
            os.tryrm(source)
            if ok then
                table.insert(defs, "-D" .. probe.flag)
                print("%s: the runtime has %s, its conformance is in the module", package:name(), probe.name)
            else
                print("%s: the runtime has no %s at this release, its rows are left out of the module",
                      package:name(), probe.name)
            end
        end

        local spotlight_source = path.join(probe_dir, "spotlight.swift")
        io.writefile(spotlight_source, "import CoreSpotlight\npublic func probe() -> CSSearchableItem {\n"
            .. "    return CSSearchableItem(uniqueIdentifier: \"x\", domainIdentifier: nil, attributeSet: CSSearchableItemAttributeSet(contentType: \"public.item\"))\n}\n"
            .. "public func probeIndex() -> CSSearchableIndex { return CSSearchableIndex.default() }\n")
        local spotlight = try {function ()
            os.vrunv(swiftc, table.join(swift.runtime_flags({
                architecture = package:arch(), deployment = minimum, sdk = sdk,
                resources = path.join(runtime:installdir(), "lib", "swift"),
                plugins = table.wrap((runtime:envs() or {}).SWIFT_PLUGIN_PATH)[1],
                module = "RevenantAppIntentsProbe", optimize = "none", prefix_map = os.curdir() .. "=/appintents"}),
                overlay_flags, {"-I", path.join(runtime:installdir(), "lib", "swift", "iphoneos"), "-typecheck", spotlight_source}))
            return true
        end}
        os.tryrm(spotlight_source)
        if spotlight then
            table.insert(defs, "-DREVENANT_APPINTENTS_CORESPOTLIGHT")
            print("%s: CoreSpotlight's classes are available at %s, their AppIntents extensions are in the module", package:name(), minimum)
        else
            print("%s: CoreSpotlight has no CSSearchableItem at %s, its AppIntents rows are left out of the module", package:name(), minimum)
        end

        local module = path.join(swiftdir, "AppIntents.swiftmodule")
        os.mkdir(module)
        local argv = table.join(swift.runtime_flags({
            architecture = package:arch(), deployment = minimum, sdk = sdk,
            resources = path.join(runtime:installdir(), "lib", "swift"),
            plugins = table.wrap((runtime:envs() or {}).SWIFT_PLUGIN_PATH)[1],
            module = "AppIntents", optimize = "fastest", prefix_map = os.curdir() .. "=/appintents"}),
            defs, overlay_flags, {"-I", swiftdir, "-emit-module", "-emit-module-path",
             path.join(module, package:arch() .. "-apple-ios.swiftmodule"), "-c"},
            sources, {"-o", path.join(objects, "AppIntents.o")})
        os.vrunv(swiftc, argv)
        os.vrunv(toolchain:tool("ar"), {"-rcs", path.join(package:installdir("lib"), "libAppIntents.a"), path.join(objects, "AppIntents.o")})

        os.tryrm(probe_dir)
        package:setenv("REVENANT_SWIFT_MODULES", swiftdir)
        os.cp(import("@addon.revenant.data", {anonymous = true}).licence(), path.join(package:installdir("licenses")))
        os.cp(path.join(package:scriptdir(), "..", "..", "..", "docs", "reference", "backports", "AppIntents", "README.md"), package:installdir("share"))
    end)
