set_project("textdragweak")
set_version("0.0.1")
-- The working copy under test, named by run.sh (DDR_ROOT); the addon is the tag in the store that has
-- plugins/emulate. A working copy is never installed as the addon (charon/AGENTS.md, Traps).
local root = os.getenv("DDR_ROOT") or path.join(os.scriptdir(), "../../../..")
add_repositories("charon " .. root)
add_addons("charon v0.8.14")
set_config("apple_minimum", "6.1.3")
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")
set_allowedplats("iphoneos")
set_allowedarchs("iphoneos|armv7")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

-- The port sources are taken from DDR_UIKIT, which the run script points at a scratch copy of,
-- so a mutant never overwrites a tracked file in the worktree.
local ui = os.getenv("DDR_UIKIT") or path.join(root, "packages/a/apple-backports/UIKit")
target("textdragweak")
    add_rules("@addon/charon/daemon")
    -- The test includes the port's own .m, because the storage functions under test are static
    -- in it, so the port's file is not compiled a second time here.
    add_files(path.join(root, "tests/backports/device/textdragweak.m"),
              path.join(root, "tests/backports/device/check.m"))
    add_includedirs(path.join(root, "tests/backports/device"))
    add_includedirs(ui)
    add_mflags("-fobjc-arc", "-fvisibility=hidden", "-Wno-deprecated-declarations")
    add_ldflags("-fobjc-arc")
    add_frameworks("UIKit", "Foundation", "CoreGraphics", "QuartzCore")
    set_values("charon.version", "1.0")
    set_values("charon.control", "control")
    set_values("charon.waive.weak-imports",
        "measurement harness, not a released image: the iOS 11 types it names are each used behind a class test")
