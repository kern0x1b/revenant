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
end
