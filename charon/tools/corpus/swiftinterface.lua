local byteorder = import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})

DEPRECATED_NO_VERSION = {100000}

local TYPE_KEYWORD = {struct = "struct", class = "class", actor = "class", enum = "enum", protocol = "protocol"}
local MODIFIERS = {}
for _, name in ipairs({"public", "open", "package", "internal", "private", "fileprivate", "final", "indirect", "static", "class",
                       "mutating", "nonmutating", "override", "convenience", "required", "dynamic", "lazy", "weak", "unowned",
                       "optional", "prefix", "postfix", "infix", "nonisolated", "isolated", "consuming", "borrowing", "distributed",
                       "__consuming", "__owned", "__shared"}) do
    MODIFIERS[name] = true
end
local MODIFIER_FOLLOWERS = {func = true, var = true, let = true, subscript = true, init = true}
for name in pairs(MODIFIERS) do
    MODIFIER_FOLLOWERS[name] = true
end
local DECL_KEYWORDS = {}
for _, name in ipairs({"struct", "class", "enum", "actor", "protocol", "extension", "typealias", "func", "var", "let", "init",
                       "subscript", "case", "associatedtype", "macro", "deinit"}) do
    DECL_KEYWORDS[name] = true
end
local OPERATOR_BYTES = {}
for byte in ("/=-+!*%<>&|^~?."):gmatch(".") do
    OPERATOR_BYTES[byte] = true
end
local INTERFACE_NAMES = {"arm64-apple-ios.swiftinterface", "arm64e-apple-ios.swiftinterface"}

local function char_length(s, i)
    local b = s:byte(i)
    if b == nil then
        return 0
    elseif b < 0xC0 then
        return 1
    elseif b < 0xE0 then
        return 2
    elseif b < 0xF0 then
        return 3
    end
    return 4
end

local function code_point(s, i)
    local n = char_length(s, i)
    local b = s:byte(i)
    if n == 1 then
        return b, 1
    end
    local cp = b & (n == 2 and 0x1F or n == 3 and 0x0F or 0x07)
    for k = 1, n - 1 do
        cp = (cp << 6) | ((s:byte(i + k) or 0x80) & 0x3F)
    end
    return cp, n
end

local function is_space_cp(cp)
    return (cp >= 9 and cp <= 13) or (cp >= 28 and cp <= 32) or cp == 0x85 or cp == 0xA0 or cp == 0x1680
        or (cp >= 0x2000 and cp <= 0x200A) or cp == 0x2028 or cp == 0x2029 or cp == 0x202F or cp == 0x205F or cp == 0x3000
end

local function space_at(s, i)
    local b = s:byte(i)
    if b == nil then
        return 0
    end
    if b < 0x80 then
        return is_space_cp(b) and 1 or 0
    end
    local cp, n = code_point(s, i)
    return is_space_cp(cp) and n or 0
end

local function is_word_cp(cp)
    if cp < 0x80 then
        return (cp >= 48 and cp <= 57) or (cp >= 65 and cp <= 90) or (cp >= 97 and cp <= 122) or cp == 95
    end
    if cp <= 0xBF then
        return cp == 0xAA or cp == 0xB2 or cp == 0xB3 or cp == 0xB5 or cp == 0xB9 or cp == 0xBA or (cp >= 0xBC and cp <= 0xBE)
    end
    if cp == 0xD7 or cp == 0xF7 or is_space_cp(cp) then
        return false
    end
    if (cp >= 0x0300 and cp <= 0x036F) or (cp >= 0x1AB0 and cp <= 0x1AFF) or (cp >= 0x1DC0 and cp <= 0x1DFF)
            or (cp >= 0x20D0 and cp <= 0x20FF) or (cp >= 0xFE00 and cp <= 0xFE0F) or (cp >= 0xFE20 and cp <= 0xFE2F) then
        return false
    end
    if cp >= 0x2000 and cp <= 0x2BFF then
        return (cp >= 0x2070 and cp <= 0x209F) or (cp >= 0x2100 and cp <= 0x218F)
    end
    if cp >= 0x2E00 and cp <= 0x2E7F then
        return false
    end
    if cp >= 0x3000 and cp <= 0x303F then
        return (cp >= 0x3005 and cp <= 0x3007) or (cp >= 0x3021 and cp <= 0x3029) or (cp >= 0x3031 and cp <= 0x3035)
            or (cp >= 0x3038 and cp <= 0x303C)
    end
    return true
