set_project("cryptoprobe")
set_version("0.0.1")
-- The armv7 probe of swift-crypto: libswiftCrypto.dylib run on the iOS 6.1.3 emulator, against the same source built for the host
-- against CryptoKit (main.swift: `swiftc -module-alias Crypto=CryptoKit`). Run from this folder:
--   xmake f -p iphoneos -a armv7 -y && xmake build -y cryptoprobe && xmake emulate -d iPhone4,1 -r 6.1.3 install
--   xmake emulate -d iPhone4,1 -r 6.1.3 run /usr/libexec/cryptoprobe rows 20261014
-- The package's patch lift-the-32-bit-refusal.patch removes upstream's 32-bit iOS refusal at its eight sites (HMAC.init, DH's
-- hkdfDerivedSymmetricKey, ECDSA's DER init and encoding for P-256/384/521), so the HMAC, HKDF, DH-HKDF, ECDSA DER and HPKE rows
-- run here. `nohmac` (rows) skips the HMAC, HKDF and DH-HKDF rows on both sides, as before the lift.
-- The package exports its module folder and its dylib link, and apple-compat's include root and CharonCompat (the Crypto module
-- imports CharonCompat, whose shims include <charon/...>).
local root = path.join(os.scriptdir(), "../../../../..")
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

target("cryptoprobe")
    add_rules("@addon/charon/daemon", "@addon/charon/swift")
    add_files("main.swift")
    add_packages("swift-crypto", "swift-runtime", "libcxx", "apple-backports", "apple-compat")
    set_values("charon.version", "1.0")
    set_values("charon.control", "control")
    -- The program carries the libraries it links.
    set_values("charon.libraries", "swift-crypto", "apple-backports")
