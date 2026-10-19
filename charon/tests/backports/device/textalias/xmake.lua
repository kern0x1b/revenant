set_project("textalias")
set_version("0.0.1")
-- The working copy under test (TEXTALIAS_ROOT overrides it); the addon is the tag already in the store
-- (charon/AGENTS.md, Traps: a working copy is never installed as the addon).
local root = os.getenv("TEXTALIAS_ROOT") or path.join(os.scriptdir(), "../../../..")
add_repositories("charon " .. root)
add_addons("charon v0.8.17")
-- The binary links the built package's libUIKitBackports.dylib, which carries the categories on NSTextTab and NSTextList.
add_requires("charon@apple-backports", {alias = "apple-backports", configs = {uikit = true}})
set_config("apple_minimum", os.getenv("TEXTALIAS_MINIMUM") or "6.1.3")
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")
set_allowedplats("iphoneos")
set_allowedarchs("iphoneos|armv7")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

-- attach.c is compiled into the test itself, so the process is an image with aliases of its own (the test's header says
-- why). The rename moves the test image's categories into __charon_catlist, where attach.c attaches them.
target("textalias")
    add_rules("@addon/charon/daemon")
    add_files(path.join(root, "tests/backports/device/textalias.m"), path.join(root, "tests/backports/device/check.m"))
    add_files(path.join(root, "packages/a/apple-backports/attach.c"))
    add_includedirs(path.join(root, "tests/backports/device"))
    add_mflags("-fobjc-arc")
    add_ldflags("-fobjc-arc", {force = true})
    add_ldflags("-Wl,-rename_section,__DATA,__objc_catlist,__DATA,__charon_catlist", {force = true})
    add_frameworks("Foundation", "UIKit")
    add_packages("apple-backports")
    set_values("charon.libraries", "apple-backports")
    set_values("charon.control", "control")
