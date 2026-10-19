-- The Swift declaration snapshot: one shard per Swift module of the SDK, spec/<F>/swift.tsv. A module's declarations are its API digester
-- dump (swift-api-digester -dump-sdk), run as one batch through coordination/heavy.sh (run_dumps) into a cache folder, and read from
-- it (dump_rows). A row is one declaration of the dump in the IR's shape: the surface kind the scope matches (class, struct, enum, protocol,
-- typealias, method, property, constant, function), the Swift USR (the precise identifier), the container, the name, the side, the
-- declared type and the parameter types, the platform introductions, and the declaration hash (design section 5.3, the same canonical
-- text with nullability and attrs and value "-": Swift has none of them). The dump carries no declaration text and no availability
-- message, and it has the deprecation as a flag with no version: the availability cell holds the platform introductions only, and the
-- message is "-".

local layout = import("layout", {anonymous = true})
local tsv = import("tsv", {anonymous = true})
local files = import("files", {anonymous = true})
local digest = import("digest", {anonymous = true})
local strings = import("strings", {anonymous = true})
local emit = import("emit", {anonymous = true})
local order = import("order", {anonymous = true})
local sdk_info = import("sdk", {anonymous = true})
local json = import("core.base.json")

local SHARD_FILE = "swift.tsv"
local COLUMNS = {"framework", "kind", "usr", "container", "name", "side", "type", "params", "availability", "message", "declhash"}
local NO_VALUE = "-"
local KIND_PREFIX = "swift-"
local DIGESTER = "swift-api-digester"
-- The digester's two modes, as the flag each takes: the API interface (no flag) and the ABI interface ("-abi"). The shard's rows are the
-- two dumps' rows together (dump_rows), because neither mode alone carries every public declaration.
local API_MODE = ""
local ABI_MODE = "-abi"
-- The SDK's developer frameworks folder, on the digester's framework search path: a module that lives there (StoreKitTest) is not found by the
-- default search, and the digester writes an empty tree for it (measured: "Failed to load module", exit 0; with -F the dump holds 280 declarations).
local DEVELOPER_FRAMEWORKS = "Developer/Library/Frameworks"
-- The digester's declaration kinds that are types, and the surface kind each is.
local TYPE_KINDS = {Class = "class", Struct = "struct", Enum = "enum", Protocol = "protocol", TypeAlias = "typealias"}
-- The declarations that have a type (a result or a variable's type) and parameter types, in the dump's children.
local SIGNED_KINDS = {Func = true, Var = true, Constructor = true, Subscript = true}
-- The platform names the digester writes as intro_<name> (lower-cased; the Mac is "Macosx" there and "macos" in the IR).
local PLATFORM_NAMES = {macosx = "macos"}
-- The modules the snapshot leaves out, each with its reason. None: Accelerate's Swift interface (usr/lib/swift) declares the umbrella's own
-- types, and the digester dumps them like any module's (2,529 rows, measured); an earlier band had left it out.
local LEFT_OUT = {}

-- The surface kind of a digester declaration, or nil when the declaration is not one the snapshot holds (an accessor, an associated type,
-- an import, a macro). in_type says whether the declaration sits in a type: a function there is a method, a variable a property.
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
        -- an enum case is a constant of its enum, the surface table's kind for it (measured on the unnamed rows: the 3,807 surface
        -- constants the shard held as property all sit under an enum, and none sits under a non-enum)
        return "constant"
    end
    return nil
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

-- The declared type and the parameter types of a signed declaration: a variable and a function have their result or type first, a
-- constructor's children are its parameters. Anything else has neither ("-").
local function signature_of(node, decl)
    if not SIGNED_KINDS[decl] then
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

-- The row of one declaration: the cells COLUMNS names. container is the api of the type the declaration sits in ("-" at module level).
local function row_of(framework, decl, node, container, kind, name)
    local usr = node.usr or NO_VALUE
    local side = node.static and "+" or "-"
    local result, params = signature_of(node, decl)
    local availability = availability_of(node)
    local declhash = digest.digest(KIND_PREFIX .. kind, usr, container, name, side, result, params, NO_VALUE, NO_VALUE, NO_VALUE, "")
    return {framework, KIND_PREFIX .. kind, usr, container, name, side, result, params, availability, NO_VALUE, declhash}
