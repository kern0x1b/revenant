add_repositories("charon @repository@")
add_addons("charon")
set_config("apple_minimum", "@minimum@")
includes("@addon/charon/apple-ios")

set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|@arch@")

target("charon-runner")
    add_rules("@addon/charon/daemon")
    add_files("charon-runner.c")
    add_frameworks("CoreFoundation")
    add_syslinks("objc")

target("charon-sblaunch")
    add_rules("@addon/charon/daemon")
    add_files("charon-sblaunch.c")
    add_frameworks("CoreFoundation")
    set_values("charon.entitlements", "charon-sblaunch.entitlements")
