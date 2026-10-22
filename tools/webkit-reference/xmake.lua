set_project("webkit-reference")
set_xmakever("3.1.2")
includes("../../frameworks/WebKit/src/engine")

local repo = path.absolute(path.join(os.projectdir(), "..", ".."))

add_rules("mode.release")
set_defaultmode("release")

add_repositories("revenant " .. repo)
add_addons("revenant", {sourcedir = path.join(repo, "toolchain")})

set_config("apple_minimum", "6.0")
if is_plat("iphoneos") then
    includes("@addon/revenant/apple-ios")
    add_requires("revenant@webkit-engine", {alias = "webkit-engine"})
end

target("webkit-reference")
    set_kind("phony")
    set_default(false)
    if is_plat("iphoneos") then
        add_packages("webkit-engine")
    end
target_end()
