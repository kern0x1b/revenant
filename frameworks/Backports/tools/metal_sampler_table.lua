local toolchain = import("metal_toolchain", {rootdir = os.scriptdir()})

ADDRESS = {"clamp_to_zero", "clamp_to_edge", "repeat", "mirrored_repeat"}
FILTER = {"nearest", "linear"}
MIPMAP = {"none", "nearest", "linear"}
COORDINATES = {"normalized", "pixel"}
COMPARE = {"never", "less", "less_equal", "greater", "greater_equal", "equal", "not_equal", "always"}
TARGET = "air64-apple-ios12.0"
BATCH = 64
EXPECTED = {"0x807bff0000080a49", "0x807bff0000084a92"}

function baseline()
    return {s = "clamp_to_edge", t = "clamp_to_edge", r = "clamp_to_edge", min = "nearest", mag = "nearest",
            mip = "none", coord = "normalized", compare = "never",
            lodMin = 0.0, lodMax = 1000.0, anisotropy = 1}
end

function descriptorKey(d)
    return table.concat({d.s, d.t, d.r, d.min, d.mag, d.mip, d.coord, d.compare,
                         string.format("%.1f", d.lodMin), string.format("%.1f", d.lodMax), tostring(d.anisotropy)}, " ")
end

function allowed(d)
    if d.coord ~= "pixel" then
        return true
    end
    local clamps = {clamp_to_zero = true, clamp_to_edge = true}
    return d.min == d.mag and d.mip == "none" and d.compare == "never" and
           clamps[d.s] and clamps[d.t] and clamps[d.r] and true or false
end

function descriptors()
    local list, seen = {}, {}
    local function add(changes)
        local d = baseline()
        for field, value in pairs(changes) do
            d[field] = value
        end
        local key = descriptorKey(d)
        if allowed(d) and not seen[key] then
            seen[key] = true
            table.insert(list, d)
        end
    end
    for _, s in ipairs(ADDRESS) do
        for _, t in ipairs(ADDRESS) do
            for _, r in ipairs(ADDRESS) do
                for _, min in ipairs(FILTER) do
                    for _, mag in ipairs(FILTER) do
                        for _, mip in ipairs(MIPMAP) do
                            for _, coord in ipairs(COORDINATES) do
                                add({s = s, t = t, r = r, min = min, mag = mag, mip = mip, coord = coord})
                            end
                        end
                    end
                end
            end
        end
    end
    for _, compare in ipairs(COMPARE) do
        add({compare = compare})
    end
    add({lodMin = 0.0, lodMax = 4.0})
    add({lodMin = 1.0, lodMax = 1000.0})
    add({anisotropy = 2})
    add({anisotropy = 16})
    return list
end

function declaration(d)
    local parts = {"s_address::" .. d.s, "t_address::" .. d.t, "r_address::" .. d.r,
                   "min_filter::" .. d.min, "mag_filter::" .. d.mag, "mip_filter::" .. d.mip,
                   "coord::" .. d.coord, "compare_func::" .. d.compare}
    if d.lodMin ~= 0.0 or d.lodMax ~= 1000.0 then
        table.insert(parts, string.format("lod_clamp(%.1f, %.1f)", d.lodMin, d.lodMax))
    end
    if d.anisotropy ~= 1 then
        table.insert(parts, "max_anisotropy(" .. d.anisotropy .. ")")
    end
    return table.concat(parts, ", ")
end

function kernelSource(index, d)
    return string.format("constexpr sampler sampler_%d(%s);\n" ..
                         "kernel void k_%d(texture2d<float, access::sample> source [[texture(0)]], " ..
                         "device float4 *output [[buffer(0)]]) {\n" ..
                         "    output[0] = source.sample(sampler_%d, float2(0.25, 0.75));\n}\n",
                         index, declaration(d), index, index)
end

function batchSource(list, first, last)
    local parts = {"#include <metal_stdlib>\nusing namespace metal;\n"}
    for index = first, last do
        table.insert(parts, kernelSource(index, list[index]))
    end
    return table.concat(parts, "\n")
end

function parseSamplers(text)
    local found = {}
    for line in text:gmatch("[^\n]+") do
        local entry, function_, state = line:match("^(%S+) (%S+) (0x%x+)$")
        if not entry then
            raise("metal-sampler-table: air2es printed a line this tool does not read: " .. line)
        end
        local index = tonumber(function_:match("^k_(%d+)$"))
        if index then
            found[index] = state
        end
    end
    return found
end

function rowLine(state, d)
    return string.format('    {%sULL, "%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s", %.1ff, %.1ff, %du},',
                         state, d.s, d.t, d.r, d.min, d.mag, d.mip, d.coord, d.compare,
                         d.lodMin, d.lodMax, d.anisotropy)
end

function render(rows)
    local lines = {}
    for _, row in ipairs(rows) do
        table.insert(lines, rowLine(row.state, row.descriptor))
    end
    return table.concat(lines, "\n") .. (#lines > 0 and "\n" or "")
end

function collect(list, bin, air2es, work)
    local metal = path.join(bin, "metal")
    local metallib = path.join(bin, "metallib")
    local found = {}
    for first = 1, #list, BATCH do
        local last = math.min(first + BATCH - 1, #list)
        local source = path.join(work, string.format("batch_%d.metal", first))
        local air = path.join(work, string.format("batch_%d.air", first))
        local library = path.join(work, string.format("batch_%d.metallib", first))
        io.writefile(source, batchSource(list, first, last))
        os.vrunv(metal, {"-c", "-target", TARGET, "-ffast-math", source, "-o", air})
        os.vrunv(metallib, {air, "-o", library})
        local states = parseSamplers(os.iorunv(air2es, {"--samplers", library}))
        for index = first, last do
            if not states[index] then
                raise(string.format("metal-sampler-table: kernel %d (%s) has no sampler state in %s", index, descriptorKey(list[index]), library))
            end
            found[index] = states[index]
        end
    end
    return found
end

function table_of(list, found)
    local byState, rows = {}, {}
    for index, d in ipairs(list) do
        local state = found[index]
        local key = descriptorKey(d)
        if byState[state] and byState[state] ~= key then
            raise("metal-sampler-table: two samplers share the state " .. state .. ": " .. byState[state] .. " and " .. key)
        end
        if not byState[state] then
            byState[state] = key
            table.insert(rows, {state = state, descriptor = d})
        end
    end
    for _, expected in ipairs(EXPECTED) do
        if not byState[expected] then
            raise("metal-sampler-table: the compiler does not produce " .. expected .. " for any sampler, so it is not the toolchain of the library the table must read")
        end
    end
    table.sort(rows, function (a, b) return a.state < b.state end)
    return rows
end

function main(dmg, air2es, output, work, mountpoint)
    local bin = toolchain.mount(dmg, mountpoint)
    work = work or path.join(os.tmpdir(), "revenant-metal-sampler-table")
    os.mkdir(work)
    local list = descriptors()
    local rows = table_of(list, collect(list, bin, air2es, work))
    io.writefile(output, render(rows))
    print(string.format("metal-sampler-table: %d samplers compiled, %d distinct states written to %s", #list, #rows, output))
end
