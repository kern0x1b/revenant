local swift = import("@addon.revenant.apple.swift", {anonymous = true})
local lowered = import("@addon.revenant.apple.lowered", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local fixture = path.join(backports, "tests", "CoreML", "load.swift")
local sources = path.join(backports, "src", "CoreML")

local function flags_for(module, runtime, sdk, vfs, include)
    local flags = swift.runtime_flags({architecture = "armv7", deployment = "6.0", sdk = sdk,
                                       resources = path.join(runtime, "lib", "swift"), module = module, optimize = "none"})
    table.join2(flags, {"-vfsoverlay", vfs, "-Xcc", "-I" .. include, "-Xfrontend", "-application-availability-floor", "-Xfrontend", "15"})
    return flags
end

function main()
    local runtime = os.getenv("REVENANT_SWIFT_RUNTIME")
    local compiler = os.getenv("REVENANT_SWIFT_COMPILER")
    assert(runtime and runtime ~= "", "REVENANT_SWIFT_RUNTIME is unset: run this through the swift_backports_tests target")
    assert(compiler and compiler ~= "", "REVENANT_SWIFT_COMPILER is unset: run this through the swift_backports_tests target")
    local sdk = workspace.sdk()
    local out = workspace.run("backports-tests", "CoreMLSwift")
    local overlay = path.join(out, "overlay")
    local vfs = lowered.overlay(sdk, overlay, nil, nil, nil, swift.triple("armv7", "6.0"))
    local include = lowered.include_directory(overlay)
    local modules = path.join(out, "modules")
    os.mkdir(modules)
    local emit = flags_for("CoreML", runtime, sdk, vfs, include)
    table.join2(emit, {"-Xfrontend", "-import-underlying-module", "-import-objc-header", path.join(sources, "RevenantCoreML.h"),
                       "-emit-module", "-emit-module-path", path.join(modules, "CoreML.swiftmodule")})
    for _, file in ipairs({"Codec.swift", "ModelWriter.swift", "ShapedArray.swift", "MLModelLoad.swift"}) do
        table.insert(emit, path.join(sources, file))
    end
    os.vrunv(compiler, emit)
    local check = flags_for("CoreMLLoad", runtime, sdk, vfs, include)
    table.join2(check, {"-I", modules, "-typecheck", "-parse-as-library", fixture})
    os.vrunv(compiler, check)
    local bare = flags_for("CoreMLLoad", runtime, sdk, vfs, include)
    table.join2(bare, {"-typecheck", "-parse-as-library", fixture})
    local log = path.join(out, "without-overlay.log")
    local code = os.execv(compiler, bare, {try = true, stdout = log, stderr = log})
    assert(code ~= 0, "the fixture typechecks without the overlay, so the test does not measure the overlay: " .. log)
    assert(io.readfile(log):find("asset", 1, true), "the fixture fails without the overlay for another reason: " .. log)
end
