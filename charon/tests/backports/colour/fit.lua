import("sample_floor", {rootdir = os.scriptdir()})

local MODIFIERS = { very = true, light = true, dark = true, pastel = true, grayish = true,
    vibrant = true, bright = true }

local function fields(line)
    local out, start = {}, 1
    while true do
        local stop = line:find("\t", start, true)
        if not stop then
            out[#out + 1] = line:sub(start)
            return out
        end
        out[#out + 1] = line:sub(start, stop - 1)
        start = stop + 1
    end
end

local function read(path_)
    local rows = {}
    for line in io.lines(path_) do
        if line:sub(1, 1) ~= "#" then
            local f = fields(line)
            assert(#f == 5, "a row of the sample has " .. #f .. " fields, not five: " .. line)
            rows[#rows + 1] = { r = tonumber(f[2]), g = tonumber(f[3]), b = tonumber(f[4]), name = f[5] }
        end
    end
    return rows
end

local function split(name)
    local words = {}
    for word in name:gmatch("%S+") do
        words[#words + 1] = word
    end
    local first = 1
    while words[first] and MODIFIERS[words[first]] do
        first = first + 1
    end
    local rest = {}
    for i = first, #words do
        rest[#rest + 1] = words[i]
    end
    local joined = table.concat(rest, " ")
    if joined == "" then
        return name
    end
    return joined
end

local function srgb(r, g, b)
    return r / 255.0, g / 255.0, b / 255.0
end

local function linear(r, g, b)
    local out = {}
    for _, value in ipairs({ r / 255.0, g / 255.0, b / 255.0 }) do
        out[#out + 1] = value <= 0.04045 and value / 12.92 or ((value + 0.055) / 1.055) ^ 2.4
    end
    return out[1], out[2], out[3]
end

local function lab(r, g, b)
    local x, y, z = linear(r, g, b)
    local function f(t)
        if t > 216 / 24389 then
            return t ^ (1 / 3)
        end
        return (841 / 108) * t + 4 / 29
    end
    local fx, fy, fz = f(x), f(y), f(z)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)
end

local function cube(v)
    if v > 0 then
        return v ^ (1 / 3)
    end
    return -((-v) ^ (1 / 3))
end

local function oklab(r, g, b)
    local x, y, z = linear(r, g, b)
    local l = 0.4122214708 * x + 0.5363325363 * y + 0.0514459929 * z
    local m = 0.2119034982 * x + 0.6806995451 * y + 0.1073969566 * z
    local s = 0.0883024619 * x + 0.2817188376 * y + 0.6299787005 * z
    local l_, m_, s_ = cube(l), cube(m), cube(s)
    return 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
        1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
        0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
end

local SPACES = {
    { label = "srgb", space = srgb },
    { label = "linear", space = linear },
    { label = "lab", space = lab },
    { label = "oklab", space = oklab },
}

local function ordered()
    return { keys = {}, values = {} }
end

local function put(map, key, value)
    if map.values[key] == nil then
        map.keys[#map.keys + 1] = key
    end
    map.values[key] = value
end

function main(sample)
    if not sample_floor.refuse_small_sample(sample) then
        os.exit(1)
    end
    local rows = read(sample)

    local hues = ordered()
    local counts = {}
    local names = {}
    for _, row in ipairs(rows) do
        local hue = split(row.name)
        if counts[hue] == nil then
            counts[hue] = 0
            put(hues, hue, true)
        end
        counts[hue] = counts[hue] + 1
        names[row.name] = true
    end
    local distinctNames = 0
    for _ in pairs(names) do
        distinctNames = distinctNames + 1
    end

    print(string.format("fit rows: %d", #rows))
    print(string.format("distinct names: %d", distinctNames))
    print(string.format("distinct hue words: %d", #hues.keys))

    local firstSeen = {}
    for i, hue in ipairs(hues.keys) do
        firstSeen[hue] = i
    end
    local byCount = {}
    for _, hue in ipairs(hues.keys) do
        byCount[#byCount + 1] = hue
    end
    table.sort(byCount, function(a, b)
        if counts[a] ~= counts[b] then
            return counts[a] > counts[b]
        end
        return firstSeen[a] < firstSeen[b]
    end)
    for _, hue in ipairs(byCount) do
        print(string.format("  %-16s %d", hue, counts[hue]))
    end

    for _, name in ipairs({ "gray", "black", "white" }) do
        print(string.format("near-neutral %-6s %d", name, counts[name] or 0))
    end

    local points = ordered()
    for _, row in ipairs(rows) do
        put(points, string.format("%d,%d,%d", row.r, row.g, row.b), {
            r = row.r, g = row.g, b = row.b, hue = split(row.name),
        })
    end
    local pointCount = #points.keys

    for _, entry in ipairs(SPACES) do
        local sums = ordered()
        for _, key in ipairs(points.keys) do
            local p = points.values[key]
            local v = { entry.space(p.r, p.g, p.b) }
            local acc = sums.values[p.hue]
            if acc == nil then
                acc = { 0.0, 0.0, 0.0, 0 }
                put(sums, p.hue, acc)
            end
            acc[1] = acc[1] + v[1]
            acc[2] = acc[2] + v[2]
            acc[3] = acc[3] + v[3]
            acc[4] = acc[4] + 1
        end
        local prototypes = {}
        for _, hue in ipairs(sums.keys) do
            local a = sums.values[hue]
            prototypes[#prototypes + 1] = { hue = hue, p = { a[1] / a[4], a[2] / a[4], a[3] / a[4] } }
        end

        local agree = 0
        for _, key in ipairs(points.keys) do
            local p = points.values[key]
            local v = { entry.space(p.r, p.g, p.b) }
            local best, bestDistance = nil, nil
            for _, candidate in ipairs(prototypes) do
                local d = 0
                for i = 1, 3 do
                    d = d + (v[i] - candidate.p[i]) ^ 2
                end
                if bestDistance == nil or d < bestDistance then
                    best, bestDistance = candidate.hue, d
                end
            end
            if best == p.hue then
                agree = agree + 1
            end
        end
        print(string.format("space %-8s hue-word agreement %d / %d = %.4f", entry.label, agree, pointCount,
            agree / pointCount))
    end
end
