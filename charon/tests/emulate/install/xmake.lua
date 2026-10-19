set_project("charonemulateinstall")
set_version("0.1")
-- One target, one control, and nothing else in the project: this is the smallest thing an install can be
-- asked to put in, so what is missing from the image after an install is the install's doing and not the
-- project's. The image is this project's alone, under the emulator root, keyed by this directory.
add_repositories("charon " .. (os.getenv("CHARON_REPO") or "https://github.com/kern0x1b/charon.git"))
add_addons("charon " .. (os.getenv("CHARON_ADDON") or "v0.8.13"))
set_config("apple_minimum", "6.1.3")
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")
set_allowedplats("iphoneos")
set_allowedarchs("iphoneos|armv7")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

target("emulateinstall")
    add_rules("@addon/charon/daemon")
    add_files("main.m")
    add_frameworks("Foundation")
    set_values("charon.control", "control")
