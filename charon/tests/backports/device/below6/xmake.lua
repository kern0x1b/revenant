set_project("below6")
set_version("0.0.1")
-- The working copy under test, named by run.sh (BELOW6_ROOT); the addon is the tag already in the store (charon/AGENTS.md, Traps: a
-- working copy is never installed as the addon).
local root = os.getenv("BELOW6_ROOT") or path.join(os.scriptdir(), "../../../..")
add_repositories("charon " .. root)
add_addons("charon v0.8.12")
-- The binary's own apple_minimum, read from run.sh (the same shape as tests/backports/device/display-probe/xmake.lua): 4.3 below the
-- class's own minimum (6.0), where charon@apple-backports carries the class itself and its weak import is refused unless the target
-- waives it; the reference release (6.0) itself at and above it, where band() (modules/apple/backports.lua) reexports the class
-- instead of carrying it, the same way the real apple-backports .deb's own band 6.0 does (checked with nm on it: no NSProgress/NSUUID
-- class metadata there, only a reexport stub) - charon's own "copy the library in" mechanism (charon/AGENTS.md, "charon.libraries
-- and verify_placed") copies the band this build's own apple_minimum names, so setting it to the reference release copies that
-- clean band, not band 4.3's, which would hold two classes of the same name next to the release's real Foundation.
local minimum = os.getenv("BELOW6_MINIMUM") or "4.3"
add_requires("charon@apple-backports", {alias = "apple-backports", configs = {uikit = os.getenv("BELOW6_UIKIT") == "1"}})
set_config("apple_minimum", minimum)
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

-- A program per class of the backports that reach below iOS 6 (tests/backports/README.md), each named for its own source,
-- tests/backports/device/<name>.m, with any extra file the program's own oracle needs (progress-cases.m, its own), and one
-- waiver reason its own use of the package might need.
local PROGRAMS = {
    nsuuid = {},
    -- progress.m decodes its own expectations file with NSJSONSerialization (device/progress.m, unchanged, written for
    -- the release), which the backports carry below iOS 5.0 and the release itself from there, so nothing is waived.
    progress = {extra = {"progress-cases.m"}},
    json1 = {},
    -- unitfmt.m calls the three measurement formatters of iOS 8.0, which the package carries from 6.0, over their own units and
    -- their own flags in all three unit styles. It asserts no wording: the number is written through the release's own
    -- NSNumberFormatter and the system of units is read from the release's own locale, so what it holds is that every method
    -- answers on the device (tests/backports/host/unitformat holds the wording, on the host).
    unitfmt = {},
    -- dateinterval.m runs the port's own NSDateIntervalFormatter - the release's DateIntervalFormat underneath - against
    -- the golden file dateinterval/expected.txt, which is the host's own class's answers over 3375 cases. The class is
    -- carried from 5.0, so the program's band names it and the file travels with it.
    -- The class floor is 5.0 and the "ported" cell builds at 4.3, so this program waives the weak
    -- import the way one that reaches below 6.0 does, and it reports a 4.3 run as "no class" rather
    -- than as a failure: the case table is a 5.0 and 6.0 question, not a 4.3 one.
    dateinterval = {extra = {"dateinterval/expected.txt"}, waiver = "NSDateIntervalFormatter is carried from 5.0 and 4.3's own Foundation has no such class"},
}
for name, program in pairs(PROGRAMS) do
    target(name)
        add_rules("@addon/charon/daemon")
        add_files(path.join(root, "tests/backports/device", name .. ".m"), path.join(root, "tests/backports/device/check.m"))
        for _, extra in ipairs(program.extra or {}) do
            -- add_extrafiles, not add_files: xmake's add_files takes sources and refuses a .txt with
            -- "unknown source file", which is how a program's golden table fails to travel with its
            -- package. add_extrafiles ships the file and does not try to compile it.
            add_extrafiles(path.join(root, "tests/backports/device", extra))
        end
        add_includedirs(path.join(root, "tests/backports/device"))
        add_mflags("-fobjc-arc")
        add_ldflags("-fobjc-arc", {force = true})
        add_frameworks("Foundation")
        add_packages("apple-backports")
        set_values("charon.libraries", "apple-backports")
        set_values("charon.control", "control")
        if program.waiver then set_values("charon.waive.weak-imports", program.waiver) end
end
