local MAGIC = "RVHEVC01"

local function read_bytes(path)
    local handle = assert(io.open(path, "rb"))
    local data = handle:read("a")
    handle:close()
    return data
end

local function write_bytes(path, data)
    local handle = assert(io.open(path, "wb"))
    handle:write(data)
    handle:close()
end

local function unescape(bytes)
    local out = {}
    local zeros = 0
    for index = 1, #bytes do
        local byte = bytes:byte(index)
        if zeros >= 2 and byte == 3 then
            zeros = 0
        else
            table.insert(out, string.char(byte))
            zeros = byte == 0 and zeros + 1 or 0
        end
    end
    return table.concat(out)
end

local function nal_units(stream)
    local starts = {}
    local index = 1
    while true do
        local _, last = stream:find("\0\0\1", index, true)
        if not last then
            break
        end
        table.insert(starts, last + 1)
        index = last + 1
    end
    local units = {}
    for position, from in ipairs(starts) do
        local following = starts[position + 1]
        local unit = stream:sub(from, following and following - 4 or #stream):gsub("%z+$", "")
        table.insert(units, unit)
    end
    return units
end

local function kind_of(nal)
    return (nal:byte(1) >> 1) & 0x3f
end

local function access_units(units)
    local aus, current, seen_vcl = {}, nil, false
    for _, nal in ipairs(units) do
        local kind = kind_of(nal)
        local vcl = kind < 32
        local first_slice = vcl and (nal:byte(3) >> 7) == 1
        if current == nil or (seen_vcl and (first_slice or (kind >= 32 and kind <= 35) or kind == 39)) then
            current = {}
            table.insert(aus, current)
            seen_vcl = false
        end
        table.insert(current, nal)
        seen_vcl = seen_vcl or vcl
    end
    return aus
end

local function reader(bytes)
    local position = 0
    local r = {}
    function r.bit()
        local byte = bytes:byte(position // 8 + 1)
        assert(byte, "the parameter set ends before a field it names")
        local bit = (byte >> (7 - position % 8)) & 1
        position = position + 1
        return bit
    end
    function r.bits(count)
        local value = 0
        for _ = 1, count do
            value = (value << 1) | r.bit()
        end
        return value
    end
    function r.ue()
        local zeros = 0
        while r.bit() == 0 do
            zeros = zeros + 1
        end
        return (1 << zeros) - 1 + r.bits(zeros)
    end
    function r.skip(count)
        position = position + count
    end
    return r
end

local function profile_tier_level(r, max_sub_layers_minus1)
    r.skip(88)
    r.skip(8)
    local profile_present, level_present = {}, {}
    for index = 0, max_sub_layers_minus1 - 1 do
        profile_present[index] = r.bit() == 1
        level_present[index] = r.bit() == 1
    end
    if max_sub_layers_minus1 > 0 then
        for _ = max_sub_layers_minus1, 7 do
            r.skip(2)
        end
    end
    for index = 0, max_sub_layers_minus1 - 1 do
        if profile_present[index] then
            r.skip(88)
        end
        if level_present[index] then
            r.skip(8)
        end
    end
end

local function parse_sps(nal)
    local payload = unescape(nal:sub(3))
    local r = reader(payload)
    r.bits(4)
    local max_sub_layers_minus1 = r.bits(3)
    local temporal_id_nesting = r.bit()
    profile_tier_level(r, max_sub_layers_minus1)
    r.ue()
    local chroma = r.ue()
    if chroma == 3 then
        r.bit()
    end
    local width, height = r.ue(), r.ue()
    local sub_width = (chroma == 1 or chroma == 2) and 2 or 1
    local sub_height = chroma == 1 and 2 or 1
    if r.bit() == 1 then
        local left, right, top, bottom = r.ue(), r.ue(), r.ue(), r.ue()
        width = width - sub_width * (left + right)
        height = height - sub_height * (top + bottom)
    end
    local bit_depth_luma = r.ue() + 8
    local bit_depth_chroma = r.ue() + 8
    assert(bit_depth_luma == 8 and bit_depth_chroma == 8, "only 8-bit streams are fixtures")
    return {
        width = width,
        height = height,
        chroma = chroma,
        bit_depth_luma = bit_depth_luma,
        bit_depth_chroma = bit_depth_chroma,
        max_sub_layers_minus1 = max_sub_layers_minus1,
        temporal_id_nesting = temporal_id_nesting,
        profile = payload:sub(1, 13),
    }
end

local function configuration(sps, parameter_sets)
    local arrays = {}
    for _, kind in ipairs({32, 33, 34}) do
        local nals = parameter_sets[kind]
        if nals then
            local parts = {string.pack(">BI2", 0x80 | kind, #nals)}
            for _, nal in ipairs(nals) do
                table.insert(parts, string.pack(">I2", #nal) .. nal)
            end
            table.insert(arrays, table.concat(parts))
        end
    end
    return table.concat({
        string.char(1),
        sps.profile:sub(2, 13),
        string.pack(">I2", 0xf000),
        string.char(0xfc),
        string.char(0xfc | sps.chroma),
        string.char(0xf8 | (sps.bit_depth_luma - 8)),
        string.char(0xf8 | (sps.bit_depth_chroma - 8)),
        string.pack(">I2", 0),
        string.char((sps.max_sub_layers_minus1 + 1) << 3 | sps.temporal_id_nesting << 2 | 3),
        string.char(#arrays),
        table.concat(arrays),
    })
end

local function timebase(input)
    local text = os.iorunv("ffprobe", {"-v", "error", "-select_streams", "v:0", "-show_entries", "stream=time_base,width,height", "-of", "csv=p=0", input})
    local width, height, num, den = text:match("^(%d+),(%d+),(%d+)/(%d+)")
    assert(num and den, "ffprobe names no time base for " .. input)
    return tonumber(den), tonumber(width), tonumber(height)
end

local function packets(input)
    local text = os.iorunv("ffprobe", {"-v", "error", "-select_streams", "v:0", "-show_entries", "packet=pts,dts,duration", "-of", "csv=p=0", input})
    local rows = {}
    for line in text:gmatch("[^\n]+") do
        local pts, dts, duration = line:match("^([^,]*),([^,]*),([^,]*)")
        table.insert(rows, {pts = tonumber(pts), dts = tonumber(dts), duration = tonumber(duration)})
    end
    return rows
end

function main(input, output)
    assert(input and os.isfile(input), "no input video: " .. tostring(input))
    assert(output, "no output file")
    local timescale, stream_width, stream_height = timebase(input)
    local rows = packets(input)
    local annexb = output .. ".annexb"
    os.vrunv("ffmpeg", {"-v", "error", "-y", "-i", input, "-map", "0:v:0", "-c:v", "copy", "-bsf:v", "hevc_mp4toannexb", "-f", "hevc", annexb})
    local stream = read_bytes(annexb)
    os.rm(annexb)
    local aus = access_units(nal_units(stream))
    assert(#aus == #rows, string.format("%d access units but %d packets in %s", #aus, #rows, input))

    local parameter_sets = {}
    local sps
    for _, nal in ipairs(aus[1]) do
        local kind = kind_of(nal)
        if kind >= 32 and kind <= 34 then
            parameter_sets[kind] = parameter_sets[kind] or {}
            table.insert(parameter_sets[kind], nal)
        end
        if kind == 33 and not sps then
            sps = parse_sps(nal)
        end
    end
    assert(sps, "the first access unit carries no SPS")
    assert(sps.width == stream_width and sps.height == stream_height, "the SPS size differs from the stream's")
    local config = configuration(sps, parameter_sets)

    local body = {}
    for index, au in ipairs(aus) do
        local parts = {}
        for _, nal in ipairs(au) do
            local kind = kind_of(nal)
            if kind ~= 32 and kind ~= 33 and kind ~= 34 and kind ~= 35 then
                table.insert(parts, string.pack(">I4", #nal) .. nal)
            end
        end
        local row = rows[index]
        assert(row.pts and row.dts and row.duration, "packet " .. index .. " has no timing")
        table.insert(body, string.pack("<i8i8i8I4", row.dts, row.pts, row.duration, #table.concat(parts)) .. table.concat(parts))
    end

    local data = string.pack("<c8I4I4I4I4", MAGIC, sps.width, sps.height, timescale, #config) .. config .. string.pack("<I4", #aus) .. table.concat(body)
    write_bytes(output, data)
    print(string.format("%s: %dx%d, timescale %d, %d samples, %d bytes", output, sps.width, sps.height, timescale, #aus, #data))
end
