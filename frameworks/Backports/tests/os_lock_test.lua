local lowered = import("@addon.revenant.apple.lowered", {anonymous = true})
local swift = import("@addon.revenant.apple.swift", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local fixture = path.join(backports, "tests", "os_lock", "main.swift")

function main()
    local runtime = os.getenv("REVENANT_SWIFT_RUNTIME")
    local compiler = os.getenv("REVENANT_SWIFT_COMPILER")
    assert(runtime and runtime ~= "", "REVENANT_SWIFT_RUNTIME is unset: run this through the swift_backports_tests target")
    assert(compiler and compiler ~= "", "REVENANT_SWIFT_COMPILER is unset: run this through the swift_backports_tests target")
    local sdk = workspace.sdk()
    local out = workspace.run("backports-tests", "OSLock")
    local vfs = lowered.overlay(sdk, path.join(out, "overlay"))
    local flags = swift.runtime_flags({architecture = "armv7", deployment = "6.0", sdk = sdk,
                                       resources = path.join(runtime, "lib", "swift"), module = "OSLock", optimize = "none"})
    table.join2(flags, {"-vfsoverlay", vfs, "-typecheck", fixture})
    os.vrunv(compiler, flags)
    local include = lowered.include_directory(path.join(out, "overlay"))
    local clang = {"-target", "armv7-apple-ios6.0", "-isysroot", sdk, "-ivfsoverlay", vfs, "-I", include, "-fsyntax-only", "-Werror"}
    os.vrunv("clang", table.join(clang, {"-x", "objective-c", "-fobjc-arc", path.join(backports, "tests", "os_lock", "use.m")}))
    os.vrunv("clang", table.join(clang, {"-x", "c", "-std=gnu11", "-Wpedantic", path.join(backports, "tests", "os_lock", "use.c")}))
end
