local TESTS = path.absolute(os.scriptdir())
local BACKPORTS = path.absolute(path.join(TESTS, ".."))
local SOURCE = path.join(BACKPORTS, "src", "UIKit", "NSAttributedString+BaselineOffset7.m")
local ORACLE = path.join(TESTS, "baseline_offset", "oracle.m")
local CORETEXT = path.join(BACKPORTS, "src", "CoreText", "CTDrawBaselineOffset7.m")
local CORETEXT_ORACLE = path.join(TESTS, "baseline_offset", "coretext_oracle.m")
local workspace = import("@addon.revenant.workspace", {anonymous = true})

local function clang()
    return os.iorunv("xcrun", {"--sdk", "macosx", "--find", "clang"}):trim()
end

function main()
    local work = workspace.fresh("baseline-offset-oracle")
    local sdk = os.iorunv("xcrun", {"--sdk", "macosx", "--show-sdk-path"}):trim()
    local program = path.join(work, "baseline_offset_oracle")
    os.vrunv(clang(), {"-isysroot", sdk, "-fobjc-arc", "-w", "-framework", "AppKit", "-framework", "Foundation", "-o", program, SOURCE, ORACLE})
    local output = os.iorunv(program, {})
    io.write(output)
    assert(output:find("plain-equal=1 raised-equal=1 offset-applied=1 negative-differs=1", 1, true),
        "the backport's baseline offset does not match the host's native drawing:\n" .. output)
    local coretext = path.join(work, "coretext_oracle")
    os.vrunv(clang(), {"-isysroot", sdk, "-fobjc-arc", "-w", "-framework", "AppKit", "-framework", "Foundation", "-framework", "CoreText",
                       "-o", coretext, CORETEXT, CORETEXT_ORACLE})
    local drawn = os.iorunv(coretext, {})
    io.write(drawn)
    assert(drawn:find("line-equal=1 run-equal=1 frame-equal=1 negative-differs=1 flipped-lowered=1 flipped-model-raises=1 flipped-appkit-unmoved=1", 1, true),
        "the CoreText backport does not draw what the host's CoreText draws:\n" .. drawn)
    assert(drawn:find("CT-LAYOUT all-equal=1", 1, true),
        "the CoreText backport's layout model does not match the host's CoreText:\n" .. drawn)
    assert(drawn:find("CT-BOUNDS all-equal=1", 1, true),
        "the CoreText backport's bounds do not match the host's CoreText for the options Telegram passes:\n" .. drawn)
    os.tryrm(work)
    print("BASELINE_OFFSET_ORACLE_TEST passed")
end
