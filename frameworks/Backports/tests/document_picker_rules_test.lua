local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local fixture = path.join(backports, "tests", "document_picker_rules", "main.m")
local header = path.join(backports, "src", "UIKit")

local EXPECTED = {
    "png-for-image yes",
    "txt-for-image no",
    "mov-for-movie yes",
    "png-for-item yes",
    "png-for-data yes",
    "zip-for-image no",
    "no-extension-for-data yes",
    "no-extension-for-image no",
    "any-for-no-types yes",
    "unique-pdf-2 report 2.pdf",
    "unique-no-extension-3 README 3",
    "unique-double-extension-2 a.tar 2.gz",
    "base-nested Documents",
    "base-equal mobile",
    "base-sibling-prefix Root",
    "base-none none",
    "chain-under-floor /var/mobile/Documents > /var/mobile/Documents/sub",
    "chain-floor-only /var/mobile/Documents",
    "chain-no-floor /a > /a/b",
}

function main()
    local out = workspace.run("backports-tests", "DocumentPickerRules")
    local binary = path.join(out, "document_picker_rules")
    os.vrunv("xcrun", {"clang", "-fobjc-arc", "-Werror", "-Wall", "-Wno-deprecated-declarations", "-framework", "Foundation", "-framework", "CoreServices", "-I", header, "-o", binary, fixture})
    local got = os.iorunv(binary, {})
    local expected = table.concat(EXPECTED, "\n") .. "\n"
    assert(got == expected, "the document picker rules differ from the picker's contract on the host:\n" .. got)
end
