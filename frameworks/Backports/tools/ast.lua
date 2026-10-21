local FLAGS = {used = true, referenced = true, implicit = true, invalid = true, destroyed = true, constexpr = true}

local function depth_of(line)
    local prefix, body = string.match(line, "^([ |]*[|`]%-)(.*)$")
    if prefix == nil then
        return nil
    end
    return #prefix // 2 - 1, body
end

local function first_path(body)
    return string.match(body, "<(/[^:<>]+):%d+:%d+")
end

local function last_path(body)
    local found = nil
    if string.find(body, "<", 1, true) then
        for path in string.gmatch(body, "<(/[^:<>]+):%d+:%d+") do
            found = path
        end
    end
    return found
end

local function words(text)
    local out = {}
    for word in string.gmatch(text, "%S+") do
        out[#out + 1] = word
    end
    return out
end

local function is_loc(token)
    return token ~= nil and (string.find(token, "^line:") ~= nil or string.find(token, "^col:") ~= nil
        or string.find(token, "^/") ~= nil)
end

local function node_of(body, state)
    local node = {children = {}, file = first_path(body) or state}
    node.kind = string.match(body, "^(%S+)")
    node.type = string.match(body, "'([^']*)'")
    local quote = string.match(body, "^.*()'")
    node.tail = quote and string.sub(body, quote + 1) or ""
    node.flags = {}
    for word in string.gmatch(node.tail, "%a+") do
        node.flags[word] = true
    end
    local pre = string.match((string.gsub(body, "<scratch space>", "SCRATCH")), "^[^'\"]*")
    local range_start, range_end = string.find(pre, "<[^<>]*>")
    node.invalid = string.find(pre, "invalid sloc", 1, true) ~= nil
    node.multiline = range_start ~= nil and string.find(string.sub(pre, range_start, range_end), ", line:", 1, true) ~= nil
    local after = range_end and string.sub(pre, range_end + 1) or pre
    local tokens = words(after)
    if node.kind == "AvailabilityAttr" then
        node.platform = tokens[1]
        node.introduced = tokens[2]
        node.unavailable = tokens[5] == "Unavailable"
        return node
    end
    for _, token in ipairs(tokens) do
        if token == "implicit" then
            node.implicit = true
        end
    end
    local index = is_loc(tokens[1]) and 2 or 1
    while tokens[index] ~= nil and FLAGS[tokens[index]] do
        index = index + 1
    end
    if tokens[index] == "-" or tokens[index] == "+" then
        node.class_method = tokens[index] == "+"
        index = index + 1
    end
    node.name = tokens[index]
    return node
end

local function version(text)
    local major, minor = string.match(text or "", "^(%d+)%.?(%d*)")
    if major == nil then
        return nil
    end
    local value = tonumber(major) * 1000 + (tonumber(minor) or 0)
    if value == 0 then
        return nil
    end
    return value
end

function scan(handle, on_block)
    local state = nil
    local top = nil
    local stack = {}
    for line in handle:lines() do
        local depth, body = depth_of(line)
        if depth ~= nil then
            local node = node_of(body, state)
            state = last_path(body) or state
            if depth == 0 then
                if top ~= nil then
                    on_block(top)
                end
                top = node
                stack = {[0] = node}
            elseif stack[depth - 1] ~= nil then
                table.insert(stack[depth - 1].children, node)
                stack[depth] = node
            end
        end
    end
    if top ~= nil then
        on_block(top)
    end
end

function ios_intro(node)
    for _, child in ipairs(node.children) do
        if child.kind == "AvailabilityAttr" and child.platform == "ios" and not child.unavailable then
            return version(child.introduced)
        end
    end
    return nil
end

function children_of(node, kind)
    local out = {}
    for _, child in ipairs(node.children) do
        if child.kind == kind then
            out[#out + 1] = child
        end
    end
    return out
end

function version_of(text)
    return version(text)
end
