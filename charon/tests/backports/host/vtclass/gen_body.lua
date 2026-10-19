local V = import("vtlib", {rootdir = os.scriptdir()})

local ORDER_LIST = {"VTFrameProcessor", "VTFrameProcessorFrame", "VTFrameProcessorOpticalFlow",
    "VTFrameRateConversionConfiguration", "VTFrameRateConversionParameters",
    "VTLowLatencyFrameInterpolationConfiguration", "VTLowLatencyFrameInterpolationParameters",
    "VTLowLatencySuperResolutionScalerConfiguration", "VTLowLatencySuperResolutionScalerParameters",
    "VTMotionBlurConfiguration", "VTMotionBlurParameters", "VTOpticalFlowConfiguration",
    "VTOpticalFlowParameters", "VTSuperResolutionScalerConfiguration",
    "VTSuperResolutionScalerParameters", "VTTemporalNoiseFilterConfiguration",
    "VTTemporalNoiseFilterParameters"}

local STRUCTS_SET = {CMTime = true, CMVideoDimensions = true}

local SCALAR_CANONICAL_SET = {}
for _, t in ipairs({"long", "long long", "unsigned int", "unsigned char", "unsigned long", "int",
                    "bool", "float", "double", "short", "char", "long double"}) do
    SCALAR_CANONICAL_SET[t] = true
end

local CLASS_BRANCH_MAP = {[12] = "struct", [5] = "CF", [1] = "scalar", [2] = "scalar", [3] = "scalar",
    [4] = "scalar", [6] = "scalar", [7] = "scalar", [8] = "scalar"}

local BRANCH_TABLE_MAP = {}

local PROTO_NAMES_LIST = {"VTFrameProcessorConfiguration", "VTFrameProcessorParameters"}

local PRIVATE_KEYS_SET = {sourcePixelFormat = true}

local DECLARED_KEYS_LIST = {
    {class = "VTSuperResolutionScalerConfiguration", keyword = "usePrecomputedFlow",
     property = "precomputedFlow", getter = "usesPrecomputedFlow",
     line = "VTFrameProcessor_SuperResolutionScaler.h:130"},
    {class = "VTFrameRateConversionParameters", keyword = "destinationFrame",
     property = "destinationFrames", getter = nil,
     line = "VTFrameProcessor_FrameRateConversion.h:198"},
}

local MACRO_TYPEDEFS_MAP = {
    ["NSDictionary<NSString *, id> *"] = "CharonVTFrameAttributes",
    ["NSArray<NSString *, id> *"] = "CharonVTFrameAttributeList",
}

local CASTS = {BOOL = "BOOL", NSInteger = "NSInteger", float = "float"}

function odict_new()
    return {keys = {}, map = {}, has = {}}
end

