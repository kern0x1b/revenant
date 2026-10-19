set_project("wifijoin613")
set_version("0.0.1")
-- The probe of tests/backports/host/netext-hotspot/emulate/wifi-join.m, built for the release and run in the
-- emulator with `xmake emulate -d iPhone4,1 -r 6.1.3 run /usr/libexec/wifijoin613`. The working copy under test is
-- named by WIFIJOIN613_ROOT; the addon is the tag in the store that has plugins/emulate.
local root = os.getenv("WIFIJOIN613_ROOT") or path.join(os.scriptdir(), "../../../../../..")
add_repositories("charon " .. root)
add_addons("charon v0.8.17")
set_config("apple_minimum", "6.1.3")
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")
set_allowedplats("iphoneos")
set_allowedarchs("iphoneos|armv7")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

target("wifijoin613")
    add_rules("@addon/charon/daemon")
    add_files(path.join(root, "tests/backports/host/netext-hotspot/emulate/wifi-join.m"))
    add_mflags("-fobjc-arc")
    add_ldflags("-fobjc-arc")
    add_frameworks("Foundation", "SystemConfiguration")
    set_values("charon.version", "1.0")
    set_values("charon.control", "control")