end

-- The qualified names of the types the dump spells: a type's usr maps to the name its uses print, without the module that declares it
-- ("AVFAudio.AVAudioSession.Location" is "AVAudioSession.Location", "SwiftUI.AccessibilityHeadingLevel" in SwiftUICore is the bare
-- "AccessibilityHeadingLevel"). A nested type the importer places in another type is declared at the top of the dump with its own name
-- alone; its uses carry the qualified name. A generic or tuple spelling is not a name and is not taken.
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

-- The api of a type declaration: its qualified name when the dump's uses give one whose last part is the declaration's own name, else the
-- container and the name.
local function type_api(node, label, container, qualified)
    local name = node.usr and qualified[node.usr]
    if name and string.match(name, "([^.]+)$") == label then
        return name
    end
    return container ~= NO_VALUE and (container .. "." .. label) or label
end

-- Walks the declarations of a node list, appending a row for each. container is the api of the type the declarations sit in, or "-".
-- A clang importer's declaration (moduleName "__ObjC", "__C": the module's own imports of the C and Objective-C types) is not the framework's
-- and is left out. A Swift declaration of another module is kept: a framework's public surface includes the declarations it re-exports
-- (SwiftUI's members that SwiftUICore declares).
local function walk(framework, nodes, container, qualified, rows)
    for _, node in ipairs(nodes or {}) do
        local decl = node.declKind
        local label = node.printedName or node.name
        local foreign = node.moduleName ~= nil and string.sub(node.moduleName, 1, 2) == "__"
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

-- The digester's dumps run as one batch through one heavy slot, not one slot per dump: a slot per dump queued each of the ~200 dumps
-- behind the whole queue (measured 2026-10-17: one module's dump waited 42 minutes with 46 jobs ahead of it), and a queue wait with no
-- output stops a stream read after ten minutes. The batch runs DUMP_WIDTH dumps at a time, each bounded by DUMP_TIMEOUT seconds, and the
-- batch by BATCH_TIMEOUT. Each dump writes its JSON, its exit status and its standard error into the run's cache folder, so a dump the
-- cache holds is not run again. A bound sends SIGTERM and, KILL_AFTER seconds later, SIGKILL (gtimeout -k): gtimeout without -k leaves a
-- child that ignores SIGTERM running, and two dumps (AdAttributionKit, AppIntents) ran 10 to 13 hours that way.
local DUMP_WIDTH = 4
local DUMP_TIMEOUT = 1800
local BATCH_TIMEOUT = 5400
local KILL_AFTER = 30
-- The exit statuses gtimeout gives when it stopped the command: 124 after SIGTERM, 137 after SIGKILL (-k).
local STOPPED_BY_BOUND = {["124"] = true, ["137"] = true}
local CACHE_ROOT = path.join(".agent-work", "digester-cache")

-- The cache folder of a run's dumps: <tree>/.agent-work/digester-cache/<key>, the key the digester binary and the SDK's content hash to
-- (every .swiftinterface and the SDKSettings.json). An unchanged SDK under an unchanged digester is a cache hit for every dump.
local function cache_folder(tree, sdk)
    local digester = string.gsub(os.iorunv("xcrun", {"--find", DIGESTER}), "%s+$", "")
    local key = string.gsub(os.iorunv("sh", {"-c", "{ shasum -a 256 \"$1\"; find \"$2\" -name '*.swiftinterface' -print0 | sort -z | "
        .. "xargs -0 shasum -a 256; shasum -a 256 \"$2/SDKSettings.json\"; } | shasum -a 256 | cut -c1-32", "sh", digester, sdk}),
        "%s+$", "")
    local folder = path.join(tree, CACHE_ROOT, key)
    os.mkdir(folder)
    return folder
end

-- The two variants a dump runs as, each with the arguments it has always run with: shard (the SDK's developer frameworks on the search
-- path, and the mode's flag as an empty argument when it has none) and model (no developer frameworks, and no empty flag: swift_model's
-- dump). A dump's JSON is the JSON its variant read before the batch.
local VARIANTS = {shard = true, model = true}

-- The base path of one dump in the cache: <folder>/<variant>/<api|abi>/<module>, with .json, .status and .err after it.
local function dump_base(folder, variant, framework, mode)
    return path.join(folder, variant, mode == ABI_MODE and "abi" or "api", framework)
end

-- The shell command of one dump: the digester's own arguments for its variant, with its JSON written to a file and its exit status
-- recorded beside it. Exported for tests/gen/dump_bound_test.lua.
function dump_command(sdk, triple, framework, mode, base, variant)
    local words = {"gtimeout", "-k", tostring(KILL_AFTER), tostring(DUMP_TIMEOUT), "xcrun", DIGESTER, "-dump-sdk"}
    if variant == "shard" then
        table.insert(words, mode == "" and "''" or mode)
    elseif mode ~= "" then
        table.insert(words, mode)
    end
    for _, arg in ipairs({"-module", framework, "-target", triple, "-sdk", sdk}) do
        table.insert(words, arg)
    end
    if variant == "shard" then
        table.insert(words, "-F")
        table.insert(words, path.join(sdk, DEVELOPER_FRAMEWORKS))
    end
    for _, arg in ipairs({"-avoid-location", "-avoid-tool-args", "-o", base .. ".json", "2>", base .. ".err", ";", "echo", "$?", ">",
                          base .. ".status"}) do
        table.insert(words, arg)
    end
    return table.concat(words, " ")
end

-- Runs the dumps of one variant the cache lacks, for the named modules, in one heavy slot: DUMP_WIDTH at a time (xargs -n 1 sh -c over
-- NUL-separated commands read from a file). Returns nothing: each dump's outcome is its .status file. A batch the slot or BATCH_TIMEOUT
-- cut short leaves its last dumps without a status, and the next run runs them.
local function run_dumps(heavy, folder, sdk, triple, names, variant)
    local commands = {}
    for _, framework in ipairs(names) do
        for _, mode in ipairs({API_MODE, ABI_MODE}) do
            local base = dump_base(folder, variant, framework, mode)
            if not os.isfile(base .. ".status") then
                os.mkdir(path.directory(base))
                table.insert(commands, dump_command(sdk, triple, framework, mode, base, variant))
            end
        end
    end
    if #commands == 0 then
        return
    end
    local jobs = path.join(folder, "jobs-" .. variant .. ".txt")
    io.writefile(jobs, table.concat(commands, "\0") .. "\0")
    -- xargs' own status is not read: a dump that the digester failed is its module's reason (cached_root), and a dump the batch never
    -- reached has no status file, which is counted here.
    try {
        function()
            os.execv("gtimeout", {"-k", tostring(KILL_AFTER), tostring(BATCH_TIMEOUT), heavy, "sh", "-c",
                                  string.format("xargs -0 -P %d -n 1 sh -c < %s; true", DUMP_WIDTH, jobs)})
        end,
        catch {
            function(e)
                print(string.format("dump batch: the batch failed to start: %s", tostring(e)))
            end
        }
    }
    local left = 0
    for _, framework in ipairs(names) do
        for _, mode in ipairs({API_MODE, ABI_MODE}) do
            if not os.isfile(dump_base(folder, variant, framework, mode) .. ".status") then
                left = left + 1
            end
        end
    end
    if left > 0 then
        print(string.format("dump batch: %s left %d dump(s) without a status (the slot or the batch bound stopped it)", variant, left))
    end
end

-- The cache folder of a run's dumps, after the batch of the named modules' dumps of one variant has run (run_dumps). Returns the folder.
function dump_batch(tree, heavy, sdk, triple, names, variant)
    assert(VARIANTS[variant], "dump_batch: no variant " .. tostring(variant))
    local folder = cache_folder(tree, sdk)
    run_dumps(heavy, folder, sdk, triple, names, variant)
    return folder
end

-- The JSON root of one module's dump in one mode of one variant, from the cache. Returns the root, or nil and the reason the digester gave
-- nothing usable.
function cached_root(folder, variant, framework, mode)
    local base = dump_base(folder, variant, framework, mode)
    if not os.isfile(base .. ".status") then
        return nil, "the digester did not run (the dump batch stopped first)"
    end
    local status = string.gsub(io.readfile(base .. ".status"), "%s+$", "")
    if STOPPED_BY_BOUND[status] then
        return nil, string.format("the digester was stopped at its time bound (%d s, status %s)", DUMP_TIMEOUT, status)
    end
    if status ~= "0" then
        return nil, string.format("the digester exited %s: %s", status, string.sub(io.readfile(base .. ".err") or "", -300))
    end
    local payload = json.decode(io.readfile(base .. ".json") or "")
    local root = payload and payload.ABIRoot
    if root == nil then
        return nil, "the digester wrote no ABI root"
    end
    return root
end

-- The rows of one module's dump in one mode, from the shard's cache. Returns the rows (possibly none), or nil and the reason the digester
-- gave nothing usable.
local function mode_rows(folder, framework, mode)
    local root, reason = cached_root(folder, "shard", framework, mode)
    if root == nil then
        return nil, reason
    end
    local rows = {}
    walk(framework, root.children, NO_VALUE, qualified_names(root, {}), rows)
    return rows
end

-- The rows of one module: the API dump's rows, and then the ABI dump's rows whose declaration the API dump does not carry.
--
-- Neither mode alone carries every public declaration, measured on the two frameworks the digester is measured on:
-- the API dump drops the underscore-prefixed declarations the interface declares public (`_UIHostingView` in SwiftUI's interface,
-- SwiftUI.framework/.../arm64e-apple-ios.swiftinterface line 21822; 56 underscore printedNames in SwiftUI's API dump against 652 in its
-- ABI dump), and the ABI dump drops declarations of its own (630 of SwiftUI's API-dump keys are in no ABI dump, the generic
-- CommandsBuilder.buildBlock overloads among them). The union carries both.
--
-- The API dump's row for a declaration the two share is the one kept: it spells the type as the interface does (the ABI dump writes an
-- opaque generic parameter as the escape text \u03c4_0_0 and drops the module from a nested type's spelling), which 1,581 of SwiftUI's
-- shared rows show. The identity is the usr, the precise identifier of the declaration, so one declaration is one row.
--
-- Returns the rows, or nil and the reason the module has none (the digester writes an empty tree for a module it cannot load, and exits 0).
local function dump_rows(folder, framework)
    local rows, reason = mode_rows(folder, framework, API_MODE)
    local extra, extra_reason = mode_rows(folder, framework, ABI_MODE)
    if extra == nil then
        if rows == nil or #rows == 0 then
            return nil, reason or extra_reason
        end
        return rows
    end
    if rows == nil or #rows == 0 then
        rows = extra
        extra = {}
    end
    local seen = {}
    for _, row in ipairs(rows) do
        seen[row[3]] = true
    end
    for _, row in ipairs(extra) do
        if not seen[row[3]] then
            seen[row[3]] = true
            table.insert(rows, row)
        end
    end
    if #rows == 0 then
        return nil, reason or extra_reason
            or "the digester holds no Swift declaration of the module's own (an overlay of C or Objective-C types only, or not loaded)"
    end
    return rows
end

-- The module names of the SDK: every .swiftinterface's module (its .swiftmodule folder), once each, in byte order.
function modules(sdk)
    local seen, names = {}, {}
    for _, filepath in ipairs(files.glob(path.join(sdk, "**", "*.swiftinterface"))) do
        local module = string.match(filepath, "([^/]+)%.swiftmodule/[^/]+%.swiftinterface$")
        if module and not seen[module] then
            seen[module] = true
            table.insert(names, module)
        end
    end
    table.sort(names, order.less)
    return names
end

-- The shard path of a module under the package tree.
function shard_path(tree, framework)
    return path.join(tree, layout.constants().SNAP_ROOT, framework, SHARD_FILE)
end

-- Writes the shards of the named modules, the dumps run as one batch (run_dumps). Returns one {name, rows, reason} per module, in order:
-- rows is the shard's row count, or nil with the reason the module has no shard.
function write_shards(tree, heavy, sdk, triple, names)
    local folder = dump_batch(tree, heavy, sdk, triple, names, "shard")
    local out = {}
    for _, framework in ipairs(names) do
        local rows, reason = dump_rows(folder, framework)
        if rows then
            emit.file(shard_path(tree, framework), strings.backslash_replace(tsv.table_text(COLUMNS, rows)))
        end
        table.insert(out, {name = framework, rows = rows and #rows, reason = reason})
    end
    return out
end

-- The key of an api the shard and the scope both match on. The surface table and the digester dump spell the same declaration differently in
-- three measured places, and the key closes each of them:
--
--   an operator: the surface's argument labels are its parameter names (a:b:, lhs:rhs:) and the dump's are underscores (_:_:), so an
--     operator is keyed by its arity. An operator is a last part that starts with a character other than a letter or an underscore.
--   a subscript: the interface's label is the surface's (TabularData's `Column.subscript(position:)`) and the dump's is `_:` (`Column.subscript(_:)`),
--     so a subscript is keyed by its arity, and the index canonicalises the dump's own subscript rows the same way. This merges the overloads
--     of one arity that differ only in labels (120 groups of the interface text, measured); the dump names no label to tell them apart.
--   a generic parameter's label: the interface's `<V>:` is the dump's `_:` in the labels; the key writes `_:`.
--
-- A failable initializer's `?` is dropped: the dump prints no `?` on a constructor (`ColorScheme.init(_:)` for `ColorScheme.init?(_:)`), so
-- the key of `init?` is the key of `init`. Measured: 41 (module, container, labels) pairs declare both forms and share one key. Any other api
-- is its own key.
function canonical_api(api)
    local head, labels = string.match(api, "^(.-)%((.*)%)$")
    local last = head and string.match(head, "([^.]*)$")
    if last == nil or last == "" then
        return api
    end
    if last == "subscript" or not string.match(last, "^[%a_]") then
        local _, colons = string.gsub(labels, ":", ":")
        return head .. "(" .. string.rep("_:", colons) .. ")"
    end
    local plain_head = last == "init?" and (string.gsub(head, "init%?$", "init")) or head
    return plain_head .. "(" .. string.gsub(labels, "<[^>]*>:", "_:") .. ")"
end

-- The index of a framework's shard the scope reads: each declaration's surface kind and api, as "kind\tapi" keys, or nil when the framework
-- has no shard. The api is the scope's: the container, a dot, the name (the name alone at module level), the operator's arity canonical.
-- The key of a Swift row in the shard's index and in the renderer's keys (swiftcode's .rendered sidecar): its kind without the
-- "swift-" prefix, and its canonical api (the api of its container's name, canonical_api). row is a shard row or a model row.
function key_of(row)
    local api = row.container ~= NO_VALUE and (row.container .. "." .. row.name) or row.name
    return string.sub(row.kind, #KIND_PREFIX + 1) .. "\t" .. canonical_api(api)
end

function index(tree, framework)
    local file = shard_path(tree, framework)
    if not os.isfile(file) then
        return nil
    end
    local keys = {}
    for _, r in ipairs(tsv.records(files.read_text(file))) do
        keys[key_of(r)] = true
    end
    return keys
end

-- The heavy.sh path (beside the corpus folder), the triple, and the modules the run covers (LEFT_OUT excluded): one module when framework
-- is given.
function plan(corpus, sdk, framework)
    local heavy = path.join(path.directory(corpus), "heavy.sh")
    assert(os.isfile(heavy), "no heavy.sh beside the corpus folder: " .. heavy)
    local names = framework and {framework} or modules(sdk)
    local out = {}
    for _, name in ipairs(names) do
        if LEFT_OUT[name] == nil then
            table.insert(out, name)
        end
    end
    return heavy, out, sdk_info.discover(sdk).triple
end
