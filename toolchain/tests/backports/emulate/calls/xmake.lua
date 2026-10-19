set_project("revenantcalls")
set_version("0.0.1")
local root = os.getenv("CHARCALLS_ROOT") or path.join(os.scriptdir(), "../../../..")
add_repositories("revenant " .. root)
add_addons("revenant v0.8.13")
set_config("apple_minimum", os.getenv("CHARCALLS_MINIMUM") or "6.1.3")
local package = os.getenv("CHARCALLS_PACKAGE") ~= "0"
if package then
    add_requires("revenant@apple-backports", {alias = "apple-backports", configs = {intents = true}})
end
includes("@addon/revenant/apple-ios")
includes("@addon/revenant/emulate")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

local task = os.getenv("REVENANT_TASK")
if not task or task == "" then
    local checkout = path.normalize(path.absolute(root))
    task = path.filename(os.exists(path.join(checkout, ".git")) and checkout or path.directory(checkout))
end
local calls = os.getenv("CHARCALLS_GENERATED") or path.join(os.getenv("HOME"), ".revenant", "cache", task, "revenant-calls", "generated")

target("revenantcalls")
    add_rules("@addon/revenant/daemon")
    add_files(path.join(root, "tests/backports/callgen/harness.m"))
    add_files(path.join(root, "tests/backports/callgen/main.m"))
    add_files(path.join(calls, "Calls.m"))
    add_includedirs(path.join(root, "tests/backports/callgen"))
    add_mflags("-fobjc-arc", "-I" .. path.join(root, "tests/backports/callgen"))
    add_ldflags("-fobjc-arc", {force = true})
    add_frameworks("Foundation")
    if package then
        add_packages("apple-backports")
        set_values("revenant.libraries", "apple-backports")
        set_values("revenant.waive.weak-imports",
                   "measurement program, not a released image: it calls every member of the framework it is handed and forks once per member")
    end
    set_values("revenant.control", "control")

target("revenantcollection")
    add_rules("@addon/revenant/daemon")
    add_files(path.join(root, "tests/backports/emulate/calls/collection-port.m"))
    add_mflags("-fobjc-arc")
    add_ldflags("-fobjc-arc", {force = true})
    add_frameworks("Foundation")
    if package then
        add_packages("apple-backports")
        set_values("revenant.libraries", "apple-backports")
        set_values("revenant.waive.weak-imports",
                   "measurement program, not a released image: it calls one member of the framework it is handed")
    end
    set_values("revenant.control", "control")
