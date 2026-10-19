-- python_random.lua: the random.Random of CPython 3, for the generators that draw from it. The Python templates seeded it
-- with 0 and drew randint(1, 6) from it, and the values they print are the committed output, so the sequence has to
-- be CPython's, not any other Mersenne Twister's.
--
--     local state = new(0)
--     randint(state, 1, 6)

local N, M = 624, 397

-- random.Random(seed) for a seed below 2**32: CPython hands init_by_array the seed as a one-word key
function new(seed)
    local key = {seed}
    local mt = {[0] = 19650218}
    for i = 1, N - 1 do
        local prev = mt[i - 1]
        mt[i] = (1812433253 * (prev ~ (prev >> 30)) + i) & 0xffffffff
    end
    local i, j = 1, 0
    for _ = 1, math.max(N, #key) do
        local prev = mt[i - 1]
        mt[i] = ((mt[i] ~ ((prev ~ (prev >> 30)) * 1664525)) + key[j + 1] + j) & 0xffffffff
        i, j = i + 1, j + 1
        if i >= N then
            mt[0] = mt[N - 1]
            i = 1
        end
        if j >= #key then
            j = 0
        end
    end
    for _ = 1, N - 1 do
        local prev = mt[i - 1]
        mt[i] = ((mt[i] ~ ((prev ~ (prev >> 30)) * 1566083941)) - i) & 0xffffffff
        i = i + 1
        if i >= N then
            mt[0] = mt[N - 1]
            i = 1
        end
    end
    mt[0] = 0x80000000
    return {mt = mt, index = N}
end

-- genrand_uint32: the next tempered word, with the state regenerated every N words
local function next_word(state)
    local mt = state.mt
    if state.index >= N then
        for kk = 0, N - 1 do
            local y = (mt[kk] & 0x80000000) | (mt[(kk + 1) % N] & 0x7fffffff)
            mt[kk] = mt[(kk + M) % N] ~ (y >> 1) ~ ((y & 1) == 1 and 0x9908b0df or 0)
        end
        state.index = 0
    end
    local y = mt[state.index]
    state.index = state.index + 1
    y = y ~ (y >> 11)
    y = y ~ ((y << 7) & 0x9d2c5680)
    y = y ~ ((y << 15) & 0xefc60000)
    y = y ~ (y >> 18)
    return y & 0xffffffff
end

-- _randbelow_with_getrandbits(n): k is n's bit length, and a draw at or above n is taken again
local function randbelow(state, n)
    local k = 0
    local rest = n
    while rest > 0 do
        k = k + 1
        rest = rest >> 1
    end
    local r = next_word(state) >> (32 - k)
    while r >= n do
        r = next_word(state) >> (32 - k)
    end
    return r
end

-- randint(a, b): randrange(a, b + 1)
function randint(state, a, b)
    return a + randbelow(state, b - a + 1)
end
