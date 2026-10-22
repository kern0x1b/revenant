local lowered = import("@addon.revenant.apple.lowered", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})

local function compiles(sdk, vfs, source, log)
    local args = {"clang", "-target", "armv7-apple-ios6.0", "-isysroot", sdk,
                  "-Werror=unguarded-availability-new", "-Werror=unguarded-availability"}
    if vfs then
        table.join2(args, {"-ivfsoverlay", vfs})
    end
    table.join2(args, {"-fobjc-arc", "-c", source, "-o", log .. ".o"})
    local code = os.execv("xcrun", args, {try = true, stdout = log, stderr = log})
    return code == 0, io.readfile(log) or ""
end

function main()
    local dir = path.absolute(os.scriptdir())
    local backports = path.absolute(path.join(dir, "..", ".."))
    local source = path.join(backports, "src", "Foundation", "NSJSONSerialization+SortedKeys.m")
    local test = path.join(dir, "json_sorted_keys_test.m")
    local out = workspace.run("backports-foundation")
    local program = path.join(out, "json_sorted_keys_test")
    os.vrunv("xcrun", {"clang", "-fobjc-arc", "-fobjc-weak", "-framework", "Foundation", "-o", program, test, source})
    local report = path.join(out, "json_sorted_keys_test.txt")
    os.execv(program, {}, {stdout = report, stderr = report})
    local text = io.readfile(report) or ""
    assert(text:find("differences 0", 1, true), "the sorted-keys writer differs from NSJSONSerialization:\n" .. text)

    local sdk = workspace.sdk()
    local vfs = lowered.overlay(sdk, path.join(out, "overlay"))
    local probes = path.join(out, "probes")
    os.mkdir(probes)
    local option = path.join(probes, "option.m")
    io.writefile(option, "#import <Foundation/Foundation.h>\nNSJSONWritingOptions f(void) { return NSJSONWritingSortedKeys; }\n")
    local ok, log = compiles(sdk, vfs, option, path.join(probes, "option.log"))
    assert(ok, "the lowered NSJSONSerialization.h does not compile NSJSONWritingSortedKeys at iOS 6.0:\n" .. log)
    local refused, refusal = compiles(sdk, nil, option, path.join(probes, "plain.log"))
    assert(not refused and refusal:find("NSJSONWritingSortedKeys", 1, true),
           "without the overlay, NSJSONWritingSortedKeys must be unavailable at iOS 6.0")
end
