import("core.base.json")

function present(value)
    if value == nil or value == false or value == "" or value == 0 or value == json.null then
        return false
    end
    if table.empty(value) then
        return false
    end
    return true
end

function note(message)
    io.stderr:write(message .. "\n")
    io.stderr:flush()
end

function parse_args(tool, spec, argv)
    local known, values = {}, {}
    for _, option in ipairs(spec) do
        known[option.name] = option
        values[option.name] = option.default
    end
    local index = 1
    while index <= #argv do
        local word = argv[index]
        local name, value = word:match("^%-%-([^=]+)=(.*)$")
        if not name then
            name = word:match("^%-%-(.+)$")
            if not name or not known[name] then
                raise("%s: unrecognized argument %s", tool, word)
            end
            index = index + 1
            value = argv[index]
            if value == nil then
                raise("%s: argument --%s: expected one argument", tool, name)
            end
        elseif not known[name] then
            raise("%s: unrecognized argument %s", tool, word)
        end
        values[name] = value
        index = index + 1
    end
    local missing = {}
    for _, option in ipairs(spec) do
        if option.required and values[option.name] == nil then
            table.insert(missing, "--" .. option.name)
        end
    end
    if #missing > 0 then
        raise("%s: the following arguments are required: %s", tool, table.concat(missing, ", "))
    end
    return values
end

function count(map)
    local total = 0
    for _ in pairs(map) do
        total = total + 1
    end
    return total
end

function split(text, separator)
    return text:split(separator, {strict = true, plain = true})
end

function partition(text, separator)
    local at = text:find(separator, 1, true)
    if not at then
        return text, "", ""
    end
    return text:sub(1, at - 1), separator, text:sub(at + #separator)
end

function strip(text)
    return text:trim()
end

function words(text)
    local out = {}
    for word in text:gmatch("%S+") do
        table.insert(out, word)
    end
    return out
end

function python_int(text)
    if type(text) ~= "string" then
        return nil
    end
    local body = strip(text)
    if not body:match("^[-+]?%d[%d_]*$") or body:find("__", 1, true) or body:sub(-1) == "_" then
        return nil
    end
    return math.tointeger(tonumber((body:gsub("_", ""))))
end

function realpath(name)
    local pending = split(path.absolute(name), "/")
    local resolved = ""
    local hops = 0
    local index = 1
    while index <= #pending do
        local part = pending[index]
        index = index + 1
        if part == "" or part == "." then
        elseif part == ".." then
            resolved = resolved:match("^(.*)/[^/]*$") or ""
        else
            local candidate = resolved .. "/" .. part
            if os.islink(candidate) and hops < 40 then
                hops = hops + 1
                local target = os.readlink(candidate)
                local rest = {}
                for at = index, #pending do
                    table.insert(rest, pending[at])
                end
                if target:sub(1, 1) == "/" then
                    resolved = ""
                end
                pending = table.join(split(target, "/"), rest)
                index = 1
            else
                resolved = candidate
            end
        end
    end
    return resolved == "" and "/" or resolved
end
