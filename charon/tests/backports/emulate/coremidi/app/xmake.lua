set_project("charoncoremidiapp")
set_version("0.0.1")
local root = os.getenv("CHARCOREMIDI_ROOT") or path.join(os.scriptdir(), "../../../../..")
add_repositories("charon " .. root)
add_addons("charon v0.8.17")
set_config("apple_minimum", os.getenv("CHARCOREMIDI_MINIMUM") or "6.1.3")
add_requires("charon@apple-backports", {alias = "apple-backports", configs = {coremidi = true}})
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

target("charoncoremidiapp")
    add_rules("@addon/charon/app")
    add_files(path.join(root, "tests/backports/emulate/coremidi/app/main.m"))
    add_files(path.join(root, "tests/backports/emulate/coremidi/app/roundtrip.m"))
    local defines = {"CHARON_APP=1"}
    if os.getenv("CHARCOREMIDI_NO_AUDIO") then
        table.insert(defines, "CHARON_NO_AUDIO_SESSION=1")
    end
    if os.getenv("CHARCOREMIDI_PROBE") then
        table.insert(defines, "CHARON_6_1_3_PROBE=1")
    end
    add_defines(defines)
    add_mflags("-fobjc-arc")
    add_ldflags("-fobjc-arc", {force = true})
    add_frameworks("Foundation", "UIKit", "CoreMIDI", "AudioToolbox")
    add_packages("apple-backports")
    set_values("charon.libraries", "apple-backports")
    set_values("app.plist-file", "Info.plist")
    set_values("charon.control", "control")
