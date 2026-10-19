set_project("seckeyecraw")
set_version("0.0.1")
-- The probe of tests/backports/device/seckey-ecraw.m, built for the release and run in the emulator
-- with `xmake emulate -d iPhone4,1 -r 6.1.3 run /usr/libexec/seckeyecraw`. It needs no package of this
-- repository's: it asks the release's own Security what it does with an elliptic key, which is what
-- facts/Security/SecKeyElliptic.md's release side is read from.
add_repositories("charon https://github.com/kern0x1b/charon.git charon-repo-0.8.10")
add_addons("charon v0.8.10")
set_config("apple_minimum", "6.1.3")
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")
set_allowedplats("iphoneos")
set_allowedarchs("iphoneos|armv7")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

local root = os.getenv("SECKEYECRAW_ROOT") or path.join(os.scriptdir(), "../../../../../..")
target("seckeyecraw")
    add_rules("@addon/charon/daemon")
    add_files(path.join(root, "tests/backports/device/seckey-ecraw.m"))
    add_mflags("-fobjc-arc", "-Wno-deprecated-declarations")
    add_ldflags("-fobjc-arc")
    add_frameworks("Security", "Foundation")
    add_syslinks("dl")
    set_values("charon.version", "1.0")
    set_values("charon.control", "seckey-ecraw")
