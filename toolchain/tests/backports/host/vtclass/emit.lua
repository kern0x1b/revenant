local V = import("vtlib", {rootdir = os.scriptdir()})
local G = import("gen_body", {rootdir = os.scriptdir()})
local R = import("emit_registry", {rootdir = os.scriptdir()})
local fail = V.fail

local function dirname(path)
    return path:match("^(.*)/[^/]*$") or "."
end

local function absolute_dir(path)
    local base = path
    if base:sub(1, 1) ~= "/" then
        base = os.curdir() .. "/" .. base
    end
    local parts = {}
    for component in base:gmatch("[^/]+") do
        if component == ".." then
            parts[#parts] = nil
        elseif component ~= "." then
            parts[#parts + 1] = component
        end
    end
    return "/" .. table.concat(parts, "/")
end

local function join(a, b)
    if a:sub(-1) == "/" then
        return a .. b
    end
    return a .. "/" .. b
end

local function split_lines(text)
    local out, start = {}, 1
    while true do
        local i, j = text:find("\n", start, true)
        if not i then
            out[#out + 1] = text:sub(start)
            return out
        end
        out[#out + 1] = text:sub(start, i - 1)
        start = j + 1
    end
end

local function rstrip(text)
    return (text:gsub("[ \t\r\n\f\v]+$", ""))
end

local function count_in(text, needle)
    local n, start = 0, 1
    while true do
        local i, j = text:find(needle, start, true)
        if not i then
            return n
        end
        n = n + 1
        start = j + 1
    end
end

local function replace_all(text, old, new)
    local out, start = {}, 1
    while true do
        local i, j = text:find(old, start, true)
        if not i then
            out[#out + 1] = text:sub(start)
            return table.concat(out)
        end
        out[#out + 1] = text:sub(start, i - 1)
        out[#out + 1] = new
        start = j + 1
    end
end

local function replace_first(text, old, new)
    local i, j = text:find(old, 1, true)
    if not i then
        return text
    end
    return text:sub(1, i - 1) .. new .. text:sub(j + 1)
end

local function py_repr(value)
    if value == nil then
        return "None"
    end
    return "'" .. value .. "'"
end

local SPACE = {[" "] = true, ["\t"] = true, ["\n"] = true, ["\r"] = true, ["\f"] = true, ["\v"] = true}

local function is_word_char(c)
    return c ~= "" and c:match("^[%w_]$") ~= nil
end

local function keyword_at(s, k, keyword)
    if s:sub(k, k + #keyword - 1) ~= keyword then
        return nil
    end
    local after = k + #keyword
    if is_word_char(s:sub(after, after)) then
        return nil
    end
    return after
end

local function strip_nullability(s)
    local out, i, n = {}, 1, #s
    while i <= n do
        local k = i
        while k <= n and SPACE[s:sub(k, k)] do
            k = k + 1
        end
        local stop = nil
        if s:sub(k, k) == "_" then
            for _, keyword in ipairs({"Nullable", "Nonnull", "null_unspecified"}) do
                stop = keyword_at(s, k + 1, keyword)
                if stop then
                    break
                end
            end
        end
        if stop == nil and s:sub(k, k + 1) == "__" then
            stop = keyword_at(s, k, "__nonnull")
        end
        if stop then
            i = stop
        else
            out[#out + 1] = s:sub(i, i)
            i = i + 1
        end
    end
    return table.concat(out)
end

local ROUND_TRIP_VALUES = {NSInteger = "1920", BOOL = "1", float = "2", OSType = "1"}

local function value_for(type_name)
    local bare = strip_nullability(type_name)
    if bare:sub(-1) == "*" or bare == "id" or bare == "CVPixelBufferRef" then
        return "NULL"
    end
    if bare == "CMTime" then
        return "{0, 1, 0, 0, 0}"
    end
    if bare == "CMVideoDimensions" then
        return "{{1920, 1080}}"
    end
    return ROUND_TRIP_VALUES[bare] or "1"
end

local function is_scalar_candidate(prop)
    return not prop.obj and prop.type ~= "CMTime" and prop.type ~= "CMVideoDimensions"
        and prop.type ~= "CVPixelBufferRef"
end

local SHORT_ESCAPES = {['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n",
                       ["\r"] = "\\r", ["\t"] = "\\t"}

local function json_string(text)
    local out = {'"'}
    for _, code in utf8.codes(text) do
        local ch = utf8.char(code)
        if SHORT_ESCAPES[ch] then
            out[#out + 1] = SHORT_ESCAPES[ch]
        elseif code >= 0x20 and code <= 0x7e then
            out[#out + 1] = ch
        elseif code < 0x10000 then
            out[#out + 1] = string.format("\\u%04x", code)
        else
            local v = code - 0x10000
            out[#out + 1] = string.format("\\u%04x\\u%04x", 0xd800 + (v >> 10), 0xdc00 + (v & 0x3ff))
        end
    end
    out[#out + 1] = '"'
    return table.concat(out)
end

local function json_list(items, depth)
    if #items == 0 then
        return "[]"
    end
    local pad, inner = string.rep(" ", depth), string.rep(" ", depth + 1)
    local parts = {}
    for i, item in ipairs(items) do
        parts[i] = inner .. json_string(item)
    end
    return "[\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "]"
end

local SUMMARY_KEYS = {"classProps", "inherited", "own", "protocols", "unavailable_ios"}

local function json_summary(summary)
    local names = V.sorted_keys(summary)
    if #names == 0 then
        return "{}"
    end
    local entries = {}
    for _, cls in ipairs(names) do
        local record = summary[cls]
        local fields = {}
        for _, key in ipairs(SUMMARY_KEYS) do
            fields[#fields + 1] = "  " .. json_string(key) .. ": " .. json_list(record[key], 2)
        end
        entries[#entries + 1] = " " .. json_string(cls) .. ": {\n" .. table.concat(fields, ",\n") .. "\n }"
    end
    return "{\n" .. table.concat(entries, ",\n") .. "\n}"
end

local function ordered_items(od)
    local items = {}
    for i, pair in ipairs(G.odict_items(od)) do
        items[i] = {name = pair[1], value = pair[2]}
    end
    return items
end

local function known_items(entry, protocols)
    local items, seen = {}, {}
    for _, item in ipairs(ordered_items(entry.own)) do
        items[#items + 1] = item
        seen[item.name] = true
    end
    for _, proto in ipairs(entry.protocols) do
        for _, item in ipairs(ordered_items(protocols[proto])) do
            if not seen[item.name] then
                items[#items + 1] = item
                seen[item.name] = true
            end
        end
    end
    return items
end

local function known_odict(entry, protocols)
    local od = G.odict_new()
    for _, item in ipairs(ordered_items(entry.own)) do
        G.odict_set(od, item.name, item.value)
    end
    for _, proto in ipairs(entry.protocols) do
        for _, item in ipairs(ordered_items(protocols[proto])) do
            G.odict_setdefault(od, item.name, item.value)
        end
    end
    return od
end

local ROUND_TRIP_HEAD = {
    "#pragma once", "",
    "// GENERATED by emit.lua. One entry per designated initialiser the SDK declares: the class, the",
    "// selector, a TYPED call that constructs the object, and the scalar properties with the value",
    "// each must read back.",
    "//",
    "// The expectation is generated from the SAME argument list as the constructor, which is what",
    "// makes it a check: a value stored under the wrong key cannot report success.",
    "typedef struct { const char *property; long long value; } VTRoundTripValue;", "",
    "typedef struct {",
    "    const char *className;",
    "    const char *selector;",
    "    id (*construct)(Class, SEL);",
    "    const VTRoundTripValue *expected;",
    "    unsigned expectedCount;",
    "} VTRoundTripCase;", "",
}

local ROUND_TRIP_GUARD_ELSE = {
    "#else",
    "static id VTConstructNotBuilt(Class cls, SEL sel)",
    "{",
    "    (void)cls; (void)sel; return nil;",
    "}",
}

local MUTANT_SOURCE_OVERRIDE = {VTMotionBlurConfiguration = "VideoToolboxValue26.m"}

local STORE_LINE_PREFIX = "    RevenantValueSet(self, @("

local function read_headers(sdk)
    local directory = join(sdk, "System/Library/Frameworks/VideoToolbox.framework/Headers")
    local paths = {}
    for _, path in ipairs(os.files(join(directory, "*.h"))) do
        local base = path:match("([^/]+)$")
        if base:sub(1, 1) ~= "." then
            paths[#paths + 1] = path
        end
    end
    V.sort_bytes(paths)
    local texts, texts_by_path = {}, {}
    for _, path in ipairs(paths) do
        texts[#texts + 1] = V.read_text(path)
        texts_by_path[path] = texts[#texts]
    end
    return table.concat(texts, "\n"), texts_by_path
end

local function emit_classes(order, protocols, classes, text, out)
    local summary, absent = {}, {}
    for _, cls in ipairs(order) do
        local entry = classes[cls]
        local own_items = ordered_items(entry.own)
        local inherited = {}
        for _, proto in ipairs(entry.protocols) do
            local proto_props = protocols[proto]
            if proto_props == nil then
                raise("KeyError: " .. proto)
            end
            for _, item in ipairs(ordered_items(proto_props)) do
                if not G.odict_has(entry.own, item.name) then
                    inherited[#inherited + 1] = item
                end
            end
        end
        local known_properties = known_odict(entry, protocols)
        local conformances = ""
        if #entry.protocols > 0 then
            conformances = " <" .. table.concat(entry.protocols, ", ") .. ">"
        end

        local initialisers = G.initialisers(text, cls)
        local header = {"@interface " .. cls .. " : NSObject" .. conformances .. "\n", ""}
        for _, item in ipairs(inherited) do
            header[#header + 1] = G.prop_line(item.name, item.value)
        end
        if #inherited > 0 and #own_items > 0 then
            header[#header + 1] = ""
        end
        for _, item in ipairs(own_items) do
            header[#header + 1] = G.prop_line(item.name, item.value)
        end
        if #initialisers > 0 then
            header[#header + 1] = ""
            for _, init in ipairs(initialisers) do
                header[#header + 1] = G.init_signature(init[1], init[2], init[3])
            end
        end
        header[#header + 1] = "@end\n"

        local ivars, ivar_seen = {}, {}
        for _, init in ipairs(initialisers) do
            for _, ivar in ipairs(G.ivars_for(init[2], known_properties, init[1], cls)) do
                local key = ivar[1] .. "\0" .. ivar[2]
                if not ivar_seen[key] then
                    ivar_seen[key] = true
                    ivars[#ivars + 1] = ivar
                end
            end
        end
        local ivar_text = {}
        for _, ivar in ipairs(ivars) do
            ivar_text[#ivar_text + 1] = " " .. ivar[2] .. " " .. ivar[1] .. ";"
        end
        local value = {"@implementation " .. cls
            .. (#ivars > 0 and ("{" .. table.concat(ivar_text) .. "}") or "") .. "\n"}
        if #inherited > 0 then
            value[#value + 1] = "#pragma mark - The protocol's own properties, implemented for this class\n"
            for _, item in ipairs(inherited) do
                value[#value + 1] = G.body(item.name, item.value)
            end
            if #own_items > 0 then
                value[#value + 1] = "\n#pragma mark - This class's own properties\n"
            end
        end
        for _, item in ipairs(own_items) do
            value[#value + 1] = G.body(item.name, item.value)
        end
        if #initialisers > 0 then
            value[#value + 1] = "\n#pragma mark - The SDK's designated initialisers\n"
            for _, init in ipairs(initialisers) do
                value[#value + 1] = G.init_body(init[1], init[2], known_properties, cls)
            end
        end
        value[#value + 1] = "@end\n"

        V.write_file(join(out, cls .. ".h"), table.concat(header, "\n"))

        local all_props = {}
        for _, item in ipairs(own_items) do
            all_props[#all_props + 1] = item
        end
        for _, item in ipairs(inherited) do
            all_props[#all_props + 1] = item
        end
        local spelled = {}
        local uses_macro = false
        for _, item in ipairs(all_props) do
            local prop = item.value
            spelled[#spelled + 1] = prop.type .. (prop.obj and " *" or "")
            if not prop.class and not G.STRUCTS()[prop.type] and prop.type ~= "CVPixelBufferRef" then
                uses_macro = true
            end
        end
        if uses_macro then
            table.insert(value, 1, "")
            table.insert(value, 1, "REVENANT_VIDEO_TOOLBOX_VALUE_STORE(" .. cls .. ")")
        end
        local typedefs = G.macro_typedefs(spelled)
        local has_typedef = false
        for _, line in ipairs(typedefs) do
            if line:sub(1, 8) == "typedef " then
                has_typedef = true
            end
        end
        if has_typedef then
            local joined = {}
            for _, line in ipairs(typedefs) do
                joined[#joined + 1] = line
            end
            for _, line in ipairs(value) do
                joined[#joined + 1] = line
            end
            value = joined
        end
        V.write_file(join(out, cls .. ".m"), table.concat(value, "\n"))

        local own_names, inherited_names, class_props = {}, {}, {}
        for _, item in ipairs(own_items) do
            own_names[#own_names + 1] = item.name
        end
        for _, item in ipairs(inherited) do
            inherited_names[#inherited_names + 1] = item.name
        end
        for _, item in ipairs(all_props) do
            if item.value.class then
                class_props[#class_props + 1] = item.name
            end
        end
        local protocol_names = {}
        for _, proto in ipairs(entry.protocols) do
            protocol_names[#protocol_names + 1] = proto
        end
        local unavailable = {}
        for _, name in ipairs(entry.unavailable_ios) do
            unavailable[#unavailable + 1] = name
        end
        summary[cls] = {protocols = protocol_names, own = own_names, inherited = inherited_names,
                        classProps = class_props, unavailable_ios = unavailable}
        for _, name in ipairs(entry.unavailable_ios) do
            absent[#absent + 1] = cls .. "." .. name .. "\tproperty\tobjc\t26.0\tAPI_UNAVAILABLE(ios)"
        end
    end
    return summary, absent
end

local function emit_round_trip(order, protocols, classes, text)
    local constructors, rows, expected_arrays, count = {}, {}, {}, 0
    for _, cls in ipairs(order) do
        local entry = classes[cls]
        local known_properties = known_odict(entry, protocols)
        for _, init in ipairs(G.initialisers(text, cls)) do
            local selector, arguments = init[1], init[2]
            local spellings = {}
            for i, arg in ipairs(arguments) do
                spellings[i] = arg[2]
            end
            local cast = "id (*)(id, SEL"
            for _, t in ipairs(spellings) do
                cast = cast .. ", " .. t
            end
            cast = cast .. ")"
            local call = ""
            for i, arg in ipairs(arguments) do
                call = call .. ", (" .. spellings[i] .. ")" .. value_for(arg[2])
            end
            constructors[#constructors + 1] = "static id VTConstruct" .. count .. "(Class cls, SEL sel)"
            constructors[#constructors + 1] = "{"
            constructors[#constructors + 1] = "    return ((" .. cast .. ")objc_msgSend)((id)[cls alloc], sel"
                .. call .. ");"
            constructors[#constructors + 1] = "}"

            local expected, put = {}, {}
            for _, arg in ipairs(arguments) do
                local keyword, type_name = arg[1], arg[2]
                local key = G.store_key(keyword, known_properties, cls, cls)
                local read_back = G.readback_property(text, cls, keyword)
                local justified = G.is_private_key(cls, keyword) or G.declared_key(cls, keyword) ~= nil
                if read_back ~= key and not justified then
                    fail(string.format(
                        "%s %s: the store would write under %s and the header's own property for this "
                        .. "argument is %s, and the difference is justified by neither PRIVATE_KEYS nor "
                        .. "DECLARED_KEYS - a value written where nothing reads it",
                        cls, selector, py_repr(key), py_repr(read_back)))
                end
                if not G.is_private_key(cls, keyword) then
                    local bare = strip_nullability(type_name)
                    local skipped = bare:sub(-1) == "*" or bare == "id" or bare == "CVPixelBufferRef"
                        or bare == "CMTime" or bare == "CMVideoDimensions"
                    if not skipped then
                        put[key] = value_for(type_name)
                    end
                end
            end
            for _, item in ipairs(ordered_items(entry.own)) do
                local name, prop = item.name, item.value
                if not (prop.obj or put[name] == nil or prop.class) then
                    if not (prop.type == "CMTime" or prop.type == "CMVideoDimensions"
                            or prop.type == "CVPixelBufferRef") then
                        expected[#expected + 1] = string.format('    {"%s", %s},',
                            prop.getter or name, put[name])
                    end
                end
            end
            expected_arrays[#expected_arrays + 1] = "static const VTRoundTripValue vtExpected" .. count .. "[] = {"
            for _, line in ipairs(expected) do
                expected_arrays[#expected_arrays + 1] = line
            end
            expected_arrays[#expected_arrays + 1] = "};"
            rows[#rows + 1] = string.format('    {"%s", "%s", VTConstruct%d, vtExpected%d, %d},',
                cls, selector, count, count, #expected)
            count = count + 1
        end
    end
    local all = {}
    for _, line in ipairs(ROUND_TRIP_HEAD) do
        all[#all + 1] = line
    end
    for _, line in ipairs(expected_arrays) do
        all[#all + 1] = line
    end
    all[#all + 1] = "#ifdef REVENANT_HOST_DIFFERENTIAL"
    for _, line in ipairs(constructors) do
        all[#all + 1] = line
    end
    for _, line in ipairs(ROUND_TRIP_GUARD_ELSE) do
        all[#all + 1] = line
    end
    for n = 0, count - 1 do
        all[#all + 1] = "#define VTConstruct" .. n .. " VTConstructNotBuilt"
    end
    all[#all + 1] = "#endif"
    all[#all + 1] = ""
    all[#all + 1] = "static const VTRoundTripCase vtRoundTripCases[] = {"
    for _, line in ipairs(rows) do
        all[#all + 1] = line
    end
    all[#all + 1] = "};"
    all[#all + 1] = ""
    all[#all + 1] = "#define VT_ROUND_TRIP_CASES " .. count
    all[#all + 1] = ""
    return table.concat(all, "\n"), count
end

local function emit_mutants(order, protocols, classes, text, out)
    local rows = {}
    local declared = G.DECLARED_KEYS()
    for _, cls in ipairs(order) do
        local entry = classes[cls]
        local known = known_items(entry, protocols)
        local known_properties = known_odict(entry, protocols)
        local source = MUTANT_SOURCE_OVERRIDE[cls] or (cls .. ".m")
        local body = V.read_text(join(out, cls .. ".m"))

        local init_keys = {}
        for _, init in ipairs(G.initialisers(text, cls)) do
            for _, arg in ipairs(init[2]) do
                init_keys[G.store_key(arg[1], known_properties, cls, cls)] = true
            end
        end
        local scalars = {}
        for _, item in ipairs(known) do
            if is_scalar_candidate(item.value) and init_keys[item.name] then
                scalars[#scalars + 1] = item.name
            end
        end
        if scalars[2] ~= nil then
            local first, other = scalars[1], scalars[2]
            local line = 'RevenantValueSet(self, @(' .. first .. '), @"' .. first .. '");'
            if count_in(body, line) == 1 then
                rows[#rows + 1] = cls .. "\t" .. source .. "\t" .. line .. "\t"
                    .. replace_all(line, '@"' .. first .. '"', '@"' .. other .. '"')
            end
        end

        for _, line in ipairs(split_lines(body)) do
            if line:sub(1, #STORE_LINE_PREFIX) == STORE_LINE_PREFIX and rstrip(line):sub(-2) == ");" then
                if count_in(body, line) == 1 then
                    rows[#rows + 1] = cls .. "\t" .. source .. "\t" .. line .. "\t"
                    break
                end
            end
        end

        for _, dk in ipairs(declared) do
            if dk.class == cls then
                for _, init in ipairs(G.initialisers(text, cls)) do
                    for _, arg in ipairs(init[2]) do
                        if arg[1] == dk.keyword then
                            local key = G.store_key(arg[1], known_properties, init[1], cls)
                            if not (key == arg[1] or key ~= dk.property) then
                                local line = 'RevenantValueSet(self, @(' .. arg[1] .. '), @"' .. key .. '");'
                                if count_in(body, line) == 1 then
                                    rows[#rows + 1] = cls .. "\t" .. source .. "\t" .. line .. "\t"
                                        .. replace_all(line, '@"' .. key .. '"', '@"' .. arg[1] .. '"')
                                end
                            end
                        end
                    end
                end
            end
        end

        for _, dk in ipairs(declared) do
            if dk.class ~= cls then
                for _, init in ipairs(G.initialisers(text, cls)) do
                    local own_key = {}
                    for _, arg in ipairs(init[2]) do
                        own_key[arg[1]] = G.store_key(arg[1], known_properties, init[1], cls)
                    end
                    local other_keyword = dk.keyword
                    if own_key[other_keyword] ~= nil and own_key[other_keyword] ~= dk.property then
                        local line = 'RevenantValueSet(self, @(' .. other_keyword .. '), @"'
                            .. own_key[other_keyword] .. '");'
                        if count_in(body, line) == 1 then
                            rows[#rows + 1] = cls .. "\t" .. source .. "\t" .. line .. "\t"
                                .. replace_all(line, '@"' .. own_key[other_keyword] .. '"',
                                    '@"' .. dk.property .. '"')
                        end
                    end
                end
            end
        end

        for _, item in ipairs(ordered_items(entry.own)) do
            local name, prop = item.name, item.value
            if prop.class then
                local getter = prop.getter or name
                for _, sign in ipairs({"+ ", "- "}) do
                    local line = sign .. "(" .. prop.type .. (prop.obj and " *" or "") .. ")" .. getter
                    if count_in(body, line) == 1 then
                        local flipped = (sign == "+ ") and "- " or "+ "
                        rows[#rows + 1] = cls .. "\t" .. source .. "\t" .. line .. "\t"
                            .. replace_first(line, sign, flipped)
                        break
                    end
                end
                break
            end
        end
    end
    return rows
end

local function run(sdk_argument)
    local sdk = sdk_argument
    if sdk == nil then
        sdk = os.getenv("VT_SDK") or ""
    end
    if sdk == "" then
        fail("emit.lua: pass an iPhoneOS*.sdk or set VT_SDK")
    end

    local text, header_texts = read_headers(sdk)
    local protocols, classes = G.parse(text)
    local order = G.ORDER()

    local work = dirname(dirname(dirname(dirname(absolute_dir(os.scriptdir())))))
    local out = import("workspace", {rootdir = work .. "/modules", anonymous = true}).run("generated", "vt")

    local summary, absent = emit_classes(order, protocols, classes, text, out)

    local round_trip, count = emit_round_trip(order, protocols, classes, text)
    V.write_file(join(out, "roundtrip-cases.h"), round_trip)

    local mutant_rows = emit_mutants(order, protocols, classes, text, out)
    V.write_file(join(out, "mutants.tsv"), table.concat(mutant_rows, "\n") .. "\n")
    print(string.format("  %d mutants generated from the emitted accessors", #mutant_rows))
    local initialised = 0
    for _, cls in ipairs(order) do
        if #G.initialisers(text, cls) > 0 then
            initialised = initialised + 1
        end
    end
    print(string.format("  %d initialisers over %d classes in the round-trip's table, each with a typed call",
        count, initialised))

    V.write_file(join(out, "summary.json"), json_summary(summary))
    V.write_file(join(out, "unavailable.tsv"), table.concat(absent, "\n") .. "\n")

    local rows = R.build_rows(G, header_texts, protocols, classes, order)
    local registry_dir = work .. "/packages/a/apple-backports/registry/VideoToolbox"
    local facts_dir = out .. "/facts"
    local written = R.write(registry_dir, facts_dir, rows, order)
    for _, pair in ipairs(written) do
        print(string.format("  registry %s: %d rows", pair[1], pair[2]))
    end
    print(string.format("  registry rows: %d over %d class(es)", #rows, #order))
    print(string.format("emitted %d classes to %s", V.count_entries(summary), out))

    local accessors, class_props = 0, 0
    for _, cls in ipairs(V.sorted_keys(summary)) do
        local record = summary[cls]
        accessors = accessors + #record.own + #record.inherited
        class_props = class_props + #record.classProps
    end
    print(string.format(
        "  %d accessors, %d class properties, %d properties the SDK marks API_UNAVAILABLE(ios)",
        accessors, class_props, #absent))
end

function main(...)
    local args = {...}
    try {
        function()
            run(args[1])
        end,
        catch {
            function(err)
                fail(tostring(err))
            end
        }
    }
end
