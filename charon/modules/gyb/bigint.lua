local BITS = 24
local BASE = 1 << BITS
local MASK = BASE - 1
local SMALL = 1 << 62

local function trim(m)
    local n = #m
    while n > 0 and m[n] == 0 do
        m[n] = nil
        n = n - 1
    end
    return m
end

local function mag_of_nonnegative(u)
    local m = {}
    while u > 0 do
        m[#m + 1] = u & MASK
        u = u >> BITS
    end
    return m
end

local function mag_cmp(a, b)
    if #a ~= #b then
        return #a < #b and -1 or 1
    end
    for i = #a, 1, -1 do
        if a[i] ~= b[i] then
            return a[i] < b[i] and -1 or 1
        end
    end
    return 0
end

local function mag_add(a, b)
    local r, carry = {}, 0
    for i = 1, math.max(#a, #b) do
        local s = (a[i] or 0) + (b[i] or 0) + carry
        r[i] = s & MASK
        carry = s >> BITS
    end
    if carry > 0 then
        r[#r + 1] = carry
    end
    return r
end

local function mag_sub(a, b)
    local r, borrow = {}, 0
    for i = 1, #a do
        local s = a[i] - (b[i] or 0) - borrow
        if s < 0 then
            s = s + BASE
            borrow = 1
        else
            borrow = 0
        end
        r[i] = s
    end
    return trim(r)
end

local function mag_mul(a, b)
    if #a == 0 or #b == 0 then
        return {}
    end
    local r = {}
    for i = 1, #a + #b do
        r[i] = 0
    end
    for i = 1, #a do
        local carry, ai = 0, a[i]
        for j = 1, #b do
            local t = r[i + j - 1] + ai * b[j] + carry
            r[i + j - 1] = t & MASK
            carry = t >> BITS
        end
        local k = i + #b
        while carry > 0 do
            local t = r[k] + carry
            r[k] = t & MASK
            carry = t >> BITS
            k = k + 1
        end
    end
    return trim(r)
end

local function mag_bitlength(a)
    if #a == 0 then
        return 0
    end
    local top, bits = a[#a], 0
    while top > 0 do
        bits = bits + 1
        top = top >> 1
    end
    return (#a - 1) * BITS + bits
end

local function mag_bit(a, i)
    local limb = a[i // BITS + 1]
    if not limb then
        return 0
    end
    return (limb >> (i % BITS)) & 1
end

local function mag_shl(a, n)
    if #a == 0 then
        return {}
    end
    local limbs, bits = n // BITS, n % BITS
    local r = {}
    for i = 1, limbs do
        r[i] = 0
    end
    local carry = 0
    for i = 1, #a do
        local v = (a[i] << bits) | carry
        r[limbs + i] = v & MASK
        carry = v >> BITS
    end
    if carry > 0 then
        r[#r + 1] = carry
    end
    return trim(r)
end

local function mag_shr(a, n)
    local limbs, bits = n // BITS, n % BITS
    local r = {}
    for i = limbs + 1, #a do
        local v = a[i] >> bits
        local nxt = a[i + 1]
        if nxt and bits > 0 then
            v = v | ((nxt << (BITS - bits)) & MASK)
        end
        r[#r + 1] = v
    end
    return trim(r)
end

local function mag_divmod(a, b)
    if mag_cmp(a, b) < 0 then
        return {}, a
    end
    local q, r = {}, {}
    for i = mag_bitlength(a) - 1, 0, -1 do
        r = mag_shl(r, 1)
        if mag_bit(a, i) == 1 then
            if #r == 0 then
                r[1] = 1
            else
                r[1] = r[1] | 1
            end
        end
        if mag_cmp(r, b) >= 0 then
            r = mag_sub(r, b)
            local limb = i // BITS + 1
            for k = #q + 1, limb do
                q[k] = 0
            end
            q[limb] = q[limb] | (1 << (i % BITS))
        end
    end
    return trim(q), r
end

local function mag_divsmall(a, d)
    local q, rem = {}, 0
    for i = #a, 1, -1 do
        local cur = rem * BASE + a[i]
        q[i] = cur // d
        rem = cur % d
    end
    return trim(q), rem
end

local function make(sign, m)
    m = trim(m)
    if #m == 0 then
        return 0
    end
    if mag_bitlength(m) <= 62 then
        local v = 0
        for i = #m, 1, -1 do
            v = (v << BITS) | m[i]
        end
        return sign < 0 and -v or v
    end
    local b = {__t = "big", sign = sign}
    for i = 1, #m do
        b[i] = m[i]
    end
    return b
end

local function parts(v)
    if math.type(v) == "integer" then
        if v == math.mininteger then
            local m = mag_of_nonnegative(1 << 62)
            return -1, mag_shl(m, 1)
        end
        if v < 0 then
            return -1, mag_of_nonnegative(-v)
        end
        return 1, mag_of_nonnegative(v)
    end
    local m = {}
    for i = 1, #v do
        m[i] = v[i]
    end
    return v.sign, m
end

function isbig(v)
    return type(v) == "table" and v.__t == "big"
end

function fits(v)
    return math.type(v) == "integer" and v > -SMALL and v < SMALL
end

function add(a, b)
    local sa, ma = parts(a)
    local sb, mb = parts(b)
    if sa == sb then
        return make(sa, mag_add(ma, mb))
    end
    local c = mag_cmp(ma, mb)
    if c == 0 then
        return 0
    elseif c > 0 then
        return make(sa, mag_sub(ma, mb))
    end
    return make(sb, mag_sub(mb, ma))
end

function neg(a)
    local s, m = parts(a)
    return make(-s, m)
end

function sub(a, b)
    return add(a, neg(b))
end

function mul(a, b)
    local sa, ma = parts(a)
    local sb, mb = parts(b)
    return make(sa * sb, mag_mul(ma, mb))
end

function cmp(a, b)
    local sa, ma = parts(a)
    local sb, mb = parts(b)
    if #ma == 0 then
        sa = 0
    end
    if #mb == 0 then
        sb = 0
    end
    if sa ~= sb then
        return sa < sb and -1 or 1
    end
    if sa == 0 then
        return 0
    end
    local c = mag_cmp(ma, mb)
    return sa > 0 and c or -c
end

function divmod(a, b)
    local sa, ma = parts(a)
    local sb, mb = parts(b)
    if #mb == 0 then
        raise("division by zero")
    end
    local q, r = mag_divmod(ma, mb)
    if #ma == 0 then
        return 0, 0
    end
    if sa == sb then
        return make(1, q), make(sa, r)
    end
    if #r == 0 then
        return make(-1, q), 0
    end
    return make(-1, mag_add(q, {1})), make(sb, mag_sub(mb, r))
end

function pow(a, n)
    local result, base = 1, a
    while n > 0 do
        if n & 1 == 1 then
            result = mul(result, base)
        end
        n = n >> 1
        if n > 0 then
            base = mul(base, base)
        end
    end
    return result
end

function shl(a, n)
    local s, m = parts(a)
    return make(s, mag_shl(m, n))
end

function shr(a, n)
    local s, m = parts(a)
    if s > 0 then
        return make(1, mag_shr(m, n))
    end
    local q, r = divmod(a, shl(1, n))
    return q
end

local function twos(v, limbs)
    local s, m = parts(v)
    local r = {}
    if s > 0 or #m == 0 then
        for i = 1, limbs do
            r[i] = m[i] or 0
        end
        return r
    end
    local d = mag_sub(m, {1})
    for i = 1, limbs do
        r[i] = (~(d[i] or 0)) & MASK
    end
    return r
end

local function from_twos(r)
    local n = #r
    if (r[n] >> (BITS - 1)) & 1 == 0 then
        return make(1, r)
    end
    local m = {}
    for i = 1, n do
        m[i] = (~r[i]) & MASK
    end
    return make(-1, mag_add(trim(m), {1}))
end

local function bitwise(a, b, op)
    local _, ma = parts(a)
    local _, mb = parts(b)
    local limbs = math.max(#ma, #mb) + 1
    local ta, tb = twos(a, limbs), twos(b, limbs)
    local r = {}
    for i = 1, limbs do
        r[i] = op(ta[i], tb[i]) & MASK
    end
    return from_twos(r)
end

function band(a, b)
    return bitwise(a, b, function(x, y) return x & y end)
end

function bor(a, b)
    return bitwise(a, b, function(x, y) return x | y end)
end

function bxor(a, b)
    return bitwise(a, b, function(x, y) return x ~ y end)
end

function bitlength(a)
    local _, m = parts(a)
    return mag_bitlength(m)
end

function tostr(a)
    local s, m = parts(a)
    if #m == 0 then
        return "0"
    end
    local chunks = {}
    while #m > 0 do
        local rem
        m, rem = mag_divsmall(m, 1000000)
        chunks[#chunks + 1] = rem
    end
    local out = {tostring(chunks[#chunks])}
    for i = #chunks - 1, 1, -1 do
        out[#out + 1] = string.format("%06d", chunks[i])
    end
    return (s < 0 and "-" or "") .. table.concat(out)
end

function tofloat(a)
    local s, m = parts(a)
    local f = 0.0
    for i = #m, 1, -1 do
        f = f * BASE + m[i]
    end
    return s * f
end

function parse(text, base)
    local sign, start = 1, 1
    local first = text:sub(1, 1)
    if first == "-" or first == "+" then
        sign = first == "-" and -1 or 1
        start = 2
    end
    local m = {}
    for i = start, #text do
        local digit = tonumber(text:sub(i, i), 36)
        if digit == nil or digit >= base then
            return nil
        end
        m = mag_add(mag_mul(m, mag_of_nonnegative(base)), mag_of_nonnegative(digit))
    end
    return make(sign, m)
end
