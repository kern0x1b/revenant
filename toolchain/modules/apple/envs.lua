function deployment(package)
    local found = assert(package:toolchains(), package:name() .. " is built for apple-ios without the apple-ios toolchain")[1]
    found:load()
    return found:config("deployment")
end

function build(package, envs)
    local joined = table.copy(envs or {})
    joined.IPHONEOS_DEPLOYMENT_TARGET = deployment(package)
    return joined
end

function host(envs)
    local joined = table.copy(envs or os.getenvs())
    joined.IPHONEOS_DEPLOYMENT_TARGET = nil
    return joined
end
