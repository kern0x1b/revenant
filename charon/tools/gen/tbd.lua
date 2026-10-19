-- The .tbd exports of a framework's arm64 slice: the symbols and the Objective-C classes the framework exports, as two sets. A
-- .tbd is YAML-like text, read here as data with string.find and explicit splitting (not as a header). It holds several documents
-- (the framework, then the private frameworks it re-exports), and each document several slices: version 3 writes `archs:` and
-- version 4 writes `targets:`; a slice counts when one of its names is arm64 or starts with arm64-.

local files = import("files", {anonymous = true})
local sdk_modules = import("sdk_modules", {anonymous = true})

local injected = nil

-- Replaces the SDK's .tbd by source(fw), which returns the framework's symbols as a set, for the tests of the constant records.
function use(source)
    injected = source
end

local DOCUMENT_MARK = "--- !tapi-tbd"

-- The position of the next slice header at or after pos: a line break, blanks, "-", blanks, then archs: or targets:. Returns the
-- position of that header's word and the position after the word, or nil when there is none.
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

-- The slices of one document: each slice's text, from its header word to the next slice's header. The text before the first header
-- is not a slice (re.split(...)[1:] in tools/gen.py@52253c0650).
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

-- The names a slice header lists (archs: [ ... ] or targets: [ ... ]), or nil when the block is no slice header.
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

-- True when a slice's names include arm64 (arm64 or arm64-<platform>).
local function is_arm64(names)
    for _, name in ipairs(names) do
        if name == "arm64" or string.sub(name, 1, 6) == "arm64-" then
            return true
        end
    end
    return false
end

-- The items of a list field (key: [ ... ]) of a slice, added to the set. The field is the first one after a line break.
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

-- A path that is not an SDK is refused with the path in the message: no SDKSettings.plist at its root, or no module for the name.
-- Without this check a wrong --sdk reads as a framework with no exports, and that answer is wrong without a sign of it.
-- The folder of a module of the SDK (sdk_modules.lua: a framework's .framework folder, nested ones inside their outer one's Frameworks/;
-- a usr module's folder; a Swift module's folder). Nil when the SDK holds no such module.
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

-- The arm64 slices of every document of a .tbd text, each as its block of text (the slice's names, then its lists).
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

-- A set of symbols with the leading underscore dropped (the spec compares them so).
local function strip_underscores(symbols)
    local stripped = {}
    for name in pairs(symbols) do
        stripped[string.sub(name, 1, 1) == "_" and string.sub(name, 2) or name] = true
    end
    return stripped
end

-- The exports of a module's arm64 slices in the SDK: symbols (the leading underscore dropped, as the spec compares them) and
-- objc-classes, two sets keyed by name with the value true, and whether an export list was read at all (sdk_modules.export_files: the
-- module's own .tbd, or for a usr module the libraries its map links). With no list the sets are empty and the flag is false, so a caller
-- writes "no export list" and never "not exported".
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

-- The symbols of one .tbd text's arm64 slices, the underscore dropped, as a set.
local function symbols_of(text, into)
    for _, block in ipairs(arm64_slices(text)) do
        add_list(block, "symbols", into)
    end
    return into
end

-- The symbols every .tbd of the SDK exports on arm64: a framework's, a library's (usr/lib) or a private framework's. A C declaration the
-- release's cache lacks is absent from the release when the SDK exports it, whichever .tbd holds it (ledger.lua's absence rule). Each file
-- is read once per call; the result is a set keyed by the symbol with the underscore dropped.
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

-- The Objective-C classes the framework exports on arm64, and those of every framework its .tbd re-exports: ARKit.tbd re-exports
-- ARKitCore, ARKitFoundation and ARKitUI (in the SDK's PrivateFrameworks folder), and its classes are in those, not in ARKit's own
-- list. A re-exported path is read from the SDK as <path>.tbd, and each .tbd is read once (tbd_class_exports in tools/gen.py).
-- Empty when the framework has no .tbd in the SDK.
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
