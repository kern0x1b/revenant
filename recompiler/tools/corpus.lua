import("env")
import("core.package.package")

function swift()
    local installs = os.dirs(path.join(package.installdir(), "s", "swift", "*", "*"))
    table.sort(installs)
    for _, install in ipairs(installs) do
        local layouts = path.join(install, "share", "swift-source", "stdlib", "toolchain", "legacy_layouts", "iphoneos", "layouts-arm64.yaml")
        if os.isfile(path.join(install, "bin", "swiftc")) and os.isfile(layouts) then
            return install, layouts
        end
    end
    raise("no revenant@swift install under %s carries its own legacy_layouts source cache (docs/reference/recompiler/corpus.md says why it is needed)", path.join(package.installdir(), "s", "swift"))
end

function swift_armv7()
    local installs = os.dirs(path.join(package.installdir(), "s", "swift-runtime", "*", "*"))
    table.sort(installs)
    for index = #installs, 1, -1 do
        local install = installs[index]
        if os.isfile(path.join(install, "lib", "swift", "iphoneos", "Swift.swiftmodule", "armv7-apple-ios.swiftmodule")) and
           os.isfile(path.join(install, "lib", "swift", "iphoneos", "libswiftCore.dylib")) then
            return install
        end
    end
    raise("no revenant@swift-runtime install under %s carries the armv7 Swift runtime", path.join(package.installdir(), "s", "swift-runtime"))
end

function libcxx_armv7()
    local installs = os.dirs(path.join(package.installdir(), "l", "libcxx", "*", "*"))
    table.sort(installs)
    for index = #installs, 1, -1 do
        local lib = path.join(installs[index], "lib")
        if os.isfile(path.join(lib, "libc++.1.dylib")) and os.isfile(path.join(lib, "libc++abi.1.dylib")) and
           os.iorunv("lipo", {"-info", path.join(lib, "libc++.1.dylib")}):find("armv7", 1, true) then
            return lib
        end
    end
    raise("no revenant@libcxx install under %s carries an armv7 libc++", path.join(package.installdir(), "l", "libcxx"))
end

function setup(name, out)
    local e = env()
    out = path.absolute(out or path.join(e.builddir, "recompiler", "corpus", name))
    os.mkdir(out)
    return e, out
end

function fail(format, ...)
    raise("FAIL: " .. format, ...)
end

function ios(e, argv)
    os.execv("xcrun", table.join({"clang", "-target", "arm64-apple-ios12.0", "-isysroot", e.sdk}, argv))
end

function armv7(e, argv)
    os.execv("xcrun", table.join({"clang", "-target", "armv7-apple-ios6.0", "-isysroot", e.sdk, "-fuse-ld=" .. e.ld}, argv))
end

function sign(e, file)
    os.execv(e.ldid, {"-S", file})
end

function run(program, argv, log)
    local errors = log .. ".stderr"
    local status = os.execv(program, argv, {stdout = log, stderr = errors, try = true})
    local text = (os.isfile(log) and io.readfile(log) or "") .. (os.isfile(errors) and io.readfile(errors) or "")
    io.writefile(log, text)
    os.tryrm(errors)
    return status == 0, text
end

function options(...)
    local found = {host_only = false, device_only = false}
    for _, argument in ipairs({...}) do
        if type(argument) == "table" then
            found.host_only = argument.host_only or found.host_only
            found.device_only = argument.device_only or found.device_only
        elseif argument == "--host-only" then
            found.host_only = true
        elseif argument == "--device-only" then
            found.device_only = true
        end
    end
    return found
end

function device()
    local module = import("@addon.revenant.device", {anonymous = true})
    local settings = module.bind(os.projectdir(), nil)
    if not module.held(settings) then
        raise("this check goes to the phone and this process (%s) does not hold it: claim it first with REVENANT_DEVICE_HOLDER set and `./xmakew device --minutes=N claim`, inside a window the coordinator gave you; a run without the phone is --host-only", module.holder_name() or "no REVENANT_DEVICE_HOLDER")
    end
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
