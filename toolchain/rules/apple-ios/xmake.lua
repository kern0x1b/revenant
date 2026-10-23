rule("apple-ios")
    on_load(function (target)
        import("@self.binding").mark(target)
        import("core.project.project")
        local toplevel = try { function () return os.iorunv("git", {"-C", os.workingdir(), "rev-parse", "--show-toplevel"}):trim() end }
        if toplevel and path.absolute(toplevel) ~= path.absolute(os.projectdir()) and path.absolute(toplevel):startswith(path.absolute(os.projectdir()) .. "/") then
            raise("xmake found the project at %s, but this is the checkout at %s nested inside it; run xmake -P . here, or it builds and locks the outer project", os.projectdir(), toplevel)
        end
        local minimum = get_config("apple_minimum")
        if minimum then
            minimum = import("@self.apple.slices").slice_minimum(get_config("arch"), minimum, os.getenv("REVENANT_SLICES"))
        end
        if not minimum then
            raise("target(%s) builds for apple-ios and its project names no oldest release: set_config(\"apple_minimum\", \"6.0\")", target:name())
        end
        local versions = {}
        for _, name in ipairs({"iphoneos-sdk", "ld64", "llvm"}) do
            local required = project.required_package(name)
            if not required then
                raise("target(%s) builds for apple-ios without includes(\"@addon/revenant/apple-ios\") in its project", target:name())
            end
            versions[name] = required:requirestr():match("%s(%S+)$")
        end
        target:set("toolchains", string.format("@addon/revenant/apple-ios[minimum=%s,sdk=%s,ld64=%s,llvm=%s]", minimum, versions["iphoneos-sdk"], versions.ld64, versions.llvm))
        if not target:get("strip") then
            target:data_set("revenant.strip.unset", true)
        end
        import("@self.apple.backports").attach(target, project)
        local mapped = "-ffile-prefix-map=" .. os.projectdir() .. "=/port"
        target:add("cxflags", mapped)
        target:add("mxflags", mapped)
        target:add("asflags", mapped)
        local sdk = import("@self.apple.sdk").folder(project.required_package("iphoneos-sdk"):installdir(), versions["iphoneos-sdk"])
        local overlay = import("@self.apple.lowered").overlay(sdk, path.join(os.projectdir(), "build", "generated", "backports", "overlay"))
        target:add("cxflags", "-ivfsoverlay", overlay, {force = true})
        target:add("values", "swift.flags", "-vfsoverlay", overlay)
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
        local objc_bool = table.wrap(target:values("apple.objc_bool"))[1]
        if objc_bool then
            if objc_bool ~= "bool" then
                raise("target(%s) names apple.objc_bool %s: the only value is bool, the Objective-C BOOL of arm64", target:name(), objc_bool)
            end
            target:add("mflags", "-U__OBJC_BOOL_IS_BOOL", "-D__OBJC_BOOL_IS_BOOL=1", {force = true})
            target:add("mxflags", "-U__OBJC_BOOL_IS_BOOL", "-D__OBJC_BOOL_IS_BOOL=1", {force = true})
        end
        if target:is_arch("armv6", "armv7", "armv7s") then
            target:add("cxflags", "-Wno-incompatible-sysroot", {force = true})
            target:add("mflags", "-Wno-incompatible-sysroot", {force = true})
            target:add("mxflags", "-Wno-incompatible-sysroot", {force = true})
            target:add("asflags", "-Wno-incompatible-sysroot", {force = true})
        end
    end)

    after_config(function (target)
        if target:data("revenant.strip.unset") and target:get("strip") == "all" then
            target:set("strip", "none")
            if target:is_binary() then
                target:add("ldflags", "-Wl,-dead_strip", {force = true})
            elseif target:is_shared() then
                target:add("shflags", "-Wl,-dead_strip", {force = true})
            end
        end
    end)
