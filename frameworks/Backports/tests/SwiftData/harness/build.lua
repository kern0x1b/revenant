local process = import("process", {rootdir = path.join(os.scriptdir(), "..", ".."), anonymous = true})

local REQUIRED = {"REVENANT_SWIFTC", "REVENANT_SWIFT_RESOURCE", "REVENANT_SWIFT_MODULES", "REVENANT_SWIFT_PORT",
                   "REVENANT_SWIFT_SDK", "REVENANT_SWIFT_AVAILABILITY", "REVENANT_FOUNDATION_MODULES"}

local function required(name)
    local value = os.getenv(name)
    if value == nil or value == "" or not os.exists(value) then
        io.stderr:write(string.format("build.lua needs %s naming something that exists; it is not set here.\n", name))
        os.exit(2)
    end
    return value
end

local function availability_flags(file)
    local flags = {}
    for line in io.readfile(file):gmatch("[^\n]+") do
        local name = line:match("^([^:]*)")
        if name ~= "" and name:sub(1, 1) ~= "#" then
            table.join2(flags, {"-Xfrontend", "-define-availability", "-Xfrontend", name .. ":*"})
            if name:startswith("SwiftStdlib") then
                local renamed = name:gsub("SwiftStdlib", "StdlibDeploymentTarget", 1)
                table.join2(flags, {"-Xfrontend", "-define-availability", "-Xfrontend", renamed .. ":*"})
            end
        end
    end
    return flags
end

local function undefined_count(dylib)
    local text = os.iorunv("nm", {"-u", dylib})
    return process.count(text, "")
end

function main(release)
    release = release or "6.1.3"
    local triple = (os.getenv("REVENANT_SWIFT_ARCH") or "armv7") .. "-apple-ios" .. release
    local harness = os.scriptdir()
    local sources = path.absolute(path.join(harness, "..", "..", "..", "src", "SwiftData"))
    local out = os.getenv("REVENANT_SWIFTDATA_OUT") or path.join(import("@addon.revenant.workspace", {anonymous = true}).scratch(), "swiftdata-build", release)
    os.mkdir(out)
    local values = {}
    for _, name in ipairs(REQUIRED) do
        values[name] = required(name)
    end
    local swiftc = values.REVENANT_SWIFTC

    local flags = {"-target", triple, "-clang-target", triple, "-sdk", values.REVENANT_SWIFT_SDK,
                   "-resource-dir", values.REVENANT_SWIFT_RESOURCE, "-Xfrontend", "-bundled-swift-runtime",
                   "-runtime-compatibility-version", "none", "-wmo", "-parse-as-library",
                   "-I", values.REVENANT_SWIFT_MODULES, "-vfsoverlay", values.REVENANT_SWIFT_PORT}
    table.join2(flags, availability_flags(values.REVENANT_SWIFT_AVAILABILITY))
    local plugins = os.getenv("REVENANT_SWIFT_PLUGIN_PATH")
    if plugins and plugins ~= "" then
        table.join2(flags, {"-plugin-path", plugins})
    end
    table.join2(flags, {"-I", values.REVENANT_FOUNDATION_MODULES})
    for map in (os.getenv("REVENANT_FOUNDATION_CMODULES") or ""):gmatch("%S+") do
        table.join2(flags, {"-Xcc", "-fmodule-map-file=" .. map, "-Xcc", "-I" .. path.directory(map),
                            "-Xcc", "-I" .. path.directory(path.directory(map))})
    end

    local swift_files = os.files(path.join(sources, "*.swift"))
    table.sort(swift_files)
    local errors = path.join(out, "compile.err")
    local object = path.join(out, "SwiftData.o")
    local module = path.join(out, "SwiftData.swiftmodule")

    local status = process.run(swiftc, table.join(flags, {"-module-name", "SwiftData", "-O", "-c", "-o", object}, swift_files),
                               {stderr = errors})
    if status ~= 0 then
        print("COMPILE FAILED with status " .. tostring(status) .. "; see " .. errors)
        os.exit(1)
    end
    local emit_errors = path.join(out, "emit.err")
    status = process.run(swiftc, table.join(flags, {"-module-name", "SwiftData", "-emit-module-path", module, "-emit-module"}, swift_files),
                         {stderr = emit_errors})
    io.writefile(errors, io.readfile(errors) .. io.readfile(emit_errors))
    local text = io.readfile(errors)
    print("COMPILE ERRORS " .. process.count(text, "error:"))
    if process.count(text, "error:") > 0 or status ~= 0 then
        local shown = 0
        for _, line in ipairs(process.lines(text)) do
            if line:find("error:", 1, true) and shown < 10 then
                print(line)
                shown = shown + 1
            end
        end
        os.exit(1)
    end
    local kind = os.iorunv("file", {"-b", object})
    print(string.format("OBJECT  %s %d bytes  %s", path.filename(object), os.filesize(object), kind:trim()))

    status = process.run(os.programfile(), {"l", path.join(harness, "symbols.lua")}, {envs = {REVENANT_SWIFTDATA_OBJECT = object}})
    if status ~= 0 then
        os.exit(status)
    end

    local backports = os.getenv("REVENANT_BACKPORTS")
    if backports and backports ~= "" and os.isfile(path.join(backports, "libCoreDataBackports.dylib")) then
        local ld64 = os.getenv("REVENANT_LD64") or ""
        local linkflags = {}
        if ld64 ~= "" and os.isexec(ld64) then
            linkflags = {"-use-ld=" .. ld64}
        end
        print("LINK -emit-library -lCoreDataBackports")
        local dylib = path.join(out, "libSwiftData.dylib")
        local linked = process.run(swiftc, table.join(flags, linkflags, {"-module-name", "SwiftData", "-emit-library", "-o", dylib,
                                                                         "-L", backports, "-lCoreDataBackports", object}),
                                   {stderr = path.join(out, "link.err")})
        if linked == 0 then
            local listing = os.iorunv("nm", {"-g", dylib})
            local defined = process.count(listing, " T ") + process.count(listing, " S ") + process.count(listing, " B ")
            print(string.format("LINKED %s %d bytes", dylib, os.filesize(dylib)))
            print(string.format("SYMBOLS defined=%d undefined=%d", defined, undefined_count(dylib)))
            if defined < 50 then
                print(string.format("LINK SUSPECT: a library with %d defined symbols did not take the module's code", defined))
            end
            local otool = os.iorunv("otool", {"-L", dylib})
            for _, line in ipairs(process.lines(otool)) do
                print("LC " .. line)
            end
        else
            print("LINK FAILED - the undefined symbols are in the UNDEFINED lines above")
        end
    else
        print("LINK not attempted: set REVENANT_BACKPORTS to a directory holding libCoreDataBackports.dylib")
    end
end
