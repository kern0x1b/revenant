set_project("displayprobe")
set_version("0.1.0")
-- The working copy under test, named by run.sh (DISPLAYPROBE_ROOT); the addon is the tag already in the store (charon/AGENTS.md,
-- Traps: a working copy is never installed as the addon).
local root = os.getenv("DISPLAYPROBE_ROOT") or path.join(os.scriptdir(), "../../../..")
add_repositories("charon " .. root)
add_addons("charon v0.8.11")
-- The two things the probe is built to vary: the minimum OS of the binary, and whether charon@apple-backports is linked.
local minimum = os.getenv("DISPLAYPROBE_MINIMUM") or "4.3"
local package = os.getenv("DISPLAYPROBE_PACKAGE") == "1"
set_config("apple_minimum", minimum)
if package then add_requires("charon@apple-backports", {alias = "apple-backports", configs = {uikit = true}}) end
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

target("display-probe")
    add_rules("@addon/charon/daemon")
    add_files(path.join(root, "tests/backports/device/display-probe.m"))
    add_mflags("-fobjc-arc")
    add_ldflags("-fobjc-arc", {force = true})
    add_defines("PROBE_MINIMUM=\"" .. minimum .. "\"", "PROBE_PACKAGE=" .. (package and "1" or "0"))
    add_frameworks("Foundation", "UIKit", "QuartzCore", "CoreGraphics")
    if package then
        add_packages("apple-backports")
        set_values("charon.libraries", "apple-backports")
        -- The libraries weakly import classes a release below 6.1.3 refuses; this program calls none of them (the same waiver
        -- as dynamics-watch's target: a measurement program, not a released image).
        set_values("charon.waive.weak-imports", "measurement program, not a released image: it only asks the display; the libraries' weak imports belong to classes it never reaches")
    end
    set_values("charon.control", "control")
