import("env")

function setup(name, out)
    local e = env()
    out = path.absolute(out or path.join(e.builddir, "katabasis", "corpus", name))
    os.mkdir(out)
    return e, out
end

function sorted(list)
    return env.sorted(list)
end

function fail(format, ...)
    raise("FAIL: " .. format, ...)
end

function ios(e, argv)
    os.execv("xcrun", table.join({"clang", "-target", "arm64-apple-ios12.0", "-isysroot", e.sdk}, argv))
end

function run(program, argv, log)
    local errors = log .. ".stderr"
    local status = os.execv(program, argv, {stdout = log, stderr = errors, try = true})
    local text = (os.isfile(log) and io.readfile(log) or "") .. (os.isfile(errors) and io.readfile(errors) or "")
    io.writefile(log, text)
    os.tryrm(errors)
    return status == 0, text
end

function device()
    local module = import("device", {rootdir = env().modules, anonymous = true})
    local settings = module.bind(os.projectdir(), nil)
    return {
        copy = function (localfile, remote)
            module.copy(settings, localfile, remote)
        end,
        run = function (command)
            return module.run(settings, command, {capture = true})
        end
    }
end

function app(out, name, plist)
    local e = env()
    import("translate").translate(path.join(out, name .. "-arm64"), path.join(out, "includes.h"), path.join(out, "xl"))
    local bundle = path.join(out, name .. "-armv7.app")
    os.tryrm(bundle)
    os.mkdir(bundle)
    os.cp(path.join(out, "xl", name), path.join(bundle, name))
    os.cp(plist, path.join(bundle, "Info.plist"))
    os.execv(e.ldid, {"-S", path.join(bundle, name)})
    print("built %s", bundle)
    return bundle
end

function same(expected, actual, message)
    if io.readfile(expected) ~= io.readfile(actual) then
        os.execv("diff", {expected, actual}, {try = true})
        fail("%s", message)
    end
end
