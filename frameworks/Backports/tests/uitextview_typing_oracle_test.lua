local TESTS = path.absolute(os.scriptdir())
local ORACLE = path.join(TESTS, "uitextview_typing", "oracle.m")
local PLIST = path.join(TESTS, "uitextview_typing", "Info.plist")
local workspace = import("@addon.revenant.workspace", {anonymous = true})

local EXPECTED = {
    "ROW empty default: keys 1 font - color other para - range {0, 0}",
    "ROW font 19 red centred: keys 3 font 19 color red para 1 range {0, 0}",
    "ROW text hello: keys 1 font - color other para - range {5, 0}",
    "ROW set: keys 2 font 23 color blue para - range {5, 0}",
    "ROW set then the caret moved to 2: keys 1 font - color other para - range {2, 0}",
    "ROW set then the same range assigned: keys 2 font 23 color blue para - range {2, 0}",
    "ROW then a range selected: keys 1 font - color other para - range {2, 2}",
    "ROW set then the caret moved to 5: keys 1 font - color other para - range {5, 0}",
    "ROW set then textAlignment centre: keys 3 font 23 color blue para 1 range {5, 0}",
    "ROW font and textColor assigned nil: font nil textColor nil",
    "ROW font and textColor nil: keys 0 font - color - para - range {0, 0}",
    "ROW font 15, textAlignment assigned left: keys 3 font 15 color other para 0 range {0, 0}",
    "ROW font 15, textAlignment untouched: keys 2 font 15 color other para - range {0, 0}",
}

function main()
    local work = workspace.fresh("uitextview-typing-oracle")
    local sdk = os.iorunv("xcrun", {"--sdk", "macosx", "--show-sdk-path"}):trim()
    local clang = os.iorunv("xcrun", {"--sdk", "macosx", "--find", "clang"}):trim()
    local program = path.join(work, "uitextview_typing_oracle")
    os.vrunv(clang, {"-fobjc-arc", "-w", "-target", "arm64-apple-ios17.0-macabi", "-isysroot", sdk,
                     "-iframework", path.join(sdk, "System", "iOSSupport", "System", "Library", "Frameworks"),
                     "-framework", "UIKit", "-framework", "Foundation",
                     "-Wl,-sectcreate,__TEXT,__info_plist," .. PLIST, "-o", program, ORACLE})
    local output = os.iorunv(program, {})
    local rows = {}
    for line in output:gmatch("[^\r\n]+") do
        if line:find("^ROW ") then
            rows[#rows + 1] = line
        end
    end
    io.write(table.concat(rows, "\n"), "\n")
    assert(#rows == #EXPECTED, "the oracle printed " .. #rows .. " rows, expected " .. #EXPECTED .. ":\n" .. output)
    for index, expected in ipairs(EXPECTED) do
        assert(rows[index] == expected, "the later UIKit answered differently:\n  got      " .. rows[index] .. "\n  expected " .. expected)
    end
    os.tryrm(work)
    print("UITEXTVIEW_TYPING_ORACLE_TEST passed")
end
