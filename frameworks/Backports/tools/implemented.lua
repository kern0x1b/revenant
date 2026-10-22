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
