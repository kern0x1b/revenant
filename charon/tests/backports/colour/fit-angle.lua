import("sample_floor", {rootdir = os.scriptdir()})

local MODIFIERS = { very = true, light = true, dark = true, pastel = true, grayish = true,
    vibrant = true, bright = true }

local TAU = 2 * math.pi

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

local function cube(v)
    if v > 0 then
        return v ^ (1 / 3)
    end
    return -((-v) ^ (1 / 3))
end

local function oklab(r, g, b)
    local out = {}
    for _, value in ipairs({ r / 255.0, g / 255.0, b / 255.0 }) do
        out[#out + 1] = value <= 0.04045 and value / 12.92 or ((value + 0.055) / 1.055) ^ 2.4
    end
    local x, y, z = out[1], out[2], out[3]
    local l = 0.4122214708 * x + 0.5363325363 * y + 0.0514459929 * z
    local m = 0.2119034982 * x + 0.6806995451 * y + 0.1073969566 * z
    local s = 0.0883024619 * x + 0.2817188376 * y + 0.6299787005 * z
    local l_, m_, s_ = cube(l), cube(m), cube(s)
    return 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
        1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
        0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
end

local function angle(r, g, b)
    local L, a, bb = oklab(r, g, b)
    return math.atan(bb, a) % TAU, math.sqrt(a * a + bb * bb), L
end

function main(sample)
    if not sample_floor.refuse_small_sample(sample) then
        os.exit(1)
    end

    local keys, points = {}, {}
    for line in io.lines(sample) do
        if line:sub(1, 1) ~= "#" then
            local r, g, b, name = line:match("^[^\t]*\t([^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)$")
            local key = string.format("%d,%d,%d", tonumber(r), tonumber(g), tonumber(b))
            if points[key] == nil then
                keys[#keys + 1] = key
            end
            points[key] = { r = tonumber(r), g = tonumber(g), b = tonumber(b), hue = split(name) }
        end
    end
    print(string.format("distinct colours: %d", #keys))

    local neutral = { gray = true, black = true, white = true }
    local chromatic = {}
    local neutralCount = 0
    for _, key in ipairs(keys) do
        local p = points[key]
        if neutral[p.hue] then
            neutralCount = neutralCount + 1
        else
            local ang, chroma, L = angle(p.r, p.g, p.b)
            chromatic[#chromatic + 1] = { angle = ang, chroma = chroma, L = L, hue = p.hue }
        end
    end
    print(string.format("chromatic points: %d   neutral: %d", #chromatic, neutralCount))

    for i, item in ipairs(chromatic) do
        item.order = i
    end
    table.sort(chromatic, function(x, y)
        if x.angle ~= y.angle then
            return x.angle < y.angle
        end
        return x.order < y.order
    end)
    local runs = {}
    for _, item in ipairs(chromatic) do
        local last = runs[#runs]
        if last and last.hue == item.hue then
            last.high = item.angle
            last.count = last.count + 1
        else
            runs[#runs + 1] = { hue = item.hue, low = item.angle, high = item.angle, count = 1 }
        end
    end
    print(string.format("contiguous runs of the angle, in angle order: %d", #runs))
    for _, run in ipairs(runs) do
        print(string.format("  %-16s %6.3f .. %6.3f  %6d", run.hue, run.low, run.high, run.count))
    end

    if #runs > 1 then
        local edges = {}
        for i, run in ipairs(runs) do
            local nextRun = runs[i % #runs + 1]
            local gap = (nextRun.low - run.high) % TAU
            edges[i] = (run.high + gap / 2.0) % TAU
        end
        local agree = 0
        for _, item in ipairs(chromatic) do
            local a = item.angle
            for i, edge in ipairs(edges) do
                local nextEdge = edges[i % #edges + 1]
                if (a - edge) % TAU < (nextEdge - edge) % TAU then
                    if runs[i].hue == item.hue then
                        agree = agree + 1
                    end
                    break
                end
            end
        end
        print(string.format("one-dimensional angle partition: %d / %d chromatic = %.4f", agree, #chromatic,
            agree / #chromatic))
    end
end
