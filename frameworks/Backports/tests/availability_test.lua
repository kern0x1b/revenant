local lowered = import("@addon.revenant.apple.lowered", {anonymous = true})
local swift = import("@addon.revenant.apple.swift", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local fixtures = path.join(backports, "tests", "availability")

local FAMILIES = {
    {fixture = "background_fetch.swift", lowered = true},
    {fixture = "user_activity.swift", lowered = true},
    {fixture = "url_session.swift", lowered = true},
    {fixture = "app_delegate.swift", lowered = true},
    {fixture = "dispatch.swift", lowered = false},
}

local function typecheck_flags(sdk, runtime, module, vfs, modules, fixture)
    local flags = swift.runtime_flags({architecture = "armv7", deployment = "6.0", sdk = sdk,
                                       resources = path.join(runtime, "lib", "swift"), module = module, optimize = "none"})
    if vfs then
        table.join2(flags, {"-vfsoverlay", vfs})
    end
    table.join2(flags, {"-module-cache-path", modules, "-typecheck", fixture})
    return flags
end

function main()
    local runtime = os.getenv("REVENANT_SWIFT_RUNTIME")
    local compiler = os.getenv("REVENANT_SWIFT_COMPILER")
    assert(runtime and runtime ~= "", "REVENANT_SWIFT_RUNTIME is unset: run this through the swift_backports_tests target")
    assert(compiler and compiler ~= "", "REVENANT_SWIFT_COMPILER is unset: run this through the swift_backports_tests target")
    local sdk = workspace.sdk()
    local out = workspace.run("backports-tests", "Availability")
    local vfs = lowered.overlay(sdk, path.join(out, "overlay"))
    local failures = {}
    for _, family in ipairs(FAMILIES) do
        local fixture = path.join(fixtures, family.fixture)
        local log = path.join(out, family.fixture .. ".log")
        local overlay_status = os.execv(compiler, typecheck_flags(sdk, runtime, "Availability", vfs, path.join(out, "modules"), fixture),
                                        {try = true, stdout = log, stderr = log})
        if overlay_status ~= 0 then
            table.insert(failures, family.fixture .. " does not typecheck at iOS 6.0 with the lowered overlay:\n" .. (io.readfile(log) or ""))
        elseif family.lowered then
            local raw_status = os.execv(compiler, typecheck_flags(sdk, runtime, "Availability", nil, path.join(out, "raw-modules"), fixture),
                                        {try = true, stdout = log, stderr = log})
            if raw_status == 0 then
                table.insert(failures, family.fixture .. " typechecks at iOS 6.0 without the overlay, so it does not prove the lowering")
            end
        end
    end
    assert(#failures == 0, table.concat(failures, "\n"))
end
