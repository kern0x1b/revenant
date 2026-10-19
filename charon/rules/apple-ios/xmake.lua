rule("apple-ios")
    on_load(function (target)
        import("core.project.project")
        local toplevel = try { function () return os.iorunv("git", {"-C", os.workingdir(), "rev-parse", "--show-toplevel"}):trim() end }
        if toplevel and path.absolute(toplevel) ~= path.absolute(os.projectdir()) and path.absolute(toplevel):startswith(path.absolute(os.projectdir()) .. "/") then
            raise("xmake found the project at %s, but this is the checkout at %s nested inside it; run xmake -P . here, or it builds and locks the outer project", os.projectdir(), toplevel)
        end
        local minimum = get_config("apple_minimum")
        if minimum then
            minimum = import("@self.apple.slices").slice_minimum(get_config("arch"), minimum, os.getenv("CHARON_SLICES"))
        end
        if not minimum then
            raise("target(%s) builds for apple-ios and its project names no oldest release: set_config(\"apple_minimum\", \"6.0\")", target:name())
        end
        local versions = {}
        for _, name in ipairs({"iphoneos-sdk", "ld64", "llvm"}) do
            local required = project.required_package(name)
            if not required then
                raise("target(%s) builds for apple-ios without includes(\"@addon/charon/apple-ios\") in its project", target:name())
            end
            versions[name] = required:requirestr():match("%s(%S+)$")
        end
        target:set("toolchains", string.format("@addon/charon/apple-ios[minimum=%s,sdk=%s,ld64=%s,llvm=%s]", minimum, versions["iphoneos-sdk"], versions.ld64, versions.llvm))
        target:set("policy", "build.ccache", false)
        -- Whether the target sets a strip of its own, taken before a mode's on_config sets one for it (after_config).
        if not target:get("strip") then
            target:data_set("charon.strip.unset", true)
        end
        local mapped = "-ffile-prefix-map=" .. os.projectdir() .. "=/port"
        target:add("cxflags", mapped)
        target:add("mxflags", mapped)
        target:add("asflags", mapped)
        local symbols = target:values("apple.compat")
        if symbols then
            local compat = target:pkg("apple-compat")
            if not compat then
                raise("target(%s) names apple.compat symbols without add_packages(\"apple-compat\")", target:name())
            end
            local flags = import("@self.apple.compat").force_includes(compat, symbols)
            target:add("cxflags", flags, {force = true})
            target:add("mxflags", flags, {force = true})
        end
    end)

    -- The checks after the link read the binary's symbol table, and the rules strip it afterwards with charon.strip. A
    -- mode that strips a target setting no strip of its own (mode.release, mode.releasedbg, mode.minsizerel) sets strip
    -- "all", which on Apple platforms links with -Wl,-x -Wl,-dead_strip (xmake's gcc.lua nf_strip), and the checks would
    -- find no function names. The link keeps the dead-code removal and leaves the symbols to charon.strip, the way
    -- xmake's utils.symbols.extract sets strip "none" until its own strip runs.
    after_config(function (target)
        if target:data("charon.strip.unset") and target:get("strip") == "all" then
            target:set("strip", "none")
            if target:is_binary() then
                target:add("ldflags", "-Wl,-dead_strip", {force = true})
            elseif target:is_shared() then
                target:add("shflags", "-Wl,-dead_strip", {force = true})
            end
        end
    end)
