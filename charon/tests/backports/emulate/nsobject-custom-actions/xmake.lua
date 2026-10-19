set_project("charonnsobjectactions")
set_version("0.0.1")
-- The measurement of -[NSObject accessibilityCustomActions] on a 6.1.3 guest (probe.m says what each line means).
-- Two daemons, the same source: nsoprobe links nothing of the port, so what it answers is the release's own;
-- nsoprobe-category also compiles the port's UIKit/UIAccessibilityCustomAction.m into its image, so the category is in
-- the process. Configure, install and run each with:
--   xmake f -p iphoneos -a armv7 -y
--   xmake emulate -d iPhone4,1 -r 6.1.3 install
--   xmake emulate -d iPhone4,1 -r 6.1.3 run /usr/libexec/nsoprobe
--   xmake emulate -d iPhone4,1 -r 6.1.3 run /usr/libexec/nsoprobe-category
--   xmake emulate -d iPhone4,1 -r 6.1.3 log
local root = os.getenv("CHARCALLS_ROOT") or path.join(os.scriptdir(), "../../../..")
add_repositories("charon " .. root)
-- The addon the store holds and names active (see tests/backports/emulate/calls/xmake.lua).
add_addons("charon v0.8.13")
set_config("apple_minimum", "6.1.3")
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

target("nsoprobe")
    add_rules("@addon/charon/daemon")
    add_files("probe.m")
    add_mflags("-fobjc-arc")
    add_ldflags("-fobjc-arc", {force = true})
    add_frameworks("Foundation")
    set_values("charon.control", "control")

target("nsoprobe-category")
    add_rules("@addon/charon/daemon")
    add_files("probe.m")
    add_files("../../../../packages/a/apple-backports/UIKit/UIAccessibilityCustomAction.m")
    add_mflags("-fobjc-arc")
    add_ldflags("-fobjc-arc", {force = true})
    add_frameworks("Foundation")
    set_values("charon.control", "control")