function odict_set(od, k, v)
    if not od.has[k] then
        od.has[k] = true
        od.keys[#od.keys + 1] = k
    end
    od.map[k] = v
end

function odict_get(od, k)
    return od.map[k]
end

function odict_has(od, k)
    return od.has[k] == true
end

function odict_keys(od)
    local out = {}
    for i, k in ipairs(od.keys) do out[i] = k end
    return out
end

function odict_items(od)
    local out = {}
    for i, k in ipairs(od.keys) do out[i] = {k, od.map[k]} end
    return out
end

function odict_copy(od)
    local c = odict_new()
    for _, k in ipairs(od.keys) do odict_set(c, k, od.map[k]) end
    return c
end

function odict_setdefault(od, k, v)
    if not od.has[k] then odict_set(od, k, v) end
    return od.map[k]
end

local function at(s, i)
    return s:sub(i, i)
end

local function byte_of(c)
    if c == "" then return -1 end
    return string.byte(c)
end

local function is_ws(c)
    return c == " " or c == "\t" or c == "\n" or c == "\r" or c == "\f" or c == "\v"
end

local function is_upper_us(c)
    local b = byte_of(c)
    return (b >= 65 and b <= 90) or b == 95
end

local function is_upper_digit_us(c)
    local b = byte_of(c)
    return (b >= 65 and b <= 90) or b == 95 or (b >= 48 and b <= 57)
end

local function is_alpha_us(c)
    local b = byte_of(c)
    return (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or b == 95
end

local function is_word(c)
    local b = byte_of(c)
    return (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or (b >= 48 and b <= 57) or b == 95
end

local function skip_ws(s, i)
    while is_ws(s:sub(i, i)) do i = i + 1 end
    return i
end

local function py_strip(s)
    local i, j = 1, #s
    while i <= j and is_ws(s:sub(i, i)) do i = i + 1 end
    while j >= i and is_ws(s:sub(j, j)) do j = j - 1 end
    return s:sub(i, j)
end

local function py_split_ws(s)
    local out, i, n = {}, 1, #s
    while true do
        i = skip_ws(s, i)
        if i > n then break end
        local j = i
        while j <= n and not is_ws(s:sub(j, j)) do j = j + 1 end
        out[#out + 1] = s:sub(i, j - 1)
        i = j
    end
    return out
end

local function split_plain(s, sep)
    local out, start = {}, 1
    while true do
        local p = s:find(sep, start, true)
        if not p then
            out[#out + 1] = s:sub(start)
            break
        end
        out[#out + 1] = s:sub(start, p - 1)
        start = p + #sep
    end
    return out
end

local function rstrip_char(s, c)
    local j = #s
    while j >= 1 and s:sub(j, j) == c do j = j - 1 end
    return s:sub(1, j)
end

local function replace_plain(s, old, new)
    local out, start = {}, 1
    while true do
        local p = s:find(old, start, true)
        if not p then
            out[#out + 1] = s:sub(start)
            break
        end
        out[#out + 1] = s:sub(start, p - 1)
        out[#out + 1] = new
        start = p + #old
    end
    return table.concat(out)
end

local function py_repr(s)
    local quote = "'"
    if s:find("'", 1, true) and not s:find('"', 1, true) then quote = '"' end
    local out = {quote}
    for i = 1, #s do
        local c = s:sub(i, i)
        local b = string.byte(c)
        if c == "\\" then
            out[#out + 1] = "\\\\"
        elseif c == quote then
            out[#out + 1] = "\\" .. c
        elseif c == "\n" then
            out[#out + 1] = "\\n"
        elseif c == "\r" then
            out[#out + 1] = "\\r"
        elseif c == "\t" then
            out[#out + 1] = "\\t"
        elseif b < 32 or b == 127 then
            out[#out + 1] = string.format("\\x%02x", b)
        else
            out[#out + 1] = c
        end
    end
    out[#out + 1] = quote
    return table.concat(out)
end

local function py_str(v)
    if v == nil then return "None" end
    if v == true then return "True" end
    if v == false then return "False" end
    return tostring(v)
end

local function path_join(a, b)
    if a:sub(-1) == "/" then return a .. b end
    return a .. "/" .. b
end

local function makedirs(path)
    if os.isdir(path) then return end
    local parent = path:match("^(.*)/[^/]+$")
    if parent and parent ~= "" and not os.isdir(parent) then makedirs(parent) end
    os.mkdir(path)
end

local JSON_NULL = {}

local function is_odict(v)
    return type(v) == "table" and v.keys ~= nil and v.map ~= nil and v.has ~= nil
end

local function py_truthy(v)
    if v == nil or v == false or v == JSON_NULL or v == "" or v == 0 then return false end
    if type(v) == "table" then
        if is_odict(v) then return #v.keys > 0 end
        return #v > 0
    end
    return true
end

local function paren_group_end(s, k)
    if at(s, k) ~= "(" then return nil end
    local m = k + 1
    while true do
        local c = at(s, m)
        if c == "" then return nil end
        if c == ")" then return m + 1 end
        if c == "(" then
            local q = m + 1
            while at(s, q) ~= "(" and at(s, q) ~= ")" and at(s, q) ~= "" do q = q + 1 end
            if at(s, q) ~= ")" then return nil end
            m = q + 1
        else
            m = m + 1
        end
    end
end

local SWIFT_LITERALS = {"NS_REFINED_FOR_SWIFT", "NS_SWIFT_NAME", "NS_SWIFT_UNAVAILABLE",
                        "NS_SWIFT_SENDABLE", "API_DEPRECATED_WITH_REPLACEMENT"}

local function token_end(s, j)
    if s:sub(j, j + 3) == "API_" then
        local k = j + 4
        while is_upper_us(at(s, k)) do k = k + 1 end
        if k > j + 4 then return k end
    end
    for _, lit in ipairs(SWIFT_LITERALS) do
        if s:sub(j, j + #lit - 1) == lit then return j + #lit end
    end
    return nil
end

local function strip_once(s)
    for i = 1, #s do
        local j = skip_ws(s, i)
        local e = token_end(s, j)
        if e then
            local k = skip_ws(s, e)
            local g = paren_group_end(s, k)
            return i, g or k
        end
    end
    return nil
end

function ORDER()
    return ORDER_LIST
end

function STRUCTS()
    return STRUCTS_SET
end

function SCALAR_CANONICAL()
    return SCALAR_CANONICAL_SET
end

function CLASS_BRANCH()
    return CLASS_BRANCH_MAP
end

function BRANCH_TABLE()
    return BRANCH_TABLE_MAP
end

function PROTO_NAMES()
    return PROTO_NAMES_LIST
end

function PRIVATE_KEYS()
    return PRIVATE_KEYS_SET
end

function DECLARED_KEYS()
    return DECLARED_KEYS_LIST
end

function MACRO_TYPEDEFS()
    return MACRO_TYPEDEFS_MAP
end

function declared_key(class_name, keyword)
    for _, rec in ipairs(DECLARED_KEYS_LIST) do
        if rec.class == class_name and rec.keyword == keyword then return rec end
    end
    return nil
end

local json_value

local function json_skip(s, i)
    while true do
        local c = at(s, i)
        if c == " " or c == "\t" or c == "\r" or c == "\n" then
            i = i + 1
        else
            return i
        end
    end
end

local function json_string(s, i)
    local parts = {}
    local j = i + 1
    while true do
        local c = at(s, j)
        if c == "" then raise("json: unterminated string") end
        if c == '"' then return table.concat(parts), j + 1 end
        if c == "\\" then
            local e = at(s, j + 1)
            if e == '"' or e == "\\" or e == "/" then
                parts[#parts + 1] = e
                j = j + 2
            elseif e == "b" then
                parts[#parts + 1] = "\8"
                j = j + 2
            elseif e == "f" then
                parts[#parts + 1] = "\12"
                j = j + 2
            elseif e == "n" then
                parts[#parts + 1] = "\n"
                j = j + 2
            elseif e == "r" then
                parts[#parts + 1] = "\r"
                j = j + 2
            elseif e == "t" then
                parts[#parts + 1] = "\t"
                j = j + 2
            elseif e == "u" then
                local hex = s:sub(j + 2, j + 5)
                if not hex:match("^%x%x%x%x$") then raise("json: bad \\u escape") end
                local cp = tonumber(hex, 16)
                j = j + 6
                if cp >= 0xD800 and cp <= 0xDBFF and s:sub(j, j + 1) == "\\u" then
                    local hex2 = s:sub(j + 2, j + 5)
                    local lo = hex2:match("^%x%x%x%x$") and tonumber(hex2, 16)
                    if lo and lo >= 0xDC00 and lo <= 0xDFFF then
                        cp = 0x10000 + (cp - 0xD800) * 1024 + (lo - 0xDC00)
                        j = j + 6
                    end
                end
                parts[#parts + 1] = utf8.char(cp)
            else
                raise("json: bad escape")
            end
        else
            if string.byte(c) < 32 then raise("json: control character in string") end
            parts[#parts + 1] = c
            j = j + 1
        end
    end
end

local function json_number(s, i)
    local tok = s:match("^-?%d+", i)
    if not tok then raise("json: expecting a value at " .. i) end
    local j = i + #tok
    local frac = s:match("^%.%d+", j)
    if frac then j = j + #frac; tok = tok .. frac end
    local expo = s:match("^[eE][-+]?%d+", j)
    if expo then j = j + #expo; tok = tok .. expo end
    return tonumber(tok), j
end

json_value = function(s, i)
    local c = at(s, i)
    if c == "{" then
        local obj = odict_new()
        i = json_skip(s, i + 1)
        if at(s, i) == "}" then return obj, i + 1 end
        while true do
            if at(s, i) ~= '"' then raise("json: expecting property name") end
            local key
            key, i = json_string(s, i)
            i = json_skip(s, i)
            if at(s, i) ~= ":" then raise("json: expecting ':'") end
            i = json_skip(s, i + 1)
            local value
            value, i = json_value(s, i)
            odict_set(obj, key, value)
            i = json_skip(s, i)
            local d = at(s, i)
            if d == "}" then return obj, i + 1 end
            if d ~= "," then raise("json: expecting ',' or '}'") end
            i = json_skip(s, i + 1)
        end
    elseif c == "[" then
        local arr = {}
        i = json_skip(s, i + 1)
        if at(s, i) == "]" then return arr, i + 1 end
        while true do
            local value
            value, i = json_value(s, i)
            arr[#arr + 1] = value
            i = json_skip(s, i)
            local d = at(s, i)
            if d == "]" then return arr, i + 1 end
            if d ~= "," then raise("json: expecting ',' or ']'") end
            i = json_skip(s, i + 1)
        end
    elseif c == '"' then
        return json_string(s, i)
    elseif s:sub(i, i + 3) == "true" then
        return true, i + 4
    elseif s:sub(i, i + 4) == "false" then
        return false, i + 5
    elseif s:sub(i, i + 3) == "null" then
        return JSON_NULL, i + 4
    end
    return json_number(s, i)
end

function probe_types(sdk, types, workdir)
    if not os.isdir(workdir) then makedirs(workdir) end
    local source = path_join(workdir, "type-probe.m")
    local lines = {"#import <VideoToolbox/VideoToolbox.h>", "#import <CoreMedia/CoreMedia.h>",
                   "#import <CoreVideo/CoreVideo.h>", "#import <CoreFoundation/CoreFoundation.h>", ""}
    for index, type_name in ipairs(types) do
        lines[#lines + 1] = "typedef " .. type_name .. " charon_probe_" .. (index - 1) .. ";"
    end
    V.write_file(source, table.concat(lines, "\n") .. "\n")

    local err_path = path_join(workdir, "type-probe.err")
    local args = {"-c", 'err="$1"; shift; xcrun "$@" 2>"$err"', "sh", err_path,
                  "clang", "-fsyntax-only", "-isysroot", sdk,
                  "-F", path_join(sdk, "System/Library/Frameworks"),
                  "-isystem", path_join(sdk, "usr/include"),
                  "-Xclang", "-ast-dump=json", "-Xclang", "-ast-dump-filter=charon_probe_", source}
    local stdout = nil
    try {
        function()
            stdout = os.iorunv("sh", args)
        end,
        catch {
            function(err)
                local stderr = ""
                if os.isfile(err_path) then stderr = V.read_file(err_path) end
                if os.isfile(err_path) then os.rm(err_path) end
                raise("the type probe did not compile:\n" .. stderr:sub(1, 2000))
            end
        }
    }
    if os.isfile(err_path) then os.rm(err_path) end

    local prefix = "charon_probe_"
    local found = {}
    local function visit(node)
        if is_odict(node) then
            local name = node.map.name
            if node.map.kind == "TypedefDecl" and type(name) == "string" and name:sub(1, #prefix) == prefix then
                local declared = node.map.type
                if not py_truthy(declared) then declared = nil end
                local canonical = nil
                if declared and is_odict(declared) then
                    local desugared = declared.map.desugaredQualType
                    if py_truthy(desugared) then
                        canonical = desugared
                    else
                        canonical = declared.map.qualType
                    end
                end
                if canonical == JSON_NULL then canonical = nil end
                found[name] = canonical
            end
            for _, k in ipairs(node.keys) do visit(node.map[k]) end
        elseif type(node) == "table" then
            for _, v in ipairs(node) do visit(v) end
        end
    end
    local index = 1
    while true do
        index = json_skip(stdout, index)
        if index > #stdout then break end
        local document
        document, index = json_value(stdout, index)
        visit(document)
    end

    local result = {}
    for name, canonical in pairs(found) do
        local digits = name:sub(#prefix + 1)
        if digits:match("^%d+$") then
            local t = types[tonumber(digits) + 1]
            if t == nil then raise("IndexError: list index out of range") end
            result[t] = canonical
        end
    end
    return result
end

function branch_of(class_number, objc_pointer)
    if objc_pointer or class_number == -1 then
        return "object"
    end
    return CLASS_BRANCH_MAP[class_number]
end

function load_branch_table(path)
    if path == nil then
        path = path_join(os.scriptdir(), "type-branches.tsv")
    end
    if not os.exists(path) then
        raise("the type probe has not been run: " .. path .. " is missing")
    end
    local table_out = {}
    for _, line in ipairs(V.read_lines(path)) do
        if py_strip(line) ~= "" then
            local fields = split_plain(line, "\t")
            if #fields == 3 then
                local digits = py_strip(fields[2])
                if not digits:match("^[+-]?%d+$") then
                    raise("invalid literal for int() with base 10: " .. py_repr(fields[2]))
                end
                table_out[fields[1]] = {tonumber(digits), fields[3] == "objc"}
            end
        end
    end
    return table_out
end

function store_branch(type_name)
    if V.count_entries(BRANCH_TABLE_MAP) == 0 then
        for k, v in pairs(load_branch_table()) do BRANCH_TABLE_MAP[k] = v end
    end
    local bare_parts = {}
    local i, n = 1, #type_name
    local function boundary_after(e)
        return not is_word(at(type_name, e))
    end
    while i <= n do
        local j = skip_ws(type_name, i)
        local matched_end = nil
        for _, lit in ipairs({"_Nullable", "_Nonnull", "_null_unspecified", "__nonnull"}) do
            if type_name:sub(j, j + #lit - 1) == lit and boundary_after(j + #lit) then
                matched_end = j + #lit
                break
            end
        end
        if matched_end then
            i = matched_end
        else
            bare_parts[#bare_parts + 1] = at(type_name, i)
            i = i + 1
        end
    end
    local bare = py_strip(table.concat(bare_parts))
    if BRANCH_TABLE_MAP[bare] == nil and BRANCH_TABLE_MAP[bare .. " *"] ~= nil then
        bare = bare .. " *"
    end
    if BRANCH_TABLE_MAP[bare] == nil then
        raise(bare .. ": the type probe has no row for it - run the probe before generating")
    end
    local row = BRANCH_TABLE_MAP[bare]
    local branch = branch_of(row[1], row[2])
    if branch == nil then
        raise(string.format("%s: the compiler classified it as %d, which is a class this toolchain has not "
            .. "shown - a NEW branch, not a default", bare, row[1]))
    end
    return branch
end

function strip(decl)
    while true do
        local a, b = strip_once(decl)
        if not a then break end
        decl = decl:sub(1, a - 1) .. decl:sub(b)
    end
    return py_strip(rstrip_char(table.concat(py_split_ws(decl), " "), ","))
end

local function split_declarator(s)
    local n = #s
    if not is_word(at(s, n)) then return nil end
    local name_start = n
    while name_start > 1 and is_word(at(s, name_start - 1)) do name_start = name_start - 1 end
    for p = 0, name_start - 1 do
        local seg = s:sub(p + 1, name_start - 1)
        local i = 1
        while is_ws(at(seg, i)) do i = i + 1 end
        local star = false
        if at(seg, i) == "*" then
            star = true
            i = i + 1
        end
        while is_ws(at(seg, i)) do i = i + 1 end
        if i > #seg then
            return s:sub(1, p), star, s:sub(name_start, n)
        end
    end
    return nil
end

local function getter_eq(attrs)
    local pos = 1
    while true do
        local p = attrs:find("getter=", pos, true)
        if not p then return nil end
        local w = p + 7
        local e = w
        while is_word(at(attrs, e)) do e = e + 1 end
        if e > w then return attrs:sub(w, e - 1) end
        pos = p + 1
    end
end

local function getter_ws(attrs)
    local pos = 1
    while true do
        local p = attrs:find("getter", pos, true)
        if not p then return nil end
        local q = skip_ws(attrs, p + 6)
        if at(attrs, q) == "=" then
            local w = skip_ws(attrs, q + 1)
            local e = w
            while is_word(at(attrs, e)) do e = e + 1 end
            if e > w then return attrs:sub(w, e - 1) end
        end
        pos = p + 1
    end
end

function props_of(text)
    local out = odict_new()
    local pos = 1
    while true do
        local p = text:find("@property", pos, true)
        if not p then break end
        local attrs, decl, after = nil, nil, nil
        local k = skip_ws(text, p + 9)
        if at(text, k) == "(" then
            local close = text:find(")", k + 1, true)
            if close then
                local semi = text:find(";", close + 1, true)
                if semi then
                    attrs = text:sub(k + 1, close - 1)
                    decl = text:sub(close + 1, semi - 1)
                    after = semi + 1
                end
            end
        end
        if after then
            local typ, star, name = split_declarator(strip(decl))
            if name then
                odict_set(out, name, {
                    type = py_strip(typ),
                    obj = star,
                    class = attrs:find("class", 1, true) ~= nil,
                    getter = getter_eq(attrs),
                    unavailable_ios = decl:find("API_UNAVAILABLE(ios)", 1, true) ~= nil,
                })
            end
            pos = after
        else
            pos = p + 1
        end
    end
    return out
end

local function next_interface(text, classname, from)
    local pos = from
    while true do
        local s = text:find("@interface", pos, true)
        if not s then return nil end
        local k = skip_ws(text, s + 10)
        if k > s + 10 and text:sub(k, k + #classname - 1) == classname
                and not is_word(at(text, k + #classname)) then
            return s, k + #classname
        end
        pos = s + 1
    end
end

local function protocol_body(text, name)
    local pos = 1
    while true do
        local s = text:find("@protocol", pos, true)
        if not s then return nil end
        local k = skip_ws(text, s + 9)
        if k > s + 9 and text:sub(k, k + #name - 1) == name then
            local q = skip_ws(text, k + #name)
            if at(text, q) == "<" then
                local gt = text:find(">", q + 1, true)
                if gt then q = gt + 1 end
            end
            local e = text:find("@end", q, true)
            if e then return text:sub(q, e - 1) end
        end
        pos = s + 1
    end
end

local function interface_head(text, q)
    q = skip_ws(text, q)
    if at(text, q) == "(" then
        local close = text:find(")", q + 1, true)
        if close then q = close + 1 end
    end
    q = skip_ws(text, q)
    if at(text, q) == ":" then
        local r = skip_ws(text, q + 1)
        local w = r
        while is_word(at(text, w)) do w = w + 1 end
        if w > r then
            local r2 = skip_ws(text, w)
            if at(text, r2) == "<" then
                local gt = text:find(">", r2 + 1, true)
                if gt then return text:sub(r2 + 1, gt - 1), gt + 1 end
            end
            return nil, r2
        end
    end
    return nil, q
end

local function class_blocks(text, classname)
    local out = {}
    local pos = 1
    while true do
        local s, after = next_interface(text, classname, pos)
        if not s then break end
        local angle, bodystart = interface_head(text, after)
        local e = text:find("@end", bodystart, true)
        if e then
            out[#out + 1] = {angle = angle, body = text:sub(bodystart, e - 1)}
            pos = e + 4
        else
            pos = s + 1
        end
    end
    return out
end

function parse(alltext)
    local protocols = {}
    for _, p in ipairs(PROTO_NAMES_LIST) do
        local pbody = protocol_body(alltext, p)
        if pbody == nil then
            raise("FAIL: the SDK headers declare no @protocol " .. p .. ", so there is nothing to compare the "
                .. "port's " .. p .. " against; the name is gone from VideoToolbox and the ledger needs a row "
                .. "saying so")
        end
        protocols[p] = props_of(pbody)
    end
    local classes = {}
    for _, c in ipairs(ORDER_LIST) do
        local proto_set, proto_names = {}, {}
        local own = odict_new()
        for _, blk in ipairs(class_blocks(alltext, c)) do
            if blk.angle and blk.angle ~= "" then
                for _, x in ipairs(split_plain(blk.angle, ",")) do
                    local sx = py_strip(x)
                    if sx ~= "" and not proto_set[sx] then
                        proto_set[sx] = true
                        proto_names[#proto_names + 1] = sx
                    end
                end
            end
            local props = props_of(blk.body)
            for _, k in ipairs(props.keys) do odict_set(own, k, props.map[k]) end
        end
        V.sort_bytes(proto_names)
        local pnames = {}
        for _, pr in ipairs(proto_names) do
            local pm = protocols[pr]
            if pm then
                for _, k in ipairs(pm.keys) do pnames[k] = pm.map[k] end
            end
        end
        local unavailable = {}
        for _, k in ipairs(own.keys) do
            if own.map[k].unavailable_ios then unavailable[#unavailable + 1] = k end
        end
        V.sort_bytes(unavailable)
        local unavailable_set = {}
        for _, k in ipairs(unavailable) do unavailable_set[k] = true end
        local own_kept_unavailable = odict_new()
        for _, k in ipairs(own.keys) do
            if not unavailable_set[k] then odict_set(own_kept_unavailable, k, own.map[k]) end
        end
        own = own_kept_unavailable
        local kept = odict_new()
        for _, k in ipairs(own.keys) do
            local pn = pnames[k]
            if pn == nil or pn.class ~= own.map[k].class then odict_set(kept, k, own.map[k]) end
        end
        local redeclared = {}
        for _, k in ipairs(kept.keys) do
            if pnames[k] ~= nil then redeclared[#redeclared + 1] = k end
        end
        V.sort_bytes(redeclared)
        classes[c] = {sup = "NSObject", protocols = proto_names, own = kept, redeclared = redeclared,
                      unavailable_ios = unavailable}
    end
    return protocols, classes
end

local function method_decls(body)
    local out = {}
    local pos = 1
    while pos <= #body do
        local i = body:find("[%-%+]", pos)
        if not i then break end
        local k = skip_ws(body, i + 1)
        local ok = false
        if at(body, k) == "(" then
            local close = body:find(")", k + 1, true)
            if close then
                local semi = body:find(";", close + 1, true)
                if semi then
                    out[#out + 1] = {body:sub(k + 1, close - 1), body:sub(close + 1, semi - 1)}
                    pos = semi + 1
                    ok = true
                end
            end
        end
        if not ok then pos = i + 1 end
    end
    return out
end

local function parts_of(s)
    local out = {}
    local i = 1
    while i <= #s do
        local matched = false
        if is_word(at(s, i)) then
            local t = i
            while is_word(at(s, t)) do t = t + 1 end
            if at(s, t) == ":" then
                local k = skip_ws(s, t + 1)
                if at(s, k) == "(" then
                    local close = s:find(")", k + 1, true)
                    if close then
                        local r = skip_ws(s, close + 1)
                        if is_word(at(s, r)) then
                            local u = r
                            while is_word(at(s, u)) do u = u + 1 end
                            out[#out + 1] = {s:sub(i, t - 1), s:sub(k + 1, close - 1), s:sub(r, u - 1)}
                            i = u
                            matched = true
                        end
                    end
                end
            end
        end
        if not matched then i = i + 1 end
    end
    return out
end

function initialisers(alltext, classname)
    local out = {}
    local pos = 1
    while true do
        local s, after = next_interface(alltext, classname, pos)
        if not s then break end
        local e = alltext:find("@end", after, true)
        if not e then break end
        local block_text = alltext:sub(after, e - 1)
        pos = e + 4
        for _, decl_rec in ipairs(method_decls(block_text)) do
            local returns, decl = decl_rec[1], decl_rec[2]
            if not decl:find("NS_UNAVAILABLE", 1, true) then
                local cleaned = strip(decl)
                local parts = parts_of(cleaned)
                if #parts > 0 and parts[1][1]:sub(1, 4) == "init" then
                    local pieces, arguments = {}, {}
                    for _, pt in ipairs(parts) do
                        pieces[#pieces + 1] = pt[1] .. ":"
                        arguments[#arguments + 1] = {pt[3], py_strip(pt[2]), pt[1]}
                    end
                    out[#out + 1] = {table.concat(pieces), arguments, py_strip(returns)}
                end
            end
        end
    end
    return out
end

function init_signature(selector, arguments, returns)
    if #arguments == 0 then
        return "- (nullable instancetype)" .. selector .. ";"
    end
    local first_word = arguments[1][3]
    local lines = {string.format("- (nullable instancetype)%s:(%s)%s", first_word, arguments[1][2], arguments[1][1])}
    local pad = string.rep(" ", #"- (nullable instancetype)" - 1)
    for index = 2, #arguments do
        local name, type_name, piece = arguments[index][1], arguments[index][2], arguments[index][3]
        lines[#lines + 1] = string.format("%s%s:(%s)%s", pad, piece, type_name, name)
    end
    return table.concat(lines, "\n") .. ";"
end

function is_private_key(class_name, keyword)
    return PRIVATE_KEYS_SET[keyword] == true
end

function ivars_for(arguments, properties, selector, class_name)
    local out = {}
    for _, arg in ipairs(arguments) do
        local keyword, type_name = arg[1], arg[2]
        if is_private_key(class_name, keyword) or store_branch(type_name) == "CF" then
            out[#out + 1] = {"_" .. store_key(keyword, properties, selector, class_name), type_name}
        end
    end
    return out
end

local function readback_matches(block_text)
    local out = {}
    local pos = 1
    while true do
        local p = block_text:find("@property", pos, true)
        if not p then break end
        local attrs, name, after = nil, nil, nil
        local k = skip_ws(block_text, p + 9)
        if at(block_text, k) == "(" then
            local close = block_text:find(")", k + 1, true)
            if close then
                attrs = block_text:sub(k + 1, close - 1)
                local a = skip_ws(block_text, close + 1)
                if is_alpha_us(at(block_text, a)) then
                    local e = a + 1
                    while true do
                        local rest_name, rest_end = nil, nil
                        local q = skip_ws(block_text, e)
                        if is_word(at(block_text, q)) then
                            local t = q
                            while is_word(at(block_text, t)) do t = t + 1 end
                            for len = t - q, 1, -1 do
                                local pe = q + len
                                local r = skip_ws(block_text, pe)
                                if is_upper_us(at(block_text, r)) then
                                    local m2 = r + 1
                                    while is_upper_digit_us(at(block_text, m2)) do m2 = m2 + 1 end
                                    local sp = skip_ws(block_text, m2)
                                    if at(block_text, sp) == "(" then
                                        local c = block_text:find(")", sp + 1, true)
                                        if c and at(block_text, c + 1) == ";" then
                                            rest_name, rest_end = block_text:sub(q, pe - 1), c + 2
                                            break
                                        end
                                    elseif at(block_text, sp) == ";" then
                                        rest_name, rest_end = block_text:sub(q, pe - 1), sp + 1
                                        break
                                    end
                                end
                                if at(block_text, r) == ";" then
                                    rest_name, rest_end = block_text:sub(q, pe - 1), r + 1
                                    break
                                end
                            end
                        end
                        if rest_name then
                            name, after = rest_name, rest_end
                            break
                        end
                        if is_word(at(block_text, e)) or is_ws(at(block_text, e))
                                or at(block_text, e) == "*" or at(block_text, e) == "<"
                                or at(block_text, e) == ">" or at(block_text, e) == "," then
                            e = e + 1
                        else
                            break
                        end
                    end
                end
            end
        end
        if after then
            out[#out + 1] = {attrs = attrs, name = name}
            pos = after
        else
            pos = p + 1
        end
    end
    return out
end

function readback_property(sdk_text, class_name, argument)
    local s, after = next_interface(sdk_text, class_name, 1)
    if not s then return nil end
    local e = sdk_text:find("@end", after, true)
    if not e then return nil end
    local props = readback_matches(sdk_text:sub(s, e + 3))
    for _, pr in ipairs(props) do
        if pr.name == argument then return pr.name end
    end
    for _, pr in ipairs(props) do
        if getter_ws(pr.attrs) == argument then return pr.name end
    end
    return nil
end

function store_key(keyword, properties, where, class_name)
    local declared = declared_key(class_name, keyword)
    if declared then
        if not odict_has(properties, declared.property) then
            raise(string.format("%s: DECLARED_KEYS names the property %s and this class does not declare it, so "
                .. "the table is about this SDK and nothing else", py_str(class_name), py_repr(declared.property)))
        end
        return declared.property
    end
    if odict_has(properties, keyword) or is_private_key(class_name, keyword) then
        return keyword
    end
    for _, name in ipairs(properties.keys) do
        if properties.map[name].getter == keyword then return name end
    end
    raise(string.format("%s: the argument %s is neither a property of %s, nor the getter of one, nor in "
        .. "DECLARED_KEYS for it - no accessor would read it back, and that is an error rather than a guess",
        py_str(where), py_repr(keyword), py_str(class_name)))
end

function init_body(selector, arguments, properties, class_name)
    local head = init_signature(selector, arguments, "instancetype")
    head = replace_plain(head, "(nullable instancetype)", "(instancetype)")
    head = rstrip_char(head, ";")
    local lines = {head, "{"}
    if #arguments > 0 then lines[#lines + 1] = "    self = [super init];" end
    for _, arg in ipairs(arguments) do
        local keyword, type_name = arg[1], arg[2]
        local key = store_key(keyword, properties, selector, class_name)
        local branch = store_branch(type_name)
        if is_private_key(class_name, keyword) or branch == "CF" then
            lines[#lines + 1] = string.format("    self->_%s = (%s)%s;", key, type_name, keyword)
            if branch == "CF" and not is_private_key(class_name, keyword) then
                lines[#lines + 1] = string.format("    if (self->_%s)", key)
                lines[#lines + 1] = string.format("        CFRetain(self->_%s);", key)
            end
        elseif branch == "struct" then
            lines[#lines + 1] = string.format("    { %s boxed = %s;", type_name, keyword)
            lines[#lines + 1] = string.format("      CharonValueSet(self, [NSValue valueWithBytes:&boxed objCType:@encode(%s)], @\"%s\"); }",
                type_name, key)
        elseif branch == "object" then
            lines[#lines + 1] = string.format("    CharonValueSet(self, %s, @\"%s\");", keyword, key)
        else
            lines[#lines + 1] = string.format("    CharonValueSet(self, @(%s), @\"%s\");", keyword, key)
        end
    end
    lines[#lines + 1] = "    return self;"
    lines[#lines + 1] = "}"
    lines[#lines + 1] = ""
    return table.concat(lines, "\n")
end

local function macro_type(type_name)
    local alias = MACRO_TYPEDEFS_MAP[type_name]
    if alias then return alias .. " *" end
    return type_name
end

function macro_typedefs(type_names)
    local lines = {"",
        "// A file-local spelling for the types the property macros cannot take. Each of these carries a",
        "// comma, and the preprocessor counts arguments rather than template parameters, so the macro",
        "// would be handed three arguments for one type. The declaration in CharonVideoToolbox.h keeps",
        "// the SDK's own spelling: this is the same type, named once so the macro has one argument."}
    local emitted = {}
    local emitted_set = {}
    for _, name in ipairs(type_names) do
        local alias = MACRO_TYPEDEFS_MAP[name]
        if alias and not emitted_set[alias] then
            emitted_set[alias] = true
            emitted[#emitted + 1] = alias
            lines[#lines + 1] = string.format("typedef %s %s;", py_strip(name:sub(1, -3)), alias)
        end
    end
    lines[#lines + 1] = ""
    return lines
end

function prop_line(n, p)
    local typ = p.type .. (p.obj and " *" or "")
    local parts = {}
    if p.class then parts[#parts + 1] = "class" end
    parts[#parts + 1] = "nonatomic"
    parts[#parts + 1] = "readonly"
    parts[#parts + 1] = p.obj and "strong" or "assign"
    if p.getter and p.getter ~= n then parts[#parts + 1] = "getter=" .. p.getter end
    return string.format("@property (%s) %s %s;", table.concat(parts, ", "), typ, n)
end

local function struct_accessor(sig, typ, store, key)
    return string.format("%s\n{\n    %s value = {0};\n    NSValue *boxed = %s[%s];\n    if (boxed)\n"
        .. "        [boxed getValue:&value];\n    return value;\n}\n", sig, typ, store, key)
end

local function cf_pixel_accessor(sig, store, key)
    return string.format("%s\n{\n    CVPixelBufferRef value = NULL;\n    NSValue *boxed = %s[%s];\n"
        .. "    if (boxed)\n    {\n        [boxed getValue:&value];\n"
        .. "        if (value)\n            CFRetain(value);\n    }\n    return value;\n}\n", sig, store, key)
end

local function cast_of(typ)
    return CASTS[typ] or typ
end

function body(n, p)
    local store = p.class and "CharonValueStoreOfClass([self class])" or "CharonValueStore(self)"
    local ret = p.type .. (p.obj and " *" or "")
    local sig = (p.class and "+ " or "- ") .. string.format("(%s)%s", ret, p.getter or n)
    local key = '@"' .. n .. '"'
    if (not p.class) and store_branch(p.type) == "CF" then
        return string.format("%s\n{\n    if (self->_%s)\n        CFRetain(self->_%s);\n    return self->_%s;\n}\n",
            sig, n, n, n)
    end
    if p.class then
        if p.obj then
            return string.format("%s\n{\n    return (%s)%s[%s];\n}\n", sig, ret, store, key)
        end
        if STRUCTS_SET[p.type] then return struct_accessor(sig, p.type, store, key) end
        if p.type == "CVPixelBufferRef" then return cf_pixel_accessor(sig, store, key) end
        return string.format("%s\n{\n    return (%s)[%s[%s] longLongValue];\n}\n", sig, cast_of(p.type), store, key)
    end
    if p.getter and p.getter ~= n then
        if p.obj then
            return string.format("%s\n{\n    return (%s)%s[%s];\n}\n", sig, ret, store, key)
        end
        return string.format("%s\n{\n    return (%s)[%s[%s] longLongValue];\n}\n", sig, cast_of(p.type), store, key)
    end
    if p.obj then
        return string.format("CHARON_VALUE_PROPERTY(%s, %s)\n", macro_type(ret), n)
    end
    if (not STRUCTS_SET[p.type]) and p.type ~= "CVPixelBufferRef" then
        local macro = (p.type == "float") and "CHARON_DOUBLE_PROPERTY" or "CHARON_SCALAR_PROPERTY"
        return string.format("%s(%s, %s)\n", macro, p.type, n)
    end
    if STRUCTS_SET[p.type] then return struct_accessor(sig, p.type, store, key) end
    if p.type == "CVPixelBufferRef" then return cf_pixel_accessor(sig, store, key) end
    return string.format("%s\n{\n    return (%s)[%s[%s] longLongValue];\n}\n", sig, cast_of(p.type), store, key)
end

function emit(classes, outdir)
    makedirs(outdir)
    for _, c in ipairs(V.sorted_keys(classes)) do
        local v = classes[c]
        local protos = ""
        if #v.protocols > 0 then protos = " <" .. table.concat(v.protocols, ", ") .. ">" end
        local h = {string.format("@interface %s : %s%s\n", c, v.sup, protos), ""}
        for _, pair in ipairs(odict_items(v.own)) do
            h[#h + 1] = prop_line(pair[1], pair[2])
        end
        h[#h + 1] = "@end\n"
        local m = {string.format("@implementation %s\n", c)}
        for _, pair in ipairs(odict_items(v.own)) do
            m[#m + 1] = body(pair[1], pair[2])
        end
        m[#m + 1] = "@end\n"
        V.write_file(path_join(outdir, c .. ".h"), table.concat(h, "\n"))
        V.write_file(path_join(outdir, c .. ".m"), table.concat(m, "\n"))
    end
end
