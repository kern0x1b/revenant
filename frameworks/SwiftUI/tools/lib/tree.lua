function root(...)
    return path.join(path.normalize(path.absolute(path.join(os.scriptdir(), "..", ".."))), ...)
end

function revenant(...)
    return path.join(path.normalize(path.join(root(), "..", "..")), ...)
end

function sources()
    return root("src")
end

function api(...)
    return root("tests", "data", "api", ...)
end

function workspace()
    return import("@addon.revenant.workspace", {anonymous = true})
end

function sdk()
    return workspace().sdk()
end

function run(...)
    return workspace().run("swiftui", ...)
end

function demo()
    import("core.project.config")
    import("core.project.project")
    config.load()
    local target = project.target("SwiftUIDemo")
    if not target then
        raise("the project at %s has no SwiftUIDemo target: run this from the top of revenant, configured with ./xmakew f -P . -p iphoneos -a armv7",
              os.projectdir())
    end
    return path.join(target:targetdir(), "SwiftUIDemo.app")
end

function fresh(name)
    return workspace().fresh(path.join("swiftui", name))
end
