local bigint = import("bigint", {rootdir = os.scriptdir(), anonymous = true})
local mtwister = import("random", {rootdir = os.scriptdir(), anonymous = true})
local byteorder = import("byteorder", {rootdir = path.join(os.scriptdir(), ".."), anonymous = true})

local None = {__t = "none"}
local NotImplemented = {__t = "notimplemented"}

function none()
    return None
end

function not_implemented()
    return NotImplemented
end

local SMALL_FACTOR = 1 << 31

local classes = {}
local builtins = {}
local str_methods, list_methods, dict_methods, tuple_methods, set_methods, int_methods = {}, {}, {}, {}, {}, {}

local throw, call, str, repr, iterate, getattr, type_of, isinstance_class

function get_builtins()
    return builtins
end

function get_classes()
    return classes
end

local function tag(v)
    local t = type(v)
    if t == "table" then
        return v.__t
    end
    return t
end

function kind(v)
    local t = type(v)
    if t == "string" then
        return "str"
    elseif t == "number" then
        return math.type(v) == "integer" and "int" or "float"
    elseif t == "boolean" then
        return "bool"
    elseif t == "function" then
        return "builtin"
    elseif t == "table" then
        local k = v.__t
        if k == "big" then
            return "int"
        end
        return k
    end
    return t
end

local function is_int(v)
    return math.type(v) == "integer" or (type(v) == "table" and v.__t == "big")
end

local function is_number(v)
    local t = type(v)
    return t == "number" or t == "boolean" or (t == "table" and v.__t == "big")
end

local function as_number(v)
    if type(v) == "boolean" then
        return v and 1 or 0
    end
    return v
end

local function to_float(v)
    v = as_number(v)
    if type(v) == "table" then
        return bigint.tofloat(v)
    end
    return v + 0.0
end

function new_list(items)
    items = items or {}
    items.__t = "list"
    return items
end

function new_tuple(items)
    items = items or {}
    items.__t = "tuple"
    return items
end

local function float_repr(x)
    if x ~= x then
        return "nan"
    elseif x == math.huge then
        return "inf"
    elseif x == -math.huge then
        return "-inf"
    elseif x == 0 then
        return (1 / x < 0) and "-0.0" or "0.0"
    end
    local s
    for p = 1, 17 do
        s = string.format("%." .. (p - 1) .. "e", x)
        if tonumber(s) == x then
            break
        end
    end
    local sign, mantissa, exp = s:match("^(-?)([%d%.]+)e([-+]%d+)$")
    local digits = mantissa:gsub("%.", "")
    digits = digits:gsub("0+$", "")
    if digits == "" then
        digits = "0"
    end
    local e = tonumber(exp)
    if e >= -4 and e < 16 then
        local n = #digits
        if e >= 0 then
            local int_part, frac
            if n <= e + 1 then
                int_part = digits .. string.rep("0", e + 1 - n)
                frac = "0"
            else
                int_part = digits:sub(1, e + 1)
                frac = digits:sub(e + 2)
            end
            return sign .. int_part .. "." .. frac
        end
        return sign .. "0." .. string.rep("0", -e - 1) .. digits
    end
    local m = digits:sub(1, 1)
    if #digits > 1 then
        m = m .. "." .. digits:sub(2)
    end
    local esign = e < 0 and "-" or "+"
    local eabs = math.abs(e)
    return sign .. m .. "e" .. esign .. (eabs < 10 and "0" .. eabs or tostring(eabs))
end

local function int_str(v)
    if type(v) == "table" then
        return bigint.tostr(v)
    end
    return tostring(math.tointeger(v) or v)
end

local function hashkey(v)
    local t = type(v)
    if t == "string" then
        return "s" .. v
    elseif t == "number" then
        if math.type(v) == "integer" then
            return "i" .. tostring(v)
        end
        local i = math.tointeger(v)
        if i then
            return "i" .. tostring(i)
        end
        return "f" .. string.format("%.17g", v)
    elseif t == "boolean" then
        return v and "i1" or "i0"
    elseif t == "table" then
        local k = v.__t
        if k == "big" then
            return "i" .. bigint.tostr(v)
        elseif k == "none" then
            return "N"
        elseif k == "tuple" then
            local parts = {}
            for i = 1, #v do
                local h = hashkey(v[i])
                parts[i] = #h .. ":" .. h
            end
            return "t(" .. table.concat(parts) .. ")"
        elseif k == "list" or k == "dict" or k == "set" then
            throw("TypeError", "unhashable type: '" .. k .. "'")
        elseif k == "object" then
            local h = getattr(v, "__hash__", true)
            if h and h ~= None then
                return "h" .. int_str(call(h, {}))
            end
        end
        return "o" .. tostring(v)
    end
    return "o" .. tostring(v)
end

function new_dict()
    return {__t = "dict", keys = {}, vals = {}, index = {}}
end

function dict_get(d, k)
    local i = d.index[hashkey(k)]
    if i then
        return d.vals[i]
    end
end

function dict_set(d, k, v)
    local h = hashkey(k)
    local i = d.index[h]
    if i then
        d.vals[i] = v
    else
        local n = #d.keys + 1
        d.keys[n] = k
        d.vals[n] = v
        d.index[h] = n
    end
end

function dict_del(d, k)
    local h = hashkey(k)
    local i = d.index[h]
    if not i then
        return false
    end
    table.remove(d.keys, i)
    table.remove(d.vals, i)
    d.index = {}
    for j, key in ipairs(d.keys) do
        d.index[hashkey(key)] = j
    end
    return true
end

local function dict_get_str(d, name)
    local i = d.index["s" .. name]
    if i then
        return d.vals[i]
    end
end

function new_set(items)
    local s = {__t = "set", d = new_dict()}
    for _, v in ipairs(items or {}) do
        dict_set(s.d, v, true)
    end
    return s
end

local function exception_args(e)
    return dict_get_str(e.dict, "args") or new_tuple({})
end

function new_exception(cls_name, message)
    local cls = classes[cls_name]
    local inst = {__t = "object", cls = cls, dict = new_dict()}
    dict_set(inst.dict, "args", new_tuple(message ~= nil and {message} or {}))
    return inst
end

local pending_exceptions = {}
local exception_counter = 0

function raise_exception(inst)
    exception_counter = exception_counter + 1
    pending_exceptions[exception_counter] = inst
    raise("<<gyb-exception:" .. exception_counter .. ">>")
end

throw = function(cls_name, message)
    raise_exception(new_exception(cls_name, message))
end

function caught_exception(e)
    if type(e) == "string" then
        local id = e:match("<<gyb%-exception:(%d+)>>")
        if id then
            return pending_exceptions[tonumber(id)]
        end
    end
end

local function call_until(cls, fn)
    local value
    try {
        function()
            value = fn()
        end,
        catch {
            function(e)
                local inst = caught_exception(e)
                if not (inst and isinstance_class(inst, cls)) then
                    raise(e)
                end
            end
        }
    }
    return value
end

function throw_error(cls_name, message)
    throw(cls_name, message)
end

local function find_in_mro(cls, name)
    for _, c in ipairs(cls.mro) do
        local v = c.attrs[name]
        if v ~= nil then
            return v
        end
    end
end

local function class_of(v)
    local k = kind(v)
    if k == "object" then
        return v.cls
    end
    return classes[k] or classes.object
end
type_of = class_of

function is_subclass(c, base)
    for _, m in ipairs(c.mro) do
        if m == base then
            return true
        end
    end
    return false
end

isinstance_class = function(v, cls)
    local c = class_of(v)
    if is_subclass(c, cls) then
        return true
    end
    if cls == classes.int and type(v) == "boolean" then
        return true
    end
    return false
end

function isinstance(v, cls)
    return isinstance_class(v, cls)
end

function truth(v)
    local t = type(v)
    if t == "boolean" then
        return v
    elseif t == "number" then
        return v ~= 0
    elseif t == "string" then
        return v ~= ""
    elseif t == "table" then
        local k = v.__t
        if k == "none" then
            return false
        elseif k == "list" or k == "tuple" then
            return #v > 0
        elseif k == "dict" then
            return #v.keys > 0
        elseif k == "set" then
            return #v.d.keys > 0
        elseif k == "big" then
            return true
        elseif k == "range" then
            return builtins.len({v}) > 0
        elseif k == "object" then
            local b = getattr(v, "__bool__", true)
            if b then
                return truth(call(b, {}))
            end
            local l = getattr(v, "__len__", true)
            if l then
                return truth(call(l, {}))
            end
            return true
        end
        return true
    end
    return true
end

