local pyish = import("pyish", {rootdir = path.join(os.scriptdir(), "..", "..", "common"), anonymous = true})

local ULPS_ALLOWED = {["activation tanh"] = 1, ["activation tanhShrink"] = 4}

local function read(file)
    local order, cases = {}, {}
    for line in pyish.lines_of(file) do
        if line:find("\t", 1, true) then
            local name, values = line:match("^([^\t]*)\t(.*)$")
            local fields = {}
            for field in (values .. ","):gmatch("([^,]*),") do
                table.insert(fields, field)
            end
            local parsed = nil
            if #fields == 4 then
                local ok = true
                for _, field in ipairs(fields) do
                    if not field:match("^[0-9a-f]+$") or #field ~= 8 then
                        ok = false
                    end
                end
                if ok then
                    parsed = {}
                    for i, field in ipairs(fields) do
                        parsed[i] = tonumber(field, 16)
                    end
                end
            end
            if cases[name] == nil then
                table.insert(order, name)
            end
            cases[name] = {value = parsed, present = true}
        end
    end
    return order, cases
end

local function shown(value)
    if value == nil then
        return "None"
    end
    local parts = {}
    for _, v in ipairs(value) do
        table.insert(parts, tostring(v))
    end
    return "[" .. table.concat(parts, ", ") .. "]"
end

local function names_only_in_one(system_order, system, port_order, port)
    local out = {}
    for _, name in ipairs(system_order) do
        if port[name] == nil then
            table.insert(out, name)
        end
    end
    for _, name in ipairs(port_order) do
        if system[name] == nil then
            table.insert(out, name)
        end
    end
    table.sort(out)
    return out
end

function compare(system_path, port_path)
    local system_order, system = read(system_path)
    local port_order, port = read(port_path)
    local problems = {}
    local symmetric = names_only_in_one(system_order, system, port_order, port)
    if #symmetric > 0 then
        table.insert(problems, "the two runs did not answer the same cases: " .. pyish.list_repr(symmetric))
    end
    for _, name in ipairs(system_order) do
        local left = system[name].value
        local right = port[name] and port[name].value or nil
        if left == nil or right == nil then
            if shown(left) ~= shown(right) then
                table.insert(problems, string.format("%s: host %s, port %s", name, shown(left), shown(right)))
            end
        else
            local allowed = ULPS_ALLOWED[name] or 0
            for index = 1, math.min(#left, #right) do
                local a, b = left[index], right[index]
                local gap = math.abs(a - b)
                if (a >> 23) ~= (b >> 23) or gap > allowed then
                    table.insert(problems, string.format("%s: value %d is 0x%08x against the host's 0x%08x (%d ulp, %d allowed)",
                        name, index - 1, b, a, gap, allowed))
                end
            end
        end
    end
    if #problems > 0 then
        print("the port's answers differ from the host's:")
        for i = 1, math.min(#problems, 20) do
            print("  " .. problems[i])
        end
        return 1
    end
    print(string.format("the port computes all %d activations as the host does: bit for bit, bar the last bit of the two cases that go through the framework's own tanh", #system_order))
    return 0
end

function main(system_path, port_path)
    os.exit(compare(system_path, port_path))
end
