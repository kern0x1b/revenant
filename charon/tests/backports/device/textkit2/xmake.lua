set_project("textkit2")
set_version("0.0.1")
-- The working copy under test, named by run.sh (TEXTKIT2_ROOT); the addon is the tag already in the store
-- (charon/AGENTS.md, Traps: a working copy is never installed as the addon). The binary links the built
-- package, so what runs is what the package carries, not a recompile of the sources.
local root = os.getenv("TEXTKIT2_ROOT") or path.join(os.scriptdir(), "../../..")
add_repositories("charon " .. root)
add_addons("charon v0.8.12")
add_requires("charon@apple-backports", {alias = "apple-backports", configs = {uikit = true}})
set_config("apple_minimum", os.getenv("TEXTKIT2_MINIMUM") or "6.1.3")
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")
set_allowedplats("iphoneos")
set_allowedarchs("iphoneos|armv7")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

target("textkit2")
    add_rules("@addon/charon/daemon")
    add_files(path.join(root, "tests/backports/device/textkit2.m"), path.join(root, "tests/backports/device/check.m"))
    add_includedirs(path.join(root, "tests/backports/device"))
    add_mflags("-fobjc-arc", "-fvisibility=hidden", "-Wno-deprecated-declarations",
               "-Wno-unguarded-availability-new")
    add_ldflags("-fobjc-arc", {force = true})
    add_frameworks("UIKit", "Foundation", "CoreGraphics", "QuartzCore")
    add_packages("apple-backports")
    set_values("charon.libraries", "apple-backports")
    set_values("charon.version", "1.0")
    set_values("charon.control", "control")
