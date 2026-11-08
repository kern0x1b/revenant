local swift = import("@addon.revenant.apple.swift", {anonymous = true})
local lowered = import("@addon.revenant.apple.lowered", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))

local UNDERLYING = {"-Xfrontend", "-import-underlying-module"}

local OVERLAYS = {
    {name = "SceneKit", folder = "SceneKit", fixture = path.join("SceneKit", "overlay.swift"), flags = UNDERLYING,
     without = "missing argument labels"},
    {name = "Vision", folder = "Vision", fixture = path.join("Vision", "overlay.swift"), flags = UNDERLYING,
     without = "has no member 'boundingBox'"},
    {name = "AuthenticationServices", folder = path.join("AuthenticationServices", "Updater"), fixture = path.join("AuthenticationServices", "updater.swift"),
     flags = {"-module-link-name", "swiftAuthenticationServices", "-Xfrontend", "-disable-implicit-string-processing-module-import"},
     without = "cannot find 'ASCredentialUpdater' in scope"},
}

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
    local out = workspace.run("backports-tests", "FrameworkOverlay")
    local overlay = path.join(out, "overlay")
    local vfs = lowered.overlay(sdk, overlay, nil, nil, nil, swift.triple("armv7", "6.0"))
    local include = lowered.include_directory(overlay)
    local modules = path.join(out, "modules")
    os.mkdir(modules)
    for _, entry in ipairs(OVERLAYS) do
        local emit = flags_for(entry.name, runtime, sdk, vfs, include)
        table.join2(emit, entry.flags, {"-emit-module", "-emit-module-path", path.join(modules, entry.name .. ".swiftmodule")})
        table.join2(emit, os.files(path.join(backports, "src", entry.folder, "*.swift")))
        os.vrunv(compiler, emit)
    end
    for _, entry in ipairs(OVERLAYS) do
        local fixture = path.join(backports, "tests", entry.fixture)
        local check = flags_for(entry.name .. "Overlay", runtime, sdk, vfs, include)
        table.join2(check, {"-I", modules, "-typecheck", "-parse-as-library", fixture})
        os.vrunv(compiler, check)
        local bare = flags_for(entry.name .. "Overlay", runtime, sdk, vfs, include)
        table.join2(bare, {"-typecheck", "-parse-as-library", fixture})
        local log = path.join(out, entry.name .. "-without-overlay.log")
        local code = os.execv(compiler, bare, {try = true, stdout = log, stderr = log})
        assert(code ~= 0, entry.name .. ": the fixture typechecks without the overlay, so the test does not measure the overlay: " .. log)
        assert(io.readfile(log):find(entry.without, 1, true), entry.name .. ": the fixture fails without the overlay for another reason: " .. log)
    end
end
