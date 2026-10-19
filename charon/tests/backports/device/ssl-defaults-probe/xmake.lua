set_project("ssldefaultsprobe")
set_version("0.1.0")
-- A measurement program, not a port: it asks the RELEASE what its own stack negotiates by default, so it
-- links the release and NOT charon@apple-backports. Asking the backport for its defaults would answer
-- the port's own constants with the port's own constants, which is the measurement this exists to avoid.
local root = os.getenv("SSLDEFAULTS_ROOT") or path.join(os.scriptdir(), "../../../..")
add_repositories("charon " .. root)
add_addons("charon v0.8.11")
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")
local minimum = os.getenv("SSLDEFAULTS_MINIMUM") or "6.1.3"
set_config("apple_minimum", minimum)
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

target("ssl-defaults-probe")
    add_rules("@addon/charon/daemon")
    add_files(path.join(root, "tests/backports/device/ssl-defaults-probe.m"))
    add_mflags("-fobjc-arc")
    add_ldflags("-fobjc-arc", {force = true})
    add_frameworks("Foundation", "Security", "CoreFoundation")
    set_values("charon.control", "control")
