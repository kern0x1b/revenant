set_project("eidolonrt")
set_version("0.0.1")
add_repositories("charon " .. (os.getenv("CHARON_REPO") or "https://github.com/kern0x1b/charon.git"))
add_addons("charon latest")
set_config("apple_minimum", "6.0")
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")  -- after apple-ios: the emulator is shade, and this project is what `xmake emulate` installs into its image
set_allowedplats("iphoneos")
set_allowedarchs("iphoneos|armv7")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")
-- Built with the backports: Styx's own weak import (_CFRunLoopTimerSetTolerance) and the runtime's are answered by the library
-- the program carries, and the runtime built so hands its lifted headers to the port, which then has to carry it.
add_requires("charon@swift-runtime", {alias = "swift-runtime", configs = {backports = true}})
add_requires("charon@libcxx", {alias = "libcxx"})
add_requires("charon@styx", {alias = "styx", configs = {backports = true}})
add_requires("charon@apple-backports", {alias = "apple-backports", configs = {coredata = true}})
-- libc++ and the runtime link apple-compat, and the build scripts link it too: required here so `xmake where` names it
add_requires("charon@apple-compat", {alias = "apple-compat"})

target("eidolonrt")
    add_rules("@addon/charon/daemon", "@addon/charon/swift")
    add_packages("styx", "apple-backports")
    set_values("charon.libraries", "apple-backports")
    add_files("main.swift")
    add_frameworks("Foundation", "CoreData")
    set_values("charon.control", "control")
