local json = import("core.base.json")

function coverage_rows(text)
    local rows = {}
    for _, row in ipairs(json.decode(text).rows or {}) do
        table.insert(rows, {id = row.id, group = row.group, native = row.native == true, status = row.status})
    end
    return rows
end

function stub_entries(text)
    local names, owners = {}, {}
    for _, stub in ipairs(json.decode(text).stubs or {}) do
        if stub.file == "src/expo/StubModules.swift" then
            table.insert(names, stub.name)
            owners[stub.name] = stub.owner
        end
    end
    return names, owners
end

function apple_config(text)
    local config = json.decode(text)
    local block = config.apple
    if block == nil then
        block = config.ios
    end
    if type(block) ~= "table" then
        return {modules = {}, subscribers = {}}
    end
    return {modules = block.modules or {}, subscribers = block.appDelegateSubscribers or {}}
end

function printed_object(text)
    local start = 1
    while true do
        local found = text:find("{", start, true)
        if not found then
            return nil
        end
        if found == 1 or text:sub(found - 1, found - 1) == "\n" then
            local candidate = text:sub(found):gsub("%s+$", "")
            local value = try { function () return json.decode(candidate) end }
            if type(value) == "table" then
                return candidate, value
            end
        end
        start = found + 1
    end
end
