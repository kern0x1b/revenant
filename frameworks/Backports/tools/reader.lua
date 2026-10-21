local BATCH = 200

local function chunks(files)
    local out = {}
    for index = 1, #files, BATCH do
        local chunk = {}
        for position = index, math.min(index + BATCH - 1, #files) do
            table.insert(chunk, files[position])
        end
        table.insert(out, chunk)
    end
    return out
end

function each_output(program, flags, files, handle)
    for _, chunk in ipairs(chunks(files)) do
        local known = {}
        for _, file in ipairs(chunk) do
            known[file] = true
        end
        local ok, text, _, errors = os.iorunv(program, table.join(flags, chunk))
        assert(ok, string.format("%s failed on %d files: %s", program, #chunk, errors or "no reason given"))
        local current = #chunk == 1 and chunk[1] or nil
        for line in text:gmatch("[^\n]+") do
            local header = line:match("^(.+):$")
            if header and known[header] then
                current = header
            elseif current then
                handle(current, line)
            end
        end
    end
end
