set_project("paseo-ios6")
set_version("0.1.0")
local home = os.getenv("HOME")
local revenant = os.getenv("REVENANT_PATH") or (home .. "/Git/projects/ios/revenant")
add_repositories("revenant " .. revenant)
if os.getenv("RN_WEBKIT") then
    add_requires("webkit-engine", {alias = "webkit-engine-prefixed", configs = {variant = "prefixed", carried = "jsc"}})
end
if os.getenv("RN_JSC_ENGINE") then
    package("rn-jsc-engine")
        set_sourcedir(os.getenv("RN_JSC_ENGINE"))
        on_install(function (package)
            os.vcp(path.join(package:sourcedir(), "bundle"), package:installdir())
        end)
    package_end()
    add_requires("rn-jsc-engine")
end
if os.getenv("RN_DEPS_REPO") then
    if os.getenv("RN_BACKPORTS") then
        add_requires("revenant@backports", {alias = "backports", configs = {libraries = "FoundationBackports,CoreTextBackports,UIKitBackports,UserNotificationsBackports,CoreGraphicsBackports,GraphicsBackports,CoreFoundationBackports,SystemBackports,IOSurfaceBackports,WebKitBackports,MapKitBackports,CoreLocationBackports,SecurityBackports,CoreMotionBackports"}})
    end
    add_requires("revenant@folly 2024.11.18.00", {alias = "folly"})
    add_requires("revenant@socketrocket 0.7.1", {alias = "socketrocket"})
end
add_addons("revenant", {sourcedir = path.join(revenant, "toolchain")})
set_config("apple_sdk", "26.2")
set_config("apple_minimum", "6.0")
includes("@addon/revenant/apple-ios")
on_config(function () import("@addon.revenant.binding", {anonymous = true}).check() end)
set_allowedplats("iphoneos")
set_allowedarchs("iphoneos|armv7")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")
if not os.getenv("RN_ONLY") or os.getenv("RN_EXPO") then
    add_requires("revenant@swift-runtime", {alias = "swift-runtime"})
end
add_requires("revenant@libcxx", {alias = "libcxx"})
if os.getenv("RN_DEPS_REPO") and (not os.getenv("RN_ONLY") or os.getenv("RN_EXPO")) then
    for _, name in ipairs({"cryptokit", "combine", "swiftui", "uniformtypeidentifiers"}) do
        add_requires("revenant@" .. name, {alias = name})
    end
end

includes(path.join(revenant, "frameworks", "ReactNative"))
includes(path.join(revenant, "frameworks", "ReactNative", "src", "host"))
