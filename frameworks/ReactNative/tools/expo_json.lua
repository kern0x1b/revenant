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
