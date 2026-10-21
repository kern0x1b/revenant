local sdkfiles = import("sdk", {rootdir = os.scriptdir(), anonymous = true})

local TBD_KEYS = {["symbols"] = true, ["weak-def-symbols"] = true, ["objc-classes"] = true}

local function setter(name)
    return "set" .. string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2) .. ":"
end

local function from_facts(frameworks)
    local public = {classes = {}, symbols = {}, methods = {}}
    for _, framework in ipairs(frameworks) do
        for _, row in ipairs(framework.rows) do
            if row.kind == "class" then
                public.classes[row.name] = true
            elseif row.kind == "C function" or row.kind == "global variable" then
                public.symbols[row.name] = true
            elseif row.kind == "instance method" or row.kind == "class method" then
                public.methods[row.kind .. "|" .. row.container .. "|" .. row.name] = true
            elseif row.kind == "property" then
                public.methods["instance method|" .. row.container .. "|" .. row.name] = true
                if string.find(row.signature, "^readonly ") == nil then
                    public.methods["instance method|" .. row.container .. "|" .. setter(row.name)] = true
                end
            end
        end
    end
    return public
end

function read_exports(text, public)
    local section, key
    for line in text:gmatch("[^\n]+") do
        local top = line:match("^([%w%-]+):")
        if top then
            section, key = top, nil
        elseif section == "exports" then
            local start, rest = line:match("^%s*([%w%-]+):%s*%[(.*)$")
            local body
            if start then
                key = TBD_KEYS[start] and start or nil
                body = rest
            elseif key then
                body = line
            end
            if body then
                local close = body:find("]", 1, true)
                local items = close and body:sub(1, close - 1) or body
                for token in items:gmatch("[^%s,]+") do
                    token = (token:gsub("['\"]", ""))
                    if key == "objc-classes" then
                        public.classes[token] = true
                    elseif token:sub(1, 1) == "_" then
                        local class = token:match("^_OBJC_CLASS_%$_(.+)$")
                        if class then
                            public.classes[class] = true
                        elseif not token:find("^_OBJC_") then
                            public.symbols[token:sub(2)] = true
                        end
                    end
                end
                if close then
                    key = nil
                end
            end
        end
    end
end

local function from_tbd(sdk, names)
    local public = {classes = {}, symbols = {}}
    local read = 0
    for _, name in ipairs(names) do
        local file = path.join(sdkfiles.framework_root(sdk, name), name .. ".tbd")
        if os.isfile(file) then
            read_exports(io.readfile(file), public)
            read = read + 1
        end
    end
    return public, read
end

function build(frameworks, sdk)
    local public = from_facts(frameworks)
    local names = sdkfiles.framework_names(sdk)
    local exported, read = from_tbd(sdk, names)
    assert(read > 0, "the SDK at " .. sdk .. " has no framework .tbd to read its exports from")
    for name in pairs(exported.classes) do
        public.classes[name] = true
    end
    for name in pairs(exported.symbols) do
        public.symbols[name] = true
    end
    return public, read, #names
end
