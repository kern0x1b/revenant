rule("macro")
    set_extensions(".swift")

    -- A macro plugin: a host executable a device compile loads with -load-plugin-executable. It is
    -- not a port target -- it is built for the *host* and runs inside the compiler -- so the swift
    -- rule (which compiles for the port's architecture and its oldest release, against the runtime
    -- a port carries) is the wrong one. What a plugin needs instead is swift-syntax, and
    -- charon@swift-syntax is what builds it: the toolchain's own copy exports every macro protocol
    -- and no CompilerPlugin, because that one sits behind @_spi(PluginMessage).
    --
    -- The plugin is published through CHARON_SWIFT_PLUGINS, which `rules/swift` adds to every compile
    -- of a package that depends on this one (rules/swift/xmake.lua:182, commit 415a119e) -- so a
    -- package that ships a plugin needs nothing but to build it and to name this rule.
    on_load(function (target)
        -- Once per load, so that a project can *see* that the rule was found before it builds with
        -- it: `xmake l -c 'print("…")'` in the project prints this line when the rule is registered,
        -- and prints nothing when the spelling is wrong. Every failure to reach this rule so far
        -- looked like a build failure rather than a rule that was never loaded, and one build spent
        -- a slow slot on that.
        print("macro rule: loaded for target(" .. target:name() .. ")")
        import("core.project.project")
        if not project.required_package("swift-syntax") then
            raise("target(%s) is a macro plugin, and its project does not require charon@swift-syntax: the toolchain's own swift-syntax does not export CompilerPlugin, so there is nothing else to build it against", target:name())
        end
        -- The addon's own `rules/swift` attaches to a target's `.swift` files **by extension**
        -- (`~/.xmake/addons/charon/v0.8.14/rules/swift/xmake.lua:3` is `set_extensions(".swift")`),
        -- and its `on_load` refuses a project that requires no runtime, which is what a host plugin
        -- target is. Measured, in this order: `set_rules("macro")` replaces the default rules and
        -- does not detach it; `{defaults = false}` on the files does not detach it either; the rule
        -- is chosen from the target's file set by extension, so what is left is to give the plugin
        -- sources an extension the addon rule does not claim and have this rule copy them, or to take
        -- the addon rule off the target by name. Both are the next attempt.
        --
        -- Own the sources. `set_default(false)` was tried here first and **measured not to work**:
        -- the next build after it failed with the identical "error opening input file
        -- 'arm64-apple-ios'", because the default rules are the *target's*, and a rule's
        -- `set_default` speaks for the task the rule defines, not for the target's rule set. The
        -- only thing that replaces a target's rules is the project: `set_rules("macro", {rootdir = …})`
        -- where I measured with `add_rules`. The rule says so here rather than leaving every project
        -- to find it, and its own README line names the spelling.
    end)

    -- `on_build`, not `on_build_file`: a plugin is one executable from the target's whole source
    -- list, and the per-file hook fires once per file, so a target with two sources would compile
    -- the plugin twice and race its own output. (c92dda44's note found the two dead statements
    -- below; the hook was the same defect next to them, and a rule that compiles N times is not a
    -- rule that works.)
    on_build(function (target)
        local plugins = path.join(target:installdir(), "plugins")
        os.mkdir(plugins)
        -- One executable per target, named for it, which is the name a port passes to
        -- -load-plugin-executable.
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
        -- The two include paths, as the install measured them: the modules are copied into
        -- `lib/swift/host/` and the objects into `lib/` beside them, so `-I` takes the first and the
        -- objects are named on the command line. (There is no `libswiftSyntax.a` to link: a
        -- target-scoped `swift build` emits one object per module.)
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
