local root = path.absolute(path.directory(os.scriptdir()))

local function arguments(text, open)
    local depth, args, start, at, quote = 0, {}, open, open, nil
    while at <= #text do
        local char = text:sub(at, at)
        if quote then
            if char == "\\" then
                at = at + 1
            elseif char == quote then
                quote = nil
            end
        elseif char == '"' then
            quote = char
        elseif char == "(" or char == "{" then
            depth = depth + 1
        elseif char == ")" or char == "}" then
            depth = depth - 1
            if depth == 0 and char == ")" then
                table.insert(args, text:sub(start + 1, at - 1))
                return args
            end
        elseif char == "," and depth == 1 then
            table.insert(args, text:sub(start + 1, at - 1))
            start = at
        end
        at = at + 1
    end
    return args
end

local function calls(text, name)
    local found = {}
    local at = 1
    while true do
        local first, last = text:find(name .. "(", at, true)
        if not first then
            return found
        end
        table.insert(found, arguments(text, last))
        at = last + 1
    end
end

local function literal(argument)
    return argument and argument:match('^%s*"([^"]+)"')
end

function main()
    local errors = {}
    local swift = io.readfile(path.join(root, "frameworks", "Backports", "src", "Swift", "xmake.lua"))
    local readme = io.readfile(path.join(root, "frameworks", "Backports", "README.md"))
    local gaps = {}
    for _, args in ipairs(calls(swift, "open_gap")) do
        local name = literal(args[1])
        if name then
            gaps[name] = true
        end
    end
    for _, args in ipairs(calls(swift, "createml")) do
        local gap = args[5] and args[5]:match("%S")
        local name = literal(args[1])
        if gap and name then
            gaps[name] = true
        end
    end
    local names = table.orderkeys(gaps)
    if #names == 0 then
        table.insert(errors, "frameworks/Backports/src/Swift/xmake.lua declares no open gap, so this check reads nothing")
    end
    for _, name in ipairs(names) do
        if not readme:find("`" .. name .. "`", 1, true) then
            table.insert(errors, "frameworks/Backports/README.md does not name the open gap " .. name)
        end
    end
    for _, line in ipairs(errors) do
        print(line)
    end
    assert(#errors == 0, #errors .. " open gaps are not in the Backports README")
end
