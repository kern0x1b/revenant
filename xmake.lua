set_project("revenant")
set_xmakever("3.1.2")

add_rules("mode.release", "mode.debug")
set_defaultmode("release")

includes("third_party/blocksruntime", "third_party/boost", "third_party/dynarmic", "third_party/farmdec", "third_party/rellume")
includes("third_party/brotli", "third_party/icu", "third_party/libpsl", "third_party/libwebp", "third_party/libxml2",
         "third_party/libxslt", "third_party/wasm3", "third_party/webkit", "third_party/woff2")
add_repositories("revenant " .. (os.getenv("REVENANT_REPO") or "."))
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

includes("frameworks/Backports")

if is_plat("iphoneos") then
    includes("frameworks/Combine", "frameworks/SwiftUI", "frameworks/WebKit")
else
    includes("emulator", "recompiler", "frameworks/Combine", "frameworks/SwiftUI", "frameworks/WebKit")
end
