package("tipkit")
    set_homepage("https://github.com/kern0x1b/charon")
    set_description("The TipKit framework of iOS 17, as one Swift module a port writes `import TipKit` for, built against the charon@swift-runtime a port carries: the tips, the rules that decide which one is shown, the events the app donates, the datastore, and the popover the tip is drawn in. The rules, the display count, the donations and the datastore are the app's own and are real; the presentation is the system's own service, which these releases do not run, so the tip is drawn in the app by the TipUI views this module declares. facts/TipKit/Rendering.md")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    local digests = {}
    local inputs = table.join({path.join(os.scriptdir(), "xmake.lua")}, os.files(path.join(os.scriptdir(), "Sources", "TipKit", "**.swift")))
    table.sort(inputs)
    for _, file in ipairs(inputs) do
        table.insert(digests, path.relative(file, os.scriptdir()) .. "=" .. hash.sha256(file))
    end
    add_configs("sources", {description = "The digest of this recipe and the module's sources, so a changed declaration is a different package.", default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    add_configs("shared", {description = "Compile against a shared swift-runtime and its packaged libc++, for a port that requires them so.", default = false, type = "boolean"})
    add_configs("backports", {description = "Compile against the swift-runtime built with the backports, for a port that requires it so.", default = false, type = "boolean"})
    add_configs("backports_uikit", {description = "With backports: the runtime whose UIKit overlay is linked to the UIKit backports, for an application.", default = false, type = "boolean"})

    on_load("iphoneos", function (package)
        package:add("deps", "charon@swift-runtime", {alias = "swift-runtime", configs = {shared = package:config("shared") or nil,
                    backports = package:config("backports") or nil, backports_uikit = package:config("backports_uikit") or nil}})
        -- the module's own API is written in terms of Foundation's LocalizedStringResource; where the
        -- runtime's Foundation predates that type, the AppIntents package carries it, and this one
        -- takes it from there (see the recipe's probe)
        package:add("deps", "charon@appintents", {alias = "appintents", configs = {shared = package:config("shared") or nil,
                    backports = package:config("backports") or nil, backports_uikit = package:config("backports_uikit") or nil}})
        package:add("links", "TipKit")
        package:add("frameworks", "Foundation", "CoreFoundation")
    end)

    on_install("iphoneos", function (package)
        local modules = path.join(os.scriptdir(), "..", "..", "..", "modules")
        local swift = import("apple.swift", {rootdir = modules, anonymous = true})
        local toolchain = assert(package:toolchains(), "TipKit is built with the apple-ios toolchain")[1]
        toolchain:load()
        local runtime = assert(package:dep("swift-runtime"), "TipKit is compiled against charon@swift-runtime")
        local swiftc = assert(table.wrap((runtime:envs() or {}).SWIFT_EXEC)[1], "swift-runtime names no compiler; reinstall it")
        local minimum = toolchain:config("deployment")
        local triple = package:arch() .. "-apple-ios" .. minimum
        local sdk = toolchain:config("sdkdir")
        local swiftdir = path.join(package:installdir("lib"), "swift", "iphoneos")
        local objects = path.absolute("objects")
        local probe_dir = path.absolute("probe")
        os.mkdir(objects)
        os.mkdir(swiftdir)
        os.mkdir(probe_dir)

        -- Whether this runtime's Foundation has `LocalizedStringResource`, measured: where it has not,
        -- the AppIntents package carries the type and this module takes it from there, and the block of
        -- TipKit that is written in terms of it is compiled in. The probe is the same one
        -- AppIntents runs, and the flag is the same name.
        local platform_resource = path.join(probe_dir, "localized.swift")
        io.writefile(platform_resource, "import Foundation\npublic func probe() -> LocalizedStringResource { return LocalizedStringResource(\"\") }")
        local has = try {function ()
            os.vrunv(swiftc, table.join(swift.runtime_flags({
                architecture = package:arch(), deployment = minimum, sdk = sdk,
                resources = path.join(runtime:installdir(), "lib", "swift"),
                plugins = table.wrap((runtime:envs() or {}).SWIFT_PLUGIN_PATH)[1],
                module = "CharonTipKitProbe", optimize = "none", prefix_map = os.curdir() .. "=/tipkit"}),
                {"-I", path.join(runtime:installdir(), "lib", "swift", "iphoneos"), "-typecheck", platform_resource}))
            return true
        end}
        os.tryrm(platform_resource)
        local defs, module_paths = {}, {}
        if has then
            table.insert(defs, "-DCHARON_PLATFORM_LOCALIZED_STRING")
            print("%s: this runtime's Foundation has LocalizedStringResource, the module uses the platform's", package:name())
        else
            local appintents = package:dep("appintents")
            table.insert(defs, "-DCHARON_CARRIES_LOCALIZED_STRING")
            table.insert(module_paths, "-I")
            table.insert(module_paths, path.join(appintents:installdir("lib"), "swift", "iphoneos"))
            print("%s: this runtime's Foundation has no LocalizedStringResource, the module takes the one charon@appintents carries",
                  package:name())
        end

        -- One module, as Styx's Combine is one module and AppIntents is one: the whole framework in a
        -- single compile, so a declaration of one file sees every other.
        local module = path.join(swiftdir, "TipKit.swiftmodule")
        os.mkdir(module)
        -- Absolute, and refused when it matches nothing: `modules/apple/sources.lua` is where the
        -- C-family sources go and it raises "compiles %s, which matches no file" for a pattern
        -- that matches none, and the Swift side had neither -- a relative glob resolved against
        -- the *compiler's* working directory, which is how charon@appintents' install failed with
        -- "error opening input file 'Sources/AppIntents/LocalizedStringResource.swift'"
        -- (kits r2), and a glob that matched nothing compiles an empty module and calls it a
        -- pass (kits r3).
        local sources_tipkit = os.files(path.join(package:scriptdir(), "Sources", "TipKit", "**.swift"))
        if #sources_tipkit == 0 then
            raise("%s compiles Sources/TipKit/**.swift, which matches no file", package:name())
        end

        local argv = table.join(swift.runtime_flags({
            architecture = package:arch(), deployment = minimum, sdk = sdk,
            resources = path.join(runtime:installdir(), "lib", "swift"),
            plugins = table.wrap((runtime:envs() or {}).SWIFT_PLUGIN_PATH)[1],
            module = "TipKit", optimize = "fastest", prefix_map = os.curdir() .. "=/tipkit"}),
            defs, module_paths, {"-I", swiftdir, "-emit-module", "-emit-module-path",
             path.join(module, package:arch() .. "-apple-ios.swiftmodule"), "-c"},
            sources_tipkit, {"-o", path.join(objects, "TipKit.o")})
        os.vrunv(swiftc, argv)
        os.vrunv(toolchain:tool("ar"), {"-rcs", path.join(package:installdir("lib"), "libTipKit.a"),
                 path.join(objects, "TipKit.o")})

        os.tryrm(probe_dir)
        package:setenv("CHARON_SWIFT_MODULES", swiftdir)
        os.cp(path.join(os.scriptdir(), "..", "..", "..", "LICENSE"), path.join(package:installdir("licenses")))
        os.cp("README.md", path.join(package:installdir("share")))
    end)
