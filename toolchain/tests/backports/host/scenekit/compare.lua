local LENGTH_BASE = {3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258}
local LENGTH_EXTRA = {0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0}
local DIST_BASE = {1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577}
local DIST_EXTRA = {0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13}
local CODE_ORDER = {16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15}

local function build_huffman(lengths, n)
    local h = {count = {}, symbol = {}}
    for len = 0, 15 do
        h.count[len] = 0
    end
    for sym = 0, n - 1 do
        h.count[lengths[sym]] = h.count[lengths[sym]] + 1
    end
    local offs = {[1] = 0}
    for len = 1, 14 do
        offs[len + 1] = offs[len] + h.count[len]
    end
    for sym = 0, n - 1 do
        local len = lengths[sym]
        if len ~= 0 then
            h.symbol[offs[len]] = sym
            offs[len] = offs[len] + 1
        end
    end
    return h
end

local function inflate(data)
    local pos = 3
    local bitbuf, bitcnt = 0, 0
    local out = {}

    local function bits(n)
        while bitcnt < n do
            local b = data:byte(pos)
            if not b then
                raise("the compressed data is truncated")
            end
            pos = pos + 1
            bitbuf = bitbuf | (b << bitcnt)
            bitcnt = bitcnt + 8
        end
        local value = bitbuf & ((1 << n) - 1)
        bitbuf = bitbuf >> n
        bitcnt = bitcnt - n
        return value
    end

    local function decode(h)
        local code, first, index = 0, 0, 0
        for len = 1, 15 do
            code = code | bits(1)
            local count = h.count[len]
            if code - count < first then
                return h.symbol[index + (code - first)]
            end
            index = index + count
            first = (first + count) << 1
            code = code << 1
        end
        raise("a huffman code is not in the table")
    end

    local function codes(lencode, distcode)
        while true do
            local sym = decode(lencode)
            if sym < 256 then
                out[#out + 1] = sym
            elseif sym == 256 then
                return
            else
                sym = sym - 257
                local length = LENGTH_BASE[sym + 1] + bits(LENGTH_EXTRA[sym + 1])
                local dsym = decode(distcode)
                local dist = DIST_BASE[dsym + 1] + bits(DIST_EXTRA[dsym + 1])
                for _ = 1, length do
                    out[#out + 1] = out[#out - dist + 1]
                end
            end
        end
    end

    local function stored()
        bitbuf, bitcnt = 0, 0
        local len = data:byte(pos) | (data:byte(pos + 1) << 8)
        pos = pos + 4
        for i = 0, len - 1 do
            out[#out + 1] = data:byte(pos + i)
        end
        pos = pos + len
    end

    local function dynamic()
        local nlen = bits(5) + 257
        local ndist = bits(5) + 1
        local ncode = bits(4) + 4
        local lengths = {}
        for i = 0, 18 do
            lengths[i] = 0
        end
        for i = 1, ncode do
            lengths[CODE_ORDER[i]] = bits(3)
        end
        local lencode = build_huffman(lengths, 19)
        local lens = {}
        local index = 0
        while index < nlen + ndist do
            local sym = decode(lencode)
            if sym < 16 then
                lens[index] = sym
                index = index + 1
            else
                local len, repeat_count = 0, 0
                if sym == 16 then
                    len = lens[index - 1]
                    repeat_count = 3 + bits(2)
                elseif sym == 17 then
                    repeat_count = 3 + bits(3)
                else
                    repeat_count = 11 + bits(7)
                end
                for _ = 1, repeat_count do
                    lens[index] = len
                    index = index + 1
                end
            end
        end
        local litlens, distlens = {}, {}
        for i = 0, nlen - 1 do
            litlens[i] = lens[i]
        end
        for i = 0, ndist - 1 do
            distlens[i] = lens[nlen + i]
        end
        codes(build_huffman(litlens, nlen), build_huffman(distlens, ndist))
    end

    local fixed_lit, fixed_dist = {}, {}
    for i = 0, 287 do
        if i < 144 then
            fixed_lit[i] = 8
        elseif i < 256 then
            fixed_lit[i] = 9
        elseif i < 280 then
            fixed_lit[i] = 7
        else
            fixed_lit[i] = 8
        end
    end
    for i = 0, 29 do
        fixed_dist[i] = 5
    end
    local fixed_lencode = build_huffman(fixed_lit, 288)
    local fixed_distcode = build_huffman(fixed_dist, 30)

    local last
    repeat
        last = bits(1)
        local kind = bits(2)
        if kind == 0 then
            stored()
        elseif kind == 1 then
            codes(fixed_lencode, fixed_distcode)
        elseif kind == 2 then
            dynamic()
        else
            raise("a deflate block has the reserved type")
        end
    until last == 1
    return out
end

local function read_png(file)
    local handle = io.open(file, "rb")
    if not handle then
        raise("%s cannot be read", file)
    end
    local data = handle:read("a")
    handle:close()
    if data:sub(1, 8) ~= "\137PNG\r\n\26\n" then
        raise("%s is not a PNG", file)
    end
    local pos = 9
    local idat = {}
    local w, h, ch
    while pos <= #data do
        local n = string.unpack(">I4", data, pos)
        local kind = data:sub(pos + 4, pos + 7)
        local body = data:sub(pos + 8, pos + 7 + n)
        pos = pos + 12 + n
        if kind == "IHDR" then
            local depth, ctype
            w, h, depth, ctype = string.unpack(">I4I4BB", body)
            if not (depth == 8 and (ctype == 2 or ctype == 6)) then
                raise("%s: depth %d, colour type %d - only 8-bit RGB and RGBA are read", file, depth, ctype)
            end
            ch = ctype == 6 and 4 or 3
        elseif kind == "IDAT" then
            table.insert(idat, body)
        end
    end
    local raw = inflate(table.concat(idat))
    local stride = w * ch
    local out = {}
    local prev = {}
    for x = 0, stride - 1 do
        prev[x] = 0
    end
    local i = 1
    for _ = 1, h do
        local f = raw[i]
        i = i + 1
        local line = {}
        for x = 0, stride - 1 do
            line[x] = raw[i + x]
        end
        i = i + stride
        for x = 0, stride - 1 do
            local a = x >= ch and line[x - ch] or 0
            local b = prev[x]
            local c = x >= ch and prev[x - ch] or 0
            if f == 1 then
                line[x] = (line[x] + a) & 255
            elseif f == 2 then
                line[x] = (line[x] + b) & 255
            elseif f == 3 then
                line[x] = (line[x] + (a + b) // 2) & 255
            elseif f == 4 then
                local p = a + b - c
                local pa, pb, pc = math.abs(p - a), math.abs(p - b), math.abs(p - c)
                local predictor
                if pa <= pb and pa <= pc then
                    predictor = a
                elseif pb <= pc then
                    predictor = b
                else
                    predictor = c
                end
                line[x] = (line[x] + predictor) & 255
            end
        end
        for x = 0, stride - 1 do
            out[#out + 1] = line[x]
        end
        prev = line
    end
    local px = {}
    for j = 0, w * h - 1 do
        local pixel = {}
        for k = 0, ch - 1 do
            pixel[k + 1] = out[j * ch + k + 1]
        end
        if ch == 3 then
            pixel[4] = 255
        end
        px[j + 1] = pixel
    end
    return w, h, px
end

function compare_files(a_path, b_path)
    local wa, ha, A = read_png(a_path)
    local wb, hb, B = read_png(b_path)
    if wa ~= wb or ha ~= hb then
        raise("the frames differ in size: %dx%d and %dx%d", wa, ha, wb, hb)
    end
    local inter, union = 0, 0
    local diffs = {}
    local signed = {0, 0, 0}
    for j = 1, #A do
        local pa, pb = A[j], B[j]
        local ia, ib = pa[4] >= 128, pb[4] >= 128
        if ia or ib then
            union = union + 1
        end
        if ia and ib then
            inter = inter + 1
            local worst = 0
            for k = 1, 3 do
                worst = math.max(worst, math.abs(pa[k] - pb[k]))
            end
            table.insert(diffs, worst)
            for k = 1, 3 do
                signed[k] = signed[k] + (pb[k] - pa[k])
            end
        end
    end
    table.sort(diffs)
    local n = #diffs
    local iou = union > 0 and inter / union or 1.0
    local mean, p95 = 0.0, 0
    if n > 0 then
        local total = 0
        for _, d in ipairs(diffs) do
            total = total + d
        end
        mean = total / n
        p95 = diffs[math.floor(0.95 * (n - 1)) + 1]
    end
    local bias = {0.0, 0.0, 0.0}
    if n > 0 then
        for k = 1, 3 do
            bias[k] = signed[k] / n
        end
    end
    return iou, mean, p95, n, bias
end

function main(a_path, b_path)
    if not (a_path and b_path) then
        io.stderr:write("usage: compare.lua <a.png> <b.png>\n")
        os.exit(2)
    end
    local iou, mean, p95, n, bias = compare_files(a_path, b_path)
    print(string.format("iou=%.4f mean=%.2f p95=%d n=%d bias=%+.2f/%+.2f/%+.2f", iou, mean, p95, n, bias[1], bias[2], bias[3]))
    os.exit(0)
end
