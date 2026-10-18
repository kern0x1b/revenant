-- healthkit as a device binary: the three questions a 6.1.3 device can answer, asked of this port on
-- the emulator and held to what Apple's own headers document, with the release's own HealthKit as the
-- control - which on 6.1.3 is absent, and the absence is what the test reports for the release side.
set_project("healthkit-device")
set_version("0.0.1")
-- The working copy under test is the repository for the addon, as the other device tests name it (textkit2, sampler-probe). With the
-- GitHub branch this file named, the configure stopped at toolchain("apple-ios"): not found, after the clone had worked.
local root = os.getenv("HEALTHKIT_ROOT") or path.join(os.scriptdir(), "../../../..")
add_repositories("charon " .. root)
add_addons("charon v0.8.12")
-- The binary links the built package, as textkit2's does, so what runs is what the package carries. HealthKit's classes are the
-- package's HealthKitBackports; the Foundation classes and constants it reaches that 6.1.3 lacks (NSDateInterval,
-- NSKeyedArchiveRootObjectKey) are carried by FoundationBackports, which the package links, so no weak import is left unresolved.
-- uikit is off: a daemon has no UIKit to draw with, and UIKitBackports would pull GraphicsBackports, whose weak __sincos_stret
-- (a 7.0 symbol) the 6.1.3 platform refuses for a daemon (photobracket's own note on the same link).
add_requires("charon@apple-backports", {alias = "apple-backports", configs = {healthkit = true}})
set_config("apple_minimum", "6.1.3")
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")
set_allowedplats("iphoneos")
set_allowedarchs("iphoneos|armv7")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

target("healthkit")
    add_rules("@addon/charon/daemon")
    add_files(path.join(root, "tests/backports/device/healthkit.m"), path.join(root, "tests/backports/device/check.m"))
    add_includedirs(path.join(root, "tests/backports/device"))
    add_mflags("-fobjc-arc", "-Wno-deprecated-declarations", "-Wno-unguarded-availability")
    add_ldflags("-fobjc-arc", {force = true})
    add_frameworks("Foundation")
    add_packages("apple-backports")
    set_values("charon.libraries", "apple-backports")
    set_values("charon.version", "1.0")
    -- The emulate run reads this control file, which run.sh copies beside xmake.lua (as display-probe's and sampler-probe's do).
    set_values("charon.control", "control")
