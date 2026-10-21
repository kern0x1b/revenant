package("emulator-guest")
    set_homepage("https://github.com/kern0x1b/revenant/tree/main/toolchain")
    set_description("revenant-runner, the daemon that starts a test inside an emulated device and writes its verdict, and revenant-sblaunch, which has SpringBoard launch an application, built by Revenant's own rules for the port's architecture and minimum release")
    set_license("MIT")

    local digests = {}
    local sources = os.files(path.join(os.scriptdir(), "..", "..", "..", "emulator", "src", "guest", "*"))
    table.sort(sources)
    for _, file in ipairs(sources) do
        table.insert(digests, path.filename(file) .. "=" .. hash.sha256(file))
    end
    add_configs("sources", {description = "The digest of the guest programs' sources, so a changed source is a different package.", default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    on_install("iphoneos", function (package)
        local toolchain = assert(package:toolchains(), "emulator-guest is built with the apple-ios toolchain")[1]
        toolchain:load()
        import("core.package.addon")
        local revenant = addon.addons()[addon.dirname("revenant")] or raise("emulator-guest is built with the revenant addon's rules, and no revenant addon is installed")
        local root = path.translate(path.join(package:scriptdir(), "..", "..", ".."))
        local project = path.absolute("guest")
        os.mkdir(project)
        io.writefile(path.join(project, "xmake.lua"), table.concat({
            "add_repositories(\"revenant " .. root .. "\")",
            "add_addons(\"revenant\")",
            "set_config(\"apple_minimum\", \"" .. toolchain:config("deployment") .. "\")",
            "includes(\"@addon/revenant/apple-ios\")",
            "option(\"component\", {type = \"string\", default = \"\"})",
            "includes(\"" .. path.join(root, "emulator", "src", "guest") .. "\")",
            "set_defaultplat(\"iphoneos\")",
            "set_defaultarchs(\"iphoneos|" .. package:arch() .. "\")",
            ""}, "\n"))
        io.save(path.join(project, "xmake-addons.lock"), {__meta__ = {version = "1.0"}, revenant = {version = revenant.version}})
        os.vrunv(os.programfile(), {"f", "-p", "iphoneos", "-a", package:arch(), "-m", "release", "-y"}, {curdir = project})
        os.vrunv(os.programfile(), {"build", "-y", "revenant-runner", "revenant-sblaunch"}, {curdir = project, envs = {REVENANT_RELEASE = "1"}})
        os.vrunv(os.programfile(), {"install", "-y", "-o", package:installdir(), "revenant-runner", "revenant-sblaunch"}, {curdir = project})
        os.vcp(path.join(root, "toolchain", "LICENSE"), package:installdir("licenses"))
    end)

    on_test(function (package)
        for _, name in ipairs({"revenant-runner", "revenant-sblaunch"}) do
            assert(os.isfile(path.join(package:installdir(), "usr", "libexec", name)))
        end
    end)
