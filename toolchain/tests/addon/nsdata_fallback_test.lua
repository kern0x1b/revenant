import("fixtures")

local PATCH = path.join(os.scriptdir(), "..", "..", "..", "packages", "s", "swift-runtime", "patches", "overlays",
                        "the-overlay-of-foundation-asks-for-ios-7-where-it-reaches-ios-7.patch")

local HARNESS = [[
import Foundation

final class Run {
    let bytes: UnsafeRawPointer
    let length: Int

    init(bytes: UnsafeRawPointer, length: Int) {
        self.bytes = bytes
        self.length = length
    }

    subscript(position: Int) -> UInt8 {
%s
    }
}

let sentinel: UInt8 = 0xAB
let payload: [UInt8] = [1, 2, 3, 4]
let margin = 16
let storage = UnsafeMutablePointer<UInt8>.allocate(capacity: margin + payload.count + margin)
storage.initialize(repeating: sentinel, count: margin + payload.count + margin)
for (index, byte) in payload.enumerated() {
    storage[margin + index] = byte
}
let run = Run(bytes: UnsafeRawPointer(storage + margin), length: payload.count)
for position in [-margin, -1, 0, 1, 2, 3, 4, payload.count + margin - 1] {
    print("\(position) \(run[position])")
}
]]

local EXPECTED = {["-16"] = "0", ["-1"] = "0", ["0"] = "1", ["1"] = "2", ["2"] = "3", ["3"] = "4", ["4"] = "0", ["19"] = "0"}
local SENTINEL = "171"

local function fallback()
    local text = io.readfile(PATCH)
    local _, header = text:find("public subscript(position: Int) -> UInt8 {\n", 1, true)
    if not header then
        return nil
    end
    local body = text:match("^%+        guard #available%(macOS 10%.9, iOS 7%.0, %*%) else {\n(.-)%+        }\n", header + 1)
    if not body then
        return nil
    end
    local lines = {}
    for line in body:gmatch("[^\n]+") do
        table.insert(lines, (line:gsub("^%+", "")))
    end
    return lines
end

local function readings(folder, name, lines)
    local source = path.join(folder, name .. ".swift")
    io.writefile(source, string.format(HARNESS, table.concat(lines, "\n")))
    local binary = path.join(folder, name)
    fixtures.run(folder, "xcrun", {"swiftc", "-O", source, "-o", binary})
    local read = {}
    for position, value in fixtures.run(folder, binary, {}):gmatch("(%-?%d+) (%d+)") do
        read[position] = value
    end
    return read
end

function failures(opt)
    local found = {}
    local lines = fallback()
    if not lines or #lines == 0 then
        return {"the patch has no fallback in NSData's subscript for a release before iOS 7, so there is nothing to read"}
    end
    local folder = fixtures.scratch()
    local errors = fixtures.refusal(function ()
        local read = readings(folder, "shipped", lines)
        local positions = table.keys(EXPECTED)
        table.sort(positions)
        for _, position in ipairs(positions) do
            if read[position] ~= EXPECTED[position] then
                table.insert(found, string.format("the fallback of NSData's subscript answers %s for position %s, not %s; outside the data it must answer 0 and not the byte next to it",
                                                  tostring(read[position]), position, EXPECTED[position]))
            end
        end
        local unchecked = {}
        for _, line in ipairs(lines) do
            if not line:find("guard position", 1, true) then
                table.insert(unchecked, line)
            end
        end
        if #unchecked == #lines then
            table.insert(found, "the fallback has no bounds check, so the control that removes it would remove nothing")
        else
            local control = readings(folder, "control", unchecked)
            if control["4"] ~= SENTINEL or control["-1"] ~= SENTINEL then
                table.insert(found, "the fallback without its bounds check does not read the byte next to the data, so the test would not notice a missing check")
            end
        end
    end)
    if errors then
        table.insert(found, errors)
    end
    os.tryrm(folder)
    return found
end
