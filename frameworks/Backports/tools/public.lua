local sdkfiles = import("sdk", {rootdir = os.scriptdir(), anonymous = true})

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

local function dyld_module()
    local modules = path.join(sdkfiles.root(), "toolchain", "modules", "apple")
    return import("dyld", {rootdir = modules, anonymous = true})
end

local function from_tbd(sdk)
    local exported = {classes = {}, symbols = {}}
    local count = 0
    for symbol in pairs(dyld_module().sdk_owners(sdk)) do
        count = count + 1
        local class = symbol:match("^_OBJC_CLASS_%$_(.+)$")
        if class then
            exported.classes[class] = true
        elseif not symbol:find("^_OBJC_") then
            exported.symbols[symbol:sub(2)] = true
        end
    end
    assert(count > 0, "the SDK at " .. sdk .. " exports no symbol in any framework .tbd")
    exported.count = count
    return exported
end

function build(frameworks, sdk)
    local declared = from_facts(frameworks)
    local exported = from_tbd(sdk)
    local public = {classes = {}, symbols = {}, methods = declared.methods}
    for name in pairs(declared.classes) do
        if exported.classes[name] then
            public.classes[name] = true
        end
    end
    for name in pairs(declared.symbols) do
        if exported.symbols[name] then
            public.symbols[name] = true
        end
    end
    return public, exported.count
end
