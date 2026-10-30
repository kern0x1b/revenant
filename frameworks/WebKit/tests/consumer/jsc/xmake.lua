set_project("webkit-jsc-consumer")
set_version("0.0.1")
-- A React Native host links the prefixed JavaScriptCore alone (carried=jsc). The root project holds one instance of
-- webkit-engine, so this consumer is its own project, as the other consumer tests are.
local root = os.getenv("REVENANT_ROOT") or path.join(os.scriptdir(), "../../../../..")
add_repositories("revenant " .. root)
add_addons("revenant", {sourcedir = path.join(root, "toolchain")})
add_requires("revenant@webkit-engine", {alias = "webkit-engine-jsc", configs = {variant = "prefixed", carried = "jsc"}})
add_requires("revenant@libcxx", {alias = "libcxx"})
set_config("apple_minimum", "6.0")
includes("@addon/revenant/apple-ios")
set_allowedplats("iphoneos")
set_allowedarchs("iphoneos|armv7")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

target("jsc-consumer")
    add_rules("@addon/revenant/apple-ios")
    set_kind("binary")
    add_files("consumer/main.c")
    add_packages("webkit-engine-jsc", "libcxx")
    add_frameworks("JavaScriptCore")
    add_ldflags("-Wl,-rpath,@executable_path/Frameworks", {force = true})
    on_config(function (target)
        local engine = target:pkg("webkit-engine-jsc"):installdir()
        target:add("frameworkdirs", path.join(engine, "frameworks"))
    end)
    after_build(function (target)
        -- The link names the framework the way the application embeds it, in its Frameworks folder, and the check below holds
        -- the binary to that.
        local jsc = "@executable_path/Frameworks/JavaScriptCore.framework/JavaScriptCore"
        -- Host-checkable: every JSC symbol the binary imports is exported by the bundled JavaScriptCore, none is an XPC
        -- import (iOS 6 exports none), and the bundled copy is installed under the name the binary uses.
        local engine = target:pkg("webkit-engine-jsc"):installdir()
        local bundled = path.join(engine, "bundle", "Frameworks", "JavaScriptCore.framework", "JavaScriptCore")
        local exported = {}
        for line in os.iorunv("nm", {"-gU", bundled}):gmatch("[^\n]+") do
            local symbol = line:match("(%S+)$")
            if symbol then
                exported[(symbol:gsub("^_", ""))] = true
            end
        end
        local missing = {}
        for line in os.iorunv("nm", {"-u", target:targetfile()}):gmatch("[^\n]+") do
            local symbol = line:match("(%S+)$")
            if symbol then
                local name = (symbol:gsub("^_", ""))
                assert(not name:find("^xpc_"), target:targetfile() .. " imports " .. name .. ", which iOS 6 does not export")
                if name:find("^JS") and not exported[name] then
                    table.insert(missing, name)
                end
            end
        end
        assert(#missing == 0, "the bundled JavaScriptCore does not export " .. table.concat(missing, ", "))
        assert(os.iorunv("otool", {"-L", target:targetfile()}):find(jsc, 1, true), target:targetfile() .. " does not name " .. jsc)
        assert(os.iorunv("otool", {"-D", bundled}):find(jsc, 1, true), bundled .. " is not installed as " .. jsc)
    end)
