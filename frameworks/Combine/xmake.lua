local component = get_config("component")
if component ~= "" and component ~= "Combine" then
    return
end

if is_plat("iphoneos") then
    if component == "Combine" then
        add_requires("revenant@swift-runtime", {alias = "swift-runtime"})
        add_requires("revenant@libcxx", {alias = "libcxx"})
    end
    add_requires("revenant@combine", {alias = "combine", configs = {shared = component == "" or nil}})

    local function sources(target, ...)
        return path.join(target:pkg("combine"):installdir(), "src", ...)
    end

    target("CombineXCTest")
        set_kind("static")
        set_default(false)
        add_rules("@addon/revenant/swift")
        set_values("swift.module", "XCTest")
        add_deps("UIKitBackports", "CoreDataBackports")
        set_optimize("fastest")
        add_files("tests/XCTest.swift")
        add_frameworks("Foundation")

    target("CombineTests")
        set_default(false)
        add_rules("@addon/revenant/daemon", "@addon/revenant/swift")
        add_deps("CombineXCTest")
        add_packages("combine")
        add_deps("CoreFoundationBackports", "UIKitBackports", "CoreDataBackports")
        add_frameworks("Foundation")
        set_optimize("fastest")
        set_values("swift.flags", "-DOPENCOMBINE_COMPATIBILITY_TEST", "-disable-availability-checking", "-suppress-warnings")
        set_values("revenant.control", "tests/control")
        set_values("revenant.version", "1.0.0")
        set_values("revenant.waive.weak-imports",
                   "every weak import is reached only behind #available or carried by the backports: the runtime's overlays built with availability checking on, Combine's run-loop timer tolerance, compiler-rt's version check")
        on_load(function (target)
            local tests = sources(target, "Tests", "OpenCombineTests")
            local discover = import("discover", {rootdir = path.join(os.scriptdir(), "tools"), anonymous = true})
            local text = discover.main(tests, path.join(os.scriptdir(), "tests", "data", "skip.txt"))
            local main = path.join(target:autogendir(), "main.swift")
            if not os.isfile(main) or io.readfile(main) ~= text then
                io.writefile(main, text)
            end
            target:add("files", path.join(tests, "**.swift"), main)
        end)

    target("CombineGenerated")
        set_kind("phony")
        set_default(false)
        add_packages("combine")
        add_tests("templates")
        on_test(function (target)
            local gyb = import("@addon.revenant.gyb.main", {anonymous = true})
            local header = io.readfile(sources(target, "utils", "template_header.txt")):gsub("\n$", "")
            local templates = os.files(sources(target, "Combine", "**.gyb"))
            assert(#templates > 0, "revenant@combine installed no gyb templates")
            for _, template in ipairs(templates) do
                local generated = path.join(path.directory(template), "GENERATED-" .. path.basename(template))
                local expanded = path.join(target:autogendir(), path.filename(generated))
                os.mkdir(path.directory(expanded))
                gyb.main("-Dtemplate_header=" .. header, "--line-directive", "", "-o", expanded, template)
                if io.readfile(expanded, {encoding = "binary"}) ~= io.readfile(generated, {encoding = "binary"}) then
                    raise("%s is not what %s expands to", generated, template)
                end
            end
            return true
        end)

    target("CombineHelpersTests")
        set_default(false)
        set_kind("binary")
        add_rules("@addon/revenant/apple-ios", "@addon/revenant/swift")
        add_deps("FoundationBackports")
        add_frameworks("Foundation", "CoreFoundation")
        set_optimize("fastest")
        add_files("tests/helpers/main.swift")
        on_load(function (target)
            local install = import("core.project.project").required_package("combine"):installdir()
            target:add("linkdirs", path.join(install, "lib"))
            target:add("values", "swift.flags", "-I" .. path.join(install, "lib", "swift", "iphoneos"), "-I" .. path.join(install, "include", "CombineHelpers"))
        end)

    target("CombineHelpers")
        set_kind("phony")
        set_default(false)
        add_deps("CombineHelpersTests")
        add_packages("combine")
        add_tests("locks")
        add_tests("autolink")
        on_test(function (target, opt)
            local checks = import("helpers", {rootdir = path.join(os.scriptdir(), "tools"), anonymous = true})
            local install = target:pkg("combine"):installdir()
            local probe = import("core.project.project").target("CombineHelpersTests")
            local scratch = path.join(target:autogendir(), "helpers")
            if path.filename(opt.name) == "locks" then
                checks.locks(path.join(install, "src", "CombineHelpers"), path.join(os.scriptdir(), "tests", "helpers", "main.swift"), scratch)
            else
                checks.autolink(install, probe, path.join(probe:objectdir(), "swift", probe:name() .. ".o"))
            end
            return true
        end)
end
