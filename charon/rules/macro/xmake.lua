rule("macro")
    set_extensions(".swift")

    on_load(function (target)
        print("macro rule: loaded for target(" .. target:name() .. ")")
        import("core.project.project")
        if not project.required_package("swift-syntax") then
            raise("target(%s) is a macro plugin, and its project does not require charon@swift-syntax: the toolchain's own swift-syntax does not export CompilerPlugin, so there is nothing else to build it against", target:name())
        end
    end)

    on_build(function (target)
        local plugins = path.join(target:installdir(), "plugins")
        os.mkdir(plugins)
        local executable = path.join(plugins, target:name())
        local syntax = os.getenv("CHARON_SWIFT_SYNTAX")
        if not syntax or not os.isdir(syntax) then
            raise("target(%s) is a macro plugin and CHARON_SWIFT_SYNTAX names no swift-syntax build; require charon@swift-syntax", target:name())
        end
        local swiftc = os.getenv("CHARON_HOST_SWIFTC")
        if not swiftc then
            raise("target(%s) is a macro plugin and CHARON_HOST_SWIFTC names no host compiler; a plugin is built for the host, not for the port", target:name())
        end
        local sources = {}
        for _, file in ipairs(os.files(path.join(target:sourcefile(), "**.swift"))) do
            table.insert(sources, file)
        end
        if #sources == 0 then
            raise("target(%s) is a macro plugin and has no .swift source to compile", target:name())
        end
        local objects = {}
        for _, object in ipairs(os.files(path.join(syntax, "*.o"))) do
            table.insert(objects, object)
        end
        if #objects == 0 then
            raise("target(%s) is a macro plugin and %s holds no swift-syntax object; install charon@swift-syntax", target:name(), syntax)
        end
        os.iorunv(swiftc, table.join({
            "-emit-executable", "-module-name", target:name(), "-o", executable,
            "-target", "arm64-apple-macosx13.0",
            "-I", path.join(syntax, "swift", "host"),
        }, sources, objects))
        print(string.format("macro plugin %s: %s", target:name(), executable))
    end)
