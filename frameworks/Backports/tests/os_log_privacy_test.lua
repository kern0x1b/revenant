local swift = import("@addon.revenant.apple.swift", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local fixtures = path.join(backports, "tests", "os_log_privacy")
local SHAPES = path.join(fixtures, "shapes.swift")
local UNGUARDED = path.join(fixtures, "mail_unguarded.swift")
local MAIL_REFUSAL = "only available in iOS 15"

local function runtime_flags(runtime, sdk, deployment, fixture)
    local flags = swift.runtime_flags({architecture = "armv7", deployment = deployment, sdk = sdk,
                                       resources = path.join(runtime, "lib", "swift"), module = "OSLogPrivacyProbe", optimize = "none"})
    table.join2(flags, {"-typecheck", fixture})
    return flags
end

local function sdk_flags(sdk, fixture)
    return {"-typecheck", "-parse-as-library", "-module-name", "OSLogPrivacyProbe", "-sdk", sdk, "-target", "arm64-apple-ios14.0", fixture}
end

function main()
    local runtime = os.getenv("REVENANT_SWIFT_RUNTIME")
    local compiler = os.getenv("REVENANT_SWIFT_COMPILER")
    assert(runtime and runtime ~= "", "REVENANT_SWIFT_RUNTIME is unset: run this through the swift_backports_tests target")
    assert(compiler and compiler ~= "", "REVENANT_SWIFT_COMPILER is unset: run this through the swift_backports_tests target")
    local sdk = workspace.sdk()
    local out = workspace.run("backports-tests", "OSLogPrivacy")

    os.vrunv(compiler, runtime_flags(runtime, sdk, "6.0", SHAPES))
    os.vrunv(compiler, sdk_flags(sdk, SHAPES))

    local runtime_log = path.join(out, "runtime-unguarded.log")
    local runtime_code = os.execv(compiler, runtime_flags(runtime, sdk, "6.0", UNGUARDED), {try = true, stdout = runtime_log, stderr = runtime_log})
    assert(runtime_code ~= 0, "the runtime accepts a mail mask outside an iOS 15 guard")
    assert(string.find(io.readfile(runtime_log) or "", MAIL_REFUSAL, 1, true), "the runtime refuses the mail mask for another reason: " .. runtime_log)

    local sdk_log = path.join(out, "sdk-unguarded.log")
    local sdk_code = os.execv(compiler, sdk_flags(sdk, UNGUARDED), {try = true, stdout = sdk_log, stderr = sdk_log})
    assert(sdk_code ~= 0, "the SDK accepts a mail mask outside an iOS 15 guard")
    assert(string.find(io.readfile(sdk_log) or "", MAIL_REFUSAL, 1, true), "the SDK refuses the mail mask for another reason: " .. sdk_log)

    print("OS_LOG_PRIVACY_TEST passed (the shapes typecheck on the runtime at iOS 6.0 and on the SDK at iOS 14.0, and a mail mask outside an iOS 15 guard is refused by both)")
end
