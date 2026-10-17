-- The full Swift declaration model of the SDK's Swift modules: the same digester dump swift_shard.lua reads, run once per run as one
-- batch (prefetch) and read from its cache, walked into one row per declaration, holding every field the dump gives that a compilable
-- declaration needs and the shard has no column for: the mangled name, the generic signature, the conformances, the superclass,
-- throws/async/mutating, the accessors, attributes, protocol-requirement and extension state, storage and raw type. The committed
-- shard (spec/<F>/swift.tsv) is NOT touched: this is a build product, never committed (like ir.lua's IR_FULL). The container and
-- name of a row are the same the shard computes, so the declhash column is the shard's own digest.
--
-- async has no key of its own in the dump: the mangled name carries it, and it is read from there by swift-demangle in one batch per
-- module (the ABI encoding is the model's own data, not the interface text). A declaration the digester lists whose mangled name has
-- the async marker gets async="yes".

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
-- The digester's declaration kinds that are types, and the surface kind each is.
local TYPE_KINDS = {Class = "class", Struct = "struct", Enum = "enum", Protocol = "protocol", TypeAlias = "typealias"}
-- The platform names the digester writes as intro_<name> (lower-cased; the Mac is "Macosx" there).
local PLATFORM_NAMES = {macosx = "macos"}
-- The full model's columns: the shard's eleven (framework, kind, usr, container, name, side, type, params, availability, message,
-- declhash) first, so a model row carries the shard row as its prefix, then the fields the shard has no column for.
local MODEL_COLUMNS = {"framework", "kind", "usr", "container", "name", "side", "type", "params", "availability", "message",
                       "declhash", "mangled", "generic_sig", "conformances", "superclass", "throwing", "async", "mutating",
                       "attributes", "accessors", "storage", "is_let", "is_open", "requirement", "in_extension", "owner_module",
                       "raw", "alias", "overriding", "init_kind", "implicit"}

-- The model's columns, in order.
function columns()
    return MODEL_COLUMNS
end

-- The Swift module names of the SDK, in byte order (the same list the shard's command uses).
function modules(sdk)
    return swift_shard.modules(sdk)
end

-- The -public-module-name a swiftinterface's flags name, read from its first lines, or nil. The compiler reads this flag for
-- "module X is an implementation detail of Y": the flags sit in the header, before the first declaration.
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

-- The implementation modules of the SDK, as a map from each to its public module: a module whose interface names another module
-- as its public one (the SDK's SwiftUICore names SwiftUI). A module that names none, or itself, is not in the map. The digester's
-- own re-export list is not the rule: SwiftUI re-exports UIKit, which is no implementation module.
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

-- The SDK's import graph: each module's direct imports (a set of module names), read from the import lines of its swiftinterface. A
-- submodule is its module (Metal.MTLDevice is Metal), an @_exported import counts as an import. A module with no interface (a C-only
-- module, CoreFoundation) imports none. Returns the map from module to its set.
function import_graph(sdk)
    local out = {}
    for _, filepath in ipairs(files.glob(path.join(sdk, "**", "*.swiftinterface"))) do
        local module = string.match(filepath, "([^/]+)%.swiftmodule/[^/]+%.swiftinterface$")
        if module and out[module] == nil then
            local imports = {}
            local handle = assert(io.open(filepath, "rb"), "cannot read " .. filepath)
            for line in handle:lines() do
                -- an import line may carry the export attribute and an access level before its keyword (@_exported public import X)
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

-- The modules that depend on a module in the import graph: every module that reaches it through imports (the module itself excepted).
-- A declaration of this module cannot name one of them: in the SDK the declaration belongs to the dependent module (CoreFoundation's
-- rows that name CoreGraphics are CoreGraphics's, since CoreGraphics imports CoreFoundation). Returns the set (name -> true).
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

-- The Swift module names of the SDK as a set (name -> true): the names an import of the rendered code may name.
function module_set(sdk)
    local out = {}
    for _, name in ipairs(modules(sdk)) do
        out[name] = true
    end
    return out
end

-- The target triple of the SDK's deployment target, read by the SDK's discovery (sdk.lua), as the shard plan reads it.
function triple_of(sdk)
    return sdk_info.discover(sdk).triple
end

-- The path of coordination/heavy.sh: beside the coordination folder when one is given, else the workspace's.
function heavy_path(coordination)
    if coordination then
        return path.join(coordination, "heavy.sh")
    end
    return path.join(os.getenv("HOME"), "Git", "projects", "ios", "coordination", "heavy.sh")
end

-- The digester's dumps of the named modules, run as one batch in one heavy slot before any model is read (swift_shard.dump_batch, the
-- model's variant): a dump run per call queued each module's dumps behind the whole queue. Returns the cache folder the models read from.
function prefetch(tree, heavy, sdk, triple, names)
    return swift_shard.dump_batch(tree, heavy, sdk, triple, names, "model")
end

-- The digester's JSON root of one module from the batch's cache: its API dump (mode nil), or its ABI dump when mode is "-abi". Returns the
-- root, or nil and the reason the digester gave none. A module the digester cannot load gets an empty tree and an exit 0, so an empty
-- root is a reason, not a failure.
local function dump(folder, framework, mode)
    return swift_shard.cached_root(folder, "model", framework, mode or "")
end

-- A cell as the model writes it: an absent field is "-".
local function dash(value)
    if value == nil or value == "" then
        return NO_VALUE
    end
    if value == true then
        return "yes"
    end
    return value
end

-- The platform introductions of a declaration, as "platform=version" tokens in byte order; "-" when it has none.
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

-- The surface kind of a digester declaration, or nil when the snapshot holds no row for it. in_type says whether the declaration
-- sits in a type: a function there is a method, a variable a property (the same rule as the shard).
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

-- The payload of an enum case, as its parameter types ("-" for a case with none). The digester gives the case as a function from its
-- payload to the enum (a generic enum's case is inside a generic function). The function that returns the enum is the one whose first
-- child is the enum's own type, the type's usr being a prefix of the case's usr; the children after its result are the payload (a
-- tuple's elements are the payload, and the metatype is no payload).
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

-- The declared type and the parameter types of a signed declaration, the shard's own rule (a variable's type, a function's result
-- then its parameters, a constructor's children are its parameters); an enum case's payload is its parameters.
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

-- The conformances a type declares, as their printed names in the dump's order; "-" when it declares none.
local function conformances_of(node)
    local out = {}
    for _, c in ipairs(node.conformances or {}) do
        table.insert(out, c.printedName or c.name or NO_VALUE)
    end
    return #out > 0 and table.concat(out, ",") or NO_VALUE
end

-- The superclass of a class, from the dump's superclassNames (the qualified spelling the uses print), or "-".
local function superclass_of(node)
    local names = node.superclassNames
    if type(names) == "table" and #names > 0 then
        return table.concat(names, ",")
    end
    return NO_VALUE
end

-- The accessor kinds of a variable or subscript, as "get,set"; "-" when the dump lists none.
local function accessors_of(node)
    local out = {}
    for _, a in ipairs(node.accessors or {}) do
        if a.accessorKind then
            table.insert(out, a.accessorKind)
        end
    end
    return #out > 0 and table.concat(out, ",") or NO_VALUE
end

-- The attributes the dump lists, in its order; "-" when there are none.
local function attributes_of(node)
    local out = {}
    for _, a in ipairs(node.declAttributes or {}) do
        table.insert(out, a)
    end
    return #out > 0 and table.concat(out, ",") or NO_VALUE
end

-- The qualified names of the types the dump spells, the shard's own reading.
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

-- The api of a type declaration: its qualified name when the dump's uses give one whose last part is the declaration's own name,
-- else the container and the name (the shard's type_api).
local function type_api(node, label, container, qualified)
    local name = node.usr and qualified[node.usr]
    if name and string.match(name, "([^.]+)$") == label then
        return name
    end
    return container ~= NO_VALUE and (container .. "." .. label) or label
end

-- The owner module of a declaration: the dump's moduleName, or the framework when it carries none. "-" when it is the framework's
-- own (not an extension of another module).
local function owner_module(node, framework)
    local module = node.moduleName
    if module == nil or module == framework then
        return NO_VALUE
    end
    return module
end

-- The type a typealias aliases, from its single child; "-" otherwise.
local function alias_of(node, decl)
    if decl ~= "TypeAlias" then
        return NO_VALUE
    end
    local child = (node.children or {})[1]
    return child and (child.printedName or child.name) or NO_VALUE
end

-- The row of one declaration, a record keyed by MODEL_COLUMNS. decl is the digester's declKind.
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

-- Walks the declarations of a node list, appending a row for each. container is the api of the type the declarations sit in, or
-- "-". A clang importer's declaration (moduleName "__ObjC", "__C") is left out (the shard's rule).
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

-- The full model of one module's dump: a list of rows (records), or nil and the reason the module has none.
function rows(root, framework)
    local out = {}
    walk(framework, root.children, NO_VALUE, qualified_names(root, {}), out)
    if #out == 0 then
        return nil, "the digester holds no Swift declaration of the module's own"
    end
    return out
end

-- Fills each row's async cell from the demangled signature of its mangled name: the ABI encoding is where the dump keeps the async
-- marker. The demangler is given the mangled spelling ("$s...") and echoes one line per name, in order. It runs in chunks, so an
-- argument list stays under the system's limit whatever a module's count; the lines are joined in order. A row with no mangled name
-- keeps "-".
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

-- The identifiers of the model that are not ASCII (a Swift identifier the SDK spells in another script, such as a Foundation
-- property whose name has a macron), as a list. The digester's canonical generic parameters (tau_D_I) are not identifiers of
-- the SDK and are left out: a rendered file never spells one.
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

-- The row as a list of cells, in MODEL_COLUMNS order.
local function cells(row)
    local out = {}
    for i, name in ipairs(MODEL_COLUMNS) do
        out[i] = row[name]
    end
    return out
end

-- The TSV text of a model: the header, then one line per row, in ASCII.
function text(rows)
    local out = {}
    for _, r in ipairs(rows) do
        table.insert(out, cells(r))
    end
    return tsv.table_text(MODEL_COLUMNS, out)
end

-- The model of one module: the API dump's rows, and then the ABI dump's rows whose usr the API dump does not carry. This is the union the
-- Swift shard holds (swift_shard.dump_rows): the API dump drops the underscore-prefixed declarations the interface declares public, and
-- the ABI dump drops others, so the skeleton of a module declares what the shard names. Returns the rows, or nil and the reason.
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

-- The union of two comma-joined lists, in order, each item once; "-" when neither has one.
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

-- The class row one key holds once a second module's row for the same class is in: the conformances are the union (a module
-- adds a conformance to another module's class in an extension, and that module's dump lists it), and the superclass is the one
-- named.
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

-- Adds the class rows of one module's model (name is the module) to a class index, keyed by "Module.Api" (the spelling a
-- superclass takes in a row). A class is keyed by the module that declares it: a row whose owner is another module is that
-- module's class, so Foundation's extension of ObjectiveC's NSObject is keyed "ObjectiveC.NSObject", the spelling its subclasses
-- name. Returns the index.
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

-- The class rows of the given modules, keyed by their qualified name (see add_classes): a class's superclass chain is read from
-- this index (swift_render.lua). Returns the index and the modules with no model, each with its reason (a module whose heavy job
-- fails is one of these, and the chain through it is missing).
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

-- Writes the model of one module under out_dir/<F>.tsv through emit. Returns the number of rows, or nil and the reason.
function write_model(folder, out_dir, framework)
    local out, reason = model(folder, framework)
    if out == nil then
        return nil, reason
    end
    emit_file(path.join(out_dir, framework .. ".tsv"), text(out))
    return #out
end

-- emit is imported lazily so the model can be tested without the writer.
local emit_module = nil
function emit_file(filepath, contents)
    if emit_module == nil then
        emit_module = import("emit", {anonymous = true})
    end
    emit_module.file(filepath, contents)
end
