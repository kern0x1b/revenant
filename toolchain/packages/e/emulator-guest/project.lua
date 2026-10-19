add_repositories("revenant @repository@")
add_addons("revenant")
set_config("apple_minimum", "@minimum@")
includes("@addon/revenant/apple-ios")

set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|@arch@")

target("revenant-runner")
    add_rules("@addon/revenant/daemon")
    add_files("revenant-runner.c")
    add_frameworks("CoreFoundation")
    add_syslinks("objc")

target("revenant-sblaunch")
    add_rules("@addon/revenant/daemon")
    add_files("revenant-sblaunch.c")
    add_frameworks("CoreFoundation")
    set_values("revenant.entitlements", "revenant-sblaunch.entitlements")
