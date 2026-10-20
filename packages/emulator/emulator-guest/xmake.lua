package("emulator-guest")
    set_homepage("https://github.com/kern0x1b/revenant/tree/main/toolchain")
    set_description("revenant-runner, the daemon that starts a test inside an emulated device and writes its verdict, and revenant-sblaunch, which has SpringBoard launch an application, built by Revenant's own rules for the port's architecture and minimum release")
    set_license("MIT")

    local digests = {}
    local sources = table.join(os.files(path.join(os.scriptdir(), "src", "*")), {path.join(os.scriptdir(), "project.lua")})
    table.sort(sources)
    for _, file in ipairs(sources) do
        table.insert(digests, path.filename(file) .. "=" .. hash.sha256(file))
    end
    add_configs("sources", {description = "The digest of the guest programs' sources and project, so a changed source is a different package.", default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    on_install("iphoneos", function (package)
        local toolchain = assert(package:toolchains(), "emulator-guest is built with the apple-ios toolchain")[1]
        toolchain:load()
        import("core.package.addon")
        local revenant = addon.addons()[addon.dirname("revenant")] or raise("emulator-guest is built with the revenant addon's rules, and no revenant addon is installed")
        local project = path.absolute("guest")
        os.mkdir(project)
        os.cp(path.join(package:scriptdir(), "src", "*"), project .. "/")
        local template = io.readfile(path.join(package:scriptdir(), "project.lua"))
        io.writefile(path.join(project, "xmake.lua"), (template:gsub("@(%w+)@", {
            repository = path.translate(path.join(package:scriptdir(), "..", "..", "..")),
            minimum = toolchain:config("deployment"),
            arch = package:arch()
        })))
        io.save(path.join(project, "xmake-addons.lock"), {__meta__ = {version = "1.0"}, revenant = {version = revenant.version}})
        local argv = {"-P", project, "-y"}
        os.vrunv(os.programfile(), table.join({"f", "-p", "iphoneos", "-a", package:arch(), "-m", "release"}, argv))
        os.vrunv(os.programfile(), table.join({"build"}, argv), {envs = {REVENANT_RELEASE = "1"}})
        os.vrunv(os.programfile(), table.join({"install", "-o", package:installdir()}, argv))
        os.vcp(path.join(package:scriptdir(), "..", "..", "..", "toolchain", "LICENSE"), package:installdir("licenses"))
    end)

    on_test(function (package)
        for _, name in ipairs({"revenant-runner", "revenant-sblaunch"}) do
            assert(os.isfile(path.join(package:installdir(), "usr", "libexec", name)))
        end
    end)
