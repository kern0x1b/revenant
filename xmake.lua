set_project("hades")
set_xmakever("3.1.2")

add_rules("mode.release", "mode.debug")
set_defaultmode("release")

add_repositories("hades-third-party third_party")
add_repositories("charon charon")

set_config("apple_minimum", "6.0")
if is_plat("iphoneos") then
    local scoped = path.join(os.getenv("HOME"), ".cache", "hades", "xmake-global")
    local globaldir = os.getenv("XMAKE_GLOBALDIR")
    if globaldir and path.absolute(globaldir) == scoped then
        add_repositories("charon " .. (os.getenv("CHARON_REPO") or "charon"))
        add_addons("charon latest")
        includes("@addon/charon/apple-ios")
        add_requires("charon@swift-runtime", {alias = "swift-runtime", configs = {backports = true}})
        add_requires("charon@libcxx", {alias = "libcxx"})
        add_requires("charon@apple-backports", {alias = "apple-backports", configs = {coredata = true, uikit = true}})
        add_requires("charon@apple-compat", {alias = "apple-compat"})
    else
        print("hades builds for iOS with the charon addon of this checkout: run `xmake l tools/charon-addon.lua`, then build with XMAKE_GLOBALDIR=%s", scoped)
    end
end

includes("*/xmake.lua")
