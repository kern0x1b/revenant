set_project("revenant")
set_xmakever("3.1.2")

add_rules("mode.release", "mode.debug")
set_defaultmode("release")

option("component", {type = "string", default = "", showmenu = true,
                     description = "Configure only this component and what it needs, for example Backports; empty configures every component."})
option("apple_sdk", {type = "string", default = "", showmenu = true,
                     description = "The iPhoneOS SDK version, 16.4 or 26.2; empty takes 16.4 for the whole graph and 26.2 for a component."})

local component = get_config("component")
local whole = component == ""

add_repositories("revenant " .. (os.getenv("REVENANT_REPO") or "."))
add_addons("revenant", {sourcedir = "toolchain"})

option("tests", {type = "string", default = "host", values = {"host", "device"}, showmenu = true,
                 description = "Which tests are declared: host, the default, is what a host with the prebuilt packages can run; device adds the tests that need a device, an emulator image or firmware."})

option("emulate", {default = false, showmenu = true,
                   description = "Require the emulator, so that ./xmakew emulate installs this project's packages into an emulated device and runs them there."})

set_config("apple_minimum", "6.0")
if is_plat("iphoneos") then
    includes("@addon/revenant/apple-ios")
    includes("emulator/src/guest")
    if has_config("emulate") then
        includes("@addon/revenant/emulate")
    end
    if whole then
        add_requires("revenant@swift-runtime", {alias = "swift-runtime", configs = {backports = true}})
        add_requires("revenant@libcxx", {alias = "libcxx"})
    end
    add_requires("revenant@apple-compat", {alias = "apple-compat"})
end

includes("frameworks/Backports")
includes("emulator", "recompiler", "frameworks/Combine", "frameworks/SwiftUI", "frameworks/WebKit", "toolchain/src/firmware-tools", "toolchain/tests")

if whole then
    target("repository")
        set_kind("phony")
        set_default(false)
        add_tests("layout")
        add_tests("comments_check")
        add_tests("comments_test")
        add_tests("copied_text")
        on_test(function (target, opt)
            local root = os.projectdir()
            if path.filename(opt.name) == "copied_text" then
                local data = path.join(root, "agent-skills", "tests", "data", "copied_text")
                local script = path.join(root, "agent-skills", "tests", "copied_text.lua")
                local function report(project)
                    return os.iorunv(os.programfile(), {"l", "-P", root, script, path.join(data, "plugin"), path.join(data, project)}, {curdir = root})
                end
                if not report("copies"):find("repeats", 1, true) or report("clean"):find("repeats", 1, true) then
                    opt.errors = "copied_text must report the copied fixture and not the clean one"
                    return false
                end
                return true
            end
            local commands = {layout = {path.join(root, "tools", "layout.lua")},
                              comments_check = {path.join(root, "tools", "comments.lua"), "check"},
                              comments_test = {path.join(root, "tools", "comments.lua"), "test"}}
            local ok = os.execv(os.programfile(), table.join({"l", "-P", root}, commands[path.filename(opt.name)]), {try = true, curdir = root})
            if ok ~= 0 then
                opt.errors = path.filename(opt.name) .. " failed"
            end
            return ok == 0
        end)
    target_end()
end
