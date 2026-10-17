set_project("arkitconfig")
set_version("0.1.0")
-- The working copy under test, named by run.sh (ARKITCONFIG_ROOT); the addon is the tag already in the store (charon/AGENTS.md,
-- Traps: a working copy is never installed as the addon).
local root = os.getenv("ARKITCONFIG_ROOT") or path.join(os.scriptdir(), "../../../..")
add_repositories("charon " .. root)
add_addons("charon v0.8.17")
set_config("apple_minimum", "6.1.3")
add_requires("charon@apple-backports", {alias = "apple-backports", configs = {arkit = true}})
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

target("arkitconfig")
    add_rules("@addon/charon/daemon")
    add_files(path.join(root, "tests/backports/device/arkit-config/arkit-config.m"))
    -- The probe names ARKit classes and properties the SDK declares from later releases; the library provides them on
    -- 6.1.3, and the unguarded-availability warnings for those names are silenced here, not in the probe's source.
    add_mflags("-fobjc-arc", "-Wno-unguarded-availability-new", "-Wno-unguarded-availability")
    add_ldflags("-fobjc-arc", {force = true})
    add_frameworks("Foundation")
    add_packages("apple-backports")
    set_values("charon.libraries", "apple-backports")
    set_values("charon.control", "control")
