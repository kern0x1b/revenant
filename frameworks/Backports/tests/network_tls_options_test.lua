local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local src = path.join(backports, "src", "Network")
local security = path.join(backports, "src", "Security")
local fixture = path.join(backports, "tests", "Network", "tlsoptions", "main.swift")
local securityObjects = {"SecProtocolOptions13_0.m", "SecProtocolMetadata13_0.m", "SecObjectWrappers12_0.m", "SecObjectWrappersIdentity12_0.m"}

local expected = table.concat({
    "verify-accept ready",
    "verify-reject waiting tls=-9807",
    "pin-match ready leaf=match",
    "pin-mismatch waiting tls=-9807 leaf=mismatch",
    "cipher-allowed ready cipher=ECDHE-RSA-AES128-GCM-SHA256",
    "cipher-refused failed tls=-9824 cipher=none",
    "ocsp ready",
    "sct ready",
    "challenge-identity ready",
    "challenge-none failed tls=-9824",
    "psk-client ready cipher=ECDHE-PSK-AES128-CBC-SHA",
    "dh-refused failed tls=-9848",
    "cipher-unknown failed tls=-9818",
    "psk-wrong-key failed tls=-9846",
    "group-default-no-shared failed tls=-9824 cipher=none",
    "group-compatibility-allowed ready cipher=AES128-SHA",
    "group-legacy-refused failed tls=-9818",
    "psk-server ready cipher=ECDHE-PSK-AES128-CBC-SHA",
    "psk-server-wrong-key failed cipher=ECDHE-PSK-AES128-CBC-SHA",
    "psk-server-static-refused failed cipher=(NONE)",
}, "\n") .. "\n"

local function swiftc(args)
    os.vrunv("xcrun", table.join({"swiftc", "-O"}, args))
end

local function clang(args)
    os.vrunv("xcrun", table.join({"clang"}, args))
end

function main()
    local out = workspace.run("backports-tests", "NetworkTLSOptions")
    local boringssl = workspace.package_of("boringssl", true)
    assert(os.isfile(path.join(boringssl, "include", "openssl", "err.h")), "the macOS BoringSSL install has no headers: " .. boringssl)
    local openssl = os.getenv("REVENANT_OPENSSL") or "/opt/homebrew/opt/openssl@3/bin/openssl"
    assert(os.isfile(openssl), "the OpenSSL server for the TLS options test is missing: " .. openssl)
    local authority, authorityKey = path.join(out, "ca.pem"), path.join(out, "ca.key")
    local certificate, key = path.join(out, "cert.pem"), path.join(out, "key.pem")
    local clientCertificate, clientKey = path.join(out, "client.pem"), path.join(out, "client.key")
    local leaf, identity = path.join(out, "leaf.der"), path.join(out, "identity.p12")
    local serverExtensions, clientExtensions = path.join(out, "server.ext"), path.join(out, "client.ext")
    io.writefile(serverExtensions, "subjectAltName=DNS:localhost,IP:127.0.0.1\nextendedKeyUsage=serverAuth\n")
    io.writefile(clientExtensions, "extendedKeyUsage=clientAuth\n")
    os.vrunv(openssl, {"req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", authorityKey, "-out", authority, "-days", "2",
                       "-subj", "/CN=Revenant TLS options test CA", "-addext", "basicConstraints=critical,CA:TRUE",
                       "-addext", "keyUsage=critical,keyCertSign,cRLSign"})
    os.vrunv(openssl, {"req", "-newkey", "rsa:2048", "-nodes", "-keyout", key, "-out", path.join(out, "server.csr"), "-subj", "/CN=localhost"})
    os.vrunv(openssl, {"x509", "-req", "-in", path.join(out, "server.csr"), "-CA", authority, "-CAkey", authorityKey, "-CAcreateserial",
                       "-days", "2", "-extfile", serverExtensions, "-out", certificate})
    os.vrunv(openssl, {"req", "-newkey", "rsa:2048", "-nodes", "-keyout", clientKey, "-out", path.join(out, "client.csr"), "-subj", "/CN=revenant-client"})
    os.vrunv(openssl, {"x509", "-req", "-in", path.join(out, "client.csr"), "-CA", authority, "-CAkey", authorityKey, "-CAcreateserial",
                       "-days", "2", "-extfile", clientExtensions, "-out", clientCertificate})
    os.vrunv(openssl, {"x509", "-in", certificate, "-outform", "DER", "-out", leaf})
    os.vrunv(openssl, {"pkcs12", "-export", "-inkey", clientKey, "-in", clientCertificate, "-certfile", authority, "-out", identity,
                       "-passout", "pass:revenant", "-keypbe", "PBE-SHA1-3DES", "-certpbe", "PBE-SHA1-3DES", "-macalg", "sha1"})

    local engine = path.join(out, "RevenantTLSEngine.o")
    clang({"-c", "-fobjc-arc", "-Wno-deprecated-declarations", "-I" .. path.join(boringssl, "include"), path.join(src, "RevenantTLSEngine.m"), "-o", engine})
    local objects = {engine}
    for _, file in ipairs(securityObjects) do
        local object = path.join(out, path.basename(file) .. ".o")
        clang({"-c", "-fobjc-arc", "-Wno-deprecated-declarations", path.join(security, file), "-o", object})
        table.insert(objects, object)
    end
    local backport = path.join(out, "backport")
    swiftc(table.join({"-D", "REVENANT_BACKPORT", "-I", path.join(src, "RevenantTLS"), "-Xcc", "-I" .. path.join(boringssl, "include")},
                      os.files(path.join(src, "*.swift")),
                      {fixture},
                      objects,
                      {path.join(boringssl, "lib", "libssl.a"), path.join(boringssl, "lib", "libcrypto.a"), "-lc++", "-o", backport}))
    os.execv(backport, {openssl, certificate, key, identity, leaf, authority}, {stdout = backport .. ".out"})
    local got = io.readfile(backport .. ".out")
    assert(got == expected, "the backport TLS options differ from the expected outcomes in " .. out .. ":\n" .. got)
end
