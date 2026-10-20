local text = import("lib.text", {rootdir = os.scriptdir(), anonymous = true})

local function output_of(program, args)
    return os.iorunv(program, args)
end

local function bisect_right(list, key)
    local lo, hi = 1, #list
    while lo <= hi do
        local mid = (lo + hi) // 2
        if list[mid][1] <= key then
            lo = mid + 1
        else
            hi = mid - 1
        end
    end
    return lo - 1
end

local function hex_value(s)
    return tonumber(string.gsub(s, "^0x", ""), 16)
end

local function app_base(report)
    local from = 1
    while true do
        local at = string.find(report, "0x", from, true)
        if not at then
            return nil
        end
        local before = at > 1 and string.sub(report, at - 1, at - 1) or ""
        local hex = string.match(report, "^0x[%da-f]+", at)
        if before ~= "" and string.find(before, "%s") and hex then
            local after = at + #hex
            if string.sub(report, after, after + 2) == " - " then
                local line_end = string.find(report, "\n", after, true) or (#report + 1)
                if string.find(string.sub(report, after + 3, line_end - 1), "+SwiftUIDemo", 1, true) then
                    return hex_value(hex)
                end
            end
        end
        from = at + 1
    end
end

function symbolicate(file, binary)
    if not os.isfile(file) then
        raise("%s: no such report; ./xmakew l frameworks/SwiftUI/tools/device.lua crash fetches the latest from the claimed device", file)
    end
    if not os.isfile(binary) then
        raise("%s: no such binary; build SwiftUIDemo first", binary)
    end
    local report = output_of("plutil", {"-extract", "description", "raw", "-o", "-", file})
    report = string.gsub(report, "\n$", "")

    local exception = string.match(report, "Exception Type:[^\n]*")
    if exception == nil then
        raise("the report has no Exception Type line")
    end
    print(exception)
    local base = app_base(report)
    if base == nil then
        raise("the report has no SwiftUIDemo frame to take the base address from")
    end

    local symbols = {}
    for _, line in ipairs(text.split(output_of("nm", {"-n", binary}), "\n")) do
        local parts = {}
        for word in string.gmatch(line, "%S+") do
            parts[#parts + 1] = word
        end
        if #parts >= 3 then
            local address = tonumber(parts[1], 16)
            if address then
                symbols[#symbols + 1] = {address, parts[3]}
            end
        end
    end

    local frames = {}
    local _, backtrace_start = string.find(report, "Last Exception Backtrace:\n(", 1, true)
    if backtrace_start then
        local close = string.find(report, ")", backtrace_start + 1, true)
        for word in string.gmatch(string.sub(report, backtrace_start + 1, close - 1), "%S+") do
            frames[#frames + 1] = hex_value(word)
        end
    end

    print("exception backtrace, app frames:")
    for i = 1, math.min(#frames, 40) do
        local frame = frames[i]
        if base and frame >= base and frame < base + 0x300000 then
            if #symbols == 0 then
                raise("no symbols in %s; nm printed none", binary)
            end
            local count = bisect_right(symbols, frame - base + 0x4000)
            local index = count > 0 and count or #symbols
            local demangled = text.strip(output_of("xcrun", {"swift-demangle", "--simplified", symbols[index][2]}))
            print("   " .. string.sub(demangled, 1, 140))
        end
    end

    print("crashed thread top:")
    local between = text.split(report, "Thread 0 Crashed:")
    if between[2] == nil then
        raise("the report has no Thread 0 Crashed section")
    end
    local section = text.split(between[2], "Thread 1")[1]
    for _, line in ipairs(text.split(section, "\n")) do
        local number, name = string.match(line, "^(%d+)%s+(%S+)%s+0x[%da-f]+ 0x[%da-f]+ %+ %d+")
        if number and string.find("0123456", number, 1, true) then
            print("   " .. number .. " " .. name)
        end
    end
end

function main(report, binary)
    if not report then
        raise("usage: ./xmakew l frameworks/SwiftUI/tools/crash.lua REPORT.plist [BINARY]")
    end
    local tree = import("lib.tree", {rootdir = os.scriptdir(), anonymous = true})
    symbolicate(report, binary or path.join(tree.demo(), "SwiftUIDemo"))
end
