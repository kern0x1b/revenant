local MIN = math.mininteger

local function ult(a, b)
    return math.ult(a, b)
end

local function lt(a, b)
    if a.hi ~= b.hi then
        return ult(a.hi, b.hi)
    end
    return ult(a.lo, b.lo)
end

local function sub(a, b)
    local lo = a.lo - b.lo
    local borrow = ult(a.lo, b.lo) and 1 or 0
    return {hi = a.hi - b.hi - borrow, lo = lo}
end

local function neg(a)
    return sub({hi = 0, lo = 0}, a)
end

local function bit(a, index)
    if index >= 64 then
        return (a.hi >> (index - 64)) & 1
    end
    return (a.lo >> index) & 1
end

local function shl1(a, low)
    return {hi = (a.hi << 1) | (a.lo >> 63), lo = (a.lo << 1) | low}
end

local function iszero(a)
    return a.hi == 0 and a.lo == 0
end

local function udivmod(n, d)
    assert(not iszero(d))
    local q, r = {hi = 0, lo = 0}, {hi = 0, lo = 0}
    for index = 127, 0, -1 do
        local carry = r.hi < 0
        r = shl1(r, bit(n, index))
        if carry or not lt(r, d) then
            r = sub(r, d)
            if index >= 64 then
                q.hi = q.hi | (1 << (index - 64))
            else
                q.lo = q.lo | (1 << index)
            end
        end
    end
    return q, r
end

local function negative(a)
    return a.hi < 0
end

local function magnitude(a)
    return negative(a) and neg(a) or a
end

local function sdiv(a, b)
    local q = udivmod(magnitude(a), magnitude(b))
    return negative(a) ~= negative(b) and neg(q) or q
end

local function smod(a, b)
    local _, r = udivmod(magnitude(a), magnitude(b))
    return negative(a) and neg(r) or r
end

local function hex(a)
    return string.format("%016x%016x", a.hi, a.lo)
end

local function value(hi, lo)
    return {hi = hi, lo = lo}
end

local function selftest()
    local cases = {
        {"u", value(0, 7), value(0, 2), "00000000000000000000000000000003"},
        {"U", value(0, 7), value(0, 2), "00000000000000000000000000000001"},
        {"u", value(1, 0), value(0, 2), "00000000000000008000000000000000"},
        {"u", value(-1, -1), value(0, 1), "ffffffffffffffffffffffffffffffff"},
        {"U", value(-1, -1), value(0, 10), "00000000000000000000000000000005"},
        {"d", value(-1, -7), value(0, 2), "fffffffffffffffffffffffffffffffd"},
        {"m", value(-1, -7), value(0, 2), "ffffffffffffffffffffffffffffffff"},
        {"d", value(0, 7), value(-1, -2), "fffffffffffffffffffffffffffffffd"},
        {"m", value(0, 7), value(-1, -2), "00000000000000000000000000000001"},
        {"d", value(MIN, 0), value(0, 1), "80000000000000000000000000000000"}
    }
    for _, case in ipairs(cases) do
        local quotient, remainder = udivmod(case[2], case[3])
        local got = case[1] == "u" and hex(quotient) or case[1] == "U" and hex(remainder)
                    or case[1] == "d" and hex(sdiv(case[2], case[3])) or hex(smod(case[2], case[3]))
        assert(got == case[4], string.format("the reference itself is wrong: %s %s %s gave %s, not %s", case[1], hex(case[2]), hex(case[3]), got, case[4]))
    end
end

local function generator(seed)
    local state = seed
    local function next64()
        state = state + 0x1e3779b97f4a7c15
        local z = state
        z = (z ~ (z >> 30)) * 0xbf58476d1ce4e5b9
        z = (z ~ (z >> 27)) * 0x94d049bb133111eb
        return z ~ (z >> 31)
    end
    local widths = {1, 8, 31, 32, 63, 64, 65, 100, 127, 128}
    return function ()
        local width = widths[(next64() >> 1) % #widths + 1]
        local hi, lo = next64(), next64()
        if width <= 64 then
            hi = 0
            lo = width == 64 and lo or (lo & ((1 << width) - 1))
        elseif width < 128 then
            hi = hi & ((1 << (width - 64)) - 1)
        end
        return value(hi, lo)
    end
end

function main(out, count)
    local corpus = import("corpus", {rootdir = path.join(os.scriptdir(), "..", "..", "scripts"), anonymous = true})
    local _
    _, out = corpus.setup("int128", out)
    selftest()
    count = tonumber(type(count) == "string" and count or nil) or 3000
    local edges = {value(0, 0), value(0, 1), value(0, 2), value(0, 3), value(0, 7), value(-1, -1), value(-1, -2), value(0, MIN),
                   value(0, math.maxinteger), value(1, 0), value(0, -1), value(1, 1), value(MIN, 0), value(math.maxinteger, -1),
                   value(MIN, 1), value(1 << 36, 0)}
    local random = generator(20260927)
    local pairs_ = {}
    for _, a in ipairs(edges) do
        for _, b in ipairs(edges) do
            if not iszero(b) then
                table.insert(pairs_, {a, b})
            end
        end
    end
    for _ = 1, (#edges + count) * 4 do
        local a, b = random(), random()
        if iszero(b) then
            b = value(0, 1)
        end
        table.insert(pairs_, {a, b})
    end
    local lines, expected = {}, {}
    for _, pair in ipairs(pairs_) do
        local a, b = pair[1], pair[2]
        for _, op in ipairs({"u", "U", "d", "m"}) do
            local overflow = (op == "d" or op == "m") and a.hi == MIN and a.lo == 0 and b.hi == -1 and b.lo == -1
            if not overflow then
                table.insert(lines, string.format("%s %016x %016x %016x %016x", op, a.hi, a.lo, b.hi, b.lo))
                local r
                if op == "u" then
                    r = udivmod(a, b)
                elseif op == "U" then
                    _, r = udivmod(a, b)
                elseif op == "d" then
                    r = sdiv(a, b)
                else
                    r = smod(a, b)
                end
                table.insert(expected, hex(r))
            end
        end
    end
    local driver = path.join(out, "driver")
    os.execv("cc", {"-O1", "-w", path.join(os.scriptdir(), "driver.c"), "-o", driver})
    local input, output = path.join(out, "cases.txt"), path.join(out, "results.txt")
    io.writefile(input, table.concat(lines, "\n") .. "\n")
    os.execv(driver, {}, {stdin = input, stdout = output})
    local got = {}
    for word in io.readfile(output):gmatch("%S+") do
        table.insert(got, word)
    end
    if #got ~= #expected then
        corpus.fail("%d results for %d cases", #got, #expected)
    end
    local wrong = 0
    for index, line in ipairs(lines) do
        if got[index] ~= expected[index] then
            wrong = wrong + 1
            if wrong <= 5 then
                print("FAIL: %s expected %s got %s", line, expected[index], got[index])
            end
        end
    end
    print("%d cases, %d wrong", #lines, wrong)
    if wrong > 0 then
        corpus.fail("int128.c disagrees with the reference in %d cases", wrong)
    end
end
