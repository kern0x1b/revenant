set_project("swiftui-surface")
add_repositories("revenant " .. path.join(os.scriptdir(), "..", "..", "..", ".."))
add_requires("revenant@swift-syntax", {alias = "swift-syntax"})
set_allowedplats("macosx")
set_allowedarchs("macosx|arm64")

target("surftool")
    set_kind("binary")
    add_packages("swift-syntax")
    add_files("main.swift")
    on_build(function (target)
        local config = import("core.project.config")
        local envs = target:pkg("swift-syntax"):envs() or {}
        local syntax = assert(table.wrap(envs.REVENANT_SWIFT_SYNTAX)[1], "revenant@swift-syntax names no build of itself; reinstall it")
        local swiftc = assert(table.wrap(envs.REVENANT_HOST_SWIFTC)[1], "revenant@swift-syntax names no host compiler")
        local shims = assert(table.wrap(envs.REVENANT_SWIFT_SYNTAX_SHIMS)[1], "revenant@swift-syntax names no shim headers")
        local output = path.join(path.absolute(config.get("builddir"), os.projectdir()), target:plat(), target:arch(), config.mode(), target:filename())
        os.mkdir(path.directory(output))
        os.vrunv(swiftc, table.join({"-O", "-module-name", "surftool", "-target", "arm64-apple-macosx13.0", "-I", path.join(syntax, "swift", "host"),
                                     "-I", path.join(shims, "_SwiftSyntaxCShims"), "-I", path.join(shims, "_SwiftLibraryPluginProviderCShims"),
                                     "-emit-executable", "-o", output}, path.join(os.scriptdir(), "main.swift"), os.files(path.join(syntax, "*.o"))))
    end)
