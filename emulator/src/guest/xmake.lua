if get_config("component") ~= "" or not is_plat("iphoneos") then
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
