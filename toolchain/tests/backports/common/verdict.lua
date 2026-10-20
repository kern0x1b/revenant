local json = import("core.base.json")

local function present(value)
    return value ~= nil and value ~= false and value ~= 0 and value ~= ""
end

function main(file, extra)
    local document = try { function () return json.decode(io.readfile(file)) end }
    if type(document) ~= "table" then
        return
    end
    local state = document.state
    if state == nil then
        state = "?"
    end
    local reason = document.reason
    if reason == nil then
        reason = ""
    end
    local parts = {tostring(state), tostring(reason)}
    if extra == "signal" and present(document.signal) then
        table.insert(parts, "signal " .. tostring(document.signal))
    end
    print(table.concat(parts, " "))
end
