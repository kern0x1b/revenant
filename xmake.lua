set_project("revenant")
set_xmakever("3.1.2")

add_rules("mode.release", "mode.debug")
set_defaultmode("release")

add_repositories("revenant-third-party third_party")
add_repositories("revenant " .. (os.getenv("REVENANT_REPO") or "toolchain"))
add_addons("revenant", {sourcedir = "toolchain"})

option("emulate", {default = false, showmenu = true,
                   description = "Require the emulator, so that ./xmakew emulate installs this project's packages into an emulated device and runs them there."})

set_config("apple_minimum", "6.0")
if is_plat("iphoneos") then
    includes("@addon/revenant/apple-ios")
    if has_config("emulate") then
        includes("@addon/revenant/emulate")
    end
    add_requires("revenant@swift-runtime", {alias = "swift-runtime", configs = {backports = true}})
    add_requires("revenant@libcxx", {alias = "libcxx"})
    add_requires("revenant@apple-backports", {alias = "apple-backports", configs = {coredata = true, uikit = true}})
    add_requires("revenant@apple-compat", {alias = "apple-compat"})
end

if is_plat("iphoneos") then
    includes("frameworks/Combine", "frameworks/SwiftUI")
else
    includes("emulator", "recompiler", "frameworks/Combine", "frameworks/SwiftUI")
end
