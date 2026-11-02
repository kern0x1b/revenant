local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local fixture = path.join(backports, "tests", "paste_matching", "main.m")
local header = path.join(backports, "src", "UIKit")

local EXPECTED = {
    "png-for-image yes",
    "jpeg-for-image yes",
    "text-for-image no",
    "data-for-image no",
    "text-for-text yes",
    "html-for-text yes",
    "url-for-url yes",
    "file-url-for-url yes",
    "data-then-png-for-image yes",
    "no-providers no",
    "no-types no",
}

function main()
    local out = workspace.run("backports-tests", "PasteMatching")
    local binary = path.join(out, "paste_matching")
    os.vrunv("xcrun", {"clang", "-fobjc-arc", "-framework", "Foundation", "-Werror", "-I", header, "-o", binary, fixture})
    local got = os.iorunv(binary, {})
    local expected = table.concat(EXPECTED, "\n") .. "\n"
    assert(got == expected, "revenant_paste_accepts differs from the conformance rule on the host:\n" .. got)
end
