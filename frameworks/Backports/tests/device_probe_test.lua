local PROVIDERS = {
    {prefix = "IOSurface", names = {"IOSurfaceBackports", "IOSurface"}},
    {prefix = "CV", names = {"CoreVideo"}},
}

local PROBES = {
    {name = "BackportsDeviceProbe", defines = {}, classes = true},
    {name = "BackportsSceneKitProbe", defines = {REVENANT_PROBE_SCENEKIT = true}, classes = false},
}

local function relative(backports, file)
    return file:sub(#backports + 2)
end

local function listed(backports, xmake)
    local body = xmake:match("local DEVICE_PROBE_SOURCES = {(.-)}")
    assert(body, "frameworks/Backports/xmake.lua names no DEVICE_PROBE_SOURCES, so the device probes cannot be checked")
    local files = {}
    for entry in body:gmatch('"([^"]+)"') do
        if entry:find("*", 1, true) then
            for _, file in ipairs(os.files(path.join(backports, entry))) do
                table.insert(files, path.absolute(file))
            end
        else
            table.insert(files, path.absolute(path.join(backports, entry)))
        end
    end
    return files
end

local function code(text, defines)
    local kept, stack = {}, {}
    local function live()
        for _, on in ipairs(stack) do
            if not on then
                return false
            end
        end
        return true
    end
    for line in (text .. "\n"):gmatch("(.-)\n") do
        local directive, macro = line:match("^%s*#%s*(%a+)%s*([%w_]*)")
        if directive == "ifdef" then
            table.insert(stack, defines[macro] == true)
        elseif directive == "ifndef" then
            table.insert(stack, defines[macro] ~= true)
        elseif directive == "if" then
            table.insert(stack, true)
        elseif directive == "else" and #stack > 0 then
            stack[#stack] = not stack[#stack]
        elseif directive == "endif" then
            table.remove(stack)
        elseif live() then
            table.insert(kept, line)
        end
    end
    local stripped = table.concat(kept, "\n"):gsub("/%*.-%*/", "")
    stripped = stripped:gsub("//[^\n]*", "")
    return (stripped:gsub('"[^"\n]*"', ""))
end

local function definitions(backports)
    local functions, classes = {}, {}
    local function add(index, name, file)
        index[name] = index[name] or {}
        if not table.contains(index[name], file) then
            table.insert(index[name], file)
        end
    end
    for _, pattern in ipairs({"**.m", "**.mm", "**.c", "**.cpp"}) do
        for _, file in ipairs(os.files(path.join(backports, "src", pattern))) do
            for line in io.readfile(file):gmatch("[^\n]+") do
                local name = line:match("^[%a_][^(]-%f[%w_](revenant_[%w_]+)%s*%(")
                if name and not line:find("^static") and not line:find(";%s*$") then
                    add(functions, name, file)
                end
                local class = line:match("^@implementation%s+([%w_]+)%s*{?%s*$")
                if class then
                    add(classes, class, file)
                end
            end
        end
    end
    return functions, classes
end

local function closure(backports, files, defines, functions, classes)
    local included, order, errors = {}, {}, {}
    local function include(file)
        if not included[file] then
            included[file] = true
            table.insert(order, file)
        end
    end
    for _, file in ipairs(files) do
        include(file)
    end
    local kinds = {{pattern = "%f[%w_](revenant_[%w_]+)", index = functions}}
    if classes then
        table.insert(kinds, {pattern = "%f[%w_]([%u][%w_]*)", index = classes})
    end
    local position = 1
    while position <= #order do
        local file = order[position]
        position = position + 1
        local text = code(io.readfile(file), defines)
        local seen = {}
        for _, kind in ipairs(kinds) do
            for name in text:gmatch(kind.pattern) do
                if not seen[name] and kind.index[name] then
                    seen[name] = true
                    local covered = false
                    for _, definer in ipairs(kind.index[name]) do
                        covered = covered or included[definer] ~= nil
                    end
                    if not covered then
                        local definer = kind.index[name][1]
                        table.insert(errors, string.format("%s uses %s, which %s defines, but no device probe lists that file",
                                                           relative(backports, file), name, relative(backports, definer)))
                        include(definer)
                    end
                end
            end
        end
    end
    return errors, order
end

local function names_in(block, names)
    for _, name in ipairs(names) do
        if block:find('["\',]' .. name .. '["\']') then
            return true
        end
    end
    return false
end

local function used_providers(backports, order)
    local used = {}
    for _, file in ipairs(order) do
        local text = code(io.readfile(file), {})
        for _, provider in ipairs(PROVIDERS) do
            if text:find("%f[%w_]" .. provider.prefix .. "%u") then
                used[provider.prefix] = true
            end
        end
    end
    return used
end

local function probe_errors(xmake, probe, used)
    local block = xmake:match('target%("' .. probe.name .. '"%).-target_end%(%)')
    if not block then
        return {probe.name .. " is not defined in frameworks/Backports/xmake.lua"}
    end
    if not block:find("DEVICE_PROBE_SOURCES", 1, true) then
        return {probe.name .. " does not add DEVICE_PROBE_SOURCES, so its sources are not the list that is checked"}
    end
    local errors = {}
    for _, provider in ipairs(PROVIDERS) do
        if used[provider.prefix] and not names_in(block, provider.names) then
            table.insert(errors, string.format("%s uses %s symbols but names none of %s", probe.name, provider.prefix, table.concat(provider.names, ", ")))
        end
    end
    return errors
end

function main()
    local backports = path.absolute(path.join(os.scriptdir(), ".."))
    local xmake = io.readfile(path.join(backports, "xmake.lua"))
    local functions, classes = definitions(backports)

    local alone = closure(backports, {path.join(backports, "src", "UIKit", "UIView+iOS13.m")}, {}, functions)
    assert(#alone > 0, "a list of UIView+iOS13.m alone is not reported, although it calls a revenant_ function defined in another file")

    local errors = {}
    for _, probe in ipairs(PROBES) do
        local found, order = closure(backports, listed(backports, xmake), probe.defines, functions, probe.classes and classes or nil)
        for _, message in ipairs(found) do
            table.insert(errors, probe.name .. ": " .. message)
        end
        for _, message in ipairs(probe_errors(xmake, probe, used_providers(backports, order))) do
            table.insert(errors, message)
        end
    end
    assert(#errors == 0, "the device probes would not link:\n  " .. table.concat(errors, "\n  "))
end
