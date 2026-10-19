local V = import("vtlib", {rootdir = os.scriptdir()})
local R = import("records_json", {rootdir = os.scriptdir()})

local function repr_value(v)
    if v == nil or v == false then
        return "None"
    end
    return V.py_repr(v)
end

local function py_split(s)
    local out = {}
    for token in string.gmatch(s, "[^ \t\n\v\f\r\28\29\30\31]+") do
        out[#out + 1] = token
    end
    return out
end

local function is_space(b)
    return b == 32 or (b >= 9 and b <= 13) or (b >= 28 and b <= 31)
end

local function is_word(b)
    return (b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or b == 95
end

local function byte_at(text, i)
    if i > #text then
        return -1
    end
    return string.byte(text, i)
end

local function table_match_at(text, p)
    local q = p
    while is_space(byte_at(text, q)) do
        q = q + 1
    end
    if string.sub(text, q, q + 1) ~= "{\"" then
        return nil
    end
    q = q + 2
    local start = q
    while is_word(byte_at(text, q)) do
        q = q + 1
    end
    if q == start then
        return nil
    end
    local cls = string.sub(text, start, q - 1)
    if string.sub(text, q, q + 3) ~= "\", \"" then
        return nil
    end
    q = q + 4
    start = q
    while is_word(byte_at(text, q)) do
        q = q + 1
    end
    local proto = string.sub(text, start, q - 1)
    if string.sub(text, q, q + 3) ~= "\", \"" then
        return nil
    end
    q = q + 4
    start = q
    while byte_at(text, q) ~= -1 and byte_at(text, q) ~= 34 do
        q = q + 1
    end
    local class_props = string.sub(text, start, q - 1)
    if string.sub(text, q, q + 3) ~= "\", \"" then
        return nil
    end
    q = q + 4
    start = q
    while byte_at(text, q) ~= -1 and byte_at(text, q) ~= 34 do
        q = q + 1
    end
    local instance_props = string.sub(text, start, q - 1)
    if string.sub(text, q, q + 2) ~= "\"}," then
        return nil
    end
    return cls, proto, class_props, instance_props, q + 3
end

local function table_rows(text)
    local rows = {}
    local p = 1
    while p <= #text do
        local at_line_start = p == 1 or string.byte(text, p - 1) == 10
        local matched = false
        if at_line_start then
            local cls, proto, class_props, instance_props, after = table_match_at(text, p)
            if cls then
                rows[#rows + 1] = {cls, proto, class_props, instance_props}
                p = after
                matched = true
            end
        end
        if not matched then
            p = p + 1
        end
    end
    return rows
end

local function split_name(name)
    local dot = string.find(name, ".", 1, true)
    local field, tail
    if dot then
        field = string.sub(name, 1, dot - 1)
        tail = string.sub(name, dot + 1)
    else
        field = name
        tail = ""
    end
    local body = tail
    if string.sub(body, -1) == "\n" then
        body = string.sub(body, 1, -2)
    end
    local second = string.find(body, ".", 1, true)
    if not second then
        return field, nil, nil
    end
    local cls = string.sub(body, 1, second - 1)
    local accessor = string.sub(body, second + 1)
    if cls == "" or accessor == "" then
        return field, nil, nil
    end
    for i = 1, #cls do
        if not is_word(string.byte(cls, i)) then
            return field, nil, nil
        end
    end
    for i = 1, #accessor do
        if not is_word(string.byte(accessor, i)) then
            return field, nil, nil
        end
    end
    return field, cls, accessor
end

local function read_or_fail(path, reader)
    local result
    try {
        function()
            result = reader(path)
        end,
        catch {
            function(err)
                V.fail("compare.lua: cannot read " .. path .. ": " .. tostring(err))
            end
        }
    }
    return result
end

local function load_json(path)
    if not os.isfile(path) then
        V.fail("compare.lua: cannot read " .. path .. ": no such file")
    end
    local map
    try {
        function()
            map = R.read_object(path)
        end,
        catch {
            function(err)
                V.fail("compare.lua: " .. path .. " is not JSON: " .. tostring(err))
            end
        }
    }
    return map
end


local function check_record(st, system, port, name)
    local host = system[name]
    local field, cls, accessor = split_name(name)
    if (field == "isClass" or field == "isInstance") and cls then
        if not st.expected[cls] then
            st.bad[#st.bad + 1] = name .. ": a class the generated table does not have"
            return
        end
        local want
        if field == "isClass" then
            want = st.expected[cls].class[accessor] == true
        else
            want = st.expected[cls].instance[accessor] == true
        end
        local side = want and "on the class" or "on the instance"
        local on_class = system["isClass." .. cls .. "." .. accessor] == "1"
        local on_instance = system["isInstance." .. cls .. "." .. accessor] == "1"
        if not on_class and not on_instance then
            local key = cls .. "." .. accessor
            if not st.host_absent[key] then
                st.host_absent[key] = true
                st.host_absent_count = st.host_absent_count + 1
            end
            st.compared = st.compared + 1
            if (port[name] == "1") ~= want then
                st.bad[#st.bad + 1] = string.format("%s: the port has %s and the iOS 26.2 SDK declares it %s - the host's SDK "
                    .. "27.0 does not declare this member at all, so the table is the only oracle",
                    name, repr_value(port[name]), side)
            end
            return
        end
        st.host_compared = st.host_compared + 1
        if (port[name] == "1") ~= want then
            st.bad[#st.bad + 1] = string.format("%s: the host has %s, the port has %s, and the iOS 26.2 SDK declares it %s",
                name, repr_value(host), repr_value(port[name]), side)
        end
        st.compared = st.compared + 1
        return
    end
    st.compared = st.compared + 1
    local port_value = port[name]
    if port_value == nil then
        port_value = false
    end
    if port_value ~= host then
        st.bad[#st.bad + 1] = string.format("%s: the host has %s and the port has %s",
            name, repr_value(host), repr_value(port[name]))
    end
end

function main(system_path, port_path, cases_path)
    if cases_path == nil then
        V.fail("compare.lua: usage: compare.lua SYSTEM.json PORT.json CASES.m")
    end
    local expected = {}
    local classes = {}
    local cases_text = read_or_fail(cases_path, V.read_text)
    for _, row in ipairs(table_rows(cases_text)) do
        local cls = row[1]
        local class_set, instance_set = {}, {}
        for _, token in ipairs(py_split(row[3])) do
            class_set[token] = true
        end
        for _, token in ipairs(py_split(row[4])) do
            instance_set[token] = true
        end
        classes[#classes + 1] = cls
        expected[cls] = {protocol = row[2], class = class_set, instance = instance_set}
    end

    local system = load_json(system_path)
    local port = load_json(port_path)
    local st = {expected = expected, bad = {}, host_absent = {}, host_absent_count = 0,
                compared = 0, host_compared = 0}
    for _, name in ipairs(V.sorted_keys(system)) do
        check_record(st, system, port, name)
    end

    for _, line in ipairs(st.bad) do
        print("DIFFERS " .. line)
    end
    if #st.bad > 0 then
        os.exit(1)
    end
    print(string.format("compared %d records over %d classes: %d against the host's own VideoToolbox, %d against the "
        .. "iOS 26.2 table alone because the host's SDK 27.0 does not declare the member",
        st.compared, #classes, st.host_compared, st.host_absent_count))
    if st.host_absent_count > 0 then
        print("host has no such member: " .. table.concat(V.sorted_keys(st.host_absent), ", "))
    end
end
