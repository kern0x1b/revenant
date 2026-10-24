option("swiftui_snapshot_only", {default = "", showmenu = true,
                                 description = "Have the snapshot bundle render only the scenario of this name."})
option("swiftui_perf", {default = false, showmenu = true,
                        description = "Have the demo application run its timing scenarios after launch and quit."})

local component = get_config("component")
if component ~= "" and component ~= "SwiftUI" and component ~= "SwiftUIDemo" then
    return
end

if is_plat("iphoneos") then
    if component == "SwiftUI" or component == "SwiftUIDemo" then
        add_requires("revenant@swift-runtime", {alias = "swift-runtime"})
        add_requires("revenant@libcxx", {alias = "libcxx"})
        add_requires("revenant@combine", {alias = "combine"})
    end

    local function weak_import_waiver()
        add_values("revenant.waive.weak-imports",
                   "every weak import is reached only behind #available or carried by the backports: the runtime's overlays built with availability checking on, Combine's run-loop timer tolerance, compiler-rt's version check")
    end

    local function demo_application(identifier, name, ...)
        add_rules("@addon/revenant/app", "@addon/revenant/swift")
        add_deps("SwiftUI")
        add_packages("combine")
        add_files("examples/showcase/*.swift")
        add_files("examples/showcase/device/gesture.m")
        add_includedirs("examples/showcase/device")
        add_deps("UIKitBackports", "CoreDataBackports")
        add_frameworks("UIKit", "Foundation", "CoreGraphics", "QuartzCore", "CoreData")
        set_values("swift.flags", "-import-objc-header", path.join(os.scriptdir(), "examples", "showcase", "device", "bridge.h"))
        set_optimize("fastest")
        set_values("app.plist-file", "examples/showcase/Info.plist")
        set_values("app.plist", "CFBundleIdentifier=" .. identifier, "CFBundleDisplayName=" .. name, ...)
        set_values("revenant.control", "examples/showcase/control")
        set_values("revenant.version", "1.0.0")
        weak_import_waiver()
    end

    local function probe_daemon(control, ...)
        add_rules("@addon/revenant/daemon", "@addon/revenant/swift")
        add_deps("SwiftUI")
        add_files(...)
        add_deps("UIKitBackports", "CoreDataBackports")
        add_frameworks("UIKit", "Foundation", "CoreGraphics", "QuartzCore", "CoreData")
        set_optimize("fastest")
        set_values("revenant.control", control)
        weak_import_waiver()
    end

    target("SwiftUI")
        set_kind("static")
        add_rules("@addon/revenant/swift")
        add_packages("combine", {public = true})
        set_optimize("fastest")
        add_files("src/*.swift")
        add_values("swift.flags", "-enforce-exclusivity=unchecked", "-suppress-warnings")
        add_frameworks("UIKit", "QuartzCore", "CoreGraphics", "CoreData", "Foundation", "CoreFoundation")
        before_build(function (target)
            os.vrunv(os.programfile(), {"l", path.join(target:scriptdir(), "tools", "coverage.lua"), "--check", "--before-build"})
        end)

    if component == "SwiftUI" then
        return
    end

    target("SwiftUIDemo")
        demo_application("space.kern0x1b.swiftui.demo", "SwiftUI")
        if has_config("swiftui_perf") then
            add_values("app.plist", "SwiftUIPerf=YES")
        end

    target("SwiftUISnapshots")
        demo_application("space.kern0x1b.swiftui.snapshots", "SwiftUISnapshots", "SwiftUISnapshots=YES", "SwiftUISnapshotImages=YES")
        local only = get_config("swiftui_snapshot_only")
        if only and only ~= "" then
            add_values("app.plist", "SwiftUISnapshotOnly=" .. only)
        end

    if component == "SwiftUIDemo" then
        return
    end

    target("SwiftUITests")
        probe_daemon("tests/control", "tests/main.swift")
        set_values("swift.flags", "-disable-availability-checking")

    target("SwiftUIProbe")
        set_default(false)
        probe_daemon("tests/probe/control", "tests/probe/main.swift")

    target("SwiftUITypeChecks")
        set_kind("phony")
        set_default(false)
        add_deps("SwiftUI")
        add_tests("tables-positive", {source = "tests/typechecks/tables/positive.swift"})
        add_tests("tables-negative", {source = "tests/typechecks/tables/negative.swift", rejected = "conform to 'TableRowContent'"})
        add_tests("tables-negative-widget-bundle", {source = "tests/typechecks/tables/negative-widget-bundle.swift",
                                                    rejected = "could not be inferred", swiftflags = {"-disable-availability-checking"}})
        add_tests("tables-negative-widget-concrete", {source = "tests/typechecks/tables/negative-widget-concrete.swift",
                                                      rejected = "could not be inferred", swiftflags = {"-disable-availability-checking"}})
        add_tests("tabs-positive", {source = "tests/typechecks/tabs/positive.swift"})
        add_tests("tabs-negative", {source = "tests/typechecks/tabs/negative.swift", rejected = "conform to specified type 'TabContent'"})
        on_test(function (target, opt)
            local swift = import("@addon.revenant.apple.swift")
            local module = target:dep("SwiftUI")
            local toolchain = module:toolchain("apple-ios")
            toolchain:load()
            local runtime = assert(module:pkg("swift-runtime"), "SwiftUI is compiled against revenant@swift-runtime")
            local swiftc = assert(table.wrap((runtime:envs() or {}).SWIFT_EXEC)[1], "swift-runtime names no compiler; reinstall it")
            local modules = {"-I", module:data("swift.moduledir")}
            for _, dependency in ipairs(module:orderpkgs()) do
                for _, folder in ipairs(table.wrap((dependency:envs() or {}).REVENANT_SWIFT_MODULES)) do
                    table.join2(modules, {"-I", folder})
                end
            end
            for _, dependency in ipairs(module:orderdeps()) do
                if dependency:data("swift.moduledir") then
                    table.join2(modules, {"-I", dependency:data("swift.moduledir")})
                end
                for _, folder in ipairs(table.wrap(dependency:get("includedirs", {interface = true}))) do
                    table.join2(modules, {"-I", folder})
                end
            end
            local argv = table.join(swift.runtime_flags({
                architecture = module:arch(), deployment = toolchain:config("deployment"), sdk = toolchain:config("sdkdir"),
                resources = path.join(runtime:installdir(), "lib", "swift"),
                plugins = table.wrap((runtime:envs() or {}).SWIFT_PLUGIN_PATH)[1], module = "TypeChecks"}),
                modules, table.wrap(module:values("swift.flags")), table.wrap(opt.swiftflags),
                {"-module-cache-path", path.join(target:autogendir(), "mc"), "-typecheck", path.join(target:scriptdir(), opt.source)})
            local log = path.join(target:autogendir(), opt.name .. ".log")
            os.mkdir(path.directory(log))
            local file = io.open(log, "w")
            local status = os.execv(swiftc, argv, {stdout = file, stderr = file, try = true})
            file:close()
            local output = io.readfile(log)
            local first = output:match("[^\n]*error:[^\n]*")
            if not opt.rejected then
                if status == 0 and output == "" then
                    return true
                end
                print("%s: it should compile, and %s", opt.name, first or ("the compiler exited " .. status .. " without saying why"))
                return false
            end
            if status ~= 0 and first and first:find(opt.rejected, 1, true) then
                return true
            end
            print("%s: a rejection naming %s was expected, and %s", opt.name, opt.rejected, first or (status == 0 and "it compiled" or "the compiler said nothing"))
            return false
        end)
end
