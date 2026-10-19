set_project("cryptoextrasprobe")
set_version("0.0.1")
-- The armv7 probe of what _CryptoExtras carries (RSA, AES-CBC, AES-CTR, AES-GCM-SIV, ChaCha20 CTR, PBKDF2, Scrypt) and of the
-- AES key wrap of Crypto: libswiftCrypto.dylib run on the iOS 6.1.3 emulator, against the same source built for the host against
-- upstream swift-crypto 5.0.1 (main.swift's host twin is the oracle; both print the same "P| " lines when the module agrees).
-- Run from this folder:
--   xmake f -P . -p iphoneos -a armv7 -y && xmake build -P . -y cryptoextrasprobe && xmake emulate -d iPhone4,1 -r 6.1.3 install
--   xmake emulate -d iPhone4,1 -r 6.1.3 run /usr/libexec/cryptoextrasprobe rows
-- The package exports its module folder and its dylib link, and apple-compat's include root and CharonCompat (the Crypto module
-- imports CharonCompat, whose shims include <charon/...>).
local root = path.absolute(path.join(os.scriptdir(), "../../../../.."))
add_repositories("charon " .. root)
add_addons("charon v0.8.17")
add_requires("charon@swift-crypto", {alias = "swift-crypto"})
add_requires("charon@swift-runtime", {alias = "swift-runtime", configs = {backports = true}})
add_requires("charon@libcxx", {alias = "libcxx"})
add_requires("charon@apple-backports", {alias = "apple-backports", configs = {coredata = true, commoncrypto = true}})
add_requires("charon@apple-compat", {alias = "apple-compat"})
set_config("apple_minimum", "6.1.3")
set_config("apple_backports", "coredata,commoncrypto")
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")
set_allowedplats("iphoneos")
set_allowedarchs("iphoneos|armv7")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

target("cryptoextrasprobe")
    add_rules("@addon/charon/daemon", "@addon/charon/swift")
    add_files("main.swift")
    add_packages("swift-crypto", "swift-runtime", "libcxx", "apple-backports", "apple-compat")
    set_values("charon.version", "1.0")
    set_values("charon.control", "control")
    -- The program carries the libraries it links.
    set_values("charon.libraries", "swift-crypto", "apple-backports")
