local TOOLCHAIN = path.directory(os.scriptdir())

function licence()
    return path.join(TOOLCHAIN, "LICENSE")
end

function src(...)
    return path.join(TOOLCHAIN, "src", ...)
end

function modules(...)
    return path.join(TOOLCHAIN, "modules", ...)
end