local function repr_str(s)
    local quote = "'"
    if s:find("'", 1, true) and not s:find('"', 1, true) then
        quote = '"'
    end
    local out = {quote}
    for _, code in utf8.codes(s) do
        local c = utf8.char(code)
        if c == quote or c == "\\" then
            out[#out + 1] = "\\" .. c
        elseif c == "\n" then
            out[#out + 1] = "\\n"
        elseif c == "\r" then
            out[#out + 1] = "\\r"
        elseif c == "\t" then
            out[#out + 1] = "\\t"
        elseif code < 32 or code == 127 then
            out[#out + 1] = string.format("\\x%02x", code)
        elseif code >= 0x80 and code < 0xa0 then
            out[#out + 1] = string.format("\\x%02x", code)
        else
            out[#out + 1] = c
        end
    end
    out[#out + 1] = quote
    return table.concat(out)
end

repr = function(v)
    local t = type(v)
    if t == "string" then
        return repr_str(v)
    elseif t == "number" then
        if math.type(v) == "integer" then
            return tostring(v)
        end
        return float_repr(v)
    elseif t == "boolean" then
        return v and "True" or "False"
    elseif t == "function" then
        return "<built-in function>"
    elseif t == "table" then
        local k = v.__t
        if k == "none" then
            return "None"
        elseif k == "big" then
            return bigint.tostr(v)
        elseif k == "list" or k == "tuple" then
            local parts = {}
            for i = 1, #v do
                parts[i] = repr(v[i])
            end
            if k == "list" then
                return "[" .. table.concat(parts, ", ") .. "]"
            end
            if #parts == 1 then
                return "(" .. parts[1] .. ",)"
            end
            return "(" .. table.concat(parts, ", ") .. ")"
        elseif k == "dict" then
            local parts = {}
            for i, key in ipairs(v.keys) do
                parts[i] = repr(key) .. ": " .. repr(v.vals[i])
            end
            return "{" .. table.concat(parts, ", ") .. "}"
        elseif k == "set" then
            if #v.d.keys == 0 then
                return "set()"
            end
            local parts = {}
            for i, key in ipairs(v.d.keys) do
                parts[i] = repr(key)
            end
            return "{" .. table.concat(parts, ", ") .. "}"
        elseif k == "range" then
            if v.step == 1 then
                return "range(" .. int_str(v.start) .. ", " .. int_str(v.stop) .. ")"
            end
            return "range(" .. int_str(v.start) .. ", " .. int_str(v.stop) .. ", " .. int_str(v.step) .. ")"
        elseif k == "object" then
            local r = getattr(v, "__repr__", true)
            if r then
                return str(call(r, {}))
            end
            if is_subclass(v.cls, classes.BaseException) then
                local args = exception_args(v)
                if #args == 1 then
                    return v.cls.name .. "(" .. repr(args[1]) .. ")"
                end
                return v.cls.name .. repr(args)
            end
            return "<" .. v.cls.name .. " object>"
        elseif k == "class" then
            return "<class '" .. v.name .. "'>"
        elseif k == "func" then
            return "<function " .. v.name .. ">"
        elseif k == "module" then
            return "<module '" .. v.name .. "'>"
        elseif k == "ellipsis" then
            return "Ellipsis"
        elseif k == "method" then
            return "<bound method>"
        end
        return "<" .. tostring(k) .. ">"
    end
    return tostring(v)
end

str = function(v)
    local t = type(v)
    if t == "string" then
        return v
    elseif t == "table" and v.__t == "object" then
        local s = getattr(v, "__str__", true)
        if s then
            return call(s, {})
        end
        if is_subclass(v.cls, classes.BaseException) then
            local args = exception_args(v)
            if #args == 0 then
                return ""
            elseif #args == 1 then
                return str(args[1])
            end
            return repr(args)
        end
    end
    return repr(v)
end

function to_str(v)
    return str(v)
end

function to_repr(v)
    return repr(v)
end

function int_tostring(v)
    return int_str(v)
end

function format_float_repr(x)
    return float_repr(x)
end

local function num_cmp(a, b)
    a, b = as_number(a), as_number(b)
    if type(a) == "table" or type(b) == "table" then
        if math.type(a) == "float" or math.type(b) == "float" then
            local fa, fb = to_float(a), to_float(b)
            return fa < fb and -1 or (fa > fb and 1 or 0)
        end
        return bigint.cmp(a, b)
    end
    if a < b then
        return -1
    elseif a > b then
        return 1
    elseif a == b then
        return 0
    end
    return nil
end

local eq

local function seq_eq(a, b)
    if #a ~= #b then
        return false
    end
    for i = 1, #a do
        if not eq(a[i], b[i]) then
            return false
        end
    end
    return true
end

eq = function(a, b)
    if a == b then
        return true
    end
    local ta, tb = type(a), type(b)
    if is_number(a) and is_number(b) then
        return num_cmp(a, b) == 0
    end
    if ta == "table" and tb == "table" then
        local ka, kb = a.__t, b.__t
        if ka == "object" then
            local f = getattr(a, "__eq__", true)
            if f then
                local r = call(f, {b})
                if r ~= NotImplemented then
                    return truth(r)
                end
            end
            return false
        end
        if kb == "object" then
            local f = getattr(b, "__eq__", true)
            if f then
                local r = call(f, {a})
                if r ~= NotImplemented then
                    return truth(r)
                end
            end
            return false
        end
        if ka ~= kb then
            return false
        end
        if ka == "list" or ka == "tuple" then
            return seq_eq(a, b)
        elseif ka == "dict" then
            if #a.keys ~= #b.keys then
                return false
            end
            for i, key in ipairs(a.keys) do
                local other = dict_get(b, key)
                if other == nil or not eq(a.vals[i], other) then
                    return false
                end
            end
            return true
        elseif ka == "set" then
            if #a.d.keys ~= #b.d.keys then
                return false
            end
            for _, key in ipairs(a.d.keys) do
                if dict_get(b.d, key) == nil then
                    return false
                end
            end
            return true
        elseif ka == "range" then
            return seq_eq(builtins.list({a}), builtins.list({b}))
        end
    end
    return false
end

function equals(a, b)
    return eq(a, b)
end

local function ne(a, b)
    if type(a) == "table" and a.__t == "object" then
        local f = getattr(a, "__ne__", true)
        if f then
            local r = call(f, {b})
            if r ~= NotImplemented then
                return truth(r)
            end
        end
    end
    return not eq(a, b)
end

local function order(a, b, op)
    if is_number(a) and is_number(b) then
        local c = num_cmp(a, b)
        if c == nil then
            return false
        end
        if op == "<" then
            return c < 0
        elseif op == "<=" then
            return c <= 0
        elseif op == ">" then
            return c > 0
        end
        return c >= 0
    end
    local ta, tb = type(a), type(b)
    if ta == "string" and tb == "string" then
        if op == "<" then
            return byteorder.less(a, b)
        elseif op == "<=" then
            return not byteorder.less(b, a)
        elseif op == ">" then
            return byteorder.less(b, a)
        end
        return not byteorder.less(a, b)
    end
    if ta == "table" and tb == "table" and a.__t == b.__t and (a.__t == "list" or a.__t == "tuple") then
        local n = math.min(#a, #b)
        for i = 1, n do
            if not eq(a[i], b[i]) then
                return order(a[i], b[i], op)
            end
        end
        if op == "<" then
            return #a < #b
        elseif op == "<=" then
            return #a <= #b
        elseif op == ">" then
            return #a > #b
        end
        return #a >= #b
    end
    if ta == "table" and a.__t == "object" then
        local names = {["<"] = "__lt__", ["<="] = "__le__", [">"] = "__gt__", [">="] = "__ge__"}
        local f = getattr(a, names[op], true)
        if f then
            local r = call(f, {b})
            if r ~= NotImplemented then
                return truth(r)
            end
        end
    end
    if tb == "table" and b.__t == "object" then
        local swapped = {["<"] = "__gt__", ["<="] = "__ge__", [">"] = "__lt__", [">="] = "__le__"}
        local f = getattr(b, swapped[op], true)
        if f then
            local r = call(f, {a})
            if r ~= NotImplemented then
                return truth(r)
            end
        end
    end
    throw("TypeError", "'" .. op .. "' not supported between instances of '" .. class_of(a).name .. "' and '" .. class_of(b).name .. "'")
end

function less(a, b)
    return order(a, b, "<")
end

local contains

function compare(op, a, b)
    if op == "==" then
        return eq(a, b)
    elseif op == "!=" then
        return ne(a, b)
    elseif op == "is" then
        return a == b or (is_number(a) and is_number(b) and type(a) == type(b) and num_cmp(a, b) == 0 and math.type(a) == math.type(b))
    elseif op == "is not" then
        return not compare("is", a, b)
    elseif op == "in" then
        return contains(b, a)
    elseif op == "not in" then
        return not contains(b, a)
    end
    return order(a, b, op)
end

local function int_add(a, b)
    if math.type(a) == "integer" and math.type(b) == "integer" then
        local r = a + b
        if ((a ~ r) & (b ~ r)) >= 0 then
            return r
        end
    end
    return bigint.add(a, b)
end

local function int_sub(a, b)
    if math.type(a) == "integer" and math.type(b) == "integer" then
        local r = a - b
        if ((a ~ b) & (a ~ r)) >= 0 then
            return r
        end
    end
    return bigint.sub(a, b)
end

local function int_mul(a, b)
    if math.type(a) == "integer" and math.type(b) == "integer" and a > -SMALL_FACTOR and a < SMALL_FACTOR and b > -SMALL_FACTOR and b < SMALL_FACTOR then
        return a * b
    end
    return bigint.mul(a, b)
end

local function int_floordiv(a, b)
    if b == 0 then
        throw("ZeroDivisionError", "integer division or modulo by zero")
    end
    if math.type(a) == "integer" and math.type(b) == "integer" and not (a == math.mininteger and b == -1) then
        return a // b
    end
    local q = bigint.divmod(a, b)
    return q
end

local function int_mod(a, b)
    if b == 0 then
        throw("ZeroDivisionError", "integer division or modulo by zero")
    end
    if math.type(a) == "integer" and math.type(b) == "integer" then
        if b == -1 then
            return 0
        end
        return a % b
    end
    local _, r = bigint.divmod(a, b)
    return r
end

local function int_pow(a, n)
    local result, base = 1, a
    while true do
        if n & 1 == 1 then
            result = int_mul(result, base)
        end
        n = n >> 1
        if n == 0 then
            return result
        end
        base = int_mul(base, base)
    end
end

local function int_shl(a, n)
    if bigint.isbig(n) or n < 0 then
        throw("ValueError", "negative shift count")
    end
    if math.type(a) == "integer" and n < 62 then
        local limit = 1 << (62 - n)
        if a > -limit and a < limit then
            return a << n
        end
    end
    return bigint.shl(a, n)
end

local function int_shr(a, n)
    if bigint.isbig(n) or n < 0 then
        throw("ValueError", "negative shift count")
    end
    if math.type(a) == "integer" then
        if n >= 63 then
            return a < 0 and -1 or 0
        end
        return a // (1 << n)
    end
    return bigint.shr(a, n)
end

local function int_bitop(op, a, b)
    if math.type(a) == "integer" and math.type(b) == "integer" then
        if op == "&" then
            return a & b
        elseif op == "|" then
            return a | b
        end
        return a ~ b
    end
    if op == "&" then
        return bigint.band(a, b)
    elseif op == "|" then
        return bigint.bor(a, b)
    end
    return bigint.bxor(a, b)
end

local function repeat_seq(seq, n, make)
    local out = {}
    if is_int(n) and not bigint.isbig(n) then
        for _ = 1, n do
            for i = 1, #seq do
                out[#out + 1] = seq[i]
            end
        end
    end
    return make(out)
end

local percent_format

local function binop_dunder(op, a, b)
    local names = {["+"] = "add", ["-"] = "sub", ["*"] = "mul", ["/"] = "truediv", ["//"] = "floordiv", ["%"] = "mod",
                   ["**"] = "pow", ["<<"] = "lshift", [">>"] = "rshift", ["&"] = "and", ["|"] = "or", ["^"] = "xor", ["@"] = "matmul"}
    local name = names[op]
    if type(a) == "table" and a.__t == "object" then
        local f = getattr(a, "__" .. name .. "__", true)
        if f then
            local r = call(f, {b})
            if r ~= NotImplemented then
                return r
            end
        end
    end
    if type(b) == "table" and b.__t == "object" then
        local f = getattr(b, "__r" .. name .. "__", true)
        if f then
            local r = call(f, {a})
            if r ~= NotImplemented then
                return r
            end
        end
    end
    throw("TypeError", "unsupported operand type(s) for " .. op .. ": '" .. class_of(a).name .. "' and '" .. class_of(b).name .. "'")
end

function binop(op, a, b)
    if is_number(a) and is_number(b) then
        local bools = type(a) == "boolean" and type(b) == "boolean"
        a, b = as_number(a), as_number(b)
        local floats = math.type(a) == "float" or math.type(b) == "float"
        if op == "+" then
            if floats then
                return to_float(a) + to_float(b)
            end
            return int_add(a, b)
        elseif op == "-" then
            if floats then
                return to_float(a) - to_float(b)
            end
            return int_sub(a, b)
        elseif op == "*" then
            if floats then
                return to_float(a) * to_float(b)
            end
            return int_mul(a, b)
        elseif op == "/" then
            local fb = to_float(b)
            if fb == 0 then
                throw("ZeroDivisionError", "division by zero")
            end
            return to_float(a) / fb
        elseif op == "//" then
            if floats then
                local fb = to_float(b)
                if fb == 0 then
                    throw("ZeroDivisionError", "float floor division by zero")
                end
                return math.floor(to_float(a) / fb) + 0.0
            end
            return int_floordiv(a, b)
        elseif op == "%" then
            if floats then
                local fa, fb = to_float(a), to_float(b)
                if fb == 0 then
                    throw("ZeroDivisionError", "float modulo")
                end
                return fa - math.floor(fa / fb) * fb
            end
            return int_mod(a, b)
        elseif op == "**" then
            if not floats and (bigint.isbig(b) and b.sign > 0 or (not bigint.isbig(b) and b >= 0)) then
                return int_pow(a, b)
            end
            return to_float(a) ^ to_float(b)
        elseif op == "<<" or op == ">>" or op == "&" or op == "|" or op == "^" then
            if floats then
                throw("TypeError", "unsupported operand type(s) for " .. op .. ": 'float'")
            end
            if op == "<<" then
                return int_shl(a, b)
            elseif op == ">>" then
                return int_shr(a, b)
            end
            local r = int_bitop(op, a, b)
            if bools then
                return r ~= 0
            end
            return r
        end
    end
    local ta, tb = kind(a), kind(b)
    if op == "+" then
        if ta == "str" and tb == "str" then
            return a .. b
        elseif ta == tb and (ta == "list" or ta == "tuple") then
            local out = {}
            for i = 1, #a do
                out[i] = a[i]
            end
            for i = 1, #b do
                out[#out + 1] = b[i]
            end
            return ta == "list" and new_list(out) or new_tuple(out)
        end
    elseif op == "*" then
        if ta == "str" and (tb == "int" or tb == "bool") then
            local n = as_number(b)
            return n > 0 and string.rep(a, n) or ""
        elseif tb == "str" and (ta == "int" or ta == "bool") then
            local n = as_number(a)
            return n > 0 and string.rep(b, n) or ""
        elseif (ta == "list" or ta == "tuple") and (tb == "int" or tb == "bool") then
            return repeat_seq(a, as_number(b), ta == "list" and new_list or new_tuple)
        elseif (tb == "list" or tb == "tuple") and (ta == "int" or ta == "bool") then
            return repeat_seq(b, as_number(a), tb == "list" and new_list or new_tuple)
        end
    elseif op == "%" then
        if ta == "str" then
            return percent_format(a, b)
        end
    elseif op == "|" and ta == "dict" and tb == "dict" then
        local out = new_dict()
        for i, k in ipairs(a.keys) do
            dict_set(out, k, a.vals[i])
        end
        for i, k in ipairs(b.keys) do
            dict_set(out, k, b.vals[i])
        end
        return out
    elseif (op == "|" or op == "&" or op == "-" or op == "^") and ta == "set" and tb == "set" then
        local out = new_set()
        local function has(s, k)
            return dict_get(s.d, k) ~= nil
        end
        if op == "|" then
            for _, k in ipairs(a.d.keys) do dict_set(out.d, k, true) end
            for _, k in ipairs(b.d.keys) do dict_set(out.d, k, true) end
        elseif op == "&" then
            for _, k in ipairs(a.d.keys) do if has(b, k) then dict_set(out.d, k, true) end end
        elseif op == "-" then
            for _, k in ipairs(a.d.keys) do if not has(b, k) then dict_set(out.d, k, true) end end
        else
            for _, k in ipairs(a.d.keys) do if not has(b, k) then dict_set(out.d, k, true) end end
            for _, k in ipairs(b.d.keys) do if not has(a, k) then dict_set(out.d, k, true) end end
        end
        return out
    end
    return binop_dunder(op, a, b)
end

function unop(op, a)
    if op == "not" then
        return not truth(a)
    end
    if is_number(a) then
        a = as_number(a)
        if op == "-" then
            if math.type(a) == "float" then
                return -a
            end
            if a == math.mininteger or bigint.isbig(a) then
                return bigint.neg(a)
            end
            return -a
        elseif op == "+" then
            return a
        elseif op == "~" then
            if math.type(a) == "float" then
                throw("TypeError", "bad operand type for unary ~: 'float'")
            end
            if bigint.isbig(a) then
                return bigint.sub(bigint.neg(a), 1)
            end
            return ~a
        end
    end
    if type(a) == "table" and a.__t == "object" then
        local names = {["-"] = "__neg__", ["+"] = "__pos__", ["~"] = "__invert__"}
        local f = getattr(a, names[op], true)
        if f then
            return call(f, {})
        end
    end
    throw("TypeError", "bad operand type for unary " .. op .. ": '" .. class_of(a).name .. "'")
end

local function utf8_chars(s)
    local chars = {}
    for _, code in utf8.codes(s) do
        chars[#chars + 1] = utf8.char(code)
    end
    return chars
end

local function is_ascii(s)
    return not s:find("[\128-\255]")
end

local function str_len(s)
    if is_ascii(s) then
        return #s
    end
    return utf8.len(s) or #s
end

local function range_len(r)
    local start, stop, step = r.start, r.stop, r.step
    if step > 0 then
        if start >= stop then
            return 0
        end
        return (stop - start - 1) // step + 1
    end
    if start <= stop then
        return 0
    end
    return (start - stop - 1) // (-step) + 1
end

iterate = function(v)
    local t = type(v)
    if t == "table" then
        local k = v.__t
        if k == "list" or k == "tuple" then
            local i = 0
            return function()
                i = i + 1
                return v[i]
            end
        elseif k == "range" then
            local cur, stop, step = v.start, v.stop, v.step
            return function()
                if (step > 0 and cur < stop) or (step < 0 and cur > stop) then
                    local r = cur
                    cur = cur + step
                    return r
                end
            end
        elseif k == "dict" then
            local keys = {}
            for i, key in ipairs(v.keys) do
                keys[i] = key
            end
            local i = 0
            return function()
                i = i + 1
                return keys[i]
            end
        elseif k == "set" then
            local keys = {}
            for i, key in ipairs(v.d.keys) do
                keys[i] = key
            end
            local i = 0
            return function()
                i = i + 1
                return keys[i]
            end
        elseif k == "iterator" then
            return v.nextf
        elseif k == "object" then
            local it = getattr(v, "__iter__", true)
            if it then
                local iterator = call(it, {})
                if type(iterator) == "table" and iterator.__t == "iterator" then
                    return iterator.nextf
                end
                local nxt = getattr(iterator, "__next__")
                return function()
                    return call_until(classes.StopIteration, function()
                        return call(nxt, {})
                    end)
                end
            end
            local gi = getattr(v, "__getitem__", true)
            if gi then
                local i = -1
                return function()
                    i = i + 1
                    return call_until(classes.IndexError, function()
                        return call(gi, {i})
                    end)
                end
            end
        end
    elseif t == "string" then
        if is_ascii(v) then
            local i = 0
            return function()
                i = i + 1
                if i <= #v then
                    return v:sub(i, i)
                end
            end
        end
        local chars = utf8_chars(v)
        local i = 0
        return function()
            i = i + 1
            return chars[i]
        end
    end
    throw("TypeError", "'" .. class_of(v).name .. "' object is not iterable")
end

function iter(v)
    return iterate(v)
end

function to_array(v)
    local t = type(v)
    if t == "table" and (v.__t == "list" or v.__t == "tuple") then
        local out = {}
        for i = 1, #v do
            out[i] = v[i]
        end
        return out
    end
    local out = {}
    for item in iterate(v) do
        out[#out + 1] = item
    end
    return out
end

function new_iterator(nextf)
    return {__t = "iterator", nextf = nextf}
end

contains = function(container, item)
    local k = kind(container)
    if k == "str" then
        if type(item) ~= "string" then
            throw("TypeError", "'in <string>' requires string as left operand")
        end
        return container:find(item, 1, true) ~= nil
    elseif k == "list" or k == "tuple" then
        for i = 1, #container do
            if eq(container[i], item) then
                return true
            end
        end
        return false
    elseif k == "dict" then
        return dict_get(container, item) ~= nil
    elseif k == "set" then
        return dict_get(container.d, item) ~= nil
    elseif k == "range" then
        if not is_int(item) then
            return false
        end
        for v in iterate(container) do
            if v == item then
                return true
            end
        end
        return false
    elseif k == "object" then
        local f = getattr(container, "__contains__", true)
        if f then
            return truth(call(f, {item}))
        end
    end
    for v in iterate(container) do
        if eq(v, item) then
            return true
        end
    end
    return false
end

function contains_item(container, item)
    return contains(container, item)
end

local function index_of(n, i, allow_end)
    i = as_number(i)
    if not is_int(i) or bigint.isbig(i) then
        throw("TypeError", "indices must be integers")
    end
    if i < 0 then
        i = i + n
    end
    return i
end

local function slice_indices(n, s)
    local step = s.step == None and 1 or as_number(s.step)
    if step == 0 then
        throw("ValueError", "slice step cannot be zero")
    end
    local start, stop
    if step > 0 then
        start = s.start == None and 0 or as_number(s.start)
        stop = s.stop == None and n or as_number(s.stop)
        if start < 0 then start = math.max(start + n, 0) elseif start > n then start = n end
        if stop < 0 then stop = math.max(stop + n, 0) elseif stop > n then stop = n end
    else
        start = s.start == None and n - 1 or as_number(s.start)
        stop = s.stop == None and -1 or as_number(s.stop)
        if s.start ~= None then
            if start < 0 then start = math.max(start + n, -1) elseif start >= n then start = n - 1 end
        end
        if s.stop ~= None then
            if stop < 0 then stop = math.max(stop + n, -1) elseif stop >= n then stop = n - 1 end
        end
    end
    return start, stop, step
end

local function slice_items(get, n, s)
    local start, stop, step = slice_indices(n, s)
    local out = {}
    local i = start
    while (step > 0 and i < stop) or (step < 0 and i > stop) do
        out[#out + 1] = get(i)
        i = i + step
    end
    return out
end

function new_slice(start, stop, step)
    return {__t = "slice", start = start, stop = stop, step = step}
end

function getitem(obj, key)
    local k = kind(obj)
    local is_slice = type(key) == "table" and key.__t == "slice"
    if k == "list" or k == "tuple" then
        if is_slice then
            local items = slice_items(function(i) return obj[i + 1] end, #obj, key)
            return k == "list" and new_list(items) or new_tuple(items)
        end
        local i = index_of(#obj, key)
        local v = obj[i + 1]
        if i < 0 or v == nil then
            throw("IndexError", k .. " index out of range")
        end
        return v
    elseif k == "str" then
        if is_ascii(obj) then
            if is_slice then
                local start, stop, step = slice_indices(#obj, key)
                if step == 1 then
                    if stop <= start then
                        return ""
                    end
                    return obj:sub(start + 1, stop)
                end
                return table.concat(slice_items(function(i) return obj:sub(i + 1, i + 1) end, #obj, key))
            end
            local i = index_of(#obj, key)
            if i < 0 or i >= #obj then
                throw("IndexError", "string index out of range")
            end
            return obj:sub(i + 1, i + 1)
        end
        local chars = utf8_chars(obj)
        if is_slice then
            return table.concat(slice_items(function(i) return chars[i + 1] end, #chars, key))
        end
        local i = index_of(#chars, key)
        if i < 0 or i >= #chars then
            throw("IndexError", "string index out of range")
        end
        return chars[i + 1]
    elseif k == "dict" then
        local v = dict_get(obj, key)
        if v == nil then
            throw("KeyError", key)
        end
        return v
    elseif k == "range" then
        local n = range_len(obj)
        if is_slice then
            local items = slice_items(function(i) return obj.start + i * obj.step end, n, key)
            return new_list(items)
        end
        local i = index_of(n, key)
        if i < 0 or i >= n then
            throw("IndexError", "range object index out of range")
        end
        return obj.start + i * obj.step
    elseif k == "object" then
        local f = getattr(obj, "__getitem__", true)
        if f then
            return call(f, {key})
        end
    elseif k == "class" and obj.attrs.__class_getitem__ then
        return obj
    end
    throw("TypeError", "'" .. class_of(obj).name .. "' object is not subscriptable")
end

function setitem(obj, key, value)
    local k = kind(obj)
    if k == "list" then
        if type(key) == "table" and key.__t == "slice" then
            local start, stop, step = slice_indices(#obj, key)
            local items = to_array(value)
            if step ~= 1 then
                local i, j = start, 1
                while (step > 0 and i < stop) or (step < 0 and i > stop) do
                    obj[i + 1] = items[j]
                    i, j = i + step, j + 1
                end
                return
            end
            if stop < start then
                stop = start
            end
            local rest = {}
            for i = stop + 1, #obj do
                rest[#rest + 1] = obj[i]
            end
            for i = #obj, start + 1, -1 do
                obj[i] = nil
            end
            for _, v in ipairs(items) do
                obj[#obj + 1] = v
            end
            for _, v in ipairs(rest) do
                obj[#obj + 1] = v
            end
            return
        end
        local i = index_of(#obj, key)
        if i < 0 or i >= #obj then
            throw("IndexError", "list assignment index out of range")
        end
        obj[i + 1] = value
        return
    elseif k == "dict" then
        dict_set(obj, key, value)
        return
    elseif k == "object" then
        local f = getattr(obj, "__setitem__", true)
        if f then
            call(f, {key, value})
            return
        end
    end
    throw("TypeError", "'" .. class_of(obj).name .. "' object does not support item assignment")
end

function delitem(obj, key)
    local k = kind(obj)
    if k == "list" then
        if type(key) == "table" and key.__t == "slice" then
            local start, stop, step = slice_indices(#obj, key)
            local remove = {}
            local i = start
            while (step > 0 and i < stop) or (step < 0 and i > stop) do
                remove[i + 1] = true
                i = i + step
            end
            local kept = {}
            for j = 1, #obj do
                if not remove[j] then
                    kept[#kept + 1] = obj[j]
                end
            end
            for j = #obj, 1, -1 do
                obj[j] = nil
            end
            for j, v in ipairs(kept) do
                obj[j] = v
            end
            return
        end
        local i = index_of(#obj, key)
        if i < 0 or i >= #obj then
            throw("IndexError", "list assignment index out of range")
        end
        table.remove(obj, i + 1)
        return
    elseif k == "dict" then
        if not dict_del(obj, key) then
            throw("KeyError", key)
        end
        return
    end
    throw("TypeError", "'" .. class_of(obj).name .. "' object does not support item deletion")
end

local function bind(f, self)
    return {__t = "method", self = self, func = f}
end

local function builtin_method(methods, obj, name)
    local m = methods[name]
    if m then
        return function(args, kw)
            return m(obj, args, kw)
        end
    end
end

local function class_attr(cls, name)
    if name == "__name__" then
        return cls.name
    elseif name == "__mro__" then
        return new_tuple(table.join({}, cls.mro))
    elseif name == "__bases__" then
        return new_tuple(table.join({}, cls.bases))
    end
    local v = find_in_mro(cls, name)
    if v ~= nil then
        if type(v) == "table" then
            if v.__t == "staticmethod" then
                return v.func
            elseif v.__t == "classmethod" then
                return bind(v.func, cls)
            end
        end
        return v
    end
    local methods = cls.methods
    if methods and methods[name] then
        local m = methods[name]
        return function(args, kw)
            local rest = {}
            for i = 2, #args do
                rest[i - 1] = args[i]
            end
            return m(args[1], rest, kw)
        end
    end
end

getattr = function(obj, name, quiet)
    local k = kind(obj)
    local v
    if k == "object" then
        if name == "__dict__" then
            return obj.dict
        elseif name == "__class__" then
            return obj.cls
        end
        v = dict_get_str(obj.dict, name)
        if v ~= nil then
            return v
        end
        local found = find_in_mro(obj.cls, name)
        if found ~= nil then
            local fk = kind(found)
            if fk == "func" or fk == "builtin" then
                return bind(found, obj)
            elseif fk == "staticmethod" then
                return found.func
            elseif fk == "classmethod" then
                return bind(found.func, obj.cls)
            elseif fk == "property" then
                return call(found.fget, {obj})
            end
            return found
        end
        if name ~= "__getattr__" then
            local ga = find_in_mro(obj.cls, "__getattr__")
            if ga then
                return call(ga, {obj, name})
            end
        end
    elseif k == "str" then
        v = builtin_method(str_methods, obj, name)
    elseif k == "list" then
        v = builtin_method(list_methods, obj, name)
    elseif k == "dict" then
        v = builtin_method(dict_methods, obj, name)
    elseif k == "tuple" then
        v = builtin_method(tuple_methods, obj, name)
    elseif k == "set" then
        v = builtin_method(set_methods, obj, name)
    elseif k == "int" or k == "bool" then
        v = builtin_method(int_methods, obj, name)
    elseif k == "module" then
        v = obj.globals[name]
    elseif k == "class" then
        v = class_attr(obj, name)
    elseif k == "native" then
        v = obj.attrs[name]
    elseif k == "func" then
        if name == "__name__" then
            v = obj.name
        end
    elseif k == "range" then
        if name == "start" or name == "stop" or name == "step" then
            v = obj[name]
        end
    end
    if v ~= nil then
        return v
    end
    if quiet then
        return nil
    end
    if k == "module" then
        throw("AttributeError", "module '" .. obj.name .. "' has no attribute '" .. name .. "'")
    end
    throw("AttributeError", "'" .. class_of(obj).name .. "' object has no attribute '" .. name .. "'")
end

function get_attribute(obj, name, quiet)
    return getattr(obj, name, quiet)
end

function setattr(obj, name, value)
    local k = kind(obj)
    if k == "object" then
        if name == "__dict__" then
            if kind(value) ~= "dict" then
                throw("TypeError", "__dict__ must be set to a dictionary")
            end
            obj.dict = value
            return
        end
        local sa = find_in_mro(obj.cls, "__setattr__")
        if sa then
            call(sa, {obj, name, value})
            return
        end
        dict_set(obj.dict, name, value)
        return
    elseif k == "class" then
        obj.attrs[name] = value
        return
    elseif k == "module" then
        obj.globals[name] = value
        return
    elseif k == "func" then
        obj.attrs = obj.attrs or {}
        obj.attrs[name] = value
        return
    end
    throw("AttributeError", "'" .. class_of(obj).name .. "' object has no attribute '" .. name .. "'")
end

function delattr(obj, name)
    local k = kind(obj)
    if k == "object" then
        if not dict_del(obj.dict, name) then
            throw("AttributeError", name)
        end
        return
    elseif k == "class" then
        obj.attrs[name] = nil
        return
    elseif k == "module" then
        obj.globals[name] = nil
        return
    end
    throw("AttributeError", name)
end

local function instantiate(cls, args, kw)
    if cls.construct then
        return cls.construct(args, kw, cls)
    end
    local new = find_in_mro(cls, "__new__")
    local inst
    if new and kind(new) ~= "builtin" then
        local nargs = {cls}
        for i = 1, #args do
            nargs[i + 1] = args[i]
        end
        inst = call(new.__t == "staticmethod" and new.func or new, nargs, kw)
        if not (type(inst) == "table" and inst.__t == "object" and is_subclass(inst.cls, cls)) then
            return inst
        end
    else
        inst = {__t = "object", cls = cls, dict = new_dict()}
        local native = cls.native_base
        if native then
            inst.native = native
        end
    end
    local init = find_in_mro(cls, "__init__")
    if init then
        local iargs = {inst}
        for i = 1, #args do
            iargs[i + 1] = args[i]
        end
        local r = call(init, iargs, kw)
        if r ~= None and r ~= nil then
            throw("TypeError", "__init__() should return None")
        end
    end
    return inst
end

call = function(f, args, kw)
    local t = type(f)
    if t == "function" then
        return f(args, kw)
    elseif t == "table" then
        local k = f.__t
        if k == "func" then
            return f.invoke(f, args, kw)
        elseif k == "method" then
            local nargs = {f.self}
            for i = 1, #args do
                nargs[i + 1] = args[i]
            end
            return call(f.func, nargs, kw)
        elseif k == "class" then
            return instantiate(f, args, kw)
        elseif k == "object" then
            local c = getattr(f, "__call__", true)
            if c then
                return call(c, args, kw)
            end
        elseif k == "staticmethod" then
            return call(f.func, args, kw)
        end
    end
    throw("TypeError", "'" .. class_of(f).name .. "' object is not callable")
end

function call_function(f, args, kw)
    return call(f, args, kw)
end

function callable(f)
    local k = kind(f)
    return k == "builtin" or k == "func" or k == "method" or k == "class" or (k == "object" and getattr(f, "__call__", true) ~= nil)
end

local function kwargs_map(kw)
    local m = {}
    if kw then
        for _, pair in ipairs(kw) do
            m[pair[1]] = pair[2]
        end
    end
    return m
end

local function arg(args, kw, index, name, default)
    local v = args[index]
    if v ~= nil then
        return v
    end
    if kw and name then
        for _, pair in ipairs(kw) do
            if pair[1] == name then
                return pair[2]
            end
        end
    end
    return default
end

function new_class(name, bases, attrs)
    local cls = {__t = "class", name = name, bases = bases, attrs = attrs or {}}
    local mro = {cls}
    local seen = {[cls] = true}
    local function add(c)
        if not seen[c] then
            seen[c] = true
            mro[#mro + 1] = c
        end
    end
    local tails = {}
    for _, b in ipairs(bases) do
        for _, m in ipairs(b.mro) do
            if m ~= classes.object then
                add(m)
            end
        end
        if b.construct and not cls.construct and b ~= classes.object and not is_subclass(b, classes.BaseException) then
            cls.construct = b.construct
        end
    end
    if classes.object and cls ~= classes.object then
        add(classes.object)
    end
    cls.mro = mro
    return cls
end

local function builtin_class(name, bases, construct, methods)
    local cls = new_class(name, bases or (classes.object and {classes.object} or {}), {})
    cls.construct = construct
    cls.methods = methods
    classes[name] = cls
    builtins[name] = cls
    return cls
end

local function to_int(v, base)
    local k = kind(v)
    if k == "int" then
        return v
    elseif k == "bool" then
        return v and 1 or 0
    elseif k == "float" then
        if v ~= v or v == math.huge or v == -math.huge then
            throw("ValueError", "cannot convert float to integer")
        end
        local t = v >= 0 and math.floor(v) or math.ceil(v)
        local i = math.tointeger(t)
        if i then
            return i
        end
        return bigint.parse(string.format("%.0f", t), 10)
    elseif k == "str" then
        local text = v:gsub("^%s+", ""):gsub("%s+$", ""):gsub("_", "")
        base = base or 10
        local sign = ""
        if text:find("^[-+]") then
            sign = text:sub(1, 1)
            text = text:sub(2)
        end
        local lower = text:lower()
        if base == 0 then
            if lower:find("^0x") then base = 16 elseif lower:find("^0o") then base = 8 elseif lower:find("^0b") then base = 2 else base = 10 end
        end
        if (base == 16 and lower:find("^0x")) or (base == 8 and lower:find("^0o")) or (base == 2 and lower:find("^0b")) then
            text = text:sub(3)
        end
        local r = text ~= "" and bigint.parse(sign .. text, base)
        if r == nil or r == false then
            throw("ValueError", "invalid literal for int() with base " .. base .. ": " .. repr(v))
        end
        return r
    elseif k == "object" then
        local f = getattr(v, "__int__", true) or getattr(v, "__index__", true)
        if f then
            return call(f, {})
        end
    end
    throw("TypeError", "int() argument must be a string, a bytes-like object or a real number, not '" .. class_of(v).name .. "'")
end

function to_integer(v)
    return to_int(v)
end

local function to_float_value(v)
    local k = kind(v)
    if k == "float" then
        return v
    elseif k == "int" or k == "bool" then
        return to_float(v)
    elseif k == "str" then
        local text = v:gsub("^%s+", ""):gsub("%s+$", ""):lower()
        if text == "inf" or text == "+inf" or text == "infinity" then
            return math.huge
        elseif text == "-inf" or text == "-infinity" then
            return -math.huge
        elseif text == "nan" or text == "+nan" or text == "-nan" then
            return 0.0 / 0.0
        end
        local n = tonumber((text:gsub("_", "")))
        if n == nil then
            throw("ValueError", "could not convert string to float: " .. repr(v))
        end
        return n + 0.0
    end
    throw("TypeError", "float() argument must be a string or a real number")
end

local function format_int_base(v, base, upper)
    if type(v) == "table" then
        local digits = {}
        local neg = v.sign < 0
        local n = neg and bigint.neg(v) or v
        local chars = upper and "0123456789ABCDEF" or "0123456789abcdef"
        while not (n == 0) do
            local q, r = bigint.divmod(n, base)
            digits[#digits + 1] = chars:sub(r + 1, r + 1)
            n = q
        end
        local s = string.reverse(table.concat(digits))
        return neg, s
    end
    local neg = v < 0
    local n = neg and -v or v
    if n == 0 then
        return false, "0"
    end
    local chars = upper and "0123456789ABCDEF" or "0123456789abcdef"
    local digits = {}
    while n > 0 do
        local r = n % base
        digits[#digits + 1] = chars:sub(r + 1, r + 1)
        n = n // base
    end
    return neg, string.reverse(table.concat(digits))
end

local function group_digits(s, sep, size)
    local int_part, rest = s:match("^(%d*)(.*)$")
    local groups = {}
    local n = #int_part
    local first = n % size
    if first > 0 then
        groups[#groups + 1] = int_part:sub(1, first)
    end
    for i = first + 1, n, size do
        groups[#groups + 1] = int_part:sub(i, i + size - 1)
    end
    return table.concat(groups, sep) .. rest
end

local function pad(body, sign, fill, align, width, zero)
    local total = #sign + str_len(body)
    if width and total < width then
        local n = width - total
        if align == "<" then
            return sign .. body .. string.rep(fill, n)
        elseif align == ">" then
            return string.rep(fill, n) .. sign .. body
        elseif align == "^" then
            local left = n // 2
            return string.rep(fill, left) .. sign .. body .. string.rep(fill, n - left)
        elseif align == "=" then
            return sign .. string.rep(fill, n) .. body
        end
    end
    return sign .. body
end

local function parse_spec(spec)
    local s = {fill = " ", align = nil, sign = "-", alt = false, zero = false, width = nil, grouping = nil, precision = nil, type = nil}
    local i = 1
    local function at(j)
        return spec:sub(j, j)
    end
    local c1, c2 = at(1), at(2)
    if c2 ~= "" and c2:find("[<>=^]") then
        s.fill, s.align = c1, c2
        i = 3
    elseif c1 ~= "" and c1:find("[<>=^]") then
        s.align = c1
        i = 2
    end
    if at(i):find("^[-+ ]$") then
        s.sign = at(i)
        i = i + 1
    end
    if at(i) == "z" then
        i = i + 1
    end
    if at(i) == "#" then
        s.alt = true
        i = i + 1
    end
    if at(i) == "0" then
        s.zero = true
        i = i + 1
    end
    local width = spec:match("^%d+", i)
    if width then
        s.width = tonumber(width)
        i = i + #width
    end
    if at(i) == "," or at(i) == "_" then
        s.grouping = at(i)
        i = i + 1
    end
    if at(i) == "." then
        local p = spec:match("^%d+", i + 1)
        if not p then
            throw("ValueError", "Format specifier missing precision")
        end
        s.precision = tonumber(p)
        i = i + 1 + #p
    end
    if i <= #spec then
        s.type = spec:sub(i, i)
        i = i + 1
    end
    if i <= #spec then
        throw("ValueError", "Invalid format specifier '" .. spec .. "'")
    end
    if s.zero and not s.align then
        s.fill = "0"
        s.align = "="
    end
    return s
end

local function format_float_spec(x, s, ty)
    local p = s.precision
    local body
    local neg = x < 0 or (x == 0 and 1 / x < 0)
    local ax = math.abs(x)
    if x ~= x then
        body = "nan"
        neg = false
    elseif ax == math.huge then
        body = "inf"
    elseif ty == "f" or ty == "F" then
        body = string.format("%." .. (p or 6) .. "f", ax)
    elseif ty == "e" or ty == "E" then
        body = string.format("%." .. (p or 6) .. "e", ax)
    elseif ty == "g" or ty == "G" then
        body = string.format((s.alt and "%#." or "%.") .. (p or 6) .. "g", ax)
    elseif ty == "%" then
        body = string.format("%." .. (p or 6) .. "f", ax * 100) .. "%"
    elseif ty == nil then
        if p then
            body = string.format("%." .. math.max(p, 1) .. "g", ax)
            if not body:find("[%.e]") and not body:find("inf") then
                body = body .. ".0"
            end
        else
            body = float_repr(ax)
        end
    else
        throw("ValueError", "Unknown format code '" .. ty .. "' for object of type 'float'")
    end
    if ty == "E" or ty == "G" or ty == "F" then
        body = body:upper()
    end
    if s.grouping then
        body = group_digits(body, s.grouping, 3)
    end
    local sign = neg and "-" or (s.sign == "+" and "+" or (s.sign == " " and " " or ""))
    return pad(body, sign, s.fill, s.align or ">", s.width)
end

function format_value(v, spec)
    local k = kind(v)
    if k == "object" then
        local f = getattr(v, "__format__", true)
        if f then
            return call(f, {spec})
        end
        v = str(v)
        k = "str"
    end
    if spec == "" then
        return str(v)
    end
    local s = parse_spec(spec)
    if k == "bool" and s.type == nil then
        v = str(v)
        k = "str"
    end
    if k == "str" or k == "none" or k == "list" or k == "tuple" or k == "dict" then
        if k ~= "str" then
            v = str(v)
        end
        if s.type and s.type ~= "s" then
            throw("ValueError", "Unknown format code '" .. s.type .. "' for object of type 'str'")
        end
        if s.precision then
            if is_ascii(v) then
                v = v:sub(1, s.precision)
            else
                v = table.concat(utf8_chars(v), "", 1, math.min(s.precision, utf8.len(v)))
            end
        end
        return pad(v, "", s.fill, s.align or "<", s.width)
    end
    if k == "int" or k == "bool" then
        v = as_number(v)
        local ty = s.type or "d"
        if ty == "e" or ty == "E" or ty == "f" or ty == "F" or ty == "g" or ty == "G" or ty == "%" then
            return format_float_spec(to_float(v), s, ty)
        end
        local neg, body
        if ty == "d" or ty == "n" then
            local text = int_str(v)
            neg = text:sub(1, 1) == "-"
            body = neg and text:sub(2) or text
        elseif ty == "x" or ty == "X" then
            neg, body = format_int_base(v, 16, ty == "X")
            if s.alt then body = (ty == "X" and "0X" or "0x") .. body end
        elseif ty == "o" then
            neg, body = format_int_base(v, 8)
            if s.alt then body = "0o" .. body end
        elseif ty == "b" then
            neg, body = format_int_base(v, 2)
            if s.alt then body = "0b" .. body end
        elseif ty == "c" then
            neg, body = false, utf8.char(v)
        else
            throw("ValueError", "Unknown format code '" .. ty .. "' for object of type 'int'")
        end
        if s.grouping then
            body = group_digits(body, s.grouping, (ty == "d" or ty == "n") and 3 or 4)
        end
        local sign = neg and "-" or (s.sign == "+" and "+" or (s.sign == " " and " " or ""))
        return pad(body, sign, s.fill, s.align or ">", s.width)
    end
    if k == "float" then
        return format_float_spec(v, s, s.type)
    end
    throw("TypeError", "unsupported format string passed to " .. class_of(v).name .. ".__format__")
end

local function resolve_field(field, args, kw, auto)
    local name, rest = field:match("^([^%.%[]*)(.*)$")
    local value
    if name == "" then
        auto.used_auto = true
        if auto.used_manual then
            throw("ValueError", "cannot switch from manual field specification to automatic field numbering")
        end
        value = args[auto.next + 1]
        if value == nil then
            throw("IndexError", "Replacement index " .. auto.next .. " out of range for positional args tuple")
        end
        auto.next = auto.next + 1
    elseif name:find("^%d+$") then
        auto.used_manual = true
        value = args[tonumber(name) + 1]
        if value == nil then
            throw("IndexError", "Replacement index " .. name .. " out of range for positional args tuple")
        end
    else
        value = kw[name]
        if value == nil then
            throw("KeyError", name)
        end
    end
    while rest ~= "" do
        local attr, after = rest:match("^%.([%w_]+)(.*)$")
        if attr then
            value = getattr(value, attr)
            rest = after
        else
            local key, after2 = rest:match("^%[([^%]]*)%](.*)$")
            if not key then
                throw("ValueError", "invalid field name '" .. field .. "'")
            end
            if key:find("^%d+$") then
                value = getitem(value, tonumber(key))
            else
                value = getitem(value, key)
            end
            rest = after2
        end
    end
    return value
end

local function convert(value, conversion)
    if conversion == "r" or conversion == "a" then
        return repr(value)
    elseif conversion == "s" then
        return str(value)
    end
    return value
end

local function str_format(fmt, args, kw, auto)
    auto = auto or {next = 0}
    local out = {}
    local i = 1
    local n = #fmt
    while i <= n do
        local c = fmt:sub(i, i)
        if c == "{" then
            if fmt:sub(i + 1, i + 1) == "{" then
                out[#out + 1] = "{"
                i = i + 2
            else
                local depth = 1
                local j = i + 1
                while j <= n and depth > 0 do
                    local d = fmt:sub(j, j)
                    if d == "{" then
                        depth = depth + 1
                    elseif d == "}" then
                        depth = depth - 1
                    end
                    j = j + 1
                end
                if depth > 0 then
                    throw("ValueError", "expected '}' before end of string")
                end
                local inner = fmt:sub(i + 1, j - 2)
                local field, conversion, spec = inner, nil, ""
                local bracket = 0
                for p = 1, #inner do
                    local d = inner:sub(p, p)
                    if d == "[" then
                        bracket = bracket + 1
                    elseif d == "]" then
                        bracket = bracket - 1
                    elseif bracket == 0 and (d == "!" or d == ":") then
                        field = inner:sub(1, p - 1)
                        local tail = inner:sub(p)
                        if d == "!" then
                            conversion = tail:sub(2, 2)
                            tail = tail:sub(3)
                        end
                        if tail:sub(1, 1) == ":" then
                            spec = tail:sub(2)
                        end
                        break
                    end
                end
                local value = resolve_field(field, args, kw, auto)
                if spec:find("{", 1, true) then
                    spec = str_format(spec, args, kw, auto)
                end
                out[#out + 1] = format_value(convert(value, conversion), spec)
                i = j
            end
        elseif c == "}" then
            if fmt:sub(i + 1, i + 1) == "}" then
                out[#out + 1] = "}"
                i = i + 2
            else
                throw("ValueError", "Single '}' encountered in format string")
            end
        else
            local j = fmt:find("[{}]", i) or n + 1
            out[#out + 1] = fmt:sub(i, j - 1)
            i = j
        end
    end
    return table.concat(out)
end

function format_string(fmt, args, kw)
    return str_format(fmt, args, kw or {})
end

function format_field(value, conversion, spec)
    return format_value(convert(value, conversion), spec or "")
end

percent_format = function(fmt, values)
    local args
    local mapping
    local k = kind(values)
    if k == "tuple" then
        args = values
    elseif k == "dict" or (k == "object" and getattr(values, "__getitem__", true) and not isinstance_class(values, classes.str)) then
        mapping = values
        args = {values}
    else
        args = {values}
    end
    local index = 1
    local out = {}
    local i = 1
    local n = #fmt
    local function next_arg()
        local v = args[index]
        if v == nil then
            throw("TypeError", "not enough arguments for format string")
        end
        index = index + 1
        return v
    end
    while i <= n do
        local c = fmt:sub(i, i)
        if c ~= "%" then
            local j = fmt:find("%", i, true) or n + 1
            out[#out + 1] = fmt:sub(i, j - 1)
            i = j
        else
            i = i + 1
            local value
            if fmt:sub(i, i) == "(" then
                local close = fmt:find(")", i, true)
                local key = fmt:sub(i + 1, close - 1)
                value = getitem(mapping or values, key)
                i = close + 1
            end
            local flags = fmt:match("^[-+ #0]*", i)
            i = i + #flags
            local width
            if fmt:sub(i, i) == "*" then
                width = as_number(next_arg())
                i = i + 1
            else
                local w = fmt:match("^%d+", i)
                if w then
                    width = tonumber(w)
                    i = i + #w
                end
            end
            local precision
            if fmt:sub(i, i) == "." then
                i = i + 1
                if fmt:sub(i, i) == "*" then
                    precision = as_number(next_arg())
                    i = i + 1
                else
                    local p = fmt:match("^%d*", i)
                    precision = tonumber(p) or 0
                    i = i + #p
                end
            end
            local conv = fmt:sub(i, i)
            if conv:find("[hlL]") then
                i = i + 1
                conv = fmt:sub(i, i)
            end
            i = i + 1
            if conv == "%" then
                out[#out + 1] = "%"
            else
                if value == nil then
                    value = next_arg()
                end
                local left = flags:find("-", 1, true) ~= nil
                local zero = flags:find("0", 1, true) ~= nil and not left
                local plus = flags:find("+", 1, true) ~= nil
                local space = flags:find(" ", 1, true) ~= nil
                local alt = flags:find("#", 1, true) ~= nil
                local body, neg = nil, false
                local numeric = true
                if conv == "s" or conv == "r" or conv == "a" then
                    numeric = false
                    body = conv == "s" and str(value) or repr(value)
                    if precision then
                        body = body:sub(1, precision)
                    end
                elseif conv == "d" or conv == "i" or conv == "u" then
                    local iv = to_int(kind(value) == "float" and value or value)
                    local text = int_str(iv)
                    neg = text:sub(1, 1) == "-"
                    body = neg and text:sub(2) or text
                    if precision and #body < precision then
                        body = string.rep("0", precision - #body) .. body
                    end
                elseif conv == "x" or conv == "X" or conv == "o" then
                    neg, body = format_int_base(to_int(value), conv == "o" and 8 or 16, conv == "X")
                    if precision and #body < precision then
                        body = string.rep("0", precision - #body) .. body
                    end
                    if alt then
                        body = (conv == "o" and "0o" or (conv == "X" and "0X" or "0x")) .. body
                    end
                elseif conv == "e" or conv == "E" or conv == "f" or conv == "F" or conv == "g" or conv == "G" then
                    local fv = to_float_value(value)
                    neg = fv < 0
                    body = string.format("%" .. (alt and "#" or "") .. "." .. (precision or 6) .. conv, math.abs(fv))
                elseif conv == "c" then
                    numeric = false
                    body = type(value) == "string" and value or utf8.char(as_number(value))
                else
                    throw("ValueError", "unsupported format character '" .. conv .. "'")
                end
                local sign = ""
                if numeric then
                    sign = neg and "-" or (plus and "+" or (space and " " or ""))
                end
                if left then
                    out[#out + 1] = pad(body, sign, " ", "<", width)
                elseif zero and numeric then
                    out[#out + 1] = pad(body, sign, "0", "=", width)
                else
                    out[#out + 1] = pad(body, sign, " ", ">", width)
                end
            end
        end
    end
    if index <= #args and not mapping and k == "tuple" then
        throw("TypeError", "not all arguments converted during string formatting")
    end
    return table.concat(out)
end

function percent(fmt, values)
    return percent_format(fmt, values)
end

local function check_str(v, what)
    if type(v) ~= "string" then
        throw("TypeError", what .. " must be str, not " .. class_of(v).name)
    end
    return v
end

local function plain_find(s, sub, init)
    return s:find(sub, init, true)
end

local function strip_chars(s, chars, left, right)
    if chars == nil or chars == None then
        if left then s = s:gsub("^%s+", "") end
        if right then s = s:gsub("%s+$", "") end
        return s
    end
    local set = {}
    for _, ch in ipairs(utf8_chars(chars)) do
        set[ch] = true
    end
    local cs = utf8_chars(s)
    local a, b = 1, #cs
    if left then
        while a <= b and set[cs[a]] do a = a + 1 end
    end
    if right then
        while b >= a and set[cs[b]] do b = b - 1 end
    end
    return table.concat(cs, "", a, b)
end

local function split_whitespace(s, maxsplit)
    local parts = {}
    local pos = 1
    local n = #s
    while true do
        local a, b = s:find("^%s+", pos)
        if a then
            pos = b + 1
        end
        if pos > n then
            break
        end
        if maxsplit >= 0 and #parts >= maxsplit then
            parts[#parts + 1] = s:sub(pos):gsub("%s+$", "")
            break
        end
        local e = s:find("%s", pos) or n + 1
        parts[#parts + 1] = s:sub(pos, e - 1)
        pos = e
    end
    return parts
end

str_methods.join = function(s, args)
    local parts = {}
    for item in iterate(args[1]) do
        if type(item) ~= "string" then
            throw("TypeError", "sequence item " .. #parts .. ": expected str instance, " .. class_of(item).name .. " found")
        end
        parts[#parts + 1] = item
    end
    return table.concat(parts, s)
end

str_methods.lower = function(s)
    return s:lower()
end

str_methods.upper = function(s)
    return s:upper()
end

str_methods.capitalize = function(s)
    return s:sub(1, 1):upper() .. s:sub(2):lower()
end

str_methods.title = function(s)
    return (s:gsub("(%a)([%a]*)", function(a, b) return a:upper() .. b:lower() end))
end

str_methods.swapcase = function(s)
    return (s:gsub("%a", function(c) if c:match("%l") then return c:upper() end return c:lower() end))
end

str_methods.casefold = str_methods.lower

str_methods.replace = function(s, args, kw)
    local old, new = check_str(args[1], "replace() argument 1"), check_str(args[2], "replace() argument 2")
    local count = as_number(arg(args, kw, 3, "count", -1))
    local out = {}
    local pos = 1
    local done = 0
    if old == "" then
        local chars = utf8_chars(s)
        for i, ch in ipairs(chars) do
            if count < 0 or done < count then
                out[#out + 1] = new
                done = done + 1
            end
            out[#out + 1] = ch
        end
        if count < 0 or done < count then
            out[#out + 1] = new
        end
        return table.concat(out)
    end
    while count < 0 or done < count do
        local a, b = plain_find(s, old, pos)
        if not a then
            break
        end
        out[#out + 1] = s:sub(pos, a - 1)
        out[#out + 1] = new
        pos = b + 1
        done = done + 1
    end
    out[#out + 1] = s:sub(pos)
    return table.concat(out)
end

str_methods.split = function(s, args, kw)
    local sep = arg(args, kw, 1, "sep", None)
    local maxsplit = as_number(arg(args, kw, 2, "maxsplit", -1))
    if sep == None then
        return new_list(split_whitespace(s, maxsplit))
    end
    check_str(sep, "separator")
    if sep == "" then
        throw("ValueError", "empty separator")
    end
    local parts = {}
    local pos = 1
    while maxsplit < 0 or #parts < maxsplit do
        local a, b = plain_find(s, sep, pos)
        if not a then
            break
        end
        parts[#parts + 1] = s:sub(pos, a - 1)
        pos = b + 1
    end
    parts[#parts + 1] = s:sub(pos)
    return new_list(parts)
end

str_methods.rsplit = function(s, args, kw)
    local sep = arg(args, kw, 1, "sep", None)
    local maxsplit = as_number(arg(args, kw, 2, "maxsplit", -1))
    if maxsplit < 0 then
        return str_methods.split(s, {sep}, nil)
    end
    if sep == None then
        local all = split_whitespace(s, -1)
        local parts = {}
        local keep = math.max(#all - maxsplit, 0)
        if keep > 0 then
            local stripped = s:gsub("%s+$", "")
            local count = 0
            local pos = #stripped
            while count < maxsplit do
                local a = stripped:sub(1, pos):find("%s+[^%s]*$")
                if not a then
                    break
                end
                local b = stripped:sub(1, pos):find("[^%s]*$")
                table.insert(parts, 1, stripped:sub(b, pos))
                pos = a - 1
                count = count + 1
            end
            table.insert(parts, 1, (stripped:sub(1, pos):gsub("^%s+", "")))
            return new_list(parts)
        end
        return new_list(all)
    end
    local parts = {}
    local pos = #s
    local rest = s
    while #parts < maxsplit do
        local found
        local start = 1
        while true do
            local a = plain_find(rest, sep, start)
            if not a then
                break
            end
            found = a
            start = a + 1
        end
        if not found then
            break
        end
        table.insert(parts, 1, rest:sub(found + #sep))
        rest = rest:sub(1, found - 1)
    end
    table.insert(parts, 1, rest)
    return new_list(parts)
end

str_methods.splitlines = function(s, args, kw)
    local keepends = truth(arg(args, kw, 1, "keepends", false))
    local lines = {}
    local pos = 1
    while pos <= #s do
        local a, b = s:find("\r?\n", pos)
        local ar = s:find("\r", pos, true)
        if ar and (not a or ar < a) and s:sub(ar + 1, ar + 1) ~= "\n" then
            a, b = ar, ar
        end
        if not a then
            lines[#lines + 1] = s:sub(pos)
            break
        end
        lines[#lines + 1] = keepends and s:sub(pos, b) or s:sub(pos, a - 1)
        pos = b + 1
    end
    return new_list(lines)
end

str_methods.strip = function(s, args)
    return strip_chars(s, args[1], true, true)
end

str_methods.lstrip = function(s, args)
    return strip_chars(s, args[1], true, false)
end

str_methods.rstrip = function(s, args)
    return strip_chars(s, args[1], false, true)
end

local function affix_check(s, args, at_start)
    local affix = args[1]
    local start = args[2] and as_number(args[2]) or 0
    local stop = args[3] and as_number(args[3]) or #s
    if start < 0 then start = math.max(start + #s, 0) end
    if stop < 0 then stop = math.max(stop + #s, 0) end
    local sub = s:sub(start + 1, stop)
    local candidates = kind(affix) == "tuple" and affix or {affix}
    for i = 1, #candidates do
        local a = check_str(candidates[i], "affix")
        if at_start then
            if sub:sub(1, #a) == a then return true end
        else
            if a == "" or sub:sub(-#a) == a then return true end
        end
    end
    return false
end

str_methods.startswith = function(s, args)
    return affix_check(s, args, true)
end

str_methods.endswith = function(s, args)
    return affix_check(s, args, false)
end

local function find_impl(s, args, reverse)
    local sub = check_str(args[1], "substring")
    local start = args[2] and args[2] ~= None and as_number(args[2]) or 0
    local stop = args[3] and args[3] ~= None and as_number(args[3]) or #s
    if start < 0 then start = math.max(start + #s, 0) end
    if stop < 0 then stop = math.max(stop + #s, 0) end
    if stop > #s then stop = #s end
    local region = s:sub(start + 1, stop)
    if reverse then
        local found
        local pos = 1
        while true do
            local a = plain_find(region, sub, pos)
            if not a then
                break
            end
            found = a
            pos = a + 1
            if sub == "" and pos > #region + 1 then
                break
            end
        end
        if found then
            return start + found - 1
        end
        return -1
    end
    local a = plain_find(region, sub, 1)
    if a then
        return start + a - 1
    end
    return -1
end

str_methods.find = function(s, args)
    return find_impl(s, args, false)
end

str_methods.rfind = function(s, args)
    return find_impl(s, args, true)
end

str_methods.index = function(s, args)
    local r = find_impl(s, args, false)
    if r < 0 then
        throw("ValueError", "substring not found")
    end
    return r
end

str_methods.rindex = function(s, args)
    local r = find_impl(s, args, true)
    if r < 0 then
        throw("ValueError", "substring not found")
    end
    return r
end

str_methods.count = function(s, args)
    local sub = check_str(args[1], "substring")
    if sub == "" then
        return str_len(s) + 1
    end
    local count, pos = 0, 1
    while true do
        local a, b = plain_find(s, sub, pos)
        if not a then
            return count
        end
        count = count + 1
        pos = b + 1
    end
end

str_methods.format = function(s, args, kw)
    return str_format(s, args, kwargs_map(kw))
end

str_methods.format_map = function(s, args)
    local m = {}
    local d = args[1]
    for i, k in ipairs(d.keys) do
        if type(k) == "string" then
            m[k] = d.vals[i]
        end
    end
    return str_format(s, {}, m)
end

str_methods.zfill = function(s, args)
    local width = as_number(args[1])
    local sign = ""
    local body = s
    if s:sub(1, 1) == "-" or s:sub(1, 1) == "+" then
        sign, body = s:sub(1, 1), s:sub(2)
    end
    if str_len(s) >= width then
        return s
    end
    return sign .. string.rep("0", width - str_len(s)) .. body
end

str_methods.ljust = function(s, args)
    return pad(s, "", args[2] or " ", "<", as_number(args[1]))
end

str_methods.rjust = function(s, args)
    return pad(s, "", args[2] or " ", ">", as_number(args[1]))
end

str_methods.center = function(s, args)
    local width = as_number(args[1])
    local fill = args[2] or " "
    local n = width - str_len(s)
    if n <= 0 then
        return s
    end
    local left = n // 2 + (n & width & 1)
    return string.rep(fill, left) .. s .. string.rep(fill, n - left)
end

str_methods.partition = function(s, args)
    local sep = check_str(args[1], "separator")
    local a, b = plain_find(s, sep, 1)
    if not a then
        return new_tuple({s, "", ""})
    end
    return new_tuple({s:sub(1, a - 1), sep, s:sub(b + 1)})
end

str_methods.rpartition = function(s, args)
    local sep = check_str(args[1], "separator")
    local r = find_impl(s, {sep}, true)
    if r < 0 then
        return new_tuple({"", "", s})
    end
    return new_tuple({s:sub(1, r), sep, s:sub(r + #sep + 1)})
end

local function all_chars(pattern)
    return function(s)
        return s ~= "" and not s:find("[^" .. pattern .. "]")
    end
end

str_methods.isdigit = all_chars("%d")
str_methods.isdecimal = all_chars("%d")
str_methods.isnumeric = all_chars("%d")
str_methods.isalpha = all_chars("%a")
str_methods.isalnum = all_chars("%w")
str_methods.isspace = all_chars("%s")
str_methods.isupper = function(s)
    return s:find("%u") ~= nil and not s:find("%l")
end
str_methods.islower = function(s)
    return s:find("%l") ~= nil and not s:find("%u")
end
str_methods.isidentifier = function(s)
    return s:find("^[%a_][%w_]*$") ~= nil
end
str_methods.encode = function(s)
    return s
end
str_methods.expandtabs = function(s, args)
    local size = args[1] and as_number(args[1]) or 8
    local out = {}
    local col = 0
    for _, ch in ipairs(utf8_chars(s)) do
        if ch == "\t" then
            local n = size > 0 and size - col % size or 0
            out[#out + 1] = string.rep(" ", n)
            col = col + n
        elseif ch == "\n" or ch == "\r" then
            out[#out + 1] = ch
            col = 0
        else
            out[#out + 1] = ch
            col = col + 1
        end
    end
    return table.concat(out)
end
str_methods.removeprefix = function(s, args)
    local p = check_str(args[1], "prefix")
    if p ~= "" and s:sub(1, #p) == p then
        return s:sub(#p + 1)
    end
    return s
end
str_methods.removesuffix = function(s, args)
    local p = check_str(args[1], "suffix")
    if p ~= "" and s:sub(-#p) == p then
        return s:sub(1, #s - #p)
    end
    return s
end

local function sort_array(items, key, reverse)
    local keyed = {}
    for i, v in ipairs(items) do
        keyed[i] = {k = key and call(key, {v}) or v, v = v, i = i}
    end
    table.sort(keyed, function(a, b)
        if reverse then
            if order(b.k, a.k, "<") then
                return true
            end
            if order(a.k, b.k, "<") then
                return false
            end
            return a.i < b.i
        end
        if order(a.k, b.k, "<") then
            return true
        end
        if order(b.k, a.k, "<") then
            return false
        end
        return a.i < b.i
    end)
    for i, e in ipairs(keyed) do
        items[i] = e.v
    end
    return items
end

list_methods.append = function(l, args)
    l[#l + 1] = args[1]
    return None
end

list_methods.extend = function(l, args)
    for _, v in ipairs(to_array(args[1])) do
        l[#l + 1] = v
    end
    return None
end

list_methods.insert = function(l, args)
    local i = as_number(args[1])
    local n = #l
    if i < 0 then
        i = math.max(i + n, 0)
    elseif i > n then
        i = n
    end
    table.insert(l, i + 1, args[2])
    return None
end

list_methods.pop = function(l, args)
    local n = #l
    if n == 0 then
        throw("IndexError", "pop from empty list")
    end
    local i = args[1] and as_number(args[1]) or -1
    if i < 0 then
        i = i + n
    end
    if i < 0 or i >= n then
        throw("IndexError", "pop index out of range")
    end
    return table.remove(l, i + 1)
end

list_methods.remove = function(l, args)
    for i = 1, #l do
        if eq(l[i], args[1]) then
            table.remove(l, i)
            return None
        end
    end
    throw("ValueError", "list.remove(x): x not in list")
end

local function seq_index(l, args)
    for i = 1, #l do
        if eq(l[i], args[1]) then
            return i - 1
        end
    end
    throw("ValueError", repr(args[1]) .. " is not in list")
end

local function seq_count(l, args)
    local n = 0
    for i = 1, #l do
        if eq(l[i], args[1]) then
            n = n + 1
        end
    end
    return n
end

list_methods.index = seq_index
list_methods.count = seq_count
tuple_methods.index = seq_index
tuple_methods.count = seq_count

list_methods.reverse = function(l)
    local n = #l
    for i = 1, n // 2 do
        l[i], l[n - i + 1] = l[n - i + 1], l[i]
    end
    return None
end

list_methods.sort = function(l, args, kw)
    local m = kwargs_map(kw)
    local items = {}
    for i = 1, #l do
        items[i] = l[i]
    end
    sort_array(items, m.key ~= None and m.key or nil, m.reverse and truth(m.reverse))
    for i = 1, #items do
        l[i] = items[i]
    end
    return None
end

list_methods.copy = function(l)
    local out = {}
    for i = 1, #l do
        out[i] = l[i]
    end
    return new_list(out)
end

list_methods.clear = function(l)
    for i = #l, 1, -1 do
        l[i] = nil
    end
    return None
end

dict_methods.get = function(d, args)
    local v = dict_get(d, args[1])
    if v == nil then
        return args[2] or None
    end
    return v
end

dict_methods.keys = function(d)
    local out = {}
    for i, k in ipairs(d.keys) do
        out[i] = k
    end
    return new_list(out)
end

dict_methods.values = function(d)
    local out = {}
    for i, v in ipairs(d.vals) do
        out[i] = v
    end
    return new_list(out)
end

dict_methods.items = function(d)
    local out = {}
    for i, k in ipairs(d.keys) do
        out[i] = new_tuple({k, d.vals[i]})
    end
    return new_list(out)
end

dict_methods.update = function(d, args, kw)
    local other = args[1]
    if other ~= nil then
        if kind(other) == "dict" then
            for i, k in ipairs(other.keys) do
                dict_set(d, k, other.vals[i])
            end
        else
            for item in iterate(other) do
                local pair = to_array(item)
                dict_set(d, pair[1], pair[2])
            end
        end
    end
    if kw then
        for _, pair in ipairs(kw) do
            dict_set(d, pair[1], pair[2])
        end
    end
    return None
end

dict_methods.pop = function(d, args)
    local v = dict_get(d, args[1])
    if v == nil then
        if args[2] ~= nil then
            return args[2]
        end
        throw("KeyError", args[1])
    end
    dict_del(d, args[1])
    return v
end

dict_methods.setdefault = function(d, args)
    local v = dict_get(d, args[1])
    if v == nil then
        v = args[2] or None
        dict_set(d, args[1], v)
    end
    return v
end

dict_methods.copy = function(d)
    local out = new_dict()
    for i, k in ipairs(d.keys) do
        dict_set(out, k, d.vals[i])
    end
    return out
end

dict_methods.clear = function(d)
    d.keys, d.vals, d.index = {}, {}, {}
    return None
end

set_methods.add = function(s, args)
    dict_set(s.d, args[1], true)
    return None
end

set_methods.discard = function(s, args)
    dict_del(s.d, args[1])
    return None
end

set_methods.remove = function(s, args)
    if not dict_del(s.d, args[1]) then
        throw("KeyError", args[1])
    end
    return None
end

set_methods.update = function(s, args)
    for _, a in ipairs(args) do
        for v in iterate(a) do
            dict_set(s.d, v, true)
        end
    end
    return None
end

set_methods.union = function(s, args)
    local out = new_set(s.d.keys)
    set_methods.update(out, args)
    return out
end

int_methods.bit_length = function(v)
    v = as_number(v)
    if bigint.isbig(v) then
        return bigint.bitlength(v)
    end
    if v < 0 then
        v = -v
    end
    local n = 0
    while v > 0 do
        n = n + 1
        v = v >> 1
    end
    return n
end

local function length(v)
    local k = kind(v)
    if k == "str" then
        return str_len(v)
    elseif k == "list" or k == "tuple" then
        return #v
    elseif k == "dict" then
        return #v.keys
    elseif k == "set" then
        return #v.d.keys
    elseif k == "range" then
        return range_len(v)
    elseif k == "object" then
        local f = getattr(v, "__len__", true)
        if f then
            return call(f, {})
        end
    end
    throw("TypeError", "object of type '" .. class_of(v).name .. "' has no len()")
end

function len(v)
    return length(v)
end

local function min_max(args, kw, want_less)
    local m = kwargs_map(kw)
    local items
    if #args == 1 then
        items = to_array(args[1])
    else
        items = args
    end
    if #items == 0 then
        if m.default ~= nil then
            return m.default
        end
        throw("ValueError", (want_less and "min" or "max") .. "() arg is an empty sequence")
    end
    local key = m.key ~= None and m.key or nil
    local best, best_key = items[1], key and call(key, {items[1]}) or items[1]
    for i = 2, #items do
        local k = key and call(key, {items[i]}) or items[i]
        if want_less and order(k, best_key, "<") or (not want_less and order(k, best_key, ">")) then
            best, best_key = items[i], k
        end
    end
    return best
end

local function make_range(args)
    local start, stop, step = 0, nil, 1
    for i = 1, #args do
        local v = as_number(args[i])
        if not is_int(v) or bigint.isbig(v) then
            throw("TypeError", "range() arguments must be integers")
        end
        args[i] = v
    end
    if #args == 1 then
        stop = args[1]
    elseif #args >= 2 then
        start, stop = args[1], args[2]
        step = args[3] or 1
    end
    if step == 0 then
        throw("ValueError", "range() arg 3 must not be zero")
    end
    return {__t = "range", start = start, stop = stop, step = step}
end

local function exc_init(args, kw)
    local self = args[1]
    local rest = {}
    for i = 2, #args do
        rest[i - 1] = args[i]
    end
    dict_set(self.dict, "args", new_tuple(rest))
    return None
end

builtin_class("object", {}, nil, nil)
classes.object.mro = {classes.object}

builtin_class("str", nil, function(args, kw)
    if #args == 0 then
        return ""
    end
    return str(args[1])
end, str_methods)
builtin_class("int", nil, function(args, kw)
    if #args == 0 then
        return 0
    end
    local base = arg(args, kw, 2, "base", nil)
    if base ~= nil then
        return to_int(check_str(args[1], "int() argument"), as_number(base))
    end
    return to_int(args[1])
end, int_methods)
builtin_class("bool", {classes.int}, function(args)
    return args[1] ~= nil and truth(args[1]) or false
end, int_methods)
builtin_class("float", nil, function(args)
    if #args == 0 then
        return 0.0
    end
    return to_float_value(args[1])
end, {})
builtin_class("list", nil, function(args)
    if #args == 0 then
        return new_list()
    end
    return new_list(to_array(args[1]))
end, list_methods)
builtin_class("tuple", nil, function(args)
    if #args == 0 then
        return new_tuple()
    end
    return new_tuple(to_array(args[1]))
end, tuple_methods)
builtin_class("dict", nil, function(args, kw)
    local d = new_dict()
    dict_methods.update(d, args, kw)
    return d
end, dict_methods)
builtin_class("set", nil, function(args)
    if #args == 0 then
        return new_set()
    end
    return new_set(to_array(args[1]))
end, set_methods)
builtin_class("frozenset", nil, function(args)
    if #args == 0 then
        return new_set()
    end
    return new_set(to_array(args[1]))
end, set_methods)
builtin_class("range", nil, function(args)
    return make_range(args)
end, {})
builtin_class("type", nil, function(args)
    if #args == 1 then
        return class_of(args[1])
    end
    local bases = to_array(args[2])
    local attrs = {}
    local d = args[3]
    for i, k in ipairs(d.keys) do
        attrs[k] = d.vals[i]
    end
    if #bases == 0 then
        bases = {classes.object}
    end
    return new_class(args[1], bases, attrs)
end, {})
builtin_class("function", nil, nil, {})
builtin_class("builtin_function_or_method", nil, nil, {})
builtin_class("method", nil, nil, {})
builtin_class("module", nil, nil, {})
builtin_class("NoneType", nil, nil, {})
builtin_class("slice", nil, function(args)
    if #args == 1 then
        return new_slice(None, args[1], None)
    end
    return new_slice(args[1], args[2], args[3] or None)
end, {})
builtin_class("iterator", nil, nil, {})
builtin_class("native", nil, nil, {})
builtin_class("ellipsis", nil, nil, {})
builtin_class("staticmethod", nil, function(args)
    return {__t = "staticmethod", func = args[1]}
end, {})
builtin_class("classmethod", nil, function(args)
    return {__t = "classmethod", func = args[1]}
end, {})
builtin_class("property", nil, function(args)
    return {__t = "property", fget = args[1]}
end, {})
classes.none = classes.NoneType
classes.builtin = classes.builtin_function_or_method
classes.func = classes["function"]

local function exception_class(name, base)
    local cls = new_class(name, {base}, {})
    classes[name] = cls
    builtins[name] = cls
    return cls
end

local base_exc = new_class("BaseException", {classes.object}, {__init__ = exc_init})
classes.BaseException = base_exc
builtins.BaseException = base_exc
exception_class("Exception", base_exc)
exception_class("StopIteration", classes.Exception)
exception_class("ArithmeticError", classes.Exception)
exception_class("ZeroDivisionError", classes.ArithmeticError)
exception_class("OverflowError", classes.ArithmeticError)
exception_class("AssertionError", classes.Exception)
exception_class("AttributeError", classes.Exception)
exception_class("LookupError", classes.Exception)
exception_class("IndexError", classes.LookupError)
exception_class("KeyError", classes.LookupError)
exception_class("NameError", classes.Exception)
exception_class("UnboundLocalError", classes.NameError)
exception_class("RuntimeError", classes.Exception)
exception_class("NotImplementedError", classes.RuntimeError)
exception_class("RecursionError", classes.RuntimeError)
exception_class("TypeError", classes.Exception)
exception_class("ValueError", classes.Exception)
exception_class("ImportError", classes.Exception)
exception_class("ModuleNotFoundError", classes.ImportError)
exception_class("SyntaxError", classes.Exception)
exception_class("IndentationError", classes.SyntaxError)
exception_class("OSError", classes.Exception)
exception_class("IOError", classes.OSError)
exception_class("EnvironmentError", classes.OSError)
exception_class("FileNotFoundError", classes.OSError)
exception_class("UnicodeError", classes.ValueError)

builtins.None = None
builtins.True = true
builtins.False = false
builtins.NotImplemented = NotImplemented
builtins.Ellipsis = {__t = "ellipsis"}

builtins.len = function(args)
    return length(args[1])
end

builtins.repr = function(args)
    return repr(args[1])
end

builtins.ascii = builtins.repr

builtins.abs = function(args)
    local v = as_number(args[1])
    if kind(v) == "object" then
        return call(getattr(v, "__abs__"), {})
    end
    if bigint.isbig(v) then
        return v.sign < 0 and bigint.neg(v) or v
    end
    if v == math.mininteger then
        return bigint.neg(v)
    end
    return v < 0 and -v or v
end

builtins.min = function(args, kw)
    return min_max(args, kw, true)
end

builtins.max = function(args, kw)
    return min_max(args, kw, false)
end

builtins.sum = function(args, kw)
    local total = arg(args, kw, 2, "start", 0)
    for v in iterate(args[1]) do
        total = binop("+", total, v)
    end
    return total
end

builtins.any = function(args)
    for v in iterate(args[1]) do
        if truth(v) then
            return true
        end
    end
    return false
end

builtins.all = function(args)
    for v in iterate(args[1]) do
        if not truth(v) then
            return false
        end
    end
    return true
end

builtins.enumerate = function(args, kw)
    local nextf = iterate(args[1])
    local i = as_number(arg(args, kw, 2, "start", 0))
    return new_iterator(function()
        local v = nextf()
        if v == nil then
            return nil
        end
        local r = new_tuple({i, v})
        i = i + 1
        return r
    end)
end

builtins.zip = function(args)
    local its = {}
    for i, a in ipairs(args) do
        its[i] = iterate(a)
    end
    return new_iterator(function()
        if #its == 0 then
            return nil
        end
        local row = {}
        for i, f in ipairs(its) do
            local v = f()
            if v == nil then
                return nil
            end
            row[i] = v
        end
        return new_tuple(row)
    end)
end

builtins.map = function(args)
    local f = args[1]
    local its = {}
    for i = 2, #args do
        its[#its + 1] = iterate(args[i])
    end
    return new_iterator(function()
        local row = {}
        for i, it in ipairs(its) do
            local v = it()
            if v == nil then
                return nil
            end
            row[i] = v
        end
        return call(f, row)
    end)
end

builtins.filter = function(args)
    local f = args[1]
    local it = iterate(args[2])
    return new_iterator(function()
        while true do
            local v = it()
            if v == nil then
                return nil
            end
            if (f == None and truth(v)) or (f ~= None and truth(call(f, {v}))) then
                return v
            end
        end
    end)
end

builtins.reversed = function(args)
    local items = to_array(args[1])
    local i = #items + 1
    return new_iterator(function()
        i = i - 1
        return items[i]
    end)
end

builtins.sorted = function(args, kw)
    local m = kwargs_map(kw)
    local items = to_array(args[1])
    sort_array(items, m.key ~= None and m.key or nil, m.reverse and truth(m.reverse))
    return new_list(items)
end

builtins.iter = function(args)
    local v = args[1]
    if kind(v) == "iterator" then
        return v
    end
    return new_iterator(iterate(v))
end

builtins.next = function(args)
    local it = args[1]
    local v
    if kind(it) == "iterator" then
        v = it.nextf()
    else
        local nxt = getattr(it, "__next__", true)
        if nxt then
            return call(nxt, {})
        end
        throw("TypeError", "'" .. class_of(it).name .. "' object is not an iterator")
    end
    if v == nil then
        if args[2] ~= nil then
            return args[2]
        end
        throw("StopIteration")
    end
    return v
end

builtins.chr = function(args)
    return utf8.char(as_number(args[1]))
end

builtins.ord = function(args)
    local s = check_str(args[1], "ord() argument")
    local code = utf8.codepoint(s, 1)
    return code
end

builtins.hex = function(args)
    local neg, body = format_int_base(to_int(args[1]), 16)
    return (neg and "-" or "") .. "0x" .. body
end

builtins.oct = function(args)
    local neg, body = format_int_base(to_int(args[1]), 8)
    return (neg and "-" or "") .. "0o" .. body
end

builtins.bin = function(args)
    local neg, body = format_int_base(to_int(args[1]), 2)
    return (neg and "-" or "") .. "0b" .. body
end

builtins.isinstance = function(args)
    local v, cls = args[1], args[2]
    if kind(cls) == "tuple" then
        for i = 1, #cls do
            if isinstance_class(v, cls[i]) then
                return true
            end
        end
        return false
    end
    return isinstance_class(v, cls)
end

builtins.issubclass = function(args)
    local c, base = args[1], args[2]
    if kind(base) == "tuple" then
        for i = 1, #base do
            if is_subclass(c, base[i]) then
                return true
            end
        end
        return false
    end
    return is_subclass(c, base)
end

builtins.hasattr = function(args)
    return getattr(args[1], args[2], true) ~= nil
end

builtins.getattr = function(args)
    local v = getattr(args[1], check_str(args[2], "attribute name"), args[3] ~= nil)
    if v == nil then
        return args[3]
    end
    return v
end

builtins.setattr = function(args)
    setattr(args[1], args[2], args[3])
    return None
end

builtins.delattr = function(args)
    delattr(args[1], args[2])
    return None
end

builtins.callable = function(args)
    return callable(args[1])
end

builtins.divmod = function(args)
    return new_tuple({binop("//", args[1], args[2]), binop("%", args[1], args[2])})
end

builtins.pow = function(args)
    local r = binop("**", args[1], args[2])
    if args[3] ~= nil then
        r = binop("%", r, args[3])
    end
    return r
end

builtins.round = function(args)
    local v = as_number(args[1])
    local nd = args[2]
    if is_int(v) and (nd == nil or nd == None) then
        return v
    end
    v = to_float(v)
    if nd == nil or nd == None then
        local f = math.floor(v)
        local diff = v - f
        local r
        if diff > 0.5 then
            r = f + 1
        elseif diff < 0.5 then
            r = f
        else
            r = (f % 2 == 0) and f or f + 1
        end
        return to_int(r)
    end
    local s = string.format("%." .. as_number(nd) .. "f", v)
    return tonumber(s) + 0.0
end

builtins.format = function(args)
    return format_value(args[1], args[2] or "")
end

builtins.hash = function(args)
    return hashkey(args[1])
end

builtins.id = function(args)
    return tonumber((tostring(args[1]):match("0x(%x+)") or "0"), 16) or 0
end

builtins.print = function(args, kw)
    local m = kwargs_map(kw)
    local parts = {}
    for i, v in ipairs(args) do
        parts[i] = str(v)
    end
    local sep = m.sep ~= nil and m.sep ~= None and m.sep or " "
    local finish = m["end"] ~= nil and m["end"] ~= None and m["end"] or "\n"
    io.write(table.concat(parts, sep) .. finish)
    return None
end

builtins.vars = function(args)
    local v = args[1]
    if kind(v) == "object" then
        return v.dict
    end
    throw("TypeError", "vars() argument must have __dict__ attribute")
end

local function random_module()
    local random_class = new_class("Random", {classes.object}, {})
    local function state_of(self)
        if not self.native then
            throw("TypeError", "not a Random instance")
        end
        return self.native
    end
    local function seed_key(seed)
        if seed == nil or seed == None then
            seed = os.time()
        end
        local k = kind(seed)
        if k == "str" then
            local h = 0
            for i = 1, #seed do
                h = (h * 31 + seed:byte(i)) & 0x7fffffff
            end
            seed = h
        elseif k == "bool" then
            seed = seed and 1 or 0
        elseif k == "float" then
            seed = to_int(seed)
        end
        if bigint.isbig(seed) then
            seed = seed.sign < 0 and bigint.neg(seed) or seed
            local words = {}
            while not (seed == 0) do
                local q, r = bigint.divmod(seed, 1 << 32)
                words[#words + 1] = r
                seed = q
            end
            return words
        end
        if seed < 0 then
            seed = -seed
        end
        local words = {}
        repeat
            words[#words + 1] = seed & 0xffffffff
            seed = seed >> 32
        until seed == 0
        return words
    end
    random_class.attrs.__init__ = function(args)
        local self = args[1]
        self.native = mtwister.new(seed_key(args[2]))
        return None
    end
    random_class.attrs.seed = function(args)
        args[1].native = mtwister.new(seed_key(args[2]))
        return None
    end
    random_class.attrs.random = function(args)
        return mtwister.random(state_of(args[1]))
    end
    random_class.attrs.getrandbits = function(args)
        return mtwister.getrandbits(state_of(args[1]), as_number(args[2]))
    end
    local function randrange(self, start, stop, step)
        local state = state_of(self)
        if stop == nil or stop == None then
            if start <= 0 then
                throw("ValueError", "empty range for randrange()")
            end
            return mtwister.randbelow(state, start)
        end
        step = step or 1
        local width = stop - start
        if step == 1 then
            if width <= 0 then
                throw("ValueError", "empty range for randrange()")
            end
            return start + mtwister.randbelow(state, width)
        end
        local n
        if step > 0 then
            n = (width + step - 1) // step
        else
            n = (width + step + 1) // step
        end
        if n <= 0 then
            throw("ValueError", "empty range for randrange()")
        end
        return start + step * mtwister.randbelow(state, n)
    end
    random_class.attrs.randrange = function(args)
        return randrange(args[1], as_number(args[2]), args[3] and as_number(args[3]), args[4] and as_number(args[4]))
    end
    random_class.attrs.randint = function(args)
        return randrange(args[1], as_number(args[2]), as_number(args[3]) + 1)
    end
    random_class.attrs.choice = function(args)
        local seq = args[2]
        local n = length(seq)
        if n == 0 then
            throw("IndexError", "Cannot choose from an empty sequence")
        end
        return getitem(seq, mtwister.randbelow(state_of(args[1]), n))
    end
    random_class.attrs.shuffle = function(args)
        local x = args[2]
        local state = state_of(args[1])
        for i = #x, 2, -1 do
            local j = mtwister.randbelow(state, i) + 1
            x[i], x[j] = x[j], x[i]
        end
        return None
    end
    local globals = {Random = random_class, __name__ = "random"}
    local default
    local function shared()
        if not default then
            default = instantiate(random_class, {}, nil)
        end
        return default
    end
    for _, name in ipairs({"random", "getrandbits", "randrange", "randint", "choice", "shuffle", "seed"}) do
        globals[name] = function(args, kw)
            local nargs = {shared()}
            for i = 1, #args do
                nargs[i + 1] = args[i]
            end
            return random_class.attrs[name](nargs, kw)
        end
    end
    return {__t = "module", name = "random", globals = globals}
end

local function itertools_module()
    local globals = {__name__ = "itertools"}
    local chain = new_class("chain", {classes.object}, {})
    chain.construct = function(args)
        local i = 1
        local current
        return new_iterator(function()
            while true do
                if current then
                    local v = current()
                    if v ~= nil then
                        return v
                    end
                    current = nil
                end
                local nxt = args[i]
                if nxt == nil then
                    return nil
                end
                i = i + 1
                current = iterate(nxt)
            end
        end)
    end
    chain.attrs.from_iterable = {__t = "staticmethod", func = function(args)
        return chain.construct(to_array(args[1]))
    end}
    globals.chain = chain
    globals.product = function(args, kw)
        local m = kwargs_map(kw)
        local pools = {}
        local repeat_count = m["repeat"] and as_number(m["repeat"]) or 1
        for _ = 1, repeat_count do
            for _, a in ipairs(args) do
                pools[#pools + 1] = to_array(a)
            end
        end
        local result = {{}}
        for _, pool in ipairs(pools) do
            local nxt = {}
            for _, prefix in ipairs(result) do
                for _, item in ipairs(pool) do
                    local row = {}
                    for i, v in ipairs(prefix) do
                        row[i] = v
                    end
                    row[#row + 1] = item
                    nxt[#nxt + 1] = row
                end
            end
            result = nxt
        end
        local i = 0
        return new_iterator(function()
            i = i + 1
            if result[i] then
                return new_tuple(result[i])
            end
        end)
    end
    globals.count = function(args)
        local cur = args[1] or 0
        local step = args[2] or 1
        return new_iterator(function()
            local r = cur
            cur = binop("+", cur, step)
            return r
        end)
    end
    globals["repeat"] = function(args)
        local v, times = args[1], args[2] and as_number(args[2])
        local n = 0
        return new_iterator(function()
            if times and n >= times then
                return nil
            end
            n = n + 1
            return v
        end)
    end
    globals.islice = function(args)
        local it = iterate(args[1])
        local start, stop, step = 0, nil, 1
        if #args == 2 then
            stop = args[2] ~= None and as_number(args[2]) or nil
        else
            start = args[2] ~= None and as_number(args[2]) or 0
            stop = args[3] ~= None and args[3] and as_number(args[3]) or nil
            step = args[4] and args[4] ~= None and as_number(args[4]) or 1
        end
        local index = 0
        local next_index = start
        return new_iterator(function()
            while true do
                if stop and next_index >= stop then
                    return nil
                end
                local v = it()
                if v == nil then
                    return nil
                end
                local current = index
                index = index + 1
                if current == next_index then
                    next_index = next_index + step
                    return v
                end
            end
        end)
    end
    return {__t = "module", name = "itertools", globals = globals}
end

local function math_module()
    local globals = {__name__ = "math", pi = math.pi, e = math.exp(1), inf = math.huge, nan = 0.0 / 0.0}
    globals.floor = function(args)
        return to_int(math.floor(to_float(args[1])))
    end
    globals.ceil = function(args)
        return to_int(math.ceil(to_float(args[1])))
    end
    globals.sqrt = function(args)
        return math.sqrt(to_float(args[1]))
    end
    globals.log = function(args)
        if args[2] then
            return math.log(to_float(args[1])) / math.log(to_float(args[2]))
        end
        return math.log(to_float(args[1]))
    end
    globals.log2 = function(args)
        return math.log(to_float(args[1]), 2)
    end
    globals.log10 = function(args)
        return math.log(to_float(args[1]), 10)
    end
    globals.pow = function(args)
        return to_float(args[1]) ^ to_float(args[2])
    end
    globals.fabs = function(args)
        return math.abs(to_float(args[1]))
    end
    globals.isnan = function(args)
        local f = to_float(args[1])
        return f ~= f
    end
    globals.isinf = function(args)
        local f = to_float(args[1])
        return f == math.huge or f == -math.huge
    end
    return {__t = "module", name = "math", globals = globals}
end

function native_modules()
    return {random = random_module, itertools = itertools_module, math = math_module}
end

function new_native(name, attrs)
    return {__t = "native", name = name, attrs = attrs}
end

function exception_message(e)
    local inst = caught_exception(e)
    if inst then
        local message = str(inst)
        if message == "" then
            return inst.cls.name
        end
        return inst.cls.name .. ": " .. message
    end
    if type(e) == "table" and e.message then
        return e.message
    end
    return tostring(e)
end

function exception_matches(inst, cls)
    if kind(cls) == "tuple" then
        for i = 1, #cls do
            if isinstance_class(inst, cls[i]) then
                return true
            end
        end
        return false
    end
    return isinstance_class(inst, cls)
end

function is_none(v)
    return v == None
end
