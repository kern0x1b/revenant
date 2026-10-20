local swift_shard = import("swift_shard", {anonymous = true})
local swift_canonical = import("swift_canonical", {anonymous = true})
local sdk_info = import("sdk", {anonymous = true})
local digest = import("digest", {anonymous = true})
local order = import("order", {anonymous = true})
local files = import("files", {anonymous = true})
local tsv = import("tsv", {anonymous = true})

local DEMANGLER = "swift-demangle"
local NO_VALUE = "-"
local KIND_PREFIX = "swift-"
local ASYNC_MARKER = " async"
local TYPE_KINDS = {Class = "class", Struct = "struct", Enum = "enum", Protocol = "protocol", TypeAlias = "typealias"}
local PLATFORM_NAMES = {macosx = "macos"}
local MODEL_COLUMNS = {"framework", "kind", "usr", "container", "name", "side", "type", "params", "availability", "message",
                       "declhash", "mangled", "generic_sig", "conformances", "superclass", "throwing", "async", "mutating",
                       "attributes", "accessors", "storage", "is_let", "is_open", "requirement", "in_extension", "owner_module",
                       "raw", "alias", "overriding", "init_kind", "implicit"}

function columns()
    return MODEL_COLUMNS
end

function modules(sdk)
    return swift_shard.modules(sdk)
end

local FLAG_LINES = 12
local function public_name_of(filepath)
    local handle = io.open(filepath, "rb")
    if handle == nil then
        return nil
    end
    local found = nil
    for _ = 1, FLAG_LINES do
        local line = handle:read("l")
        if line == nil then
            break
        end
        found = string.match(line, "%-public%-module%-name ([%w_]+)")
        if found then
            break
        end
    end
    handle:close()
    return found
end

function public_modules(sdk)
    local out, seen = {}, {}
    for _, filepath in ipairs(files.glob(path.join(sdk, "**", "*.swiftinterface"))) do
        local module = string.match(filepath, "([^/]+)%.swiftmodule/[^/]+%.swiftinterface$")
        if module and not seen[module] then
            seen[module] = true
            local public = public_name_of(filepath)
            if public and public ~= module then
                out[module] = public
            end
        end
    end
    return out
end

function import_graph(sdk)
    local out = {}
    for _, filepath in ipairs(files.glob(path.join(sdk, "**", "*.swiftinterface"))) do
        local module = string.match(filepath, "([^/]+)%.swiftmodule/[^/]+%.swiftinterface$")
        if module and out[module] == nil then
            local imports = {}
            local handle = assert(io.open(filepath, "rb"), "cannot read " .. filepath)
            for line in handle:lines() do
                local rest = string.gsub(line, "^@_exported%s+", "")
                rest = string.gsub(rest, "^public%s+", "")
                local target = string.match(rest, "^import%s+([%w_]+)")
                if target then
                    imports[target] = true
                end
            end
            handle:close()
            out[module] = imports
        end
    end
    return out
end

function dependents_of(graph, module)
    local reverse = {}
    for from, targets in pairs(graph) do
        for to in pairs(targets) do
            reverse[to] = reverse[to] or {}
            table.insert(reverse[to], from)
        end
    end
    local out, queue = {}, {module}
    local seen = {[module] = true}
    local head = 1
    while head <= #queue do
        for _, from in ipairs(reverse[queue[head]] or {}) do
            if not seen[from] then
                seen[from] = true
                out[from] = true
                table.insert(queue, from)
            end
        end
        head = head + 1
    end
    return out
end

function associated_bounds(sdk)
    local out = {}
    for _, filepath in ipairs(files.glob(path.join(sdk, "**", "*.swiftinterface"))) do
        local module = string.match(filepath, "([^/]+)%.swiftmodule/[^/]+%.swiftinterface$")
        if module and out[module] == nil then
            local bounds = {}
            local current = nil
            local handle = assert(io.open(filepath, "rb"), "cannot read " .. filepath)
            for line in handle:lines() do
                local declared, primaries = string.match(line, "^public protocol ([%w_]+)<([^>]*)>")
                if declared == nil then
                    declared = string.match(line, "^public protocol ([%w_]+)")
                end
                if declared then
                    current = {associated = {}, primaries = primaries}
                    bounds[declared] = current
                elseif string.match(line, "^}") then
                    current = nil
                elseif current then
                    local name, bound = string.match(line, "^%s+associatedtype ([%w_]+)%s*:%s*(.-)%s*$")
                    if name then
                        current.associated[name] = string.match(bound, "^(.-)%s+where%s") or bound
                    end
                end
            end
            handle:close()
            out[module] = bounds
        end
    end
    return out
end

