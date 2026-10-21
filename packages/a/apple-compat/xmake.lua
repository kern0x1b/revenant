package("apple-compat")
    set_homepage("https://github.com/kern0x1b/revenant/tree/main/toolchain")
    set_description("What a current library calls and an old Apple system does not have, provided as hidden definitions linked into the image that calls them")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    includes(path.join(os.scriptdir(), "port", "digest.lua"))
    add_configs("sources", {description = "The digest of this recipe and the shims it compiles, so a changed shim or recipe is a different package.", default = apple_compat_sources_digest, type = "string", readonly = true})

    on_load("iphoneos", function (package)
        local toolchain = assert(package:toolchains(), "apple-compat is built with the apple-ios toolchain")[1]
        toolchain:load()
        local compat = import("@addon.revenant.apple.compat", {anonymous = true})
        local symbols, sharing = compat.needed(toolchain:config("deployment"))
        package:data_set("provided", symbols)
        package:data_set("process_wide", sharing)
        if #symbols > 0 then
            package:add("links", "apple-compat")
        end
    end)

    on_install("iphoneos", function (package)
        local toolchain = package:toolchains()[1]
        toolchain:load()
        local data = import("@addon.revenant.data", {anonymous = true})
        import("core.package.addon")
        local revenant = addon.addons()[addon.dirname("revenant")] or raise("apple-compat is built with the revenant addon's rules, and no revenant addon is installed")
        local root = path.translate(path.join(package:scriptdir(), "..", "..", ".."))
        local project = path.absolute("compat")
        os.mkdir(project)
        io.writefile(path.join(project, "xmake.lua"), table.concat({
            "add_repositories(\"revenant " .. root .. "\")",
            "add_addons(\"revenant\")",
            "set_config(\"apple_minimum\", \"" .. toolchain:config("deployment") .. "\")",
            "set_config(\"apple_sdk\", \"" .. toolchain:config("sdk") .. "\")",
            "includes(\"@addon/revenant/apple-ios\")",
            "option(\"component\", {type = \"string\", default = \"\"})",
            "includes(\"" .. data.src("apple-compat") .. "\")",
            "set_defaultplat(\"iphoneos\")",
            "set_defaultarchs(\"iphoneos|" .. package:arch() .. "\")",
            ""}, "\n"))
        io.save(path.join(project, "xmake-addons.lock"), {__meta__ = {version = "1.0"}, revenant = {version = revenant.version}})
        if #(package:data("provided") or {}) > 0 then
            os.vrunv(os.programfile(), {"f", "-p", "iphoneos", "-a", package:arch(), "-m", "release", "-y"}, {curdir = project})
            os.vrunv(os.programfile(), {"build", "-y", "apple-compat"}, {curdir = project, envs = {REVENANT_RELEASE = "1"}})
            os.vrunv(os.programfile(), {"install", "-y", "-o", package:installdir(), "apple-compat"}, {curdir = project})
        end
        os.vcp(data.licence(), package:installdir("licenses"))
    end)

    on_test(function (package)
        local symbols = package:data("provided") or {}
        if #symbols > 0 then
            assert(os.isfile(path.join(package:installdir("lib"), "libapple-compat.a")))
        end
        for _, symbol in ipairs(package:data("process_wide") or {}) do
            assert(os.isfile(path.join(package:installdir("share"), "apple-compat", "process-wide", symbol .. ".c")))
        end
    end)
