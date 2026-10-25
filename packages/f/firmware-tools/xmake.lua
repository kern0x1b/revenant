package("firmware-tools")
    set_kind("binary")
    set_homepage("https://github.com/kern0x1b/revenant/tree/main/toolchain")
    set_description("revenant-firmware: decrypts the FileVault root filesystem images of iOS 2 to 9 with CommonCrypto and unwraps the wkms key of iOS 18's Apple Encrypted Archives with CryptoKit's HPKE, for the system's aea to decrypt")
    set_license("MIT")

    local digests = {}
    for _, file in ipairs(os.files(path.join(os.scriptdir(), "..", "..", "..", "toolchain", "src", "firmware-tools", "src", "*"))) do
        table.insert(digests, path.filename(file) .. "=" .. hash.sha256(file))
    end
    table.sort(digests)
    add_configs("sources", {description = "The digest of the tool's sources, so a changed source is a different package.", default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    on_install("@macosx", function (package)
        local root = path.translate(path.join(os.scriptdir(), "..", "..", ".."))
        local project = path.absolute("project")
        os.mkdir(project)
        io.writefile(path.join(project, "xmake.lua"), table.concat({
            "set_project(\"firmware-tools\")",
            "set_xmakever(\"3.1.2\")",
            "add_rules(\"mode.release\", \"mode.debug\")",
            "set_defaultmode(\"release\")",
            "option(\"component\", {type = \"string\", default = \"\"})",
            "includes(\"" .. import("@addon.revenant.data", {anonymous = true}).src("firmware-tools") .. "\")",
            ""}, "\n"))
        os.vrunv(os.programfile(), {"f", "-P", project, "-p", "macosx", "-a", "arm64", "-m", "release", "-y"}, {curdir = project})
        os.vrunv(os.programfile(), {"build", "-P", project, "-y", "revenant-firmware"}, {curdir = project})
        os.vrunv(os.programfile(), {"install", "-P", project, "-y", "-o", package:installdir(), "revenant-firmware"}, {curdir = project})
        os.vcp(import("@addon.revenant.data", {anonymous = true}).licence(), package:installdir("licenses"))
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("bin"), "revenant-firmware")))
    end)
