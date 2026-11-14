local workspace = import("@addon.revenant.workspace", {anonymous = true})

function main()
    local dir = path.absolute(os.scriptdir())
    local backports = path.absolute(path.join(dir, ".."))
    local source = path.join(dir, "alias_protocols", "main.m")
    local out = workspace.run("backports-foundation")
    local program = path.join(out, "alias_protocols_test")
    os.vrunv("xcrun", {"clang", "-fobjc-arc", "-Wall", "-Werror=protocol", "-Werror=objc-property-implementation", "-Wno-unused-function",
                       "-I", path.join(dir, "Foundation"), "-I", path.join(backports, "src", "Foundation"), "-framework", "Foundation", "-o", program, source})
    local report = path.join(out, "alias_protocols_test.txt")
    local code = os.execv(program, {}, {try = true, stdout = report, stderr = report})
    local text = io.readfile(report) or ""
    assert(code == 0 and text:find("failures=0", 1, true), "an alias class does not carry the protocols its source lists, or its registered alias does not:\n" .. text)
    local negative = path.join(out, "alias_protocols_negative.txt")
    local refused = os.execv(program, {"--negative"}, {try = true, stdout = negative, stderr = negative})
    assert(refused ~= 0, "the negative run asks for a protocol the alias does not adopt and must fail:\n" .. (io.readfile(negative) or ""))
    local unwrapped = path.join(out, "alias_protocols_negative_wrap.txt")
    local stale = os.execv(program, {"--negative-wrap"}, {try = true, stdout = unwrapped, stderr = unwrapped})
    local seen = io.readfile(unwrapped) or ""
    assert(stale ~= 0 and seen:find("FAIL the proxy, which an app or a translated library binds to, runs the wrapper too", 1, true),
           "wrapping only the system method must leave the proxy on the system implementation, and the check must say so:\n" .. seen)
end
