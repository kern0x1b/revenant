local tsv = import("tsv", {anonymous = true})
local strings = import("strings", {anonymous = true})

local TYPE_KEYWORDS = {class = "class", struct = "struct", enum = "enum", protocol = "protocol", actor = "class"}
local MODIFIERS = {public = true, open = true, final = true, static = true, class = true, convenience = true, required = true,
                   override = true, dynamic = true, mutating = true, nonmutating = true, indirect = true, lazy = true,
                   weak = true, unowned = true, distributed = true, nonisolated = true}
local PLATFORMS = {iOS = true, ["*"] = true}
local KNOWN_PLATFORMS = {iOS = true, macOS = true, macCatalyst = true, tvOS = true, watchOS = true, visionOS = true, swift = true,
                         ["*"] = true}

function token_end(text, i)
    if string.sub(text, i, i) == "\"" then
        local j = i + 1
        while j <= #text and string.sub(text, j, j) ~= "\"" do
            if string.sub(text, j, j) == "\\" then
                j = j + 1
            end
            j = j + 1
        end
        return j + 1
    end
    return i + 2
end

function is_token(text, i)
    return string.sub(text, i, i) == "\"" or string.sub(text, i, i + 1) == "->"
end

function balanced(text, open)
    local depth, i = 0, open
    while i <= #text do
        local c = string.sub(text, i, i)
        if is_token(text, i) then
            i = token_end(text, i)
        else
            if c == "(" or c == "<" or c == "[" then
                depth = depth + 1
            elseif c == ")" or c == ">" or c == "]" then
                depth = depth - 1
                if depth == 0 then
                    return string.sub(text, open + 1, i - 1), i
                end
            end
            i = i + 1
        end
    end
    return nil
end

function split_top(text)
    local out, depth, start, i = {}, 0, 1, 1
    while i <= #text do
        local c = string.sub(text, i, i)
        if is_token(text, i) then
            i = token_end(text, i)
        else
            if c == "(" or c == "<" or c == "[" then
                depth = depth + 1
            elseif c == ")" or c == ">" or c == "]" then
                depth = depth - 1
            elseif c == "," and depth == 0 then
                table.insert(out, string.sub(text, start, i - 1))
                start = i + 1
            end
            i = i + 1
        end
    end
    local last = string.sub(text, start)
    if string.match(last, "%S") then
        table.insert(out, last)
    end
    return out
end

function available_args(inner)
    local own = {}
    local current = nil
    for _, arg in ipairs(split_top(inner)) do
        local item = string.gsub(string.gsub(arg, "^%s+", ""), "%s+$", "")
        local platform, version = string.match(item, "^([%w%*]+)%s+([%d%.]+)$")
        local key, value = string.match(item, "^(%a+)%s*:%s*(.-)%s*$")
        if platform and KNOWN_PLATFORMS[platform] then
            if PLATFORMS[platform] then
                own.introduced = version
            end
            current = platform
        elseif item == "*" or KNOWN_PLATFORMS[item] then
            current = item
        elseif item == "unavailable" then
            if current and PLATFORMS[current] then
                own.unavailable = true
            end
        elseif item == "deprecated" then
            if current and PLATFORMS[current] then
                own.deprecated = "yes"
            end
        elseif key and current and PLATFORMS[current] then
            value = string.gsub(value, "^\"", "")
            value = string.gsub(value, "\"$", "")
            if key == "introduced" then
                own.introduced = value
            elseif key == "deprecated" then
                own.deprecated = (value == "100000" or value == "100000.0") and "yes" or value
            elseif key == "obsoleted" then
                own.obsoleted = value
            end
        end
    end
    return own
end

