local shared = import("@addon.revenant.member", {anonymous = true})

function root(...)
    return shared.root(os.scriptdir(), ...)
end

function revenant(...)
    return shared.checkout(root(), ...)
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
    return path.join(os.projectdir(), "build", "iphoneos", "armv7", "release", "SwiftUIDemo.app")
end

function fresh(name)
    return workspace().fresh(path.join("swiftui", name))
end
