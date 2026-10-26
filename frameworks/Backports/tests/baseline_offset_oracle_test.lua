local TESTS = path.absolute(os.scriptdir())
local BACKPORTS = path.absolute(path.join(TESTS, ".."))
local SOURCE = path.join(BACKPORTS, "src", "UIKit", "NSAttributedString+BaselineOffset7.m")
local ORACLE = path.join(TESTS, "baseline_offset", "oracle.m")
local workspace = import("@addon.revenant.workspace", {anonymous = true})

local function clang()
    return os.iorunv("xcrun", {"--sdk", "macosx", "--find", "clang"}):trim()
end

function main()
    local work = workspace.fresh("baseline-offset-oracle")
    local program = path.join(work, "baseline_offset_oracle")
    local sdk = os.iorunv("xcrun", {"--sdk", "macosx", "--show-sdk-path"}):trim()
    os.vrunv(clang(), {"-isysroot", sdk, "-fobjc-arc", "-w", "-framework", "AppKit", "-framework", "Foundation", "-o", program, SOURCE, ORACLE})
    local output = os.iorunv(program, {})
    io.write(output)
    assert(output:find("plain-equal=1 raised-equal=1 offset-applied=1 negative-differs=1", 1, true),
        "the backport's baseline offset does not match the host's native drawing:\n" .. output)
    os.tryrm(work)
    print("BASELINE_OFFSET_ORACLE_TEST passed")
end
