local function hex_of(bytes)
    return (bytes:gsub(".", function(c) return string.format("%02x", c:byte()) end))
end

local function hx(x)
    return hex_of(string.pack("<f", x))
end

local function one_below(x)
    return hex_of(string.pack("<I4", string.unpack("<I4", string.pack("<f", x)) - 1))
end

local function line(name, hexes)
    return string.format("case %s %d %s", name, 4 * #hexes, table.concat(hexes))
end

local function write(file, text)
    io.writefile(file, text)
end

local function values(list)
    local out = {}
    for _, v in ipairs(list) do
        table.insert(out, hx(v))
    end
    return out
end

function fixture(work)
    local base = values({1.0, 2.0, 3.0, 4.0})
    local same = values({0.5, 0.25, 0.125, 0.0625})
    local far_system = values({-0.000331588089, 1.0, 2.0, 3.0})
    local far_port = values({-0.000331564806, 1.0, 2.0, 3.0})
    local ulp_system = values({0.1, 0.2, 0.3, 0.4})
    local ulp_port = {hx(0.1), hx(0.2), hx(0.3), one_below(0.4)}

    write(work .. "/system.prefix", table.concat({
        line("sum 0", base), line("neuron 7", same),
        line("neuron 15", far_system), line("softmax 1", ulp_system)}, "\n") .. "\n")
    write(work .. "/port.prefix", table.concat({
        line("sum 0", base), line("neuron 7", same),
        line("neuron 15", far_port), line("softmax 1", ulp_port)}, "\n") .. "\n")
    write(work .. "/owed.tsv", "neuron 15\tthe fixture's one case the port does not reproduce\n")
    print("fixture: 4 cases, 2 bit-identical, 1 at 1 ulp, 1 at 800")
end

local function replace_once(text, old, new)
    local s, e = text:find(old, 1, true)
    if not s or text:find(old, e + 1, true) then
        io.stderr:write("the control could not be built: the anchor does not occur exactly once\n")
        os.exit(1)
    end
    return text:sub(1, s - 1) .. new .. text:sub(e + 1)
end

function control(source, dest, common)
    local text = io.readfile(source)
    text = replace_once(text, 'path.join(os.scriptdir(), "..", "..", "common")', string.format("%q", common))
    text = replace_once(text, "    for i = 1, n do\n", "    local graded = {}\n    for i = 1, n do\n")
    text = replace_once(text, "        local grade_name, worst_ulp, worst_rel, mispaired = grade_case(s, p, fam, bound)\n",
        "        local grade_name, worst_ulp, worst_rel, mispaired = grade_case(s, p, fam, bound)\n"
        .. "        graded[owed_path] = grade_name\n")
    io.writefile(dest, text)
    print("control: the 2026-09-29 form of the grader, with the write-only table and its assignment restored")
end

function main(command, ...)
    local run = {fixture = fixture, control = control}
    if not run[command or ""] then
        io.stderr:write("usage: rank-selftest.lua fixture <dir> | control <rank.lua> <out.lua>\n")
        os.exit(2)
    end
    run[command](...)
end
