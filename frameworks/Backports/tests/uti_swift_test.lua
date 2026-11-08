local swift = import("@addon.revenant.apple.swift", {anonymous = true})
local lowered = import("@addon.revenant.apple.lowered", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local fixture = path.join(backports, "tests", "UniformTypeIdentifiers", "bridge.swift")
local sources = path.join(backports, "src", "UniformTypeIdentifiers")

local function flags_for(module, runtime, sdk, vfs, include)
    local flags = swift.runtime_flags({architecture = "armv7", deployment = "6.0", sdk = sdk,
                                       resources = path.join(runtime, "lib", "swift"), module = module, optimize = "none"})
    table.join2(flags, {"-vfsoverlay", vfs, "-Xcc", "-I" .. include, "-Xfrontend", "-application-availability-floor", "-Xfrontend", "15"})
    return flags
end

local function emit_module(compiler, folder, files, runtime, sdk, vfs, include)
    os.mkdir(folder)
    local flags = flags_for("UniformTypeIdentifiers", runtime, sdk, vfs, include)
    table.join2(flags, {"-Xfrontend", "-import-underlying-module", "-emit-module", "-emit-module-path", path.join(folder, "UniformTypeIdentifiers.swiftmodule")})
    table.join2(flags, files)
    os.vrunv(compiler, flags)
end

local function compile_fixture(compiler, modules, object, runtime, sdk, vfs, include, log)
    local flags = flags_for("UniformTypeIdentifiersBridge", runtime, sdk, vfs, include)
    table.join2(flags, {"-I", modules, "-parse-as-library", "-c", fixture, "-o", object})
    return os.execv(compiler, flags, {try = true, stdout = log, stderr = log})
end

function main()
    local runtime = os.getenv("REVENANT_SWIFT_RUNTIME")
    local compiler = os.getenv("REVENANT_SWIFT_COMPILER")
    assert(runtime and runtime ~= "", "REVENANT_SWIFT_RUNTIME is unset: run this through the swift_backports_tests target")
    assert(compiler and compiler ~= "", "REVENANT_SWIFT_COMPILER is unset: run this through the swift_backports_tests target")
    local sdk = workspace.sdk()
    local out = workspace.run("backports-tests", "UniformTypeIdentifiersBridge")
    local overlay = path.join(out, "overlay")
    local vfs = lowered.overlay(sdk, overlay, nil, nil, nil, swift.triple("armv7", "6.0"))
    local include = lowered.include_directory(overlay)
    local all = os.files(path.join(sources, "*.swift"))
    local without = {}
    for _, file in ipairs(all) do
        if path.filename(file) ~= "Bridging.swift" then
            table.insert(without, file)
        end
    end
    assert(#without == #all - 1, "Bridging.swift is not among the sources of the module: " .. sources)

    local bridged = path.join(out, "bridged")
    emit_module(compiler, bridged, all, runtime, sdk, vfs, include)
    local log = path.join(out, "bridged.log")
    local code = compile_fixture(compiler, bridged, path.join(out, "bridged.o"), runtime, sdk, vfs, include, log)
    assert(code == 0, "the fixture does not compile against the module that bridges UTType: " .. log)
    assert(os.isfile(path.join(out, "bridged.o")), "the fixture compiled and wrote no object: " .. log)

    local bare = path.join(out, "unbridged")
    emit_module(compiler, bare, without, runtime, sdk, vfs, include)
    local control = path.join(out, "unbridged.log")
    code = compile_fixture(compiler, bare, path.join(out, "unbridged.o"), runtime, sdk, vfs, include, control)
    assert(code ~= 0, "the fixture compiles against a module that does not bridge UTType, so the test does not measure the bridge: " .. control)
    assert(io.readfile(control):find("Array<UTType>", 1, true), "the fixture fails without the bridge for another reason: " .. control)
end
