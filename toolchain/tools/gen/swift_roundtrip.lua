local batch = import("batch", {anonymous = true})
local swift_render = import("swift_render", {anonymous = true})
local json = import("core.base.json")

local NO_VALUE = "-"
local SIGNATURE = {"type", "params", "generic_sig", "conformances", "superclass", "throwing", "async", "mutating", "attributes",
                   "accessors", "storage", "is_let", "is_open", "requirement", "in_extension", "owner_module", "raw", "alias",
                   "overriding", "init_kind", "availability"}
local KEY_SEPARATOR = "\t"
local WITNESS_SEPARATOR = "\t"
local LIST_CELLS = {conformances = true, attributes = true}
local LIST_SEPARATOR = ","

local function key_of(row)
    return table.concat({row.kind, row.usr, row.container, row.name, row.side}, KEY_SEPARATOR)
end

local function items_of(value)
    local items = {}
    if value == nil or value == NO_VALUE then
        return items
    end
    for item in string.gmatch(value, "[^" .. LIST_SEPARATOR .. "]+") do
        table.insert(items, item)
    end
    return items
end

local function canonical(cell, value)
    if not LIST_CELLS[cell] or value == nil or value == NO_VALUE then
        return value
    end
    local seen, unique = {}, {}
    for _, item in ipairs(items_of(value)) do
        if not seen[item] then
            seen[item] = true
            table.insert(unique, item)
        end
    end
    table.sort(unique)
    return table.concat(unique, LIST_SEPARATOR)
end

local STORED_CELLS = {storage = true, is_let = true}
local STORAGE_ATTRIBUTES = {HasStorage = true, HasInitialValue = true, ReferenceOwnership = true}

local function rendered_computed(sdk_row, our_row)
    return sdk_row.storage == "yes" and our_row.storage == NO_VALUE
end

local function by_design(cell, sdk_value, our_value, computed)
    return computed and STORED_CELLS[cell] ~= nil and sdk_value == "yes" and our_value == NO_VALUE
end

local function without(value, dropped)
    local kept = {}
    for _, item in ipairs(items_of(value)) do
        if not dropped[item] then
            table.insert(kept, item)
        end
    end
    if #kept == 0 then
        return NO_VALUE
    end
    return table.concat(kept, LIST_SEPARATOR)
end

local function label_of(row)
    local api = row.container ~= NO_VALUE and (row.container .. "." .. row.name) or row.name
    return row.kind .. " " .. api
end

function diagnostics(text)
    local count, first = 0, nil
    for line in string.gmatch(text or "", "[^\n]+") do
        if string.find(line, ": error: ", 1, true) then
            count = count + 1
            first = first or line
        end
    end
    return count, first
end

function underlying_of(headers, module_dir, name)
    local framework = path.join(headers, "Frameworks", name .. ".framework")
    if not os.isfile(path.join(framework, "Modules", "module.modulemap")) then
        return nil
    end
    local folder = path.join(module_dir, "underlying")
    os.mkdir(folder)
    local link = path.join(folder, name .. ".framework")
    if not os.exists(link) then
        os.ln(path.absolute(framework), link)
    end
    return folder
end

function compile_item(triple, sdk, source, module_dir, name, underlying)
    local words = {"xcrun", "swiftc", "-parse-as-library", "-Xfrontend", "-experimental-allow-module-with-compiler-errors",
                   "-Xfrontend", "-enable-builtin-module", "-emit-module", "-module-name", name, "-target", triple, "-sdk", sdk,
                   "-emit-module-path", path.join(module_dir, name .. ".swiftmodule"), source}
    if underlying ~= nil then
        table.insert(words, "-F")
        table.insert(words, underlying)
        table.insert(words, "-import-underlying-module")
    elseif os.isfile(path.join(sdk, "usr", "include", name, "module.modulemap")) then
        table.insert(words, "-import-underlying-module")
    end
    local quoted = {}
    for i, word in ipairs(words) do
        quoted[i] = batch.quote(word)
    end
    local log = path.join(module_dir, "compile.log")
    return {base = path.join(module_dir, "compile"), command = table.concat(quoted, " ") .. " > " .. batch.quote(log) .. " 2>&1"}
