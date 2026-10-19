set_project("coreml")
set_version("0.0.1")
-- The Core ML device call test: a daemon that links libCoreMLBackports and calls every method the
-- registry claims, over the containers embedded in tests/backports/device/coreml-models.h.
-- The working copy under test is named by emulate.sh (COREML_ROOT); the addon is the tag already in
-- the store (charon/AGENTS.md, Traps: a working copy is never installed as the addon).
local root = os.getenv("COREML_ROOT") or path.join(os.scriptdir(), "../../../../..")
add_repositories("charon " .. root)
add_addons("charon v0.8.13")
add_requires("charon@apple-backports", {alias = "apple-backports", configs = {coreml = true}})
set_config("apple_minimum", os.getenv("COREML_MINIMUM") or "6.1.3")
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

target("coreml")
    add_rules("@addon/charon/daemon")
    add_files(path.join(root, "tests/backports/device/coreml.m"), path.join(root, "tests/backports/device/check.m"))
    add_includedirs(path.join(root, "tests/backports/device"))
    add_mflags("-fobjc-arc", "-Wno-deprecated-declarations")
    add_ldflags("-fobjc-arc", {force = true})
    add_frameworks("Foundation", "CoreGraphics", "CoreVideo")
    add_packages("apple-backports")
    set_values("charon.libraries", "apple-backports")
    set_values("charon.control", "control")
    -- CoreVideo is where the pixel buffer a feature value may be an image of lives, and the test
    -- asks CVPixelBuffer only through Core ML; the waiver is for the framework link, not for a use
    -- of a class the backports do not carry.
    set_values("charon.waive.weak-imports", "the test links CoreVideo for the image feature value's own type and creates no buffer of its own")