function clang_modules(sdk)
    local out = {}
    for _, filepath in ipairs(files.glob(path.join(sdk, "System", "Library", "Frameworks", "*.framework", "Modules", "module.modulemap"))) do
        local handle = assert(io.open(filepath, "rb"), "cannot read " .. filepath)
        for line in handle:lines() do
            local name = string.match(line, "^%s*framework%s+module%s+([%w_]+)")
            if name then
                out[name] = true
            end
        end
        handle:close()
    end
    local usr = path.join(sdk, "usr", "include", "module.modulemap")
    if os.isfile(usr) then
        local handle = assert(io.open(usr, "rb"), "cannot read " .. usr)
        for line in handle:lines() do
            local name = string.match(line, "^%s*extern%s+module%s+([%w_]+)")
            if name then
                out[name] = true
            end
        end
        handle:close()
    end
    return out
end

function module_set(sdk)
    local out = {Builtin = true}
    for _, name in ipairs(modules(sdk)) do
        out[name] = true
    end
    for name in pairs(clang_modules(sdk)) do
        out[name] = true
    end
    return out
end

function triple_of(sdk)
    return sdk_info.discover(sdk).triple
end

function heavy_path(coordination)
    if coordination then
        return path.join(coordination, "heavy.sh")
    end
    return path.join(os.getenv("HOME"), "Git", "projects", "ios", "coordination", "heavy.sh")
end

function prefetch(heavy, sdk, triple, names)
    return swift_shard.dump_batch(heavy, sdk, triple, names, "model")
end

local function dump(folder, framework, mode)
    return swift_shard.cached_root(folder, "model", framework, mode or "")
end

local function dash(value)
    if value == nil or value == "" then
        return NO_VALUE
    end
    if value == true then
        return "yes"
    end
    return value
end

local function availability_of(node)
    local tokens = {}
    for key, value in pairs(node) do
        local platform = type(key) == "string" and string.match(key, "^intro_(.+)$")
        if platform and type(value) == "string" then
            table.insert(tokens, (PLATFORM_NAMES[string.lower(platform)] or string.lower(platform)) .. "=" .. value)
        end
    end
    if #tokens == 0 then
        return NO_VALUE
    end
    table.sort(tokens)
    return table.concat(tokens, ",")
end

local function surface_kind(decl, in_type)
    if TYPE_KINDS[decl] then
        return TYPE_KINDS[decl]
    end
    if decl == "Func" then
        return in_type and "method" or "function"
    end
    if decl == "Constructor" or decl == "Subscript" then
        return "method"
    end
    if decl == "Var" then
        return in_type and "property" or "constant"
    end
    if decl == "EnumElement" then
        return "constant"
    end
    if decl == "AssociatedType" then
        return "associatedtype"
    end
    return nil
end

