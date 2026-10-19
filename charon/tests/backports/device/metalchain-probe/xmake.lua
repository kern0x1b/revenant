set_project("metalchainprobe")
set_version("0.1.0")
-- The Metal 4 command chain on the emulated iPhone3,1 6.1.3 guest, against the answers Apple's own Metal
-- gave on the host and which are written down in tests/backports/device/metalchain-expectations.h.
--
-- WHY IT IS ITS OWN PROJECT, like vdsp-probe and textkit2: a case has to be something
-- `xmake emulate install` can put in the image, and that means a target with a control file and a
-- daemon rule - not a source file in tests/backports/device/.
--
-- THE PORT'S METAL SOURCES ARE COMPILED IN, and the reason is measured, not stylistic. The shape that
-- would link the library instead - add_requires("charon@apple-backports", {configs = {metal = true}})
-- with add_packages and charon.libraries, the shape tests/backports/device/textkit2 and
-- tests/backports/host/coreml/emulate use - DOES NOT RESOLVE on this machine today: every project that
-- requires the package fails at configure with
--     error: attempt to call a nil value (global 'add_configs')
-- which is xmake 3.1.1 loading packages/a/apple-backports/xmake.lua (69 add_configs calls, line 48 on)
-- and reaching for a package-scope API it has not bound. Measured on 2026-10-04, and it is not this
-- project's shape: the same require in a project of four lines fails the same way, and the same four
-- lines pass an hour later with nothing in the tree changed, so the state that decides it is the shared
-- store's and not the file. The coordinator saw the sibling form of it as "every package not found"
-- (QUEUE, v-crutch5, 2026-10-04). What is built here instead is the port's own Metal folder - every
-- packages/a/apple-backports/Metal/*.m, 59 files and the probe, 60 objects - so the answers come from
-- the code in this tree and a reader can see exactly which files are under test.
--
-- WHAT THAT COSTS, said plainly: the probe does not test the .deb, so it cannot catch a packaging
-- defect. It tests every object the library carries, because it is those same objects.
--
-- FRAMEWORKS: Foundation, QuartzCore, OpenGLES and CoreGraphics - and NOT Metal. libMetalBackports
-- declares QuartzCore, CoreGraphics, OpenGLES and Foundation and does not declare Metal
-- (modules/apple/backports.lua:73), because on this release this port IS Metal; a program that also
-- asked the SDK for Metal.framework would be held by the import check to a framework 6.1.3 has not got.
local root = os.getenv("METALCHAINPROBE_ROOT") or path.join(os.scriptdir(), "../../../..")
add_repositories("charon " .. root)
add_addons("charon v0.8.13")
local minimum = os.getenv("METALCHAINPROBE_MINIMUM") or "6.1.3"
set_config("apple_minimum", minimum)
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

target("metalchain-probe")
    add_rules("@addon/charon/daemon")
    add_files(path.join(root, "tests/backports/device/metalchain-probe/metalchain.m"))
    add_files(path.join(root, "packages/a/apple-backports/Metal/*.m"))
    add_frameworks("Foundation", "QuartzCore", "OpenGLES", "CoreGraphics")
    -- ONLY THE DEVICE FOLDER IS ON THE INCLUDE PATH, and that is the whole of it: every port object
    -- reaches its own headers by clang's quoted-include rule, which looks in the including file's own
    -- folder, so no Metal object can pick a name up out of another folder. metalchain.m needs the device
    -- folder for metalchain-expectations.h and nothing else does.
    add_includedirs(path.join(root, "tests/backports/device"))
    add_mflags("-fobjc-arc")
    add_ldflags("-fobjc-arc", {force = true})
    set_values("charon.control", "control")