-- The port xmake emulate installs and launches: Eidolon's demo application and its engine tests, as
-- packages, so the emulator image carries them and SpringBoard lists the application by its identifier.
-- The SwiftUI module itself is charon@eidolon, which builds it from this repository's pinned commit.
set_project("eidolon")
set_version("0.1")
-- The packages come from charon's released repository, so a build of this port is a build of released
-- packages. CHARON_REPO names a checkout instead, and that is a band's own business: xmake resolves
-- the packages out of it and installs them into the shared store beside everyone's, where they are a
-- different package from the released ones (a recipe digest is in the key) and every other band then
-- reads that tree's. Nothing outside a band should set it, and a build that set it and then failed
-- must not be left running: it holds the shared package lock while it waits for the next one.
add_repositories("charon " .. (os.getenv("CHARON_REPO") or "https://github.com/kern0x1b/charon.git"))
add_addons("charon " .. (os.getenv("CHARON_ADDON") or "v0.8.16"))
set_config("apple_minimum", "6.0")
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")
set_allowedplats("iphoneos")
set_allowedarchs("iphoneos|armv7")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

-- The runtime the port carries, built with the backports: the runtime's overlays and Styx weakly import
-- later API that only the library answers, and a runtime built so hands its lifted headers to the port,
-- which then has to carry the library as well. One build of each: charon@eidolon passes these configs on
-- to the runtime and Styx, so the port declares the same ones or it would get a second build of each.
add_requires("charon@swift-runtime", {alias = "swift-runtime", configs = {backports = true}})
add_requires("charon@libcxx", {alias = "libcxx"})
add_requires("charon@styx", {alias = "styx", configs = {backports = true}})
add_requires("charon@eidolon", {alias = "swiftui", configs = {backports = true}})
add_requires("charon@apple-backports", {alias = "apple-backports", configs = {coredata = true, uikit = true}})

-- Every weak import the program and the runtime it carries make is answered behind a check: the
-- runtime's overlays are compiled with availability checking on, so a call to later API stands behind
-- #available, and Styx's own _CFRunLoopTimerSetTolerance is answered by the backports this program
-- carries. Stated once so each target does not repeat it.
--
-- Unmeasured, and said so: the check that would remove this waiver runs after the link, and this
-- port is not linked yet - the packages it takes are in no released repository, so a build of it
-- resolves them from a checkout into the shared store, which is not this repository's to do. What
-- the waiver claims is what apple.runtime_guards records for the runtime and what the backports
-- answer for Styx; a build without it either confirms that and the waiver goes, or names a weak
-- import the table does not record, which is a row the table is missing.
-- Inside a target() scope xmake binds that target's API as globals and there is no `self` - measured,
-- `self` in a target scope is nil - so a helper that took the target was handed nil and indexed it. The
-- scope's own add_values is what can be handed over instead: it is already bound to this target, so the
-- sentence is written once and every target gets it.
local function eidolon_weak_import_waiver(add_values)
    add_values("charon.waive.weak-imports",
               "every weak import is reached only behind #available or carried by the backports: the runtime's overlays built with availability checking on, Styx's run-loop timer tolerance, compiler-rt's version check")
end

target("EidolonDemo")
    add_rules("@addon/charon/app", "@addon/charon/swift")
    add_files("Demo/*.swift")
    add_files("Demo/device/gesture.m")
    add_includedirs("Demo/device")
    add_packages("swiftui", "apple-backports")
    add_frameworks("UIKit", "Foundation", "CoreGraphics", "QuartzCore", "CoreData")
    set_values("swift.flags", "-import-objc-header", path.join(os.scriptdir(), "Demo", "device", "bridge.h"))
    set_optimize("fastest")
    set_values("app.plist-file", "Info.plist")
    set_values("app.plist", "CFBundleIdentifier=space.kern0x1b.eidolon.demo", "CFBundleDisplayName=Eidolon")
    -- Naming the backports switches verify_placed to the branch that copies the library in.
    set_values("charon.libraries", "apple-backports")
    set_values("charon.control", "control")
    eidolon_weak_import_waiver(add_values)

-- The same program as a second bundle. The scenarios need a key window and SpringBoard's own lifecycle,
-- so they are the application that renders them; what tells it to is a key of its own Info.plist, which
-- is where a port says what it wants in the guest.
target("EidolonSnapshots")
    add_rules("@addon/charon/app", "@addon/charon/swift")
    add_files("Demo/*.swift")
    add_files("Demo/device/gesture.m")
    add_includedirs("Demo/device")
    add_packages("swiftui", "apple-backports")
    add_frameworks("UIKit", "Foundation", "CoreGraphics", "QuartzCore", "CoreData")
    set_values("swift.flags", "-import-objc-header", path.join(os.scriptdir(), "Demo", "device", "bridge.h"))
    set_optimize("fastest")
    set_values("app.plist-file", "Info.plist")
    set_values("app.plist", "CFBundleIdentifier=space.kern0x1b.eidolon.snapshots", "CFBundleDisplayName=EidolonSnapshots", "EidolonSnapshots=YES", "EidolonSnapshotImages=YES")
    -- One scenario, for a while working on it: EIDOLON_SNAPSHOT_ONLY names it at configure time.
    local only = os.getenv("EIDOLON_SNAPSHOT_ONLY")
    if only and only ~= "" then
        add_values("app.plist", "EidolonSnapshotOnly=" .. only)
    end
    set_values("charon.libraries", "apple-backports")
    set_values("charon.control", "control")
    eidolon_weak_import_waiver(add_values)

-- The engine tests: one binary and no UIApplication, so xmake emulate run starts it as the guest's first
-- process and its verdict is the exit status.
target("EidolonTests")
    add_rules("@addon/charon/daemon", "@addon/charon/swift")
    add_files("Tests/*.swift")
    add_packages("swiftui", "apple-backports")
    add_frameworks("UIKit", "Foundation", "CoreGraphics", "QuartzCore", "CoreData")
    set_optimize("fastest")
    -- The tests are the one program compiled with availability checking off, as eidolon/build.sh has
    -- always compiled them: they call iOS 7+ API on purpose, to check what Eidolon does with it.
    set_values("swift.flags", "-disable-availability-checking")
    set_values("charon.libraries", "apple-backports")
    set_values("charon.control", "control-tests")
    eidolon_weak_import_waiver(add_values)
