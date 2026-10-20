set_project("swiftui-surface")
add_repositories("revenant " .. path.join(os.scriptdir(), "..", "..", "..", "..", "toolchain"))
add_requires("revenant@swift-syntax", {alias = "swift-syntax"})
set_allowedplats("macosx")
set_allowedarchs("macosx|arm64")

target("surftool")
    set_kind("binary")
    add_packages("swift-syntax")
    add_files("main.swift")
    on_build(function (target)
        local envs = target:pkg("swift-syntax"):envs() or {}
        local syntax = assert(table.wrap(envs.REVENANT_SWIFT_SYNTAX)[1], "revenant@swift-syntax names no build of itself; reinstall it")
        local swiftc = assert(table.wrap(envs.REVENANT_HOST_SWIFTC)[1], "revenant@swift-syntax names no host compiler")
        os.mkdir(path.directory(target:targetfile()))
        os.vrunv(swiftc, table.join({"-O", "-module-name", "surftool", "-target", "arm64-apple-macosx13.0", "-I", path.join(syntax, "swift", "host"),
                                     "-emit-executable", "-o", target:targetfile()}, path.join(os.scriptdir(), "main.swift"), os.files(path.join(syntax, "*.o"))))
    end)
