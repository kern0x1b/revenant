local swift = import("@addon.revenant.apple.swift", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local shim = path.join(backports, "src", "Translation", "Translation.swift")
local fixtures = path.join(backports, "tests", "translation")

local function run(compiler, arguments, log)
    return os.execv(compiler, arguments, {try = true, stdout = log, stderr = log}) == 0
end

function main()
    local runtime = os.getenv("REVENANT_SWIFT_RUNTIME")
    local compiler = os.getenv("REVENANT_SWIFT_COMPILER")
    local modules = os.getenv("REVENANT_TEST_MODULES")
    assert(runtime and runtime ~= "", "REVENANT_SWIFT_RUNTIME is unset: run this through the swift_backports_tests target")
    assert(compiler and compiler ~= "", "REVENANT_SWIFT_COMPILER is unset: run this through the swift_backports_tests target")
    assert(modules and modules ~= "", "REVENANT_TEST_MODULES is unset: run this through the swift_backports_tests target")
    local search = {}
    for folder in modules:gmatch("[^:]+") do
        table.join2(search, {"-I", folder})
    end
    local out = workspace.run("backports-tests", "Translation")
    os.rm(out)
    os.mkdir(out)
    local function flags_for(module)
        local flags = swift.runtime_flags({architecture = "armv7", deployment = "6.0", sdk = workspace.sdk(),
                                           resources = path.join(runtime, "lib", "swift"), module = module, optimize = "none"})
        table.join2(flags, search, {"-I", path.join(runtime, "lib", "swift", "iphoneos"), "-swift-version", "5"})
        return flags
    end
    local log = path.join(out, "shim.log")
    local built = table.join(flags_for("Translation"), {"-emit-module", "-emit-module-path", path.join(out, "Translation.swiftmodule"), shim})
    if not run(compiler, built, log) then
        raise("the Translation shim does not compile for armv7 iOS 6: %s", io.readfile(log) or "")
    end
    local consumer = table.join(flags_for("TranslationUse"), {"-I", out})
    local guarded_log = path.join(out, "guarded.log")
    if not run(compiler, table.join(consumer, {"-typecheck", path.join(fixtures, "guarded.swift")}), guarded_log) then
        raise("a use of translationPresentation guarded by iOS 17.4 does not typecheck against the shim: %s", io.readfile(guarded_log) or "")
    end
    local unguarded_log = path.join(out, "unguarded.log")
    if run(compiler, table.join(consumer, {"-typecheck", path.join(fixtures, "unguarded.swift")}), unguarded_log) then
        raise("translationPresentation typechecks on iOS 6 without an availability guard: the shim is not marked iOS 17.4")
    end
    local diagnostic = io.readfile(unguarded_log) or ""
    if not diagnostic:find("is only available in iOS 17.4 or newer", 1, true) then
        raise("the unguarded use fails for another reason than iOS 17.4 availability: %s", diagnostic)
    end
end
