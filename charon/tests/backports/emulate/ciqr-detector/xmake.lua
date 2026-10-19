set_project("ciqrdetector")
set_version("0.0.1")
-- The probe of tests/backports/emulate/ciqr-detector/main.m, built for the release and run in the emulator with
-- `xmake emulate -d iPhone4,1 -r 6.1.3 run /usr/libexec/ciqrdetector`. The working copy under test is named by
-- CIQRDETECTOR_ROOT; the addon is the tag in the store that has plugins/emulate.
local root = os.getenv("CIQRDETECTOR_ROOT") or path.join(os.scriptdir(), "../../../..")
add_repositories("charon " .. root)
add_addons("charon v0.8.17")
set_config("apple_minimum", "6.1.3")
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")
set_allowedplats("iphoneos")
set_allowedarchs("iphoneos|armv7")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

target("ciqrdetector")
    add_rules("@addon/charon/daemon")
    add_files("main.m")
    add_mflags("-fobjc-arc")
    add_ldflags("-fobjc-arc")
    add_frameworks("Foundation", "CoreImage")
    set_values("charon.version", "1.0")
    set_values("charon.control", "control")
