local bigint = import("bigint", {rootdir = path.join(os.scriptdir(), "..", "..", "..", "..", "modules", "gyb"), anonymous = true})

local DIGITS = "0123456789ABCDEF"
local BITS_PER_WORD = 32
local MODEXP_BITS = {32, 61, 64, 96, 128, 160, 192, 224, 255, 256, 288, 384, 512, 768, 1024, 1536, 2048, 3072}

local state = 20260927

local function next_word()
    state = state * 6364136223846793005 + 1442695040888963407
    return (state >> 32) & 0xFFFFFFFF
end

local function remainder(a, m)
    local _, r = bigint.divmod(a, m)
    return r
end

local function random_below(limit)
    local value = 0
    for _ = 1, bigint.bitlength(limit) // BITS_PER_WORD + 2 do
        value = bigint.add(bigint.shl(value, BITS_PER_WORD), next_word())
    end
    return remainder(value, limit)
end

local function random_in(low, high)
    return bigint.add(random_below(bigint.sub(high, low)), low)
end

local function modulus_of(bits)
    local span = bigint.pow(2, bits - 1)
    local value = random_in(span, bigint.mul(span, 2))
    if remainder(value, 2) == 0 then
        value = bigint.add(value, 1)
    end
    return value
end

local function modexp(base, exponent, modulus)
    local result, factor, rest = 1, base, exponent
    while bigint.cmp(rest, 0) > 0 do
        if bigint.band(rest, 1) == 1 then
            result = remainder(bigint.mul(result, factor), modulus)
        end
        rest = bigint.shr(rest, 1)
        if bigint.cmp(rest, 0) > 0 then
            factor = remainder(bigint.mul(factor, factor), modulus)
        end
    end
    return remainder(result, modulus)
end

local function hex(value)
    if bigint.cmp(value, 0) == 0 then
        return "0"
    end
    local out = {}
    while bigint.cmp(value, 0) > 0 do
        local digit = bigint.band(value, 15)
        table.insert(out, 1, DIGITS:sub(digit + 1, digit + 1))
        value = bigint.shr(value, 4)
    end
    return table.concat(out)
end

local function product_mod(left, right, modulus)
    return remainder(bigint.mul(left, right), modulus)
end

local function parse_hex(pieces)
    return bigint.parse(table.concat(pieces), 16)
end

local N1024 = parse_hex({
    "EEAF0AB9ADB38DD69C33F80AFA8FC5E86072618775FF3C0B9EA2314C9C256576D674DF7496EA81D3383B4813D692C6E0E0D5D8E250B98BE48E495C1D6089DAD1",
    "5DC7D7B46154D6B6CE8EF4AD69B15D4982559B297BCF1885C529F566660E57EC68EDBC3C05726CC02FD4CBF4976EAA9AFD5138FE8376435B9FC61D2FC0EB06E3",
})

local N3072 = parse_hex({
    "FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7EDEE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3DC2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F83655D23DCA3AD961C62F356208552BB9ED529077096966D670C354E4ABC9804F1746C08CA18217C32905E462E36CE3B",
    "E39E772C180E86039B2783A2EC07A28FB5C55DF06F4C52C9DE2BCBF6955817183995497CEA956AE515D2261898FA051015728E5A8AAAC42DAD33170D04507A33A85521ABDF1CBA64ECFB850458DBEF0A8AEA71575D060C7DB3970F85A6E1E4C7ABF5AE8CDB0933D71E8C94E04A25619DCEE3D2261AD2EE6BF12FFA06D98A0864D87602733EC86A64521F2B18177B200CBBE117577A615D6C770988C0BAD946E208E24FA074E5AB3143DB5BFCE0FD108E4B82D120A93AD2CAFFFFFFFFFFFFFFFF",
})

local K = bigint.parse("7556AA045AEF2CDD07ABAF0F665C3E818913186F", 16)
local V = parse_hex({
    "7E273DE8696FFC4F4E337D05B4B375BEB0DDE1569E8FA00A9886D8129BADA1F1",
    "822223CA1A605B530E379BA4729FDC59F105B4787E5186F5C671085A1447B52A",
    "48CF1970B4FB6F8400BBF4CEBFBB168152E08AB5EA53D15C1AFF87B2B9DA6E04",
    "E058AD51CC72BFC9033B564E26480D78E955A5E29E7AB245DB2BE315E2099AFB",
})
local X = bigint.parse("94B7555AABE9127CC58CCF4993DB6CF84D16C124", 16)
local A = bigint.parse("60975527035CF2AD1989806F0407210BC81EDC04E2762A56AFD529DDDA2D4393", 16)
local NARROW = bigint.parse("DEADBEEFCAFEF00D", 16)
local WIDE = bigint.add(bigint.pow(2, 2000), 12345)

local function rows()
    local out = {
        {"mul", K, V, N1024},
        {"mul", V, V, N1024},
        {"mul", K, K, N1024},
        {"mul", X, V, N1024},
        {"mul", A, V, N1024},
        {"mul", NARROW, NARROW, N3072},
        {"mul", WIDE, NARROW, N3072},
    }
    for _, bits in ipairs(MODEXP_BITS) do
        local modulus = modulus_of(bits)
        local base = random_in(2, modulus)
        local exponent = random_in(2, modulus)
        table.insert(out, {"pow", base, exponent, modulus})
    end
    for _, row in ipairs(out) do
        if row[1] == "mul" then
            row[5] = product_mod(row[2], row[3], row[4])
        else
            row[5] = modexp(row[2], row[3], row[4])
        end
    end
    return out
end

function main(cases_out, expected_out)
    local cases, expected = {}, {}
    for _, row in ipairs(rows()) do
        table.insert(cases, string.format("%s\t%s\t%s\t%s\n", row[1], hex(row[2]), hex(row[3]), hex(row[4])))
        table.insert(expected, hex(row[5]) .. "\n")
    end
    io.writefile(cases_out, table.concat(cases))
    io.writefile(expected_out, table.concat(expected))
end
