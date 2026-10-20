package("firmware-tools")
    set_kind("binary")
    set_homepage("https://github.com/kern0x1b/revenant/tree/main/toolchain")
    set_description("revenant-firmware: decrypts the FileVault root filesystem images of iOS 2 to 9 with CommonCrypto and unwraps the wkms key of iOS 18's Apple Encrypted Archives with CryptoKit's HPKE, for the system's aea to decrypt")
    set_license("MIT")

    local digests = {}
    for _, file in ipairs(os.files(path.join(os.scriptdir(), "src", "*"))) do
        table.insert(digests, path.filename(file) .. "=" .. hash.sha256(file))
    end
    table.sort(digests)
    add_configs("sources", {description = "The digest of the tool's sources, so a changed source is a different package.", default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    on_install("@macosx", function (package)
        os.mkdir(package:installdir("bin"))
        os.vrunv("xcrun", {"swiftc", "-O", path.join(package:scriptdir(), "src", "revenant-firmware.swift"), "-o", path.join(package:installdir("bin"), "revenant-firmware")})
        os.vcp(path.join(package:scriptdir(), "..", "..", "..", "toolchain", "LICENSE"), package:installdir("licenses"))
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("bin"), "revenant-firmware")))
    end)