end

local function word_at(s, i)
    local b = s:byte(i)
    if b == nil then
        return 0
    end
    if b < 0x80 then
        return is_word_cp(b) and 1 or 0
    end
    local cp, n = code_point(s, i)
    return is_word_cp(cp) and n or 0
end

local function letter_at(s, i)
    local b = s:byte(i)
    if b ~= nil and b >= 48 and b <= 57 then
        return 0
    end
    return word_at(s, i)
end

local function ascii_identifier_start(s, i)
    local b = s:byte(i)
    return b ~= nil and ((b >= 65 and b <= 90) or (b >= 97 and b <= 122) or b == 95)
end

local function word_run(s, i)
    local j = i
    while true do
        local n = word_at(s, j)
        if n == 0 then
            return j
        end
        j = j + n
    end
end

local function space_run(s, i)
    local j = i
    while true do
        local n = space_at(s, j)
        if n == 0 then
            return j
        end
        j = j + n
    end
end

function lstrip(s)
    local start = space_run(s, 1)
    return start == 1 and s or s:sub(start)
end

function strip(s)
    local start = space_run(s, 1)
    local i, last = start, start - 1
    while i <= #s do
        local n = space_at(s, i)
        if n == 0 then
            n = char_length(s, i)
            last = i + n - 1
        end
        i = i + n
    end
    if start == 1 and last == #s then
        return s
    end
    return s:sub(start, last)
end

function split(s)
    local out = {}
    local i = 1
    while i <= #s do
        i = space_run(s, i)
        if i > #s then
            break
        end
        local j = i
        while j <= #s and space_at(s, j) == 0 do
            j = j + char_length(s, j)
        end
        table.insert(out, s:sub(i, j - 1))
        i = j
    end
    return out
end

local function valid_utf8(text)
    local out = {}
    local i, n = 1, #text
    while i <= n do
        local b = text:byte(i)
        local need
        if b < 0x80 then
            need = {}
        elseif b >= 0xC2 and b <= 0xDF then
            need = {{0x80, 0xBF}}
        elseif b == 0xE0 then
            need = {{0xA0, 0xBF}, {0x80, 0xBF}}
        elseif (b >= 0xE1 and b <= 0xEC) or b == 0xEE or b == 0xEF then
            need = {{0x80, 0xBF}, {0x80, 0xBF}}
        elseif b == 0xED then
            need = {{0x80, 0x9F}, {0x80, 0xBF}}
        elseif b == 0xF0 then
            need = {{0x90, 0xBF}, {0x80, 0xBF}, {0x80, 0xBF}}
        elseif b >= 0xF1 and b <= 0xF3 then
            need = {{0x80, 0xBF}, {0x80, 0xBF}, {0x80, 0xBF}}
        elseif b == 0xF4 then
            need = {{0x80, 0x8F}, {0x80, 0xBF}, {0x80, 0xBF}}
        end
        if need == nil then
            table.insert(out, "\xEF\xBF\xBD")
            i = i + 1
        else
            local j, good = i + 1, true
            for _, range in ipairs(need) do
                local c = text:byte(j)
                if c == nil or c < range[1] or c > range[2] then
                    good = false
                    break
                end
                j = j + 1
            end
            if good then
                table.insert(out, text:sub(i, j - 1))
            else
                table.insert(out, "\xEF\xBF\xBD")
            end
            i = j
        end
    end
    return table.concat(out)
end

function decode(text)
    if utf8.len(text) then
        return text
    end
    return valid_utf8(text)
end

function splitlines(text)
    local lines = {}
    local start, i, n = 1, 1, #text
    while i <= n do
        local b = text:byte(i)
        local width = 0
        if b == 10 or b == 11 or b == 12 or b == 28 or b == 29 or b == 30 then
            width = 1
        elseif b == 13 then
            width = text:byte(i + 1) == 10 and 2 or 1
        elseif b == 0xC2 and text:byte(i + 1) == 0x85 then
            width = 2
        elseif b == 0xE2 and text:byte(i + 1) == 0x80 and (text:byte(i + 2) == 0xA8 or text:byte(i + 2) == 0xA9) then
            width = 3
        end
        if width > 0 then
            table.insert(lines, text:sub(start, i - 1))
            i = i + width
            start = i
        else
            i = i + 1
        end
    end
    if start <= n then
        table.insert(lines, text:sub(start))
    end
    return lines
