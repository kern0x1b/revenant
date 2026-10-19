rule("swift")
    add_deps("@self/apple-ios")
    set_extensions(".swift")

    -- Swift comes in two kinds here. Embedded Swift is the subset with no runtime library, and a port that uses it needs
    -- nothing beside its own binary. The whole language needs the runtime, which charon@swift-runtime builds for the
    -- port's architecture and oldest release and the port carries with it; a port says which one it takes by the package
    -- it requires, and taking both would leave two standard libraries in one program.
    on_load(function (target)
        import("core.project.project")
        local runtime = project.required_package("swift-runtime")
        local embedded = project.required_package("swift-embedded")
        if runtime and embedded then
            raise("target(%s) compiles Swift, and its project requires both swift-runtime and swift-embedded: a program takes one standard library or the other", target:name())
        end
        if not runtime and not embedded then
            raise("target(%s) compiles Swift, and its project requires neither: add_requires(\"charon@swift-runtime\", {alias = \"swift-runtime\"}) for the whole language, or add_requires(\"charon@swift-embedded\", {alias = \"swift-embedded\"}) for the subset with no runtime library", target:name())
        end
        if embedded then
            target:add("packages", "swift-embedded")
            return
        end
        -- The C++ runtime is the port's too: libc++abi exports the locks, the atomics and the emulated thread-local
        -- storage once for the process, and the Swift libraries are linked against it.
        if not project.required_package("libcxx") then
            raise("target(%s) compiles Swift against the runtime it carries, which links the C++ runtime: add_requires(\"charon@libcxx\", {alias = \"libcxx\"})", target:name())
        end
        target:add("packages", "swift-runtime", "libcxx")
    end)

    on_config(function (target)
        -- A static library of Swift is archived by the tool xmake keeps for the Swift language, whose flags are its own
        -- (scarflags) and empty: the archiver was given the library's path and read it as options ("illegal option -- /").
        -- The C languages' archiver has -cr; the Swift one is given the same.
        target:add("scarflags", "-cr", {force = true})
        -- Swift that Objective-C calls is a target whose header the compiler writes: what depends on it must compile after it, or
        -- the Objective-C finds no header (the objects of a target and of the ones it depends on are otherwise built together).
        for _, flag in ipairs(table.wrap(target:values("swift.flags"))) do
            if flag == "-emit-objc-header" or flag == "-emit-objc-header-path" then
                target:set("policy", "build.fence", true)
            end
        end
        import("@self.apple.platform").verify_one_runtime(target)
        -- The runtime is shared libraries; the program carries them the way it carries any package's - a tweak or a
        -- daemon in its package's folder, an application inside its bundle. A shared runtime is a package of its own that
        -- the program depends on instead: it carries none of it, and its libc++ is the one in that package's folder.
        local runtime = target:pkg("swift-runtime")
        if runtime and not runtime:requireconf("configs", "shared") then
            for _, carried in ipairs({"swift-runtime", "libcxx"}) do
                target:add("values", "charon.libraries", carried)
                target:add("values", "app.frameworks", carried)
            end
        end
        local sourcebatch = target:sourcebatches()["@addon/charon/swift"] or target:sourcebatches()["swift"]
        if sourcebatch and #sourcebatch.sourcefiles > 0 then
            local objectfile = path.join(target:objectdir(), "swift", target:name() .. ".o")
            target:data_set("swift.objectfile", objectfile)
            table.insert(target:objectfiles(), objectfile)
        end
        -- The program names the build of the runtime it was compiled against, and the link fails against any other: by
        -- default the libraries are built without library evolution, so two builds of them do not answer for each other, and a
        -- build with the library_evolution config is a build of its own, named by its own mark.
        local package = target:pkg("swift-runtime")
        if package then
            local mark = table.wrap((package:envs() or {}).CHARON_SWIFT_RUNTIME_MARK)[1]
            if not mark then
                raise("swift-runtime at %s names no build of itself; reinstall it", package:installdir())
            end
            target:add("ldflags", "-Wl,-u,_" .. mark, {force = true})
            -- A runtime built with the backports hands its port headers to the port's own Swift too, and the port carries
            -- the backports that make them true.
            local port_headers = table.wrap((package:envs() or {}).CHARON_SWIFT_PORT_HEADERS)[1]
            if port_headers then
                local carried = target:pkg("apple-backports")
                if not carried then
                    raise("target(%s) compiles against swift-runtime built with the backports, and does not carry them: add_requires(\"charon@apple-backports\", {alias = \"apple-backports\"}) and add_packages(\"apple-backports\")", target:name())
                end
                -- The port's headers let the port write a call the backports implement; the call finds its implementation
                -- only where that library is loaded. A library the runtime was built to link is one the port must carry too:
                -- its config says so, and a class message that reaches a library that is not there is not a link error but
                -- an unrecognized selector at run time.
                local libraries = {coredata = "CoreDataBackports", uikit = "UIKitBackports"}
                for _, config in ipairs(table.wrap((package:envs() or {}).CHARON_SWIFT_RUNTIME_BACKPORTS)[1]:split(",")) do
                    local found = false
                    for _, folder in ipairs(table.wrap(carried:get("linkdirs"))) do
                        found = found or os.isfile(path.join(folder, "lib" .. libraries[config] .. ".dylib"))
                    end
                    if not found then
                        raise("target(%s) compiles against swift-runtime built with the %s backports, and its apple-backports package holds no lib%s.dylib: add_requires(\"charon@apple-backports\", {alias = \"apple-backports\", configs = {%s = true}})", target:name(), config, libraries[config], config)
                    end
                end
                target:add("values", "swift.flags", "-vfsoverlay", port_headers)
            end
        end
    end)

    -- The runtime is linked by what the program imports, whether it carries the libraries or shares them. The compiler
    -- records the libraries of the modules an object imports in the object; they are named here, as libraries, so that they
    -- come before the frameworks on the link line:
    -- left to the object they would come after them, and a symbol of an overlay would bind to the framework of the same
    -- name, which the SDK's stub also exports and the device does not. A program that imports no UIKit names no overlay of
    -- UIKit, loads no UIKit, and depends on no package that holds it.
    before_link(function (target)
        local runtime = target:pkg("swift-runtime")
        if not runtime then
            return
        end
        -- The Swift a program is made of is its own and that of the libraries of Swift it links: the imports of each object
        -- are what the program needs of the runtime, and a program with no Swift of its own is one whose Swift is all in a
        -- library.
        local objectfiles = {}
        for _, candidate in ipairs(table.join({target}, target:orderdeps())) do
            local objectfile = candidate:data("swift.objectfile")
            if objectfile and os.isfile(objectfile) then
                table.insert(objectfiles, objectfile)
            end
        end
        -- Swift compiled outside the build and added as objects (add_files("x.o")) is a program's Swift as much as any other.
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
            for _, name in ipairs((table.wrap((runtime:envs() or {}).CHARON_SHARED_PACKAGE)[1] or ""):split(";")) do
                table.insert(folders, path.join(runtime:installdir(), "share", "root", "usr", "lib", "charon", (name:match("^([^=]+)"))))
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

            -- With the runtime the program carries, the compiler writes the object itself: the code is the release's own
            -- and needs none of the lowering Embedded Swift is put through. It reads the runtime's resource directory,
            -- and so takes that Swift rather than the one the SDK carries for the architecture.
            if target:pkg("swift-runtime") then
                local modules, plugins = {}, {}
                for _, dependency in ipairs(target:orderpkgs()) do
                    for _, folder in ipairs(table.wrap((dependency:envs() or {}).CHARON_SWIFT_MODULES)) do
                        table.join2(modules, {"-I", folder})
                    end
                    -- A package that ships a macro plugin of its own says where it is, the same way
                    -- it says where its modules are, and every one of those directories is its own
                    -- -plugin-path: the runtime's own plugins (SwiftMacros, ObservationMacros) come
                    -- in through runtime_flags' `plugins`, and a package that expands a macro of its
                    -- own - SwiftData's @Model, for one - has no other way to be found by a port
                    -- that uses it.
                    for _, folder in ipairs(table.wrap((dependency:envs() or {}).CHARON_SWIFT_PLUGINS)) do
                        table.join2(plugins, {"-plugin-path", folder})
                    end
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
                }), modules, plugins, table.wrap(target:values("swift.flags")), {"-c"}, sourcebatch.sourcefiles, {"-o", objectfile})
                depend.on_changed(function ()
                    progress.show(jobopt.progress, "${color.build.object}compiling.swift %s", target:name())
                    os.mkdir(path.directory(objectfile))
                    os.vrunv(swiftc, argv)
                end, {files = sourcebatch.sourcefiles, dependfile = objectfile .. ".d", values = argv, changed = target:is_rebuilt()})
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
