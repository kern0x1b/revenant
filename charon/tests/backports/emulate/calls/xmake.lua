set_project("charoncalls")
set_version("0.0.1")
local root = os.getenv("CHARCALLS_ROOT") or path.join(os.scriptdir(), "../../../..")
add_repositories("charon " .. root)
add_addons("charon v0.8.13")
set_config("apple_minimum", os.getenv("CHARCALLS_MINIMUM") or "6.1.3")
local package = os.getenv("CHARCALLS_PACKAGE") ~= "0"
if package then
    add_requires("charon@apple-backports", {alias = "apple-backports", configs = {intents = true}})
end
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

local calls = os.getenv("CHARCALLS_GENERATED") or path.join(root, "tests/backports/emulate/calls/.agent-work/generated")

target("charoncalls")
    add_rules("@addon/charon/daemon")
    add_files(path.join(root, "tests/backports/callgen/harness.m"))
    add_files(path.join(root, "tests/backports/callgen/main.m"))
    add_files(path.join(calls, "Calls.m"))
    add_includedirs(path.join(root, "tests/backports/callgen"))
    add_mflags("-fobjc-arc", "-I" .. path.join(root, "tests/backports/callgen"))
    add_ldflags("-fobjc-arc", {force = true})
    add_frameworks("Foundation")
    if package then
        add_packages("apple-backports")
        set_values("charon.libraries", "apple-backports")
        set_values("charon.waive.weak-imports",
                   "measurement program, not a released image: it calls every member of the framework it is handed and forks once per member")
    end
    set_values("charon.control", "control")

target("charoncollection")
    add_rules("@addon/charon/daemon")
    add_files(path.join(root, "tests/backports/emulate/calls/collection-port.m"))
    add_mflags("-fobjc-arc")
    add_ldflags("-fobjc-arc", {force = true})
    add_frameworks("Foundation")
    if package then
        add_packages("apple-backports")
        set_values("charon.libraries", "apple-backports")
        set_values("charon.waive.weak-imports",
                   "measurement program, not a released image: it calls one member of the framework it is handed")
    end
    set_values("charon.control", "control")
