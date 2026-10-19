import("core.base.task")
import("core.project.config")
import("core.project.project")
import("debian")

function universal(target, architectures, stage)
    import("apple.merge")
    import("apple.platform")
    import("apple.macho")
    import("apple.compat")
    import("apple.dyld")
    local bundles = {}
    for _, architecture in ipairs(architectures) do
        local built
        if architecture == config.arch() then
            built = path.join(target:targetdir(), target:basename() .. ".app")
        else
            local builddir = path.join(config.builddir(), ".charon", "slices", architecture)
            local envs = {XMAKE_CONFIGDIR = path.join(builddir, "config"), CHARON_SLICE = architecture, CHARON_SLICES = table.concat(architectures, ",")}
            os.vexecv(os.programfile(), {"f", "-P", os.projectdir(), "-p", config.plat(), "-a", architecture, "-m", config.mode() or "release", "-o", builddir, "-y"}, {envs = envs})
            os.vexecv(os.programfile(), {"build", "-P", os.projectdir(), "-y", target:name()}, {envs = envs})
            built = path.join(builddir, config.plat(), architecture, config.mode() or "release", target:basename() .. ".app")
        end
        if not os.isdir(built) then
            raise("the %s slice of %s built no %s", architecture, target:name(), built)
        end
        table.insert(bundles, built)
    end
    local installed = os.dirs(path.join(stage, "**", target:basename() .. ".app"))[1]
    if not installed then
        raise("%s installed no %s.app into %s to replace with the merged bundle", target:name(), target:basename(), stage)
    end
    local merged = merge.merge(bundles, architectures, installed)
    local executable = path.join(installed, target:basename())
    for _, binary in ipairs(merged) do
        macho.verify(binary, {waived = platform.waivers(target), arrived = compat.arrived("iOS"), process_wide = compat.process_wide(), stripped = true})
    end
    table.sort(merged, function (a, b) return a ~= executable and b == executable end)
    for _, binary in ipairs(merged) do
        platform.sign(target, binary, binary == executable and target:values("charon.entitlements") or nil)
    end
    for _, architecture in ipairs(architectures) do
        local source = platform.imports_source(target, architecture)
        local provided = architecture == target:arch() and platform.provided_libraries(target) or {}
        dyld.check(source, table.join(merged, provided), installed, platform.import_options(target, provided))
        platform.report_selectors(source, merged, architecture, installed, provided)
    end
end

function packages()
    local grouped = {}
    for _, target in ipairs(project.ordertargets()) do
        local control = target:values("charon.control")
        if control then
            control = path.absolute(control, target:scriptdir())
            grouped[control] = grouped[control] or {targets = {}, scripts = nil, licenses = {}}
            local declared = target:values("charon.version")
            if declared then
                if grouped[control].version and grouped[control].version ~= declared then
                    raise("%s is packaged at versions %s and %s by different targets", control, grouped[control].version, declared)
                end
                grouped[control].version = declared
            end
            table.insert(grouped[control].targets, target)
            for _, license in ipairs(table.wrap(target:values("charon.licenses"))) do
                table.insert(grouped[control].licenses, path.absolute(license, target:scriptdir()))
            end
            local scripts = target:values("charon.maintainer-scripts")
            if scripts then
                grouped[control].scripts = path.absolute(scripts, target:scriptdir())
            end
        end
    end
    return grouped
end

function write(opt)
    opt = opt or {}
    task.run("config", {}, {disable_dump = true})
    local written, carried = {}, {}
    local grouped = packages()
    for _, control in ipairs(table.orderkeys(grouped)) do
        local described = grouped[control]
        local wanted = not opt.target
        for _, target in ipairs(described.targets) do
            wanted = wanted or target:name() == opt.target
        end
        local version = described.version or project.version()
        if wanted and not version then
            raise("%s has no charon.version on its targets and the project no set_version(), and a Debian package cannot be written without one", control)
        end
        if wanted then
            import("apple.platform")
            os.setenv("CHARON_RELEASE", "1")
            local stage = path.join(config.builddir(), ".charon", "stage", path.basename(control))
            os.tryrm(stage)
            local depends = {}
            for _, target in ipairs(described.targets) do
                -- What the program links against is read from the program, so it is built first.
                task.run("build", {target = target:name()})
                local dependencies = {}
                local backports, shared = platform.backport_package(target), platform.shared_runtime(target)
                if backports then
                    table.insert(dependencies, backports)
                end
                table.join2(dependencies, shared and shared.packages or {})
                for _, dependency in ipairs(dependencies) do
                    table.insert(depends, string.format("%s (%s %s)", dependency.name, dependency.relation, dependency.version))
                    if not carried[dependency.name] then
                        carried[dependency.name] = true
                        local outputdir = opt.outputdir or config.builddir()
                        local copied
                        if dependency.meta then
                            -- A package of the shared runtime is written here and signed with the program's own ldid: the
                            -- recipe that staged it has no ldid, whose dependencies would reach every package depending on it.
                            copied = import("apple.shared_runtime").deb(dependency.meta, dependency.root, platform.ldid(target),
                                                                        path.join(config.builddir(), ".charon", "shared", dependency.name), outputdir)
                        else
                            copied = platform.copy_program(dependency.deb, path.join(outputdir, path.filename(dependency.deb)), dependency.name)
                        end
                        cprint("${bright green}deb${clear} %s", copied)
                        table.insert(written, {deb = copied})
                    end
                end
                task.run("install", {target = target:name(), installdir = stage})
                local architectures = table.wrap(target:values("apple.architectures"))
                if #architectures > 1 then
                    universal(target, architectures, stage)
                end
            end
            if #described.licenses > 0 then
                local fields = debian.control_text(control, version, stage)
                local documents = path.join(stage, "usr", "share", "doc", fields.Package)
                os.mkdir(documents)
                for _, license in ipairs(table.unique(described.licenses)) do
                    if not os.isfile(license) then
                        raise("%s names license file %s, and there is no such file", control, license)
                    end
                    os.vcp(license, documents .. "/")
                end
            end
            local output = debian.write({control = control, version = version, root = stage,
                                         scripts = described.scripts, depends = table.unique(depends),
                                         outputdir = opt.outputdir or config.builddir()})
            cprint("${bright green}deb${clear} %s", output)
            table.insert(written, {deb = output, stage = stage})
        end
    end
    if #written == 0 then
        raise("no target names a control file with set_values(\"charon.control\", ...), so there is no package to write")
    end
    return written
end
