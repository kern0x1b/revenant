local files = import("files", {anonymous = true})
local sdk_modules = import("sdk_modules", {anonymous = true})

local injected = nil

function use(source)
    injected = source
end

local DOCUMENT_MARK = "--- !tapi-tbd"

local function next_slice(document, pos)
    local archs_start, archs_end, archs_at = string.find(document, "\n%s*%-%s+()archs:", pos)
    local targets_start, targets_end, targets_at = string.find(document, "\n%s*%-%s+()targets:", pos)
    if archs_start == nil and targets_start == nil then
        return nil
    end
    if targets_start == nil or (archs_start ~= nil and archs_start < targets_start) then
        return archs_at, archs_end
    end
    return targets_at, targets_end
end

local function slices_of(document)
    local starts = {}
    local at, after = next_slice(document, 1)
    while at ~= nil do
        table.insert(starts, at)
        at, after = next_slice(document, after)
    end
    local out = {}
    for i, start in ipairs(starts) do
        local stop = starts[i + 1] and (starts[i + 1] - 1) or #document
        table.insert(out, string.sub(document, start, stop))
    end
    return out
end

local function slice_names(block)
    local list = string.match(block, "^archs:%s*%[([^%]]*)%]") or string.match(block, "^targets:%s*%[([^%]]*)%]")
    if list == nil then
        return nil
    end
    local names = {}
    for name in string.gmatch(list .. ",", "([^,]*),") do
        table.insert(names, (string.gsub(string.gsub(name, "^%s+", ""), "%s+$", "")))
    end
    return names
end

local function is_arm64(names)
    for _, name in ipairs(names) do
        if name == "arm64" or string.sub(name, 1, 6) == "arm64-" then
            return true
        end
    end
    return false
end

local function add_list(block, key, into)
    local _, after = string.find(block, "\n%s*" .. key .. ":%s*%[")
    if after == nil then
        return
    end
    local close = string.find(block, "]", after, true)
    assert(close, "a " .. key .. " list is not closed in a .tbd slice")
    local text = string.gsub(string.sub(block, after + 1, close - 1), "\n", " ")
    for item in string.gmatch(text .. ",", "([^,]*),") do
        local name = string.gsub(string.gsub(item, "^%s+", ""), "%s+$", "")
        if name ~= "" then
            into[name] = true
        end
    end
end

function framework_dir(sdk, fw)
    return sdk_modules.root_of(sdk, fw)
end

local function check_sdk(sdk, fw)
    if not os.isfile(path.join(sdk, "SDKSettings.plist")) then
        raise("--sdk %s is not an SDK: it has no SDKSettings.plist", sdk)
    end
    if sdk_modules.module_of(sdk, fw) == nil then
        raise("--sdk %s holds no module %s", sdk, fw)
    end
end

local function arm64_slices(text)
    local out = {}
    local pos = 1
    while true do
        local mark = string.find(text, DOCUMENT_MARK, pos, true)
        if mark == nil then
            break
        end
        local start = mark + #DOCUMENT_MARK
        local stop_mark = string.find(text, DOCUMENT_MARK, start, true)
        local document = string.sub(text, start, (stop_mark or (#text + 1)) - 1)
        for _, block in ipairs(slices_of(document)) do
            local names = slice_names(block)
            if names ~= nil and is_arm64(names) then
                table.insert(out, block)
            end
        end
        pos = stop_mark or (#text + 1)
    end
    return out
end

local function strip_underscores(symbols)
    local stripped = {}
    for name in pairs(symbols) do
        stripped[string.sub(name, 1, 1) == "_" and string.sub(name, 2) or name] = true
    end
    return stripped
end

function exports(sdk, fw)
    if injected then
        return injected(fw), {}, true
    end
    check_sdk(sdk, fw)
    local symbols, classes = {}, {}
    local files_read = sdk_modules.export_files(sdk, fw)
    for _, file in ipairs(files_read) do
        for _, block in ipairs(arm64_slices(files.read_text(file) or "")) do
            add_list(block, "symbols", symbols)
            add_list(block, "objc%-classes", classes)
        end
    end
    return strip_underscores(symbols), classes, #files_read > 0
end

local function symbols_of(text, into)
    for _, block in ipairs(arm64_slices(text)) do
        add_list(block, "symbols", into)
    end
    return into
end

function all_symbols(sdk)
    assert(os.isfile(path.join(sdk, "SDKSettings.plist")), "--sdk " .. sdk .. " is not an SDK: it has no SDKSettings.plist")
    local symbols = {}
    for _, tbd_path in ipairs(os.files(path.join(sdk, "**.tbd"))) do
        local text = files.read_text(tbd_path)
        if text ~= nil then
            symbols_of(text, symbols)
        end
    end
    return strip_underscores(symbols)
end

function class_exports(sdk, fw)
    check_sdk(sdk, fw)
    local classes, done = {}, {}
    local todo = sdk_modules.export_files(sdk, fw)
    while #todo > 0 do
        local tbd_path = table.remove(todo)
        if not done[tbd_path] then
            done[tbd_path] = true
            local text = files.read_text(tbd_path)
            if text ~= nil then
                for _, block in ipairs(arm64_slices(text)) do
                    add_list(block, "objc%-classes", classes)
                    local reexports = {}
                    add_list(block, "re%-exports", reexports)
                    for target in pairs(reexports) do
                        table.insert(todo, path.join(sdk, (string.gsub(target, "^/", "")) .. ".tbd"))
                    end
                end
            end
        end
    end
    return classes
end
