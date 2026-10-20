set_project("vdspprobe")
set_version("0.1.0")
local root = os.getenv("VDSPPROBE_ROOT") or path.join(os.scriptdir(), "../../../..")
add_repositories("revenant " .. root)
add_addons("revenant v0.8.13")
local minimum = os.getenv("VDSPPROBE_MINIMUM") or "6.1.3"
set_config("apple_minimum", minimum)
includes("@addon/revenant/apple-ios")
includes("@addon/revenant/emulate")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

target("vdsp-biquad-probe")
    add_rules("@addon/revenant/daemon")
    add_files(path.join(root, "tests/backports/device/vdsp-probe/vdsp-biquad-probe.m"))
    add_files(path.join(root, "packages/frameworks/apple-backports/Accelerate/vDSPBiquad6.m"))
    add_files(path.join(root, "packages/frameworks/apple-backports/Accelerate/vDSPSve7.m"))
    add_defines("vDSP_sve_svesq=revenant_probe_vDSP_sve_svesq",
                "vDSP_sve_svesqD=revenant_probe_vDSP_sve_svesqD")
    add_files(path.join(root, "packages/frameworks/apple-backports/Accelerate/vDSPSve7.m"))
    add_defines("vDSP_sve_svesq=revenant_probe_vDSP_sve_svesq", "vDSP_sve_svesqD=revenant_probe_vDSP_sve_svesqD")
    add_defines("vDSP_biquad=revenant_probe_vDSP_biquad",
                "vDSP_biquadD=revenant_probe_vDSP_biquadD",
                "vDSP_biquad_CreateSetup=revenant_probe_vDSP_biquad_CreateSetup",
                "vDSP_biquad_CreateSetupD=revenant_probe_vDSP_biquad_CreateSetupD",
                "vDSP_biquad_DestroySetup=revenant_probe_vDSP_biquad_DestroySetup",
                "vDSP_biquad_DestroySetupD=revenant_probe_vDSP_biquad_DestroySetupD")
    add_frameworks("Foundation", "Accelerate")
    add_mflags("-fobjc-arc")
    add_ldflags("-fobjc-arc", {force = true})
    set_values("revenant.control", "control")
