local N, M = 624, 397

local function init_genrand(s)
    local mt = {[0] = s & 0xffffffff}
    for i = 1, N - 1 do
        local prev = mt[i - 1]
        mt[i] = (1812433253 * (prev ~ (prev >> 30)) + i) & 0xffffffff
    end
    return mt
end

function new(key)
    local mt = init_genrand(19650218)
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

function next_word(state)
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

function getrandbits(state, k)
    if k <= 32 then
        return next_word(state) >> (32 - k)
    end
    local result, shift = 0, 0
    while k > 0 do
        local word = next_word(state)
        if k < 32 then
            word = word >> (32 - k)
        end
        result = result | (word << shift)
        shift = shift + 32
        k = k - 32
    end
    return result
end

function randbelow(state, n)
    local k, rest = 0, n
    while rest > 0 do
        k = k + 1
        rest = rest >> 1
    end
    local r = getrandbits(state, k)
    while r >= n do
        r = getrandbits(state, k)
    end
    return r
end

function random(state)
    local a = next_word(state) >> 5
    local b = next_word(state) >> 6
    return (a * 67108864.0 + b) * (1.0 / 9007199254740992.0)
end
