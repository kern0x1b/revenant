local sdkfiles = import("sdk", {rootdir = os.scriptdir(), anonymous = true})
local reader = import("reader", {rootdir = os.scriptdir(), anonymous = true})

local function add(keys, framework, key)
    keys[framework] = keys[framework] or {}
    keys[framework][key] = true
end

local function symbol(keys, framework, line)
    local letter, name = line:match("^%s*%x*%s*(%a) (%S+)$")
    if name and name:sub(1, 1) == "_" then
        local class = name:match("^_OBJC_CLASS_%$_(.+)$")
        if class and (letter == "S" or letter == "D") then
            add(keys, framework, "class||" .. class)
        elseif name:find("^_%$s") and letter ~= "U" then
            add(keys, framework, "swift symbol||" .. name:sub(2))
        elseif not name:find("^_OBJC") then
            if letter == "T" then
                add(keys, framework, "C function||" .. name:sub(2))
            elseif letter == "D" or letter == "S" then
                add(keys, framework, "global variable||" .. name:sub(2))
            end
        end
    end
end

local function method(keys, framework, line)
    local sign, container, selector = line:match("^%x+ %a ([%+%-])%[(%S+) ([^%]]+)%]$")
    if sign then
        local class = container:match("^[^(]+")
        add(keys, framework, (sign == "+" and "class method" or "instance method") .. "|" .. class .. "|" .. selector)
    end
end

function defined_protocols()
    local names = {}
    local text = os.iorunv("/usr/bin/grep", {"-rhoE", "--include=*.m", "--include=*.mm", "--include=*.h",
        "^@protocol [A-Za-z_][A-Za-z0-9_]*[^;]*$", sdkfiles.src_root()})
    for line in text:gmatch("[^\n]+") do
        local name = string.match(line, "^@protocol ([%w_]+)")
        if name then
            names[name] = true
        end
    end
    return names
end

function from_objects(root)
    local keys = {}
    root = root or path.join(sdkfiles.root(), "build", ".objs")
    local objects, frameworks = {}, {}
    for _, object in ipairs(os.files(path.join(root, "**.o"))) do
        local framework = string.match(object, "/src/([^/]+)/[^/]+%.o$")
        if framework then
            table.insert(objects, object)
            frameworks[object] = framework
        end
    end
    assert(#objects > 0, "no objects of a src/<Framework> folder under " .. root)
    reader.each_output("nm", {}, objects, function (object, line)
        symbol(keys, frameworks[object], line)
        method(keys, frameworks[object], line)
    end)
    local total = 0
    for _, set in pairs(keys) do
        for _ in pairs(set) do
            total = total + 1
        end
    end
    assert(total > 0, "no member of a src/<Framework> object under " .. root)
    return keys
end

local function lowered_into(keys, set)
    keys.lowered = keys.lowered or {}
    local found = keys.lowered
    for class, members in pairs(set.classes) do
        found["class||" .. class] = true
        for member in pairs(members) do
            local sign, selector = member:match("^([%+%-])(.+)$")
            if sign then
                found[(sign == "+" and "class method" or "instance method") .. "|" .. class .. "|" .. selector] = true
            end
        end
    end
    for name in pairs(set.functions) do
        found["C function||" .. name] = true
    end
    for name in pairs(set.globals) do
        found["global variable||" .. name] = true
        found["enum constant||" .. name] = true
    end
end

local SWIFT_KINDS = {class = true, struct = true, enum = true, protocol = true, actor = true}

function swift_types(src)
    local names = {}
    for _, file in ipairs(os.files(path.join(src, "**.swift"))) do
        for line in io.readfile(file):gmatch("[^\n]+") do
            local words, public = {}, false
            for word in line:gmatch("[%w_]+") do
                table.insert(words, word)
            end
            for index, word in ipairs(words) do
                if word == "public" or word == "open" then
                    public = true
                elseif public and SWIFT_KINDS[word] and words[index + 1] then
                    names[words[index + 1]] = true
                end
            end
        end
    end
    return names
end

local COMPONENT_SOURCES = {SwiftUI = "frameworks/SwiftUI/src"}

function components(repository)
    local found = {swift = {}, folders = {}}
    for framework, relative in pairs(COMPONENT_SOURCES) do
        found.folders[framework] = true
        for name in pairs(swift_types(path.join(repository, relative))) do
            found.swift[name] = true
        end
    end
    return found
end

function registry(root, src, set)
    local keys = {}
    if #os.files(path.join(root, "**.o")) > 0 then
        keys = from_objects(root)
    end
    for _, folder in ipairs(os.dirs(path.join(src, "*"))) do
        local name = path.filename(folder)
        keys[name] = keys[name] or {}
    end
    lowered_into(keys, set)
    return keys
end
