set_project("charoncoremidiapp")
set_version("0.0.1")
-- The CoreMIDI round trip as an installed application, launched through SpringBoard (xmake emulate launch): the
-- same probe as the daemon, in an application that declares the audio background mode (Info.plist) and activates an
-- audio session before it asks for the endpoints.
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
    -- One list: a nil between the arguments of add_defines ends the arguments there, which dropped the probe define whenever
    -- the audio session was left on.
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
    -- The SDK weak-links the iOS 14 and 9 functions and constants (it weak-links what is newer than the deployment target), and
    -- the release has none of them. Each of them is the library's own symbol on this release: libCoreMIDIBackports, which the
    -- program carries, exports it, so the weak reference binds to the library and is not NULL, and the release check resolves
    -- it against that export. No waiver is needed: the release check passes the nine without one (measured on this release's
    -- tree, and the round trip runs on the emulated 6.1.3 with it removed; see the status of the entry "CoreMIDI emulator
    -- application: its weak-import waiver covers the whole program" in coordination/crutches.md).
