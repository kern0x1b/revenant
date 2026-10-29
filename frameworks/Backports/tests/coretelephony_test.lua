local lowered = import("@addon.revenant.apple.lowered", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))

function main()
    local sdk = workspace.sdk()
    local out = workspace.run("backports-tests", "CoreTelephony")
    local vfs = lowered.overlay(sdk, path.join(out, "overlay"))
    local include = lowered.include_directory(path.join(out, "overlay"))
    local clang = {"-target", "armv7-apple-ios6.0", "-isysroot", sdk, "-ivfsoverlay", vfs, "-I", include,
                   "-fobjc-arc", "-fsyntax-only", "-Werror", "-Wunguarded-availability"}
    os.vrunv("clang", table.join(clang, {"-x", "objective-c", path.join(backports, "tests", "coretelephony", "use.m")}))
    os.vrunv("clang", table.join(clang, {path.join(backports, "src", "CoreTelephony", "CTTelephonyNetworkInfo+RadioAccess.m")}))
end
