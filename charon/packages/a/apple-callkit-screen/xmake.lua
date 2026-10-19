package("apple-callkit-screen")
    set_homepage("https://github.com/kern0x1b/charon")
    set_description("charon-callkit-screen, the MobileSubstrate tweak that raises the system call screen for the CallKit backport, filtered to com.apple.springboard, built by Charon's own tweak rule")
    set_license("MIT")

    local digests = {}
    local sources = table.join(os.files(path.join(os.scriptdir(), "src", "*")), {path.join(os.scriptdir(), "project.lua")})
    table.sort(sources)
    for _, file in ipairs(sources) do
        table.insert(digests, path.filename(file) .. "=" .. hash.sha256(file))
    end
    add_configs("sources", {description = "The digest of the tweak's sources and project, so a changed source is a different package.", default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    on_install("iphoneos", function (package)
        local toolchain = assert(package:toolchains(), "apple-callkit-screen is built with the apple-ios toolchain")[1]
        toolchain:load()
        import("core.package.addon")
        local charon = addon.addons()[addon.dirname("charon")] or raise("apple-callkit-screen is built with the charon addon's rules, and no charon addon is installed")
        local project = path.absolute("tweak")
        os.mkdir(project)
        os.cp(path.join(package:scriptdir(), "src", "*"), project .. "/")
        local template = io.readfile(path.join(package:scriptdir(), "project.lua"))
        io.writefile(path.join(project, "xmake.lua"), (template:gsub("@(%w+)@", {
            repository = path.translate(path.join(package:scriptdir(), "..", "..", "..")),
            minimum = toolchain:config("deployment"),
            arch = package:arch()
        })))
        io.save(path.join(project, "xmake-addons.lock"), {__meta__ = {version = "1.0"}, charon = {version = charon.version}})
        local argv = {"-P", project, "-y"}
        os.vrunv(os.programfile(), table.join({"f", "-p", "iphoneos", "-a", package:arch(), "-m", "release"}, argv))
        os.vrunv(os.programfile(), table.join({"build"}, argv), {envs = {CHARON_RELEASE = "1"}})
        os.vrunv(os.programfile(), table.join({"install", "-o", package:installdir()}, argv))
        os.vcp(path.join(package:scriptdir(), "..", "..", "..", "LICENSE"), package:installdir("licenses"))
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir(), "Library", "MobileSubstrate", "DynamicLibraries", "charon-callkit-screen.dylib")))
        assert(os.isfile(path.join(package:installdir(), "Library", "MobileSubstrate", "DynamicLibraries", "charon-callkit-screen.plist")))
    end)
