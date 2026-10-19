local pdfwrite = import("pdfwrite", {rootdir = os.scriptdir()})

local function read_file(file)
    local handle = assert(io.open(file, "rb"))
    local data = handle:read("a")
    handle:close()
    return data
end

local function byte_less(a, b)
    for i = 1, math.min(#a, #b) do
        local x, y = a:byte(i), b:byte(i)
        if x ~= y then
            return x < y
        end
    end
    return #a < #b
end

local function float_of(text)
    local value = tonumber(text)
    if value == nil then
        raise("ValueError: could not convert string to float: " .. text)
    end
    return value
end

local function tc_value(raw)
    local at = 1
    while at <= #raw do
        local run_end = at
        while run_end <= #raw and raw:sub(run_end, run_end):find("^[%-%d%.]$") do
            run_end = run_end + 1
        end
        if run_end > at then
            local white_end = run_end
            while white_end <= #raw and raw:sub(white_end, white_end):find("^%s$") do
                white_end = white_end + 1
            end
            if white_end > run_end and raw:sub(white_end, white_end + 1) == "Tc" then
                return raw:sub(at, run_end - 1)
            end
        end
        at = at + 1
    end
    return nil
end

local function has_spacing(data)
    local search = 1
    while true do
        local s = data:find("stream", search, true)
        if not s then
            return false
        end
        local body
        if data:sub(s + 6, s + 6) == "\n" then
            body = s + 7
        elseif data:sub(s + 6, s + 7) == "\r\n" then
            body = s + 8
        end
        local stop = body and data:find("\nendstream", body, true)
        if not stop then
            search = s + 1
        else
            local raw = data:sub(body, stop - 1)
            local next_search = stop + #"\nendstream"
            local flate = data:sub(math.max(1, s - 120), s - 1):find("/FlateDecode", 1, true)
            local usable = true
            if flate then
                raw = pdfwrite.zlib_decompress(raw)
                usable = raw ~= nil
            end
            if usable and raw:find(" Tf", 1, true) then
                local spacing = tc_value(raw)
                return spacing ~= nil and float_of(spacing) ~= 0.0
            end
            search = next_search
        end
    end
end

function main(directory)
    if not directory then
        raise("usage: tc-fixtures.lua <fixtures directory>")
    end
    local listing = os.iorunv("/bin/ls", {"-1", directory})
    local names = {}
    for name in listing:gmatch("[^\n]+") do
        if name:sub(-4) == ".pdf" then
            names[#names + 1] = name
        end
    end
    table.sort(names, byte_less)
    for _, name in ipairs(names) do
        if has_spacing(read_file(path.join(directory, name))) then
            print(name)
        end
    end
end
