set_project("shearprobe")
set_version("0.1.0")
-- The port's integer shear engine against the 6.1.3 release's own ARGB8888 shear, on the emulated iPhone3,1
-- 6.1.3 guest. WHY IT IS ITS OWN PROJECT, like vdsp-probe and metalchain-probe: a case has to be something
-- `xmake emulate install` can put in the image, which means a target with a control file and a daemon rule and
-- not a source file in tests/backports/device/.
--
-- THE PORT'S OWN HEADERS ARE COMPILED IN, and the reason is the measurement, not the packaging: the whole
-- question is which `(phase, base)` pair each destination sample reads, and the pair the port computes is
-- `CharonResampleFilterOf` + `CharonShearReady` + `CharonShearRun` - the three calls a band file makes and
-- nothing else (vImageShear70.m:6). Compiling the headers is what puts the port's own arithmetic on the
-- guest's own arithmetic; requiring the .deb instead would test the packaging and not the question, and the
-- package does not resolve on this machine today anyway (metalchain-probe's xmake.lua, measured 2026-10-04:
-- every project that requires it fails at configure with "attempt to call a nil value (global
-- 'add_configs')", which is the shared store's state and not this project's shape).
--
-- WHAT THAT COSTS, said plainly: this probe does not test the .deb, so it cannot catch a packaging defect.
-- It tests the exact source the library compiles.
--
-- Accelerate IS a device framework on 6.1.3 and Foundation is needed for nothing here; the probe is plain C
-- and takes no command-line arguments, because on this guest `xmake emulate run` is given a bare path and
-- anything after it answers "fail(spawn error 2)" (coordinator, measured on the v-crutch5 runs of 2026-10-04).
local root = os.getenv("SHEARPROBE_ROOT") or path.join(os.scriptdir(), "../../../..")
add_repositories("charon " .. root)
-- The HIGHEST add_versions of the addon recipe, and naming a version below it installs that one and makes it
-- the machine's active addon for every session (AGENTS.md, "A working copy installed as the addon"). The
-- recipe's newest is v0.8.14; a lock file left by another band naming its own worktree is stale and is not
-- read: this .gitignore keeps the lock out of the tree and xmake rewrites it.
add_addons("charon v0.8.14")
local minimum = os.getenv("SHEARPROBE_MINIMUM") or "6.1.3"
set_config("apple_minimum", minimum)
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

target("shear-probe")
    add_rules("@addon/charon/daemon")
    add_files(path.join(root, "tests/backports/device/shearprobe/shearprobe.m"))
    -- ONLY the port's own Accelerate folder is on the include path, and the port's objects reach their own
    -- headers by clang's quoted-include rule from their own folder, so nothing else can pick a name up out of
    -- it. shearprobe.m needs those four headers and nothing else does.
    add_includedirs(path.join(root, "packages/a/apple-backports/Accelerate"))
    add_frameworks("Accelerate")
    add_mflags("-fobjc-arc")
    add_ldflags("-fobjc-arc", {force = true})
    set_values("charon.control", "control")
