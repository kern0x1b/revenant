-- The round trip of the Swift skeleton (swift_render.lua), the proof that the rendered text means what the SDK means: a module
-- rendered from the SDK's model is compiled with xcrun swiftc under its own name, dumped with the digester (its folder ahead of the
-- SDK on the search path) and the model of that dump is compared with the SDK's on the key (kind, usr, container, name, side) and
-- the signature cells. A module that does not compile may give no dump: the digester cannot load a module with an unresolved type
-- (an error type), so its first error is the result and no row is compared. The build products are never committed.

local heavy_batch = import("heavy_batch", {anonymous = true})
local swift_render = import("swift_render", {anonymous = true})
local json = import("core.base.json")

local NO_VALUE = "-"
-- The cells a declaration's signature is made of, besides its key. The model's own cells: the digester's, read from the dump.
local SIGNATURE = {"type", "params", "generic_sig", "conformances", "superclass", "throwing", "async", "mutating", "attributes",
                   "accessors", "storage", "is_let", "is_open", "requirement", "in_extension", "owner_module", "raw", "alias",
                   "overriding", "init_kind", "availability"}
-- The tab joins the key's cells: no declaration name holds one.
local KEY_SEPARATOR = "\t"
-- The key a witness is recorded by in the renderer (swift_render's witnessed set): the container and the name, tab-joined.
local WITNESS_SEPARATOR = "\t"
-- The cells that are lists (comma-joined): compared as sets. The dump's order of a list is not a difference of the declaration, and
-- the dump repeats a platform attribute once per platform (Available, Available, ...), which is one attribute in ours.
local LIST_CELLS = {conformances = true, attributes = true}
local LIST_SEPARATOR = ","

-- The key of a row: its kind, usr, container, name and side.
local function key_of(row)
    return table.concat({row.kind, row.usr, row.container, row.name, row.side}, KEY_SEPARATOR)
end

-- The items of a list cell, in order; none for a missing or "-" cell.
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

-- A cell's value as the comparison reads it: a list cell is its sorted set of items, every other cell is its value.
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

-- The by-design difference: the renderer writes a stored property as a computed one (the skeleton has no initializer), so the SDK
-- says the declaration has storage and ours does not. A let is always stored, and the digester gives the storage its own attributes
-- (HasStorage, HasInitialValue, ReferenceOwnership): those cells are the same difference, counted on their own line, not a mismatch.
local STORED_CELLS = {storage = true, is_let = true}
local STORAGE_ATTRIBUTES = {HasStorage = true, HasInitialValue = true, ReferenceOwnership = true}

-- Whether a row is a stored declaration that ours renders computed: the SDK says storage and ours says none.
local function rendered_computed(sdk_row, our_row)
    return sdk_row.storage == "yes" and our_row.storage == NO_VALUE
end

-- Whether a cell's difference is the by-design one: a stored cell the SDK says yes to and ours says nothing to.
local function by_design(cell, sdk_value, our_value, computed)
    return computed and STORED_CELLS[cell] ~= nil and sdk_value == "yes" and our_value == NO_VALUE
end

-- A list cell less the given items: "-" when none is left.
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

-- A row's label for a report: its kind and its api (container and name, or the name).
local function label_of(row)
    local api = row.container ~= NO_VALUE and (row.container .. "." .. row.name) or row.name
    return row.kind .. " " .. api
end

-- The diagnostics of a compiler's output: how many errors it printed and the first one, or 0 and nil.
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

-- The folder a module's own ObjC part is compiled from, as the compiler's framework search path, or nil when the generated headers have
-- none for it. The folder holds a link to that one framework and nothing else: the headers tree has every framework, and a search path
-- over all of them shadows the SDK's (CoreFoundation's headers then fail to build). The module's own name is its clang module, so the
-- compile imports it as the underlying module (compile_item).
function underlying_of(headers, module_dir, name)
    local framework = path.join(headers, "Frameworks", name .. ".framework")
    if not os.isfile(path.join(framework, "Modules", "module.modulemap")) then
        return nil
    end
    local folder = path.join(module_dir, "underlying")
    os.mkdir(folder)
    local link = path.join(folder, name .. ".framework")
    -- the link's target is absolute: a relative one is read from the link's folder, and the compile would not find the framework
    if not os.exists(link) then
        os.ln(path.absolute(framework), link)
    end
    return folder
