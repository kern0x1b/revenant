local sdkfiles = import("sdk", {rootdir = os.scriptdir(), anonymous = true})

local TBD_KEYS = {["symbols"] = true, ["weak-symbols"] = true, ["objc-classes"] = true}

local function setter(name)
    return "set" .. string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2) .. ":"
end

local function from_facts(frameworks)
    local declared = {classes = {}, symbols = {}, methods = {}}
    for _, framework in ipairs(frameworks) do
        for _, row in ipairs(framework.rows) do
            if row.kind == "class" then
                declared.classes[row.name] = true
            elseif row.kind == "C function" or row.kind == "global variable" then
                declared.symbols[row.name] = true
            elseif row.kind == "instance method" or row.kind == "class method" then
                declared.methods[row.kind .. "|" .. row.container .. "|" .. row.name] = true
            elseif row.kind == "property" then
                declared.methods["instance method|" .. row.container .. "|" .. row.name] = true
                if string.find(row.signature, "^readonly ") == nil then
                    declared.methods["instance method|" .. row.container .. "|" .. setter(row.name)] = true
                end
            end
        end
    end
    return declared
end

local function each_export(text, visit)
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
                    visit(key, (token:gsub("['\"]", "")))
                end
                if close then
                    key = nil
                end
            end
        end
    end
end

local function read_exports(text, declared, exported)
    each_export(text, function (key, token)
        if key == "objc-classes" then
            if declared.classes[token] then
                exported.classes[token] = true
            end
        elseif token:sub(1, 1) == "_" then
            local class = token:match("^_OBJC_CLASS_%$_(.+)$")
            if class then
                if declared.classes[class] then
                    exported.classes[class] = true
                end
            elseif not token:find("^_OBJC_") and declared.symbols[token:sub(2)] then
                exported.symbols[token:sub(2)] = true
            end
        end
    end)
end

local function from_tbd(sdk, declared)
    local exported = {classes = {}, symbols = {}}
    local read = 0
    for _, name in ipairs(sdkfiles.framework_names(sdk)) do
        local file = path.join(sdkfiles.framework_root(sdk, name), name .. ".tbd")
        if os.isfile(file) then
            read_exports(io.readfile(file), declared, exported)
            read = read + 1
        end
    end
    assert(read > 0, "the SDK at " .. sdk .. " has no framework .tbd to read its exports from")
    return exported, read
end

function build(frameworks, sdk)
    local declared = from_facts(frameworks)
    local exported, read = from_tbd(sdk, declared)
    local public = {classes = exported.classes, symbols = exported.symbols, methods = declared.methods}
    local found = 0
    for _ in pairs(public.classes) do
        found = found + 1
    end
    for _ in pairs(public.symbols) do
        found = found + 1
    end
    return public, found, read
end

local function tbd_files(sdk)
    local files = {}
    for _, name in ipairs(sdkfiles.framework_names(sdk)) do
        table.insert(files, path.join(sdkfiles.framework_root(sdk, name), name .. ".tbd"))
    end
    for _, file in ipairs(os.files(path.join(sdk, "usr", "lib", "*.tbd"))) do
        table.insert(files, file)
    end
    return files
end

local function scan_images(sdk)
    local images = {}
    for _, file in ipairs(tbd_files(sdk)) do
        if os.isfile(file) then
            local text = io.readfile(file)
            local install = string.match(text, "install%-name:%s*['\"]?([^'\"\n]+)")
            if install then
                each_export(text, function (key, token)
                    if (key == "symbols" or key == "weak-symbols") and token:sub(1, 1) == "_" and not token:find("^_OBJC_") then
                        local name = token:sub(2)
                        if images[name] == nil then
                            images[name] = install:gsub("%s+$", "")
                        end
                    end
                end)
            end
        end
    end
    return images
end

function install_names(sdk)
    local file = path.join(sdkfiles.cache_folder(sdk), "install_names.tsv")
    local images = {}
    if os.isfile(file) then
        for line in io.lines(file) do
            local name, install = string.match(line, "^([^\t]+)\t(.+)$")
            assert(name, "a malformed install-name row in " .. file .. ": " .. line)
            images[name] = install
        end
        return images
    end
    images = scan_images(sdk)
    local names = {}
    for name in pairs(images) do
        table.insert(names, name)
    end
    table.sort(names)
    local rows = {}
    for _, name in ipairs(names) do
        table.insert(rows, name .. "\t" .. images[name])
    end
    os.mkdir(path.directory(file))
    io.writefile(file .. ".part", table.concat(rows, "\n") .. (#rows > 0 and "\n" or ""))
    os.mv(file .. ".part", file)
    return images
end
