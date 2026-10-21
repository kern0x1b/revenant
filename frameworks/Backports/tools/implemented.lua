local sdkfiles = import("sdk", {rootdir = os.scriptdir(), anonymous = true})

local function add(keys, framework, key)
    keys[framework] = keys[framework] or {}
    keys[framework][key] = true
end

local function classes_and_functions(keys, framework, object)
    for line in os.iorunv("nm", {object}):gmatch("[^\n]+") do
        local letter, name = line:match("^%s*%x*%s*(%a) (%S+)$")
        if name and name:sub(1, 1) == "_" then
            local class = name:match("^_OBJC_CLASS_%$_(.+)$")
            if class and (letter == "S" or letter == "D") then
                add(keys, framework, "class||" .. class)
            elseif not name:find("^_OBJC") then
                if letter == "T" then
                    add(keys, framework, "C function||" .. name:sub(2))
                elseif letter == "D" or letter == "S" then
                    add(keys, framework, "global variable||" .. name:sub(2))
                end
            end
        end
    end
end

local function methods(keys, framework, object)
    for line in os.iorunv("otool", {"-ov", object}):gmatch("[^\n]+") do
        if line:match("^%s+imp%s") then
            local sign, container, selector = line:match("([%+%-])%[(%S+) ([^%]]+)%]$")
            if sign then
                local class = container:match("^[^(]+")
                add(keys, framework, (sign == "+" and "class method" or "instance method") .. "|" .. class .. "|" .. selector)
            end
        end
    end
end

function from_objects(root)
    local keys = {}
    root = root or path.join(sdkfiles.root(), "build", ".objs")
    for _, object in ipairs(os.files(path.join(root, "**.o"))) do
        local framework = string.match(object, "/src/([^/]+)/[^/]+%.o$")
        if framework then
            classes_and_functions(keys, framework, object)
            methods(keys, framework, object)
        end
    end
    return keys
end
