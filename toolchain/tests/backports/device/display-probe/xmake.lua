set_project("displayprobe")
set_version("0.1.0")
local root = os.getenv("DISPLAYPROBE_ROOT") or path.join(os.scriptdir(), "../../../..")
add_repositories("revenant " .. root)
add_addons("revenant v0.8.11")
local minimum = os.getenv("DISPLAYPROBE_MINIMUM") or "4.3"
local package = os.getenv("DISPLAYPROBE_PACKAGE") == "1"
set_config("apple_minimum", minimum)
if package then add_requires("revenant@apple-backports", {alias = "apple-backports", configs = {uikit = true}}) end
includes("@addon/revenant/apple-ios")
includes("@addon/revenant/emulate")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

target("display-probe")
    add_rules("@addon/revenant/daemon")
    add_files(path.join(root, "tests/backports/device/display-probe.m"))
    add_mflags("-fobjc-arc")
    add_ldflags("-fobjc-arc", {force = true})
    add_defines("PROBE_MINIMUM=\"" .. minimum .. "\"", "PROBE_PACKAGE=" .. (package and "1" or "0"))
    add_frameworks("Foundation", "UIKit", "QuartzCore", "CoreGraphics")
    if package then
        add_packages("apple-backports")
        set_values("revenant.libraries", "apple-backports")
        set_values("revenant.waive.weak-imports", "measurement program, not a released image: it only asks the display; the libraries' weak imports belong to classes it never reaches")
    end
    set_values("revenant.control", "control")
