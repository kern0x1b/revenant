import("fixtures")

local NO_IMPORT = [[
public func probe() -> Int {
    DispatchQueue.main.async {}
    return 0
}
]]

local BARE = [[
public func bare() -> Int {
    return 0
}
]]

local UMBRELLA = "#import <Foundation/Foundation.h>\n"
local FLAT = "int probeValue(void);\n"

local function newest(pattern)
    local best
    for _, file in ipairs(os.files(pattern)) do
        if not best or os.mtime(file) > os.mtime(best) then
            best = file
        end
    end
    return best
end

local function runtime()
    local packages = path.join(os.getenv("XMAKE_GLOBALDIR"), ".xmake", "packages")
    local library = newest(path.join(packages, "s", "swift-runtime", "6.4.0", "*", "lib", "swift", "iphoneos", "libswiftDispatch.dylib"))
    return library and path.directory(path.directory(library))
end

local function compile(folder, opt, resources, name, source, header, umbrella, underlying)
    local work = path.join(folder, name)
    os.mkdir(work)
    local swift = import("apple.swift", {rootdir = opt.modules, anonymous = true})
    local argv = swift.runtime_flags({
        architecture = "armv7", deployment = "6.0", sdk = opt.sdk, resources = resources, module = "Probe", underlying = underlying})
    io.writefile(path.join(work, "source.swift"), source)
    if header then
        io.writefile(path.join(work, "Probe.h"), header)
        io.writefile(path.join(work, "module.modulemap"), string.format("module Probe {\n  %s \"Probe.h\"\n  export *\n}\n",
                                                                        umbrella and "umbrella header" or "header"))
        table.join2(argv, {"-Xcc", "-fmodule-map-file=" .. path.join(work, "module.modulemap")})
    end
    table.join2(argv, {"-module-cache-path", path.join(work, "cache"), "-typecheck", path.join(work, "source.swift")})
    return fixtures.refusal(function ()
        fixtures.run(work, path.join(opt.swift, "bin", "swiftc"), argv)
    end)
end

function failures(opt)
    local found = {}
    local resources = runtime()
    if not resources then
        table.insert(found, "swift-runtime must be installed for iphoneos before this test runs; configure with "
                            .. "./xmakew f -p iphoneos -a armv7, then require revenant@swift-runtime")
        return found
    end
    local folder = fixtures.scratch()
    local refused = compile(folder, opt, resources, "bare", BARE, nil, false, false)
    if refused then
        table.insert(found, "a Swift target with no clang module of its name must compile with the default flags: " .. refused)
    end
    refused = compile(folder, opt, resources, "umbrella", NO_IMPORT, UMBRELLA, true, true)
    if refused then
        table.insert(found, "a Swift file with no import must see DispatchQueue through a module whose umbrella header imports "
                            .. "Foundation, when the target has that clang module: " .. refused)
    end
    refused = compile(folder, opt, resources, "umbrella-unflagged", NO_IMPORT, UMBRELLA, true, false)
    if not refused then
        table.insert(found, "without -Xfrontend -import-underlying-module the imports of the module's umbrella header stay out of "
                            .. "the file, as they do not in Xcode: DispatchQueue must not resolve")
    end
    refused = compile(folder, opt, resources, "flat", NO_IMPORT, FLAT, false, true)
    if not refused then
        table.insert(found, "a module whose header imports nothing must not supply DispatchQueue: the imports come from an "
                            .. "umbrella header that imports Foundation")
    end
    os.tryrm(folder)
    return found
end
