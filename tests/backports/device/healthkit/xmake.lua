-- healthkit as a device binary: the three questions a 6.1.3 device can answer, asked of this port on
-- the emulator and held to what Apple's own headers document, with the release's own HealthKit as the
-- control - which on 6.1.3 is absent, and the absence is what the test reports for the release side.
set_project("healthkit-device")
set_version("0.0.1")
-- the working copy under test is the repository for the addon, as the other device tests name it (textkit2, sampler-probe). With the
-- GitHub branch this file named, the configure stopped at toolchain("apple-ios"): not found, after the clone had worked.
local root = os.getenv("HEALTHKIT_ROOT") or path.join(os.scriptdir(), "../../../..")
add_repositories("charon " .. root)
add_addons("charon v0.8.12")
set_config("apple_minimum", "6.1.3")
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")
set_allowedplats("iphoneos")
set_allowedarchs("iphoneos|armv7")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

-- The library's own sources, as modules/apple/backports.lua's sources() gathers them: every .m of the folder, and of .gen/HealthKit,
-- where gen writes the measured constant objects (tools/gen/measured.lua). run.sh runs gen for HealthKit before configure. A list
-- written here went stale: it named a file that no longer exists and missed the constants and classes the folder now carries.
local healthkit = path.join(root, "packages/a/apple-backports/HealthKit")
local generated = path.join(root, "packages/a/apple-backports/.gen/HealthKit")

target("healthkit")
    add_rules("@addon/charon/daemon")
    add_files(path.join(healthkit, "*.m"), path.join(generated, "*.m"))
    add_files(path.join(root, "tests/backports/device/healthkit.m"), path.join(root, "tests/backports/device/check.m"))
    add_includedirs(path.join(root, "tests/backports/device"), path.join(root, "packages/a/apple-backports/HealthKit"))
    add_mflags("-fobjc-arc", "-Wno-deprecated-declarations", "-Wno-unguarded-availability")
    add_ldflags("-fobjc-arc", "-lsqlite3")
    add_frameworks("Foundation", "UIKit", "CoreGraphics", "QuartzCore", "CoreLocation", "AudioToolbox", "ImageIO")
    add_syslinks("sqlite3")
    set_values("charon.version", "1.0")
    -- The two weak imports are NSDateInterval (HKStatistics, HKWorkout, HKWorkoutRoute110) and NSKeyedArchiveRootObjectKey (HKObject's
    -- decoder). The three questions reach neither: the query on an unreadable type answers an empty result with an error, which
    -- builds no statistics or workout and decodes no stored sample. The 6.1.3 cache exports neither name, so the program is a
    -- measurement of those questions, not a released image, and the waiver says so as display-probe's does.
    set_values("charon.waive.weak-imports", "measurement program, not a released image: the three questions reach neither NSDateInterval (HKStatistics, HKWorkout) nor NSKeyedArchiveRootObjectKey (HKObject's decoder)")
    -- The emulate run reads this control file, which run.sh copies beside xmake.lua (as display-probe's and sampler-probe's do).
    set_values("charon.control", "control")
