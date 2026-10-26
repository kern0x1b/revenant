local component = get_config("component")
if (component ~= "" and component ~= "SwiftUIDemo") or not is_plat("iphoneos") then
    return
end

local GUEST = os.scriptdir()

target("revenant-runner")
    add_rules("@addon/revenant/daemon")
    add_files(path.join(GUEST, "revenant-runner.c"))
    add_frameworks("CoreFoundation")
    add_syslinks("objc")

target("revenant-sblaunch")
    add_rules("@addon/revenant/daemon")
    add_files(path.join(GUEST, "revenant-sblaunch.c"))
    add_frameworks("CoreFoundation")
    set_values("revenant.entitlements", "revenant-sblaunch.entitlements")

target("revenant-shot")
    add_rules("@addon/revenant/daemon")
    add_files(path.join(GUEST, "revenant-shot.m"))
    add_frameworks("CoreFoundation", "CoreGraphics", "Foundation", "UIKit")
    add_syslinks("objc")
