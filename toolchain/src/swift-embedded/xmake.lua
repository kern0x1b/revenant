if get_config("component") ~= "" or not is_plat("iphoneos") then
    return
end

add_requires("revenant@swift 6.4.0", {alias = "swift", host = true, system = false})

local function source(target)
    return path.join(target:pkg("swift"):installdir("share"), "swift-source")
end

target("swiftUnicodeDataTables")
    set_kind("static")
    set_default(false)
    add_rules("@addon/revenant/apple-ios")
    add_packages("swift")
    on_load(function (target)
        local swift = import("@addon.revenant.apple.swift", {anonymous = true})
        local tables = swift.unicode_tables(source(target))
        target:add("files", path.join(tables.folder, "*.cpp"))
        target:add("includedirs", tables.includedirs)
        target:add("defines", tables.defines)
        target:add("cxxflags", tables.cxxflags)
    end)
    on_config(function (target)
        local swift = import("@addon.revenant.apple.swift", {anonymous = true})
        local generated = path.join(target:autogendir(), "generated")
        io.writefile(path.join(generated, "swift", "Runtime", "CMakeConfig.h"), swift.runtime_config(target:pkg("swift"):version_str()))
        target:add("includedirs", generated)
    end)
    after_build(function (target)
        local swift = import("@addon.revenant.apple.swift", {anonymous = true})
        local found = target:toolchain("apple-ios")
        found:load()
        swift.build_module({
            swiftc = path.join(target:pkg("swift"):installdir("bin"), "swiftc"),
            source = source(target),
            architecture = target:arch(),
            deployment = found:config("deployment"),
            sdk = found:config("sdkdir"),
            output = path.join(target:targetdir(), "swift", "embedded"),
            workdir = path.join(target:autogendir(), "module")
        })
    end)
    after_install(function (target)
        local folder = path.join(target:installdir("lib"), "swift", "embedded")
        os.mkdir(folder)
        os.vcp(path.join(target:targetdir(), "swift", "embedded", "*"), folder .. "/")
        os.mkdir(target:installdir("licenses"))
        os.vcp(path.join(source(target), "LICENSE.txt"), target:installdir("licenses"))
    end)