end

function compile_result(module_dir)
    local base = path.join(module_dir, "compile")
    if not os.isfile(base .. ".status") then
        raise("the compiler did not run (the batch stopped first)")
    end
    local status = tonumber((string.gsub(io.readfile(base .. ".status"), "%s+$", "")))
    local count, first = diagnostics(io.readfile(base .. ".log") or "")
    return count, first, status
end

function dump_item(triple, sdk, module_dir, name)
    local words = {"xcrun", "swift-api-digester", "-dump-sdk", "-module", name, "-I", module_dir, "-target", triple, "-sdk", sdk,
                   "-avoid-location", "-avoid-tool-args", "-o", path.join(module_dir, "dump.json")}
    local quoted = {}
    for i, word in ipairs(words) do
        quoted[i] = batch.quote(word)
    end
    local json_path = path.join(module_dir, "dump.json")
    if os.isfile(json_path) then
        os.rm(json_path)
    end
    local err = path.join(module_dir, "dump.err")
    return {base = path.join(module_dir, "dump"), command = table.concat(quoted, " ") .. " 2> " .. batch.quote(err)}
end

function dump_result(module_dir)
    local base = path.join(module_dir, "dump")
    if not os.isfile(base .. ".status") then
        return nil, "the digester did not run (the batch stopped first)"
    end
    local status = string.gsub(io.readfile(base .. ".status"), "%s+$", "")
    if status ~= "0" then
        return nil, string.format("the digester exited %s: %s", status, string.sub(io.readfile(base .. ".err") or "", -200))
    end
    local handle = io.open(path.join(module_dir, "dump.json"), "rb")
    if handle == nil then
        return nil, "the digester wrote no dump"
    end
    local payload = json.decode(handle:read("a"))
    handle:close()
    if payload == nil or payload.ABIRoot == nil then
        return nil, "the digester wrote no ABI root"
    end
    return payload.ABIRoot
end

function compare(sdk_rows, our_rows, witnessed, attributed)
    local ours, duplicates = {}, 0
    for _, row in ipairs(our_rows) do
        local key = key_of(row)
        if ours[key] then
            duplicates = duplicates + 1
        else
            ours[key] = row
        end
    end
    local result = {sdk = #sdk_rows, ours = #our_rows, equal = 0, missing = {}, extra = 0, duplicates = duplicates,
                    by_design = 0, witnessed = 0, projected = 0, attributed = 0, causes = {}, examples = {}}
    local matched = {}
    for _, row in ipairs(sdk_rows) do
        local key = key_of(row)
        local other = ours[key]
        if other == nil then
            if swift_render.projected(row) then
                result.projected = result.projected + 1
            elseif swift_render.attributed_row(row, attributed) then
                result.attributed = result.attributed + 1
            else
                table.insert(result.missing, label_of(row))
            end
        else
            matched[key] = true
            local differs, designed = false, false
            local computed = rendered_computed(row, other)
            for _, cell in ipairs(SIGNATURE) do
                local sdk_cell = row[cell]
                if computed and cell == "attributes" then
                    sdk_cell = without(sdk_cell, STORAGE_ATTRIBUTES)
                end
                local sdk_value, our_value = canonical(cell, sdk_cell), canonical(cell, other[cell])
                if sdk_value ~= our_value then
                    if by_design(cell, sdk_value, our_value, computed) then
                        designed = true
                    else
                        differs = true
                        result.causes[cell] = (result.causes[cell] or 0) + 1
                        if result.examples[cell] == nil then
                            result.examples[cell] = string.format("%s: sdk %s, ours %s", label_of(row), tostring(row[cell]),
                                                                  tostring(other[cell]))
                        end
                    end
                end
            end
            if designed then
                result.by_design = result.by_design + 1
            end
            if not differs then
                result.equal = result.equal + 1
            end
        end
    end
    for key, row in pairs(ours) do
        if not matched[key] then
            if witnessed and witnessed[row.container .. WITNESS_SEPARATOR .. row.name] then
                result.witnessed = result.witnessed + 1
            else
                result.extra = result.extra + 1
            end
        end
    end
    return result
end