function take_available(line)
    local own = nil
    local rest = line
    while true do
        local start = string.find(rest, "@available(", 1, true)
        if start == nil then
            break
        end
        local inner, close = balanced(rest, start + #"@available")
        if inner == nil then
            break
        end
        own = own or {}
        for k, v in pairs(available_args(inner)) do
            own[k] = v
        end
        rest = string.sub(rest, 1, start - 1) .. string.sub(rest, close + 1)
    end
    return own, rest
end

function merge_available(earlier, later)
    if earlier == nil then
        return later
    end
    if later == nil then
        return earlier
    end
    local out = {}
    for k, v in pairs(earlier) do
        out[k] = v
    end
    for k, v in pairs(later) do
        out[k] = v
    end
    return out
end

function strip_attributes(text)
    while true do
        local word = string.match(text, "^%s*(@[%w_%.]+)")
        if word == nil then
            return text
        end
        local after = string.sub(text, #string.match(text, "^%s*@[%w_%.]+") + 1)
        if string.sub(after, 1, 1) == "(" then
            local _, close = balanced(after, 1)
            after = string.sub(after, (close or #after) + 1)
        end
        text = after
    end
end

function extended_name(text, module, imports)
    local name = string.match(text, "^%s*([%w_%.\128-\255]+)")
    if name == nil then
        return nil
    end
    local head, tail = string.match(name, "^([%w_\128-\255]+)%.(.+)$")
    if head and (head == module or imports[head]) then
        name = tail
    end
    return name
end

function labels_of(inner)
    local labels = {}
    for _, piece in ipairs(split_top(inner)) do
        local text = string.gsub(strip_attributes(piece), "^%s+", "")
        local head = string.match(text, "^([^:]*):")
        local label = head and string.match(head, "^%s*([^%s]+)") or string.match(text, "^%s*([^%s:]+)")
        table.insert(labels, (label or "_") .. ":")
    end
    return table.concat(labels)
end

function callable_api(name, after)
    local open = string.find(after, "(", 1, true)
    if open == nil then
        return name
    end
    local inner = balanced(after, open)
    if inner == nil then
        return nil
    end
    return name .. "(" .. labels_of(inner) .. ")"
end

function declaration(text)
    local keyword = nil
    while true do
        keyword = string.match(text, "^%s*([%a_\128-\255]+)")
        if keyword == nil then
            return nil
        end
        local after = string.sub(text, #string.match(text, "^%s*[%a_\128-\255]+") + 1)
        if keyword == "class" then
            local nxt = string.match(after, "^%s*([%a_\128-\255]+)")
            if nxt == "func" or nxt == "var" or nxt == "let" or nxt == "subscript" or nxt == "init" or nxt == "static" then
                text = after
            else
                break
            end
        elseif MODIFIERS[keyword] then
            text = after
        else
            break
        end
    end
    local after = string.sub(text, #string.match(text, "^%s*[%a_\128-\255]+") + 1)
    if keyword == "extension" then
        return {kind = "extension", target = after}
    elseif TYPE_KEYWORDS[keyword] then
        local name = string.match(after, "^%s*([%a_\128-\255][%w_\128-\255]*)")
        return name and {kind = TYPE_KEYWORDS[keyword], name = name, type = true} or nil
    elseif keyword == "typealias" then
        local name = string.match(after, "^%s*([%a_\128-\255][%w_\128-\255]*)")
        return name and {kind = "typealias", name = name, type = true} or nil
    elseif keyword == "func" then
        local name = string.match(after, "^%s*([%a_\128-\255][%w_\128-\255]*)") or string.match(after, "^%s*([^%s%(%w_\128-\255]+)")
        if name == nil then
            return nil
        end
        local rest = string.sub(after, string.find(after, name, 1, true) + #name)
        local api = callable_api(name, rest)
        return api and {kind = "method", name = name, api = api, callable = true} or nil
    elseif keyword == "init" then
        local failable = string.match(after, "^([%?!])") or ""
        local api = callable_api("init" .. failable, after)
        return api and {kind = "method", name = "init", api = api, callable = true} or nil
    elseif keyword == "subscript" then
        local api = callable_api("subscript", after)
        return api and {kind = "method", name = "subscript", api = api, callable = true} or nil
    elseif keyword == "var" or keyword == "let" then
        local name = string.match(after, "^%s*([%a_\128-\255][%w_\128-\255]*)")
        return name and {kind = "variable", name = name, api = name} or nil
    elseif keyword == "case" then
        local names = {}
        for _, piece in ipairs(split_top(after)) do
            local name = string.match(piece, "^%s*([%a_\128-\255][%w_\128-\255]*)")
            if name then
                table.insert(names, name)
            end
        end
        return {kind = "case", names = names}
    end
    return nil
end

function record_of(kind, api, own, container, hidden)
    local introduced, via = nil, "none"
    if own and own.introduced then
        introduced, via = own.introduced, "own"
    elseif container and container.introduced then
        introduced, via = container.introduced, "container"
    end
    local unavailable = (own and own.unavailable) or hidden
    return {kind = kind, api = api, introduced = introduced, deprecated = own and own.deprecated or nil,
            obsoleted = own and own.obsoleted or nil, unavailable = unavailable and "yes" or "", via = via}
end

function hidden_of(stack)
    for i = #stack, 1, -1 do
        if stack[i].type and stack[i].own and stack[i].own.unavailable then
            return true
        end
    end
    return false
end

function brace_count(text, c)
    local _, n = string.gsub(text, c, "")
    return n
end

function qual_of(stack)
    for i = #stack, 1, -1 do
        if stack[i].type then
            return stack[i].qual
        end
    end
    return nil
end

function container_of(stack)
    for i = #stack, 1, -1 do
        if stack[i].type and stack[i].own and stack[i].own.introduced then
            return stack[i].own
        end
    end
    return nil
end

function parse_interface(text, module)
    local imports = {}
    for name in string.gmatch(text, "import%s+([%w_]+)") do
        imports[name] = true
    end
    local records, stack, pending = {}, {}, nil
    for line in string.gmatch(text, "[^\n]+") do
        local trimmed = string.gsub(line, "^%s+", "")
        local first = string.sub(trimmed, 1, 1)
        if trimmed ~= "" and first ~= "#" and string.sub(trimmed, 1, 2) ~= "//" then
            local own, rest = take_available(trimmed)
            local body = string.gsub(strip_attributes(string.gsub(rest, "%s+$", "")), "^%s+", "")
            local closes = string.match(body, "^(}+)")
            if closes then
                for _ = 1, #closes do
                    table.remove(stack)
                end
                body = string.gsub(string.sub(body, #closes + 1), "^%s+", "")
            end
            if body == "" then
                pending = merge_available(pending, own)
            else
                local decl = string.match(body, "^[%a_\128-\255]") and declaration(body) or nil
                if decl then
                    local decl_own = merge_available(pending, own)
                    pending = nil
                    local qual = qual_of(stack)
                    local container = container_of(stack)
                    local hidden = hidden_of(stack)
                    local opened = 0
                    if decl.kind == "extension" then
                        local target = extended_name(decl.target, module, imports)
                        if string.find(body, "{", 1, true) then
                            table.insert(stack, {type = true, qual = target, own = decl_own})
                            opened = 1
                        end
                    elseif decl.type then
                        local api = qual and (qual .. "." .. decl.name) or decl.name
                        table.insert(records, record_of(decl.kind, api, decl_own, container, hidden))
                        if string.find(body, "{", 1, true) then
                            table.insert(stack, {type = true, qual = api, own = decl_own})
                            opened = 1
                        end
                    elseif decl.kind == "case" then
                        for _, name in ipairs(decl.names) do
                            table.insert(records, record_of("constant", qual and (qual .. "." .. name) or name, decl_own, container,
                                                            hidden))
                        end
                    else
                        local kind = decl.kind
                        if kind == "method" then
                            kind = qual and "method" or "function"
                        elseif kind == "variable" then
                            kind = qual and "property" or "constant"
                        end
                        local api = qual and (qual .. "." .. decl.api) or decl.api
                        table.insert(records, record_of(kind, api, decl_own, container, hidden))
                    end
                    local net = brace_count(body, "{") - brace_count(body, "}") - opened
                    for _ = 1, net do
                        table.insert(stack, {type = false})
                    end
                    for _ = 1, -net do
                        table.remove(stack)
                    end
                else
                    pending = nil
                    local net = brace_count(body, "{") - brace_count(body, "}")
                    for _ = 1, net do
                        table.insert(stack, {type = false})
                    end
                    for _ = 1, -net do
                        table.remove(stack)
                    end
                end
            end
        end
    end
    return records
end

local SHARD_COLUMNS = {"module", "kind", "api", "introduced", "deprecated", "obsoleted", "unavailable", "via"}

function shard_text(text, module)
    local rows = {}
    for _, record in ipairs(parse_interface(text, module)) do
        table.insert(rows, {module, record.kind, strings.backslash_replace(record.api), record.introduced or "",
                            record.deprecated or "", record.obsoleted or "", record.unavailable, record.via})
    end
    return tsv.table_text(SHARD_COLUMNS, rows), #rows
end
