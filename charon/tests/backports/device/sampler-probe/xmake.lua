set_project("samplerprobe")
set_version("0.1.0")
-- Does the emulated release carry the Apple sampler as an audio component? A component is a
-- registration and not an export, so this can only be answered by asking the release; see
-- facts/AVFAudio/AVAudioUnitMIDI.md, which records why the cache grep that seemed to settle it
-- settled nothing.
local root = os.getenv("SAMPLERPROBE_ROOT") or path.join(os.scriptdir(), "../../../..")
add_repositories("charon " .. root)
add_addons("charon v0.8.13")
local minimum = os.getenv("SAMPLERPROBE_MINIMUM") or "6.1.3"
set_config("apple_minimum", minimum)
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

target("sampler-probe")
    add_rules("@addon/charon/daemon")
    add_files(path.join(root, "tests/backports/device/sampler-probe.m"))
    add_mflags("-fobjc-arc")
    add_ldflags("-fobjc-arc", {force = true})
    add_defines("PROBE_MINIMUM=\"" .. minimum .. "\"")
    add_frameworks("Foundation", "AudioToolbox")
    set_values("charon.control", "control")