end

function parse_version(text)
    local parts = {}
    for part in (text .. "."):gmatch("([^.]*)%.") do
        table.insert(parts, tonumber(part))
    end
    while #parts < 2 do
        table.insert(parts, 0)
    end
    return parts
end

function show_version(version)
    local parts = {}
    for i, part in ipairs(version) do
        parts[i] = part
    end
    while #parts > 2 and parts[#parts] == 0 do
        table.remove(parts)
    end
    local shown = {}
    for i, part in ipairs(parts) do
        shown[i] = tostring(math.tointeger(part) or part)
    end
    return table.concat(shown, ".")
end

function compare(a, b)
    for i = 1, math.min(#a, #b) do
        if a[i] ~= b[i] then
            return a[i] < b[i] and -1 or 1
        end
    end
    if #a == #b then
        return 0
    end
    return #a < #b and -1 or 1
end

local function less(a, b)
    return compare(a, b) < 0
end

local function same(a, b)
    return a ~= nil and b ~= nil and compare(a, b) == 0
end

function is_version(text)
    return text:match("^%d+$") ~= nil or text:match("^%d+%.%d+$") ~= nil or text:match("^%d+%.%d+%.%d+$") ~= nil
end

function balanced(text, start)
    local depth, quoted, index = 0, false, start
    while index <= #text do
        local char = text:sub(index, index)
        if quoted then
            if char == "\\" then
                index = index + 1
            elseif char == "\"" then
                quoted = false
            end
        elseif char == "\"" then
            quoted = true
        elseif char == "(" then
            depth = depth + 1
        elseif char == ")" then
            depth = depth - 1
            if depth == 0 then
                return index + 1
            end
        end
        index = index + 1
    end
    return #text + 1
end

function top_level_split(text, separator)
    separator = separator or ","
    local parts, current = {}, {}
    local depth, quoted, index = 0, false, 1
    while index <= #text do
        local char = text:sub(index, index)
        if quoted then
            table.insert(current, char)
            if char == "\\" and index + 1 <= #text then
                index = index + 1
                table.insert(current, text:sub(index, index))
            elseif char == "\"" then
                quoted = false
            end
        elseif char == "\"" then
            quoted = true
            table.insert(current, char)
        elseif char == "(" or char == "[" or char == "<" or char == "{" then
            depth = depth + 1
            table.insert(current, char)
        elseif char == ")" or char == "]" or char == ">" or char == "}" then
            if not (char == ">" and index > 1 and text:sub(index - 1, index - 1) == "-") then
                depth = depth - 1
            end
            table.insert(current, char)
        elseif char == separator and depth <= 0 then
            table.insert(parts, strip(table.concat(current)))
            current = {}
        else
            table.insert(current, char)
        end
        index = index + 1
    end
    local tail = strip(table.concat(current))
    if tail ~= "" then
        table.insert(parts, tail)
    end
    return parts
end

function strip_code(line)
    local out, quoted, index = {}, false, 1
    while index <= #line do
        local char = line:sub(index, index)
        if quoted then
            if char == "\\" then
                index = index + 1
            elseif char == "\"" then
                quoted = false
            end
        elseif char == "\"" then
            quoted = true
        elseif char == "/" and line:sub(index, index + 1) == "//" then
            break
        else
            table.insert(out, char)
        end
        index = index + 1
    end
    return table.concat(out)
end

local function attribute_end(rest)
    if rest:sub(1, 1) ~= "@" or not ascii_identifier_start(rest, 2) then
        return nil
    end
    local j = 3
    while true do
        if rest:sub(j, j) == "." then
            j = j + 1
        else
            local n = word_at(rest, j)
            if n == 0 then
                return j
            end
            j = j + n
        end
    end
end

function leading_attributes(line)
    local attributes = {}
    local rest = lstrip(line)
    while true do
        local finish = attribute_end(rest)
        if finish == nil then
            return attributes, rest
        end
        if rest:sub(finish, finish) == "(" then
            finish = balanced(rest, finish)
        end
        table.insert(attributes, rest:sub(1, finish - 1))
        rest = lstrip(rest:sub(finish))
    end
end

local function partition(text, separator)
    local at = text:find(separator, 1, true)
    if at == nil then
        return text, nil, ""
    end
    return text:sub(1, at - 1), separator, text:sub(at + #separator)
end

function ios_availability(attribute)
    local open = attribute:find("(", 1, true)
    local close
    for i = #attribute, 1, -1 do
        if attribute:sub(i, i) == ")" then
            close = i
            break
        end
    end
    if open == nil or close == nil then
        raise("swiftinterface: an @available attribute with no parenthesis pair: %s", attribute)
    end
    local inner = attribute:sub(open + 1, close - 1)
    local introduced, deprecated, obsoleted = nil, nil, nil
    local unavailable = false
    local platform = nil
    for _, argument in ipairs(top_level_split(inner)) do
        local tokens = split(argument)
        if #tokens > 0 then
            if not argument:find(":", 1, true) then
                if (tokens[1] == "iOS" or tokens[1] == "*") and platform == nil then
                    platform = tokens[1]
                    if #tokens > 1 and is_version(tokens[2]) then
                        introduced = parse_version(tokens[2])
                    end
                elseif tokens[1] == "unavailable" then
                    unavailable = true
                elseif tokens[1] == "deprecated" then
                    deprecated = deprecated or DEPRECATED_NO_VERSION
                end
            else
                local label, _, value = partition(argument, ":")
                label = strip(label)
                value = strip(value)
                if label == "introduced" and is_version(value) then
                    introduced = parse_version(value)
                elseif label == "deprecated" and is_version(value) then
                    deprecated = parse_version(value)[1] < DEPRECATED_NO_VERSION[1] and parse_version(value) or DEPRECATED_NO_VERSION
                elseif label == "obsoleted" and is_version(value) then
                    obsoleted = parse_version(value)
                end
            end
        end
    end
    if platform == nil then
        return nil
    end
    if platform == "*" then
        if deprecated or obsoleted or unavailable then
            return {nil, deprecated, obsoleted, unavailable}
        end
        return nil
    end
    return {introduced, deprecated, obsoleted, unavailable}
end

function fold(attributes)
    local introduced, deprecated, obsoleted = nil, nil, nil
    local unavailable, found = false, false
    for _, attribute in ipairs(attributes) do
        if attribute:sub(1, #"@available") == "@available" then
            local one = ios_availability(attribute)
            if one ~= nil then
                found = true
                if one[1] and (introduced == nil or less(one[1], introduced)) then
                    introduced = one[1]
                end
                if one[2] and (deprecated == nil or less(one[2], deprecated)) then
                    deprecated = one[2]
                end
                if one[3] and (obsoleted == nil or less(one[3], obsoleted)) then
                    obsoleted = one[3]
                end
                unavailable = unavailable or one[4]
            end
        end
    end
    return {introduced = introduced, deprecated = deprecated, obsoleted = obsoleted, unavailable = unavailable, found = found}
end

function strip_generics(text)
    local out, depth = {}, 0
    for index = 1, #text do
        local char = text:sub(index, index)
        if char == "<" then
            depth = depth + 1
        elseif char == ">" and depth > 0 then
            depth = depth - 1
        elseif depth == 0 then
            table.insert(out, char)
        end
    end
    return table.concat(out)
end

function name_match(text)
    local i = 1
    if text:sub(1, 1) == "$" then
        i = 2
    end
    local n = letter_at(text, i)
    if n > 0 then
        local finish = word_run(text, i + n)
        return text:sub(1, finish - 1)
    end
    if text:sub(1, 1) == "`" then
        local close = text:find("`", 2, true)
        if close and close > 2 then
            return text:sub(1, close)
        end
    end
    return nil
end

local function operator_match(text)
    local j = 1
    while OPERATOR_BYTES[text:sub(j, j)] do
        j = j + 1
    end
    return j > 1 and text:sub(1, j - 1) or nil
end

local function strip_backticks(name)
    return (name:gsub("^`+", ""):gsub("`+$", ""))
end

function skip_generics(text)
    local depth = 0
    for index = 1, #text do
        local char = text:sub(index, index)
        if char == "<" then
            depth = depth + 1
        elseif char == ">" and text:sub(index - 1, index - 1) ~= "-" then
            depth = depth - 1
            if depth == 0 then
                return lstrip(text:sub(index + 1))
            end
        end
    end
    return ""
end

function function_name(text)
    local keyword = text:match("^[a-z]+")
    local after = lstrip(text:sub(#keyword + 1))
    local name
    if keyword == "init" then
        local first = after:sub(1, 1)
        name = "init" .. ((first == "?" or first == "!") and first or "")
        after = lstrip((after:gsub("^[?!]+", "")))
        if after:sub(1, 1) == "<" then
            after = skip_generics(after)
        end
    elseif keyword == "subscript" then
        name = "subscript"
        if after:sub(1, 1) == "<" then
            after = skip_generics(after)
        end
    else
        local word = name_match(after)
        local found = word or operator_match(after)
        name = found and strip_backticks(found) or "?"
        if found then
            after = lstrip(after:sub(#found + 1))
        end
        if word and after:sub(1, 1) == "<" then
            after = skip_generics(after)
        end
    end
    if after:sub(1, 1) ~= "(" then
        return name
    end
    local finish = balanced(after, 1)
    local labels = {}
    for _, parameter in ipairs(top_level_split(after:sub(2, finish - 2))) do
        local _, rest = leading_attributes(parameter)
        local first = split((partition(rest, ":")))
        table.insert(labels, (first[1] or "_") .. ":")
    end
    return name .. "(" .. table.concat(labels) .. ")"
end

local function identifier_at(text)
    if not ascii_identifier_start(text, 1) then
        return nil
    end
    return word_run(text, 2)
end

function declaration(rest)
    local modifiers = {}
    local text = rest
    while true do
        local finish = identifier_at(text)
        if finish == nil then
            break
        end
        local word = text:sub(1, finish - 1)
        if not MODIFIERS[word] then
            break
        end
        local after = finish
        if text:sub(after, after + 5) == "(safe)" then
            after = after + 6
        elseif text:sub(after, after + 7) == "(unsafe)" then
            after = after + 8
        end
        after = space_run(text, after)
        if word == "class" then
            local tail = text:sub(after)
            local following = identifier_at(tail)
            if following == nil or not MODIFIER_FOLLOWERS[tail:sub(1, following - 1)] then
                break
            end
        end
        modifiers[word] = true
        text = text:sub(after)
    end
    local keyword = text:match("^[A-Za-z_]+")
    if keyword == nil or not DECL_KEYWORDS[keyword] then
        return nil
    end
    return keyword, modifiers, text
end

local function entries(folder, suffix)
    local out = {}
    if not os.isdir(folder) then
        return out
    end
    for _, entry in ipairs(os.filedirs(path.join(folder, "*"))) do
        local name = path.filename(entry)
        if name:sub(1, 1) ~= "." and name:sub(-#suffix) == suffix then
            table.insert(out, path.join(folder, name))
        end
    end
    return out
end

local function framework_modules(root)
    local out = {}
    for _, framework in ipairs(entries(root, ".framework")) do
        table.join2(out, entries(path.join(framework, "Modules"), ".swiftmodule"))
    end
    byteorder.sort(out)
    return out
end

function interfaces(sdk)
    local found, modules = {}, {}
    local roots = {path.join(sdk, "System", "Library", "Frameworks"),
                   path.join(sdk, "System", "Cryptexes", "OS", "System", "Library", "Frameworks"),
                   path.join(sdk, "Developer", "Library", "Frameworks")}
    local directories = {}
    for _, root in ipairs(roots) do
        table.join2(directories, framework_modules(root))
    end
    local libraries = entries(path.join(sdk, "usr", "lib", "swift"), ".swiftmodule")
    byteorder.sort(libraries)
    table.join2(directories, libraries)
    for _, directory in ipairs(directories) do
        local name = path.filename(directory)
        local module = name:sub(1, #name - #".swiftmodule")
        if found[module] == nil then
            for _, file in ipairs(INTERFACE_NAMES) do
                local candidate = path.join(directory, file)
                if os.isfile(candidate) then
                    found[module] = candidate
                    table.insert(modules, module)
                    break
                end
            end
        end
    end
    byteorder.sort(modules)
    return {modules = modules, path = found}
end

local function qualified(owner, name)
    return owner ~= "" and (owner .. "." .. name) or name
end

local function unqualified(name, modules)
    local head, dot, tail = partition(name, ".")
    return (dot and modules[head]) and tail or name
end

local function extension_target(text)
    local i = 1
    while i <= #text + 1 do
        local j = space_run(text, i)
        local c = text:sub(j, j)
        if c == ":" or c == "{" then
            return text:sub(1, i - 1)
        end
        if j > i and text:sub(j, j + 4) == "where" and space_run(text, j + 5) > j + 5 then
            return text:sub(1, i - 1)
        end
        i = i + math.max(char_length(text, i), 1)
    end
    return text
end

local function combine(own, container)
    local result = {introduced = own.introduced, deprecated = own.deprecated, obsoleted = own.obsoleted, unavailable = own.unavailable,
                    found = own.found}
    result.via = own.introduced and "own" or "none"
    if container ~= nil then
        if own.introduced == nil and container.introduced ~= nil then
            result.introduced = container.introduced
            result.via = "container"
        end
        if not own.found then
            result.obsoleted = container.obsoleted
            result.unavailable = container.unavailable
        end
    end
    return result
end

local function add(rows, order, module, kind, api, detail)
    local row = rows[api]
    if row then
        if detail.introduced and (row.introduced == nil or less(detail.introduced, row.introduced)) then
            row.introduced = detail.introduced
            row.via = detail.via
        end
        return
    end
    rows[api] = {api = api, framework = module, kind = kind, lang = "swift", introduced = detail.introduced, deprecated = detail.deprecated,
                 obsoleted = detail.obsoleted, unavailable = detail.unavailable, via = detail.via}
    table.insert(order, api)
end

local function has_prefix(list, prefix)
    for _, item in ipairs(list) do
        if item:sub(1, #prefix) == prefix then
            return true
        end
    end
    return false
end

local function count(text, char)
    local n = 0
    for _ in text:gmatch(char) do
        n = n + 1
    end
    return n
end

local function pop(stack)
    if #stack == 0 then
        raise("swiftinterface: pop from an empty scope stack")
    end
    table.remove(stack)
end

function parse_text(text, module, modules, problems)
    modules = modules or {}
    local underflow = 0
    local rows, order = {}, {}
    local stack, pending = {}, {}
    for _, raw in ipairs(splitlines(decode(text))) do
        local line = strip(raw)
        if line ~= "" and line:sub(1, 2) ~= "//" and line:sub(1, 1) ~= "#" then
            local code = strip_code(line)
            local net = count(code, "{") - count(code, "}")
            local scope = stack[#stack]
            if scope ~= nil and scope.kind == "body" then
                for _ = 1, math.max(net, 0) do
                    table.insert(stack, {kind = "body"})
                end
                for _ = 1, math.max(-net, 0) do
                    pop(stack)
                end
                pending = {}
            else
                local attributes, rest = leading_attributes(line)
                table.join2(pending, attributes)
                if rest ~= "" then
                    local keyword, modifiers, decl_text = declaration(rest)
                    if keyword == nil then
                        for _ = 1, math.max(net, 0) do
                            table.insert(stack, {kind = "body"})
                        end
                        for _ = 1, math.max(-net, 0) do
                            if #stack > 0 then
                                table.remove(stack)
                            else
                                underflow = underflow + 1
                            end
                        end
                        pending = {}
                    else
                        local own = fold(pending)
                        local spi = has_prefix(pending, "@_spi")
                        local usable = has_prefix(pending, "@usableFromInline")
                        pending = {}
                        local container = scope ~= nil and scope.detail or nil
                        local in_kind = scope ~= nil and scope.kind or "top"
                        local public = modifiers.public or modifiers.open
                        local implicit_public = in_kind == "protocol" or (in_kind == "enum" and keyword == "case")
                        local emit = (public or implicit_public) and not spi and not usable and not modifiers.internal
                            and not modifiers.private and not modifiers.fileprivate and not modifiers.package
                        if keyword == "extension" then
                            local target = strip_generics(strip(decl_text:sub(#"extension" + 1)))
                            target = unqualified(strip(extension_target(target)), modules)
                            local detail = combine(own, container)
                            if net > 0 then
                                table.insert(stack, {kind = "extension", name = target, detail = detail})
                            end
                        else
                            local names = {}
                            for _, s in ipairs(stack) do
                                if s.name and s.name ~= "" and (s.kind == "type" or s.kind == "protocol" or s.kind == "enum"
                                                                or s.kind == "extension") then
                                    table.insert(names, s.name)
                                end
                            end
                            local owner = table.concat(names, ".")
                            local after = strip(decl_text:sub(#keyword + 1))
                            if TYPE_KEYWORD[keyword] then
                                local found = name_match(after)
                                local name = found and strip_backticks(found) or "?"
                                local detail = combine(own, container)
                                if emit then
                                    add(rows, order, module, TYPE_KEYWORD[keyword], qualified(owner, name), detail)
                                end
                                if net > 0 then
                                    local kind = keyword == "protocol" and "protocol" or keyword == "enum" and "enum" or "type"
                                    table.insert(stack, {kind = kind, name = name, detail = detail})
                                end
                            elseif keyword == "func" or keyword == "init" or keyword == "subscript" or keyword == "macro" then
                                local api_name = function_name(decl_text)
                                local kind = in_kind ~= "top" and "method" or "function"
                                if keyword == "macro" then
                                    kind = "function"
                                end
                                if emit then
                                    add(rows, order, module, kind, qualified(owner, api_name), combine(own, container))
                                end
                                if net > 0 then
                                    table.insert(stack, {kind = "body"})
                                end
                            elseif keyword == "var" or keyword == "let" then
                                local found = name_match(after)
                                local name = found and strip_backticks(found) or "?"
                                if emit then
                                    add(rows, order, module, in_kind ~= "top" and "property" or "constant", qualified(owner, name),
                                        combine(own, container))
                                end
                                if net > 0 then
                                    table.insert(stack, {kind = "body"})
                                end
                            elseif keyword == "typealias" then
                                local found = name_match(after)
                                local name = found and strip_backticks(found) or "?"
                                if emit then
                                    add(rows, order, module, "typealias", qualified(owner, name), combine(own, container))
                                end
                            elseif keyword == "case" then
                                local detail = combine(own, container)
                                for _, item in ipairs(top_level_split(after)) do
                                    local found = name_match(item)
                                    if found and emit then
                                        add(rows, order, module, "constant", qualified(owner, strip_backticks(found)), detail)
                                    end
                                end
                            elseif net > 0 then
                                table.insert(stack, {kind = "body"})
                            end
                        end
                    end
                end
            end
        end
    end
    if problems ~= nil and (#stack > 0 or underflow > 0) then
        table.insert(problems, string.format("%s: %d scope(s) open at the end of the file, %d closing brace(s) with none open",
                                             module, #stack, underflow))
    end
    local out = {}
    for _, api in ipairs(order) do
        table.insert(out, rows[api])
    end
    return out
end

function parse(filepath, module, modules, problems)
    return parse_text(io.readfile(filepath, {encoding = "binary"}), module, modules, problems)
end

function show(version)
    if version == nil then
        return ""
    end
    if same(version, DEPRECATED_NO_VERSION) then
        return "yes"
    end
    return show_version(version)
end

function shown(row)
    return {api = row.api, framework = row.framework, kind = row.kind, lang = "swift", introduced = show(row.introduced),
            deprecated = show(row.deprecated), obsoleted = show(row.obsoleted), unavailable = row.unavailable and "yes" or "", via = row.via}
end

function rows(sdk, only, problems)
    local found = interfaces(sdk)
    local modules = {}
    for _, module in ipairs(found.modules) do
        modules[module] = true
    end
    for _, entry in ipairs(entries(path.join(sdk, "System", "Library", "Frameworks"), ".framework")) do
        local name = path.filename(entry)
        modules[name:sub(1, #name - #".framework")] = true
    end
    local out = {}
    for _, module in ipairs(found.modules) do
        if not only or only[module] then
            for _, row in ipairs(parse(found.path[module], module, modules, problems)) do
                table.insert(out, shown(row))
            end
        end
    end
    return out
end

function main(sdk, ...)
    if not sdk or sdk == "" then
        raise("usage: xmake l tools/corpus/swiftinterface.lua <sdk> [Module ...]: one line per public declaration of the SDK's "
              .. ".swiftinterface files: module, kind, api, introduced, deprecated, obsoleted, unavailable, via")
    end
    local only = nil
    for _, module in ipairs({...}) do
        only = only or {}
        only[module] = true
    end
    local problems = {}
    local lines = {}
    for _, row in ipairs(rows(sdk, only, problems)) do
        table.insert(lines, table.concat({row.framework, row.kind, row.api, row.introduced, row.deprecated, row.obsoleted, row.unavailable,
                                          row.via}, "\t"))
        if #lines >= 4096 then
            io.write(table.concat(lines, "\n") .. "\n")
            lines = {}
        end
    end
    if #lines > 0 then
        io.write(table.concat(lines, "\n") .. "\n")
    end
    for _, problem in ipairs(problems) do
        io.stderr:write("swiftinterface.lua: " .. problem .. "\n")
    end
end
