local layout = import("layout", {anonymous = true})
local workspace = import("workspace", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})
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
local API_MODE = ""
local ABI_MODE = "-abi"
local DEVELOPER_FRAMEWORKS = "Developer/Library/Frameworks"
local TYPE_KINDS = {Class = "class", Struct = "struct", Enum = "enum", Protocol = "protocol", TypeAlias = "typealias"}
local SIGNED_KINDS = {Func = true, Var = true, Constructor = true, Subscript = true}
local PLATFORM_NAMES = {macosx = "macos"}
local LEFT_OUT = {}

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
    return nil
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

local function row_of(framework, decl, node, container, kind, name)
    local usr = node.usr or NO_VALUE
    local side = node.static and "+" or "-"
    local result, params = signature_of(node, decl)
    local availability = availability_of(node)
    local declhash = digest.digest(KIND_PREFIX .. kind, usr, container, name, side, result, params, NO_VALUE, NO_VALUE, NO_VALUE, "")
    return {framework, KIND_PREFIX .. kind, usr, container, name, side, result, params, availability, NO_VALUE, declhash}
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

local DUMP_WIDTH = 4
local DUMP_TIMEOUT = 1800
local BATCH_TIMEOUT = 5400
local KILL_AFTER = 30
local STOPPED_BY_BOUND = {["124"] = true, ["137"] = true}
local CACHE_ROOT = "digester-cache"

local function cache_folder(sdk)
    local digester = string.gsub(os.iorunv("xcrun", {"--find", DIGESTER}), "%s+$", "")
    local key = string.gsub(os.iorunv("sh", {"-c", "{ shasum -a 256 \"$1\"; find \"$2\" -name '*.swiftinterface' -print0 | sort -z | "
        .. "xargs -0 shasum -a 256; shasum -a 256 \"$2/SDKSettings.json\"; } | shasum -a 256 | cut -c1-32", "sh", digester, sdk}),
        "%s+$", "")
    return workspace.run(CACHE_ROOT, key)
end

local VARIANTS = {shard = true, model = true}

local function dump_base(folder, variant, framework, mode)
    return path.join(folder, variant, mode == ABI_MODE and "abi" or "api", framework)
end

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

function dump_batch(heavy, sdk, triple, names, variant)
    assert(VARIANTS[variant], "dump_batch: no variant " .. tostring(variant))
    local folder = cache_folder(sdk)
    run_dumps(heavy, folder, sdk, triple, names, variant)
    return folder
end

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

local function mode_rows(folder, framework, mode)
    local root, reason = cached_root(folder, "shard", framework, mode)
    if root == nil then
        return nil, reason
    end
    local rows = {}
    walk(framework, root.children, NO_VALUE, qualified_names(root, {}), rows)
    return rows
end

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

function shard_path(tree, framework)
    return path.join(tree, layout.constants().SNAP_ROOT, framework, SHARD_FILE)
end

function write_shards(tree, heavy, sdk, triple, names)
    local folder = dump_batch(heavy, sdk, triple, names, "shard")
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
