set_project("maptable6")
set_version("0.0.1")
-- The working copy under test, named by probes.sh and emulate.sh (MAPTABLE6_ROOT); the addon is the tag in the store that
-- has plugins/emulate, which is the way the newest tests pin it (textdragdrop, textdragweak): a working copy of this
-- repository is never installed as the addon (charon/AGENTS.md, Traps), and the sources under test are named by path below.
local root = os.getenv("MAPTABLE6_ROOT") or path.join(os.scriptdir(), "../../../../..")
add_repositories("charon " .. root)
add_addons("charon v0.8.14")
set_config("apple_minimum", "4.3")
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")
set_allowedplats("iphoneos")
set_allowedarchs("iphoneos|armv7")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

-- differential.m as a device binary: the port, under names of its own, against the release's factories where the release
-- has them (6.0), and alone where it does not (4.3, 5.0, 5.1.1). One binary, built for the lowest release, runs on all four.
local source = os.getenv("MAPTABLE6_PORT")
if not source or source == "" then source = path.join(root, "packages/a/apple-backports/Foundation/NSMapTable+Objects6.m") end
local port = {defines = {"weakToStrongObjectsMapTable=charonHost_weakToStrongObjectsMapTable",
                         "strongToWeakObjectsMapTable=charonHost_strongToWeakObjectsMapTable",
                         "weakToWeakObjectsMapTable=charonHost_weakToWeakObjectsMapTable",
                         "strongToStrongObjectsMapTable=charonHost_strongToStrongObjectsMapTable"}}
target("maptable6")
    add_rules("@addon/charon/daemon")
    add_files(source, port)
    add_files(path.join(root, "tests/backports/host/maptable6/differential.m"),
              path.join(root, "tests/backports/device/check.m"))
    add_includedirs(path.join(root, "tests/backports/device"))
    add_mflags("-fobjc-arc", "-fvisibility=hidden", "-Wno-deprecated-declarations")
    -- The rounds of the two-thread check, as the build asks (MAPTABLE6_ROUNDS), for a longer stress than the default.
    if os.getenv("MAPTABLE6_ROUNDS") then add_defines("THREAD_ROUNDS=" .. os.getenv("MAPTABLE6_ROUNDS")) end
    add_ldflags("-fobjc-arc")
    add_frameworks("Foundation")
    set_values("charon.version", "1.0")
    set_values("charon.control", "control")

-- The probes the facts cite (probes/), built only when asked for: probes.sh sets MAPTABLE6_PROBES.
if os.getenv("MAPTABLE6_PROBES") then
    target("enumprobe")
        add_rules("@addon/charon/daemon")
        add_files(source, port)
        add_files(path.join(root, "tests/backports/host/maptable6/probes/enum.m"), path.join(root, "tests/backports/device/check.m"))
        add_includedirs(path.join(root, "tests/backports/device"))
        add_mflags("-fobjc-arc", "-fvisibility=hidden", "-Wno-deprecated-declarations")
        add_ldflags("-fobjc-arc")
        add_frameworks("Foundation")
        set_values("charon.version", "1.0")
        set_values("charon.control", "control-enum")
    target("weakprobe")
        add_rules("@addon/charon/daemon")
        add_files(path.join(root, "tests/backports/host/maptable6/probes/weak.m"))
        add_mflags("-fobjc-arc")
        add_ldflags("-fobjc-arc")
        add_frameworks("Foundation")
        set_values("charon.version", "1.0")
        set_values("charon.control", "control-weak")
    -- Whether the release's dispatch_resume calls a source's registration handler before it returns or only
    -- enqueues it, which the registration half of the barrier source entry rests on
    -- (coordination/crutches.md, "apple-compat: a barrier source handler below iOS 10").
    target("registrationprobe")
        add_rules("@addon/charon/daemon")
        add_files(path.join(root, "tests/backports/host/maptable6/probes/registration.m"))
        add_mflags("-fobjc-arc")
        add_ldflags("-fobjc-arc")
        add_frameworks("Foundation")
        set_values("charon.version", "1.0")
        set_values("charon.control", "control-weak")
    -- Whether arclite's own __weak on 4.3 is cleared before -dealloc, which is the measurement the 4.3
    -- paragraph of facts/Foundation/NSMapTable.md calls unmeasured.
    target("weakwindowprobe")
        add_rules("@addon/charon/daemon")
        add_files(path.join(root, "tests/backports/host/maptable6/probes/weakwindow.m"))
        add_mflags("-fobjc-arc")
        add_ldflags("-fobjc-arc")
        add_frameworks("Foundation")
        set_values("charon.version", "1.0")
        set_values("charon.control", "control-weak")
end
