rule("swift")
    add_deps("@self/apple-ios")
    set_extensions(".swift")

    on_load(function (target)
        import("core.project.project")
        local runtime = project.required_package("swift-runtime")
        local embedded = project.required_package("swift-embedded")
        if runtime and embedded then
            raise("target(%s) compiles Swift, and its project requires both swift-runtime and swift-embedded: a program takes one standard library or the other", target:name())
        end
        if not runtime and not embedded then
            raise("target(%s) compiles Swift, and its project requires neither: add_requires(\"revenant@swift-runtime\", {alias = \"swift-runtime\"}) for the whole language, or add_requires(\"revenant@swift-embedded\", {alias = \"swift-embedded\"}) for the subset with no runtime library", target:name())
        end
        if embedded then
            target:add("packages", "swift-embedded")
            return
        end
        if not project.required_package("libcxx") then
            raise("target(%s) compiles Swift against the runtime it carries, which links the C++ runtime: add_requires(\"revenant@libcxx\", {alias = \"libcxx\"})", target:name())
        end
        target:add("packages", "swift-runtime", "libcxx")
    end)

    on_config(function (target)
        target:add("scarflags", "-cr", {force = true})
        for _, flag in ipairs(table.wrap(target:values("swift.flags"))) do
            if flag == "-emit-objc-header" or flag == "-emit-objc-header-path" then
                target:set("policy", "build.fence", true)
            end
        end
        import("@self.apple.platform").verify_one_runtime(target)
        local runtime = target:pkg("swift-runtime")
        if runtime and not runtime:requireconf("configs", "shared") then
            for _, carried in ipairs({"swift-runtime", "libcxx"}) do
                target:add("values", "revenant.libraries", carried)
                target:add("values", "app.frameworks", carried)
            end
        end
        local sourcebatch = target:sourcebatches()["@addon/revenant/swift"] or target:sourcebatches()["swift"]
        if sourcebatch and #sourcebatch.sourcefiles > 0 then
            local objectfile = path.join(target:objectdir(), "swift", target:name() .. ".o")
            target:data_set("swift.objectfile", objectfile)
            table.insert(target:objectfiles(), objectfile)
            if target:is_static() or target:is_shared() then
                target:data_set("swift.moduledir", path.join(target:autogendir(), "swift"))
                target:set("policy", "build.fence", true)
            end
        end
        local package = target:pkg("swift-runtime")
        if package then
            local mark = table.wrap((package:envs() or {}).REVENANT_SWIFT_RUNTIME_MARK)[1]
            if not mark then
                raise("swift-runtime at %s names no build of itself; reinstall it", package:installdir())
            end
            target:add("ldflags", "-Wl,-u,_" .. mark, {force = true})
        end
    end)

    before_link(function (target)
        local runtime = target:pkg("swift-runtime")
        if not runtime then
            return
        end
        local objectfiles = {}
        for _, candidate in ipairs(table.join({target}, target:orderdeps())) do
            local objectfile = candidate:data("swift.objectfile")
            if objectfile and os.isfile(objectfile) then
                table.insert(objectfiles, objectfile)
            end
        end
        for _, candidate in ipairs(table.join({target}, target:orderdeps())) do
            for _, objectfile in ipairs(candidate:objectfiles() or {}) do
                if objectfile:endswith(".o") and os.isfile(objectfile) then
                    table.insert(objectfiles, objectfile)
                end
            end
        end
        if #objectfiles == 0 then
            return
        end
        local macho = import("@self.apple.macho")
        local folders = {}
        if runtime:requireconf("configs", "shared") then
            for _, name in ipairs((table.wrap((runtime:envs() or {}).REVENANT_SHARED_PACKAGE)[1] or ""):split(";")) do
                table.insert(folders, path.join(runtime:installdir(), "share", "root", "usr", "lib", "revenant", (name:match("^([^=]+)"))))
            end
        else
            table.insert(folders, path.join(runtime:installdir(), "lib", "swift", "iphoneos"))
        end
        for _, objectfile in ipairs(objectfiles) do
            for _, options in ipairs(macho.images(macho.read(objectfile))[1].linker_options) do
                local library = #options == 1 and options[1]:match("^%-l(.+)$")
                for _, folder in ipairs(library and folders or {}) do
                    if os.isfile(path.join(folder, "lib" .. library .. ".dylib")) then
                        target:add("linkdirs", folder)
                        target:add("links", library)
                        break
                    end
                end
            end
        end
    end)

    on_build_files(function (target, jobgraph, sourcebatch, opt)
        jobgraph:add(target:fullname() .. "/swift/module", function (index, total, jobopt)
            import("core.project.depend")
            import("utils.progress")
            local swift = import("@self.apple.swift")
            local objectfile = target:data("swift.objectfile")
            local toolchain = target:toolchain("apple-ios")
            toolchain:load()
            local package = target:pkg("swift-runtime") or target:pkg("swift-embedded")
            local swiftc = table.wrap((package:envs() or {}).SWIFT_EXEC)[1]
            if not swiftc or not os.isfile(swiftc) then
                raise("%s at %s names no compiler its Swift was built with; reinstall it", package:name(), package:installdir())
            end
            local has_main = false
            for _, file in ipairs(sourcebatch.sourcefiles) do
                if path.filename(file) == "main.swift" then
                    has_main = true
                end
            end

            if target:pkg("swift-runtime") then
                local modules, plugins = {}, {}
                for _, dependency in ipairs(target:orderpkgs()) do
                    for _, folder in ipairs(table.wrap((dependency:envs() or {}).REVENANT_SWIFT_MODULES)) do
                        table.join2(modules, {"-I", folder})
                    end
                    for _, folder in ipairs(table.wrap((dependency:envs() or {}).REVENANT_SWIFT_PLUGINS)) do
                        table.join2(plugins, {"-plugin-path", folder})
                    end
                end
                local imported = {}
                for _, dependency in ipairs(target:orderdeps()) do
                    local moduledir = dependency:data("swift.moduledir")
                    if moduledir then
                        table.join2(modules, {"-I", moduledir})
                        table.insert(imported, path.join(moduledir, (dependency:values("swift.module") or dependency:name()) .. ".swiftmodule",
                                                         dependency:arch() .. "-apple-ios.swiftmodule"))
                    end
                    for _, folder in ipairs(table.wrap(dependency:get("includedirs", {interface = true}))) do
                        table.join2(modules, {"-I", folder})
                    end
                end
                local emitted = {}
                local moduledir = target:data("swift.moduledir")
                if moduledir then
                    emitted = {"-emit-module", "-emit-module-path", path.join(moduledir, (target:values("swift.module") or target:name()) .. ".swiftmodule",
                                                                              target:arch() .. "-apple-ios.swiftmodule")}
                end
                local argv = table.join(swift.runtime_flags({
                    architecture = target:arch(),
                    deployment = toolchain:config("deployment"),
                    sdk = toolchain:config("sdkdir"),
                    resources = path.join(package:installdir(), "lib", "swift"),
                    plugins = table.wrap((package:envs() or {}).SWIFT_PLUGIN_PATH)[1],
                    module = target:values("swift.module") or target:name(),
                    optimize = target:get("optimize"),
                    symbols = table.contains(table.wrap(target:get("symbols")), "debug"),
                    prefix_map = os.projectdir() .. "=/port",
                    has_main = has_main
                }), modules, plugins, table.wrap(target:values("swift.flags")), emitted, {"-c"}, sourcebatch.sourcefiles, {"-o", objectfile})
                depend.on_changed(function ()
                    progress.show(jobopt.progress, "${color.build.object}compiling.swift %s", target:name())
                    os.mkdir(path.directory(objectfile))
                    if #emitted > 0 then
                        os.mkdir(path.directory(emitted[3]))
                    end
                    os.vrunv(swiftc, argv)
                end, {files = table.join(sourcebatch.sourcefiles, imported), dependfile = objectfile .. ".d", values = argv, changed = target:is_rebuilt()})
                return
            end
            local bitcode = objectfile .. ".bc"
            local argv = table.join(swift.compile_flags({
                architecture = target:arch(),
                deployment = toolchain:config("deployment"),
                sdk = toolchain:config("sdkdir"),
                modules = path.join(package:installdir(), "lib", "swift", "embedded"),
                module = target:values("swift.module") or target:name(),
                optimize = target:get("optimize"),
                symbols = table.contains(table.wrap(target:get("symbols")), "debug"),
                prefix_map = os.projectdir() .. "=/port",
                has_main = has_main
            }), table.wrap(target:values("swift.flags")), {"-emit-bc"}, sourcebatch.sourcefiles, {"-o", bitcode})
            local codegen = table.join(table.wrap(toolchain:get("cxflags")), swift.codegen_flags({optimize = target:get("optimize")}),
                                       {"-c", bitcode, "-o", objectfile})
            depend.on_changed(function ()
                progress.show(jobopt.progress, "${color.build.object}compiling.swift %s", target:name())
                os.mkdir(path.directory(objectfile))
                os.vrunv(swiftc, argv)
                os.vrunv(toolchain:tool("cc"), codegen, {envs = {IPHONEOS_DEPLOYMENT_TARGET = toolchain:config("deployment")}})
            end, {files = sourcebatch.sourcefiles, dependfile = objectfile .. ".d", values = table.join(argv, codegen), changed = target:is_rebuilt()})
        end)
    end, {jobgraph = true, batch = true})

    after_install(function (target)
        local moduledir = (target:is_static() or target:is_shared()) and target:data("swift.moduledir")
        if moduledir and os.isdir(moduledir) then
            local swiftdir = path.join(target:installdir(), "lib", "swift", "iphoneos")
            os.mkdir(swiftdir)
            os.vcp(path.join(moduledir, "*"), swiftdir .. "/")
        end
    end)
