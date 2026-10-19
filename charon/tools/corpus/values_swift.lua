import("core.base.json")
import("core.base.bytes")

local common = import("values_common", {rootdir = os.scriptdir(), anonymous = true})
local byteorder = import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})

local CACHE_RECORD_VERSION = 2
local TARGET = "armv7-apple-ios6.1.3"

function cache_record_version()
    return CACHE_RECORD_VERSION
end

function target()
    return TARGET
end

local TYPE_KINDS = {TypeNominal = true, TypeDecl = true, TypeAlias = true, TypeNameAlias = true}
local IGNORED_KINDS = {Import = true, Root = true}

local present = common.present

function list(items)
    return json.mark_as_array(items or {})
end

local function is_array(value)
    return json.is_marked_as_array(value) or (type(value) == "table" and value[1] ~= nil)
end

local ESCAPES = {['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t", ["\b"] = "\\b", ["\f"] = "\\f"}

local function quoted(text)
    local out = {'"'}
    for _, code in utf8.codes(text) do
        local char = utf8.char(code)
        if ESCAPES[char] then
            table.insert(out, ESCAPES[char])
        elseif code < 0x20 or code >= 0x7f then
            if code > 0xffff then
                local rest = code - 0x10000
                table.insert(out, string.format("\\u%04x\\u%04x", 0xd800 + (rest >> 10), 0xdc00 + (rest & 0x3ff)))
            else
                table.insert(out, string.format("\\u%04x", code))
            end
        else
            table.insert(out, char)
        end
    end
    table.insert(out, '"')
    return table.concat(out)
end

local function encoded(value, indent, level)
    if value == nil or value == json.null then
        return "null"
    end
    local kind = type(value)
    if kind == "boolean" then
        return value and "true" or "false"
    end
    if kind == "string" then
        return quoted(value)
    end
    if kind == "number" then
        local integer = math.tointeger(value)
        if integer == nil then
            raise("values_swift: the index holds a non-integer number %s, which this writer does not spell as Python would", tostring(value))
        end
        return tostring(integer)
    end
    local items = {}
    if is_array(value) then
        for _, item in ipairs(value) do
            table.insert(items, encoded(item, indent, level + 1))
        end
    else
        for _, key in ipairs(byteorder.keys(value)) do
            table.insert(items, quoted(key) .. ": " .. encoded(value[key], indent, level + 1))
        end
    end
    local open, close = "{", "}"
    if is_array(value) then
        open, close = "[", "]"
    end
    if #items == 0 then
        return open .. close
    end
    if not indent then
        return open .. table.concat(items, ", ") .. close
    end
    local inner = "\n" .. string.rep(" ", indent * (level + 1))
    return open .. inner .. table.concat(items, "," .. inner) .. "\n" .. string.rep(" ", indent * level) .. close
end

function encode(value, indent)
    return encoded(value, indent, 0)
end

local function sorted_set(values)
    local seen, out = {}, {}
    for _, value in ipairs(values) do
        if not seen[value] then
            seen[value] = true
            table.insert(out, value)
        end
    end
    byteorder.sort(out)
    return list(out)
end

function sorted_conformances(conformances)
    local out = {}
    for name, listed in pairs(conformances) do
        out[name] = sorted_set(listed)
    end
    return out
end

local function without_payload_case(qualified)
    local start = 1
    while true do
        local at = qualified:find(".(", start, true)
        if not at then
            return qualified
        end
        local rest = qualified:sub(at + 2)
        local from = 1
        while true do
            local arrow = rest:find(" -> ", from, true)
            if not arrow then
                break
            end
            if rest:sub(1, arrow - 1):match("^%s*%)?[^ ]*$") and not rest:sub(arrow + 4):find("\n", 1, true) then
                return qualified:sub(1, at - 1)
            end
            from = arrow + 1
        end
        start = at + 1
    end
end

local function colon_count(inside)
    local count = 0
    for _ in inside:gmatch(":") do
        count = count + 1
    end
    return count
end

local function reduced_arguments(qualified)
    return (qualified:gsub("%(([^()]*)%)", function (inside)
        local count = colon_count(inside)
        local labels = {}
        for _ = 1, count do
            table.insert(labels, "_")
        end
        return "(" .. table.concat(labels, ":") .. (inside:sub(-1) == ":" and ":" or "") .. ")"
    end))
end

local function own_name(node)
    if present(node.printedName) then
        return node.printedName
    end
    return node.name
end

function index_from_json(payload, conformances)
    local names = {}
    conformances = conformances or {}
    local function setdefault(name, kind)
        if names[name] == nil then
            names[name] = kind == nil and json.null or kind
        end
    end
    local root = payload.ABIRoot
    if root == nil then
        root = {}
    end
    local stack = {{root, {}}}
    while #stack > 0 do
        local item = table.remove(stack)
        local node, trail = item[1], item[2]
        local kind = node.kind
        local own = own_name(node)
        local children = node.children or {}
        if IGNORED_KINDS[kind] or not present(own) then
            for _, child in ipairs(children) do
                table.insert(stack, {child, trail})
            end
        else
            local here = table.join(trail, {own})
            local qualified = table.concat(here, ".")
            local payload_case = without_payload_case(qualified)
            if TYPE_KINDS[kind] then
                setdefault(own, kind)
                setdefault(qualified, kind)
                if payload_case ~= qualified then
                    setdefault(payload_case, kind)
                end
                local listed = {}
                for _, conformance in ipairs(node.conformances or {}) do
                    table.insert(listed, own_name(conformance))
                end
                if #listed > 0 then
                    for _, name in ipairs({own, qualified, payload_case}) do
                        conformances[name] = conformances[name] or {}
                        table.join2(conformances[name], listed)
                    end
                end
            else
                setdefault(qualified, kind)
                local reduced = reduced_arguments(qualified)
                if reduced ~= qualified then
                    setdefault(reduced, kind)
                end
            end
            local inside = TYPE_KINDS[kind] and here or trail
            for _, child in ipairs(children) do
                table.insert(stack, {child, inside})
            end
        end
    end
    return names, conformances
end

function digester_complaint(streams)
    for _, stream in ipairs(streams or {}) do
        if present(stream) then
            for line in tostring(stream):gmatch("[^\r\n]+") do
                if line:find("error:", 1, true) or line:find("missing required modules", 1, true) then
                    return common.strip(line):sub(1, 300)
                end
            end
        end
    end
    return ""
end

function read_declarations(payload, module, streams)
    local names, conformances = index_from_json(payload)
    if table.empty(names) then
        local complaint = digester_complaint(streams)
        return nil, nil, string.format("the digester reported no declaration of %s, which is a module it could not load, not an empty one%s",
                                       module, complaint ~= "" and (": the digester said " .. complaint) or "")
    end
    return names, conformances, nil
end

function read_cache_record(data)
    if type(data) ~= "table" or is_array(data) or data.version ~= CACHE_RECORD_VERSION then
        return nil
    end
    if type(data.names) ~= "table" or is_array(data.names) then
        return nil
    end
    local conformances = data.conformances
    if not present(conformances) then
        conformances = {}
    end
    return {names = data.names, conformances = conformances}
end

function write_cache_record(file, names, conformances)
    io.writefile(file, encode({version = CACHE_RECORD_VERSION, names = names, conformances = sorted_conformances(conformances)}))
end

function find_digester()
    local root = path.join(os.getenv("HOME") or "~", ".xmake", "packages", "s", "swift")
    local best_time, best_path
    for _, file in ipairs(os.files(path.join(root, "**", "swift-api-digester"))) do
        local modified = os.mtime(file)
        if not best_path or modified > best_time or (modified == best_time and byteorder.less(best_path, file)) then
            best_time, best_path = modified, file
        end
    end
    if not best_path then
        raise("api-ledger-swift.lua: no swift-api-digester under %s; pass --digester", root)
    end
    return best_path
end

function package_of(module_file)
    local directory = path.directory(module_file)
    local manifest = ""
    for _ = 1, 6 do
        local candidate = path.join(directory, "manifest.txt")
        if os.exists(candidate) then
            manifest = candidate
            break
        end
        local parent = path.directory(directory)
        if not parent or parent == directory then
            break
        end
        directory = parent
    end
    local found = {package = directory, manifest = manifest}
    if manifest == "" then
        return found
    end
    local text = io.readfile(manifest)
    for _, key in ipairs({"backports", "backports_uikit", "shared", "recipe"}) do
        local value = text:match("%f[%w_]" .. key .. ' = "?([^"\n,}]+)')
        if value then
            found[key] = value
        end
    end
    return found
end

function read_module(digester, module_dir, module, sdk, vfs, shims, workdir, search, extra_maps, include_dirs)
    local out_path = path.join(workdir, string.format("tmp%s-%s.json", hash.uuid4():gsub("-", ""):sub(1, 8):lower(), (module:gsub("[^%w_]", "_"))))
    local log_path = out_path .. ".log"
    local args = {"-dump-sdk", "-module", module, "-I", module_dir}
    for _, extra in ipairs(search or {}) do
        table.join2(args, {"-I", extra})
    end
    table.join2(args, {"-target", TARGET, "-sdk", sdk, "-Xcc", "-Wno-incompatible-sysroot"})
    local maps = shims and {shims} or {}
    table.join2(maps, extra_maps or {})
    for _, module_map in ipairs(maps) do
        table.join2(args, {"-Xcc", "-fmodule-map-file=" .. module_map})
    end
    for _, directory in ipairs(include_dirs or {}) do
        table.join2(args, {"-Xcc", "-I" .. directory})
    end
    table.join2(args, {"-Xcc", "-ivfsoverlay", "-Xcc", vfs, "-o", out_path})
    io.writefile(out_path, "")
    local log = io.open(log_path, "w")
    local status, errors = os.execv(digester, args, {try = true, stdout = log, stderr = log, timeout = 1800 * 1000})
    log:close()
    local output = io.readfile(log_path) or ""
    os.tryrm(log_path)
    if errors == "wait process timeout" then
        os.tryrm(out_path)
        raise("swift-api-digester timed out after 1800 seconds on %s", module)
    end
    if status == nil then
        os.tryrm(out_path)
        return nil, nil, string.format("the digester's output for %s could not be read: %s", module, tostring(errors))
    end
    if status ~= 0 then
        os.tryrm(out_path)
        local text = common.strip(output)
        return nil, nil, string.format("swift-api-digester failed (%d): %s", status, text:sub(-300))
    end
    local payload, failure = json.loadfile(out_path)
    os.tryrm(out_path)
    if payload == nil then
        return nil, nil, string.format("the digester's output for %s could not be read: %s", module, tostring(failure))
    end
    return read_declarations(payload, module)
end

function string_hash(text)
    return hash.sha256(bytes(text))
end
