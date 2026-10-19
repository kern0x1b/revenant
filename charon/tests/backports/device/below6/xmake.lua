set_project("below6")
set_version("0.0.1")
local root = os.getenv("BELOW6_ROOT") or path.join(os.scriptdir(), "../../../..")
add_repositories("charon " .. root)
add_addons("charon v0.8.12")
local minimum = os.getenv("BELOW6_MINIMUM") or "4.3"
add_requires("charon@apple-backports", {alias = "apple-backports", configs = {uikit = os.getenv("BELOW6_UIKIT") == "1"}})
set_config("apple_minimum", minimum)
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

local PROGRAMS = {
    nsuuid = {},
    progress = {extra = {"progress-cases.m"}},
    json1 = {},
    unitfmt = {},
    dateinterval = {extra = {"dateinterval/expected.txt"}, waiver = "NSDateIntervalFormatter is carried from 5.0 and 4.3's own Foundation has no such class"},
}
for name, program in pairs(PROGRAMS) do
    target(name)
        add_rules("@addon/charon/daemon")
        add_files(path.join(root, "tests/backports/device", name .. ".m"), path.join(root, "tests/backports/device/check.m"))
        for _, extra in ipairs(program.extra or {}) do
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
