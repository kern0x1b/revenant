local REPLACEMENTS = {
    {"return CFRunLoopTimerGetTolerance(underlyingTimer)",
        "if #available(iOS 7.0, *) { return CFRunLoopTimerGetTolerance(underlyingTimer) }\n            return 0"},
    {"CFRunLoopTimerSetTolerance(underlyingTimer, newValue)",
        "if #available(iOS 7.0, *) { CFRunLoopTimerSetTolerance(underlyingTimer, newValue) }"},
}

local function replace_all(s, from, to)
    local out, start = {}, 1
    while true do
        local i, j = string.find(s, from, start, true)
        if not i then
            out[#out + 1] = string.sub(s, start)
            return table.concat(out)
        end
        out[#out + 1] = string.sub(s, start, i - 1)
        out[#out + 1] = to
        start = j + 1
    end
end

function main(...)
    local file = ({...})[1]
    local s = io.readfile(file)
    for _, replacement in ipairs(REPLACEMENTS) do
        s = replace_all(s, replacement[1], replacement[2])
    end
    io.writefile(file, s)
end
