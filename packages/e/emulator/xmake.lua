package("emulator")
    set_kind("binary")
    set_homepage("https://github.com/kern0x1b/revenant/tree/main/emulator")
    set_description("Revenant's emulator for an iPhone OS or iOS firmware's own userland: it boots the firmware over an emulated XNU on macOS arm64 hosts, for the devices and releases Revenant emulates. Provenance and required attribution in the emulator's NOTICE.")
    set_license("MPL-2.0")

    local root = path.translate(path.join(os.scriptdir(), "..", "..", ".."))
    includes(path.join(os.scriptdir(), "port", "sources.lua"))
    add_configs("sources", {description = "The digest of the emulator's sources in this checkout, so a changed source is a different emulator.", default = digest(root) or "", type = "string"})
    add_configs("sdl", {description = "Build the SDL2 window backend, for watching a guest on the desktop.", default = false, type = "boolean"})
    add_configs("ffmpeg", {description = "Build the FFmpeg audio decoder, for a guest that plays compressed audio.", default = false, type = "boolean"})

    on_install("macosx|arm64", function (package)
        local root = path.translate(path.join(package:scriptdir(), "..", "..", ".."))
        local project = path.absolute("project")
        os.mkdir(project)
        io.writefile(path.join(project, "xmake.lua"), table.concat({
            "set_project(\"emulator\")",
            "set_xmakever(\"3.1.2\")",
            "add_rules(\"mode.release\", \"mode.debug\")",
            "set_defaultmode(\"release\")",
            "option(\"component\", {type = \"string\", default = \"\"})",
            "add_repositories(\"revenant " .. root .. "\")",
            "includes(\"" .. path.join(root, "emulator") .. "\")",
            ""}, "\n"))
        local argv = {"-P", project, "-y"}
        os.vrunv(os.programfile(), table.join({"f", "-p", "macosx", "-a", "arm64", "-m", "release",
                                               "--emulator_sdl=" .. (package:config("sdl") and "y" or "n"),
                                               "--emulator_ffmpeg=" .. (package:config("ffmpeg") and "y" or "n")}, argv))
        os.vrunv(os.programfile(), table.join({"build"}, argv, {"emulator"}))
        os.vrunv(os.programfile(), table.join({"install", "-o", package:installdir()}, argv, {"emulator"}))
        local binary = path.join(package:installdir("bin"), "emulator")
        local allowed = {"/usr/lib/", "/System/", "@rpath/libvulkan", path.translate(os.getenv("XMAKE_GLOBALDIR") or path.join(os.getenv("HOME"), ".xmake"))}
        local linked = os.iorunv("otool", {"-L", binary})
        for line in linked:gmatch("[^\n]+") do
            local library = line:match("^%s+(%S+)")
            local known = false
            for _, prefix in ipairs(allowed) do
                known = known or (library and library:startswith(prefix))
            end
            if library and not known then
                raise("the emulator links %s, which is neither a system library nor one of its packages; the build found a library outside Revenant", library)
            end
        end
        local licenses = package:installdir("licenses")
        os.mkdir(licenses)
        os.cp(path.join(root, "LICENSES", "MPL-2.0.txt"), path.join(licenses, "LICENSE"))
        os.cp(path.join(root, "docs", "reference", "emulator", "notice.md"), path.join(licenses, "NOTICE"))
    end)

    on_test(function (package)
        local listed = os.iorunv(path.join(package:installdir("bin"), "emulator"), {"profile", "--list"})
        assert(listed:find("iPhone3,1", 1, true))
    end)
