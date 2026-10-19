set_project("entropyprobe")
set_version("0.0.1")
-- The guest's random sources on the armv7 iOS 6.1.3 emulator (entropy.c): SecRandomCopyBytes, CCRandomGenerateBytes from
-- libCommonCryptoBackports, CCRandomCopyBytes, and reads of /dev/random and /dev/urandom, in one process per run. Run from this
-- folder, once per boot (each `run` boots the image afresh):
--   xmake f -p iphoneos -a armv7 -y && xmake build -y entropyprobe && xmake emulate -d iPhone4,1 -r 6.1.3 install
--   xmake emulate -d iPhone4,1 -r 6.1.3 run /usr/libexec/entropyprobe 2
local root = path.join(os.scriptdir(), "../../../../..")
add_repositories("charon " .. root)
add_addons("charon v0.8.17")
add_requires("charon@apple-backports", {alias = "apple-backports", configs = {commoncrypto = true}})
set_config("apple_minimum", "6.1.3")
set_config("apple_backports", "commoncrypto")
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")
set_allowedplats("iphoneos")
set_allowedarchs("iphoneos|armv7")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

target("entropyprobe")
    add_rules("@addon/charon/daemon")
    add_files("entropy.c")
    add_packages("apple-backports")
    add_frameworks("Security")
    set_values("charon.version", "1.0")
    set_values("charon.control", "control")
    set_values("charon.libraries", "apple-backports")
