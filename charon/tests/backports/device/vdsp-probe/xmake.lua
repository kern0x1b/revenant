set_project("vdspprobe")
set_version("0.1.0")
-- The biquad on the guest: the release's own vDSP_biquad against this band's kernel, both on the target's
-- arithmetic. The port's file is compiled in with its six names renamed, so the probe holds the release's
-- answers and the port's side by side - and the renames have to come from the same list the host
-- differential uses, or the two builds are not the same shape.
local root = os.getenv("VDSPPROBE_ROOT") or path.join(os.scriptdir(), "../../../..")
add_repositories("charon " .. root)
add_addons("charon v0.8.13")
local minimum = os.getenv("VDSPPROBE_MINIMUM") or "6.1.3"
set_config("apple_minimum", minimum)
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

target("vdsp-biquad-probe")
    add_rules("@addon/charon/daemon")
    add_files(path.join(root, "tests/backports/device/vdsp-probe/vdsp-biquad-probe.m"))
    add_files(path.join(root, "packages/a/apple-backports/Accelerate/vDSPBiquad6.m"))
    add_files(path.join(root, "packages/a/apple-backports/Accelerate/vDSPSve7.m"))
    add_defines("vDSP_sve_svesq=charon_probe_vDSP_sve_svesq",
                "vDSP_sve_svesqD=charon_probe_vDSP_sve_svesqD")
    add_files(path.join(root, "packages/a/apple-backports/Accelerate/vDSPSve7.m"))
    add_defines("vDSP_sve_svesq=charon_probe_vDSP_sve_svesq", "vDSP_sve_svesqD=charon_probe_vDSP_sve_svesqD")
    add_defines("vDSP_biquad=charon_probe_vDSP_biquad",
                "vDSP_biquadD=charon_probe_vDSP_biquadD",
                "vDSP_biquad_CreateSetup=charon_probe_vDSP_biquad_CreateSetup",
                "vDSP_biquad_CreateSetupD=charon_probe_vDSP_biquad_CreateSetupD",
                "vDSP_biquad_DestroySetup=charon_probe_vDSP_biquad_DestroySetup",
                "vDSP_biquad_DestroySetupD=charon_probe_vDSP_biquad_DestroySetupD")
    add_frameworks("Foundation", "Accelerate")
    add_mflags("-fobjc-arc")
    add_ldflags("-fobjc-arc", {force = true})
    set_values("charon.control", "control")