local function enum_payload(node)
    local usr = node.usr or ""
    local function returns_enum(fn)
        local first = (fn.children or {})[1]
        return first ~= nil and first.usr ~= nil and string.sub(usr, 1, #first.usr) == first.usr
    end
    local function find(n)
        for _, child in ipairs(n.children or {}) do
            if child.kind == "TypeFunc" then
                if returns_enum(child) then
                    return child
                end
                local inner = find(child)
                if inner then
                    return inner
                end
            end
        end
        return nil
    end
    local fn = find(node)
    if fn == nil then
        return NO_VALUE
    end
    local payload = {}
    for i = 2, #fn.children do
        if fn.children[i].name ~= "Metatype" then
            table.insert(payload, fn.children[i])
        end
    end
    if #payload == 1 and payload[1].name == "Tuple" then
        payload = payload[1].children or {}
    end
    local types = {}
    for _, child in ipairs(payload) do
        table.insert(types, child.printedName or child.name or NO_VALUE)
    end
    return #types > 0 and table.concat(types, " | ") or NO_VALUE
end

local function signature_of(node, decl)
    if decl == "EnumElement" then
        return NO_VALUE, enum_payload(node)
    end
    if decl ~= "Func" and decl ~= "Var" and decl ~= "Constructor" and decl ~= "Subscript" then
        return NO_VALUE, NO_VALUE
    end
    local children = {}
    for _, child in ipairs(node.children or {}) do
        table.insert(children, child.printedName or child.name or NO_VALUE)
    end
    if decl == "Constructor" then
        return NO_VALUE, #children > 0 and table.concat(children, " | ") or NO_VALUE
    end
    local params = {}
    for i = 2, #children do
        table.insert(params, children[i])
    end
    return children[1] or NO_VALUE, #params > 0 and table.concat(params, " | ") or NO_VALUE
end

local function conformances_of(node)
    local out = {}
    for _, c in ipairs(node.conformances or {}) do
        table.insert(out, c.printedName or c.name or NO_VALUE)
    end
    return #out > 0 and table.concat(out, ",") or NO_VALUE
end

local function superclass_of(node)
    local names = node.superclassNames
    if type(names) == "table" and #names > 0 then
        return table.concat(names, ",")
    end
    return NO_VALUE
end

local function accessors_of(node)
    local out = {}
    for _, a in ipairs(node.accessors or {}) do
        if a.accessorKind then
            table.insert(out, a.accessorKind)
        end
    end
    return #out > 0 and table.concat(out, ",") or NO_VALUE
end

local function attributes_of(node)
    local out = {}
    for _, a in ipairs(node.declAttributes or {}) do
        table.insert(out, a)
    end
    return #out > 0 and table.concat(out, ",") or NO_VALUE
end

local function qualified_names(node, out)
    if node.kind == "TypeNominal" and node.usr and node.printedName and out[node.usr] == nil then
        local name = string.match(node.printedName, "^[^.]+%.(.+)$")
        if name and not string.find(name, "[<%(%[ ]") then
            out[node.usr] = name
        end
    end
    for _, child in ipairs(node.children or {}) do
        qualified_names(child, out)
    end
    return out
end

local function type_api(node, label, container, qualified)
    local name = node.usr and qualified[node.usr]
    if name and string.match(name, "([^.]+)$") == label then
        return name
    end
    return container ~= NO_VALUE and (container .. "." .. label) or label
end

local function owner_module(node, framework)
    local module = node.moduleName
    if module == nil or module == framework then
        return NO_VALUE
    end
    return module
end

local function alias_of(node, decl)
    if decl ~= "TypeAlias" then
        return NO_VALUE
    end
    local child = (node.children or {})[1]
    return child and (child.printedName or child.name) or NO_VALUE
end

local function row_of(framework, decl, node, container, kind, name, async)
    local usr = node.usr or NO_VALUE
    local side = node.static and "+" or "-"
    local result, params = signature_of(node, decl)
    local availability = availability_of(node)
    local declhash = digest.digest(KIND_PREFIX .. kind, usr, container, name, side, result, params, NO_VALUE, NO_VALUE, NO_VALUE, "")
    local module = node.moduleName
    local foreign = module ~= nil and string.sub(module, 1, 2) == "__"
    return {
        framework = framework, kind = KIND_PREFIX .. kind, usr = usr, container = container, name = name, side = side,
        type = result, params = params, availability = availability, message = NO_VALUE, declhash = declhash,
        mangled = dash(node.mangledName), generic_sig = dash(node.genericSig), conformances = conformances_of(node),
        superclass = superclass_of(node), throwing = node.throwing and "yes" or NO_VALUE, async = async or NO_VALUE,
        mutating = dash(node.funcSelfKind), attributes = attributes_of(node), accessors = accessors_of(node),
        storage = node.hasStorage and "yes" or NO_VALUE, is_let = node.isLet and "yes" or NO_VALUE,
        is_open = node.isOpen and "yes" or NO_VALUE, requirement = node.protocolReq and "yes" or NO_VALUE,
        in_extension = node.isFromExtension and "yes" or NO_VALUE,
        owner_module = foreign and NO_VALUE or owner_module(node, framework),
        raw = dash(node.enumRawTypeName), alias = alias_of(node, decl), overriding = node.overriding and "yes" or NO_VALUE,
        init_kind = dash(node.init_kind), implicit = node.implicit and "yes" or NO_VALUE,
    }
end

local function walk(framework, nodes, container, qualified, rows)
    for _, node in ipairs(nodes or {}) do
        local decl = node.declKind
        local label = node.printedName or node.name
        local module = node.moduleName
        local foreign = module ~= nil and string.sub(module, 1, 2) == "__"
        local kind = surface_kind(decl, container ~= NO_VALUE)
        if kind and label and not foreign then
            if TYPE_KINDS[decl] then
                local api = type_api(node, label, container, qualified)
                local parent = string.match(api, "^(.*)%.[^.]+$") or NO_VALUE
                local leaf = string.match(api, "([^.]+)$")
                table.insert(rows, row_of(framework, decl, node, parent, kind, leaf))
                walk(framework, node.children, api, qualified, rows)
            else
                table.insert(rows, row_of(framework, decl, node, container, kind, label))
            end
        end
    end
end

function rows(root, framework)
    local out = {}
    walk(framework, root.children, NO_VALUE, qualified_names(root, {}), out)
    if #out == 0 then
        return nil, "the digester holds no Swift declaration of the module's own"
    end
    return out
end

local DEMANGLE_CHUNK = 500
function annotate_async(rows, batch)
    local demangle = batch or function(names)
        local out, at = {}, 1
        while at <= #names do
            local chunk = {}
            for i = at, math.min(at + DEMANGLE_CHUNK - 1, #names) do
                table.insert(chunk, names[i])
            end
            local text = os.iorunv("xcrun", table.join({DEMANGLER}, chunk))
            for line in string.gmatch(text or "", "[^\n]+") do
                table.insert(out, line)
            end
            at = at + DEMANGLE_CHUNK
        end
        return out
    end
    local names = {}
    for _, r in ipairs(rows) do
        if r.mangled ~= NO_VALUE then
            table.insert(names, r.mangled)
        end
    end
    local lines = demangle(names)
    if #lines ~= #names then
        raise(string.format("swift-demangle answered %d lines for %d names", #lines, #names))
    end
    local index = 0
    for _, r in ipairs(rows) do
        if r.mangled ~= NO_VALUE then
            index = index + 1
            if string.find(lines[index], ASYNC_MARKER, 1, true) then
                r.async = "yes"
            end
        end
    end
    return rows
end

function non_ascii_identifiers(rows)
    local seen, out = {}, {}
    for _, r in ipairs(rows) do
        for _, name in ipairs(MODEL_COLUMNS) do
            local value = r[name]
            if type(value) == "string" then
                for run in string.gmatch(value, "[%w_\128-\255]+") do
                    if string.find(run, "[\128-\255]") and not string.find(run, "^\207\132_") and not seen[run] then
                        seen[run] = true
                        table.insert(out, run)
                    end
                end
            end
        end
    end
    table.sort(out, order.less)
    return out
end

local function cells(row)
    local out = {}
    for i, name in ipairs(MODEL_COLUMNS) do
        out[i] = row[name]
    end
    return out
end

function text(rows)
    local out = {}
    for _, r in ipairs(rows) do
        table.insert(out, cells(r))
    end
    return tsv.table_text(MODEL_COLUMNS, out)
end

function model(folder, framework)
    local root, reason = dump(folder, framework)
    if root == nil then
        return nil, reason
    end
    local out, why = rows(root, framework)
    local abi_root = dump(folder, framework, "-abi")
    local extra = abi_root ~= nil and rows(abi_root, framework) or {}
    out = out or {}
    local seen = {}
    for _, row in ipairs(out) do
        seen[row.usr] = true
    end
    for _, row in ipairs(extra) do
        if not seen[row.usr] then
            seen[row.usr] = true
            table.insert(out, row)
        end
    end
    if #out == 0 then
        return nil, why
    end
    annotate_async(out)
    out = swift_canonical.rows(out)
    return out
end

local function union_list(a, b)
    if a == NO_VALUE then
        return b
    end
    if b == NO_VALUE then
        return a
    end
    local seen, out = {}, {}
    for _, list in ipairs({a, b}) do
        for item in string.gmatch(list, "[^,]+") do
            if not seen[item] then
                seen[item] = true
                table.insert(out, item)
            end
        end
    end
    return table.concat(out, ",")
end

local function merged_class(existing, row)
    if existing == nil then
        return row
    end
    local copy = {}
    for k, v in pairs(existing) do
        copy[k] = v
    end
    copy.conformances = union_list(existing.conformances, row.conformances)
    if copy.superclass == NO_VALUE then
        copy.superclass = row.superclass
    end
    return copy
end

function add_classes(classes, name, rows)
    for _, row in ipairs(rows) do
        if row.kind == "swift-class" then
            local owner = row.owner_module ~= NO_VALUE and row.owner_module or name
            local api = row.container ~= NO_VALUE and (row.container .. "." .. row.name) or row.name
            local key = owner .. "." .. api
            classes[key] = merged_class(classes[key], row)
        end
    end
    return classes
end

function class_index(folder, names)
    local classes, missing = {}, {}
    for _, name in ipairs(names) do
        local rows, reason, failure = nil, nil, nil
        try {
            function ()
                rows, reason = model(folder, name)
            end,
            catch {
                function (err)
                    failure = tostring(err)
                end
            }
        }
        if failure ~= nil or rows == nil then
            table.insert(missing, name .. ": " .. (failure or reason))
        else
            add_classes(classes, name, rows)
        end
    end
    return classes, missing
end

function write_model(folder, out_dir, framework)
    local out, reason = model(folder, framework)
    if out == nil then
        return nil, reason
    end
    emit_file(path.join(out_dir, framework .. ".tsv"), text(out))
    return #out
end

local emit_module = nil
function emit_file(filepath, contents)
    if emit_module == nil then
        emit_module = import("emit", {anonymous = true})
    end
    emit_module.file(filepath, contents)
end
