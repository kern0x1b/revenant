local lowered = import("@addon.revenant.apple.lowered", {anonymous = true})
local swift = import("@addon.revenant.apple.swift", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local fixture = path.join(backports, "tests", "metal_lowering", "main.swift")
local overlay_source = path.join(backports, "src", "IOSurface", "IOSurface.swift")

local function flags_for(module, runtime, sdk, vfs)
    local flags = swift.runtime_flags({architecture = "armv7", deployment = "6.0", sdk = sdk,
                                       resources = path.join(runtime, "lib", "swift"), module = module, optimize = "none"})
    table.join2(flags, {"-vfsoverlay", vfs})
    return flags
end

function main()
    local runtime = os.getenv("REVENANT_SWIFT_RUNTIME")
    local compiler = os.getenv("REVENANT_SWIFT_COMPILER")
    assert(runtime and runtime ~= "", "REVENANT_SWIFT_RUNTIME is unset: run this through the swift_backports_tests target")
    assert(compiler and compiler ~= "", "REVENANT_SWIFT_COMPILER is unset: run this through the swift_backports_tests target")
    local sdk = workspace.sdk()
    local out = workspace.run("backports-tests", "MetalLowering")
    local vfs = lowered.overlay(sdk, path.join(out, "overlay"))
    local modules = path.join(out, "modules")
    if not os.isdir(modules) then
        os.mkdir(modules)
    end
    local emit = flags_for("IOSurface", runtime, sdk, vfs)
    table.join2(emit, {"-emit-module", "-emit-module-path", path.join(modules, "IOSurface.swiftmodule"), overlay_source})
    os.vrunv(compiler, emit)
    local check = flags_for("MetalLowering", runtime, sdk, vfs)
    table.join2(check, {"-I", modules, "-typecheck", fixture})
    os.vrunv(compiler, check)
end