end

-- The compile of a rendered source under its module name into module_dir, as a batch item (heavy_batch.run): its shell text, with both
-- output streams in <module_dir>/compile.log. The compiler admits a module with errors (so the dump can still be read when the errors are
-- not error types). underlying (underlying_of's folder, or nil) is the framework search path of the module's own ObjC part: the module
-- imports it as its underlying clang module, so its Swift declarations see the ObjC ones.
function compile_item(triple, sdk, source, module_dir, name, underlying)
    -- -enable-builtin-module: the explicit import of Builtin (the skeleton's import Builtin, for the stdlib modules' Builtin.Executor) is
    -- refused without it; the flag changes nothing else
    local words = {"xcrun", "swiftc", "-parse-as-library", "-Xfrontend", "-experimental-allow-module-with-compiler-errors",
                   "-Xfrontend", "-enable-builtin-module", "-emit-module", "-module-name", name, "-target", triple, "-sdk", sdk,
                   "-emit-module-path", path.join(module_dir, name .. ".swiftmodule"), source}
    if underlying ~= nil then
        table.insert(words, "-F")
        table.insert(words, underlying)
        table.insert(words, "-import-underlying-module")
    end
    local quoted = {}
    for i, word in ipairs(words) do
        quoted[i] = heavy_batch.quote(word)
    end
    local log = path.join(module_dir, "compile.log")
    return {base = path.join(module_dir, "compile"), command = table.concat(quoted, " ") .. " > " .. heavy_batch.quote(log) .. " 2>&1"}
end

-- The result of a module's compile batch item: the number of errors in its log, the first one, and the exit status. Raises when the batch
-- gave the compile no status (the batch stopped first), so the module is recorded as not measured.
function compile_result(module_dir)
    local base = path.join(module_dir, "compile")
    if not os.isfile(base .. ".status") then
        raise("the compiler did not run (the batch stopped first)")
    end
    local status = tonumber((string.gsub(io.readfile(base .. ".status"), "%s+$", "")))
    local count, first = diagnostics(io.readfile(base .. ".log") or "")
    return count, first, status
end

-- The digester's dump of a module compiled into module_dir, with that folder ahead of the SDK, as a batch item: its JSON to
-- <module_dir>/dump.json and its error output to <module_dir>/dump.err.
function dump_item(triple, sdk, module_dir, name)
    local words = {"xcrun", "swift-api-digester", "-dump-sdk", "-module", name, "-I", module_dir, "-target", triple, "-sdk", sdk,
                   "-avoid-location", "-avoid-tool-args", "-o", path.join(module_dir, "dump.json")}
    local quoted = {}
    for i, word in ipairs(words) do
        quoted[i] = heavy_batch.quote(word)
    end
    -- a JSON of an earlier run is removed: a digester that exits 0 without writing one must not have its old dump read
    local json_path = path.join(module_dir, "dump.json")
    if os.isfile(json_path) then
        os.rm(json_path)
    end
    local err = path.join(module_dir, "dump.err")
    return {base = path.join(module_dir, "dump"), command = table.concat(quoted, " ") .. " 2> " .. heavy_batch.quote(err)}
end

-- The digester's dump of a module from its batch item. Returns the JSON root, or nil and the reason: the digester's exit status and the
-- tail of its error output (a crash on an error type is one of these).
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

-- Compares the SDK's model rows with ours. Returns a result: the row counts, the rows equal on every signature cell, the rows
-- missing from ours, the count of ours with no SDK row, the rows that differ, counted per cell, and one example per cell. A row
-- whose only difference is a by-design one is equal (counted in by_design as well): its difference is not a mismatch.
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
            -- a projected value is synthesized from its property wrapper, so the skeleton does not declare it: by design
            if swift_render.projected(row) then
                result.projected = result.projected + 1
            elseif swift_render.attributed_row(row, attributed) then
                -- a row naming a module that depends on this one belongs to that module in the SDK: the skeleton leaves it out
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
            -- a witness the skeleton declares for an ObjC or Foundation protocol is a member the SDK's model does not give: by design
            if witnessed and witnessed[row.container .. WITNESS_SEPARATOR .. row.name] then
                result.witnessed = result.witnessed + 1
            else
                result.extra = result.extra + 1
            end
        end
    end
    return result
end
