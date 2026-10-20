import("core.base.json")
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})
local workspace = import("workspace", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})

CORPUS = workspace.corpus()
function corpus_dir()
    return CORPUS
end

function built_exports_file()
    return BUILT_EXPORTS
end

function built_exports_header()
    return BUILT_EXPORTS_HEADER
end

CACHES = os.getenv("REVENANT_CACHES_DIR") or path.join(CORPUS, "caches")
STORE = path.join(CORPUS, "store.json")
LADDER = {{band = "7", stem = "7.0.1"}, {band = "8-10", stem = "10.3.4"}, {band = "11-12", stem = "12.0"}, {band = "13+", stem = "18.0"}}
BAND_ORDER = {"7", "8-10", "11-12", "13+"}
BAND_ROUTE = {["7"] = "Backports 7-10", ["8-10"] = "Backports 7-10/10",
              ["11-12"] = "Backports 11-12", ["13+"] = "beyond current backports"}

RUNTIME_LIBS = {"libobjc", "libdyld", "libc++", "libc++abi", "libcompiler_rt",
                "libunwind", "libSystem", "libdbm"}
CAT_ORDER = {FRAMEWORK = 0, SYSCALL = 1, SYSLIB = 2, RUNTIME = 3}
GAP_STATUS = {["gap?"] = true, owed = true, absent = true}
STATUS_RANK = {implemented = 0, inert = 1, ignored = 2, owed = 3, absent = 4}
A5_UNREACHABLE = {Metal = true, MetalKit = true, MetalPerformanceShaders = true, MetalPerformanceShadersGraph = true}
BUILT_EXPORTS = os.getenv("REVENANT_BUILT_EXPORTS") or path.join(CORPUS, "built-exports-6.1.3.txt")
BUILT_EXPORTS_HEADER = "# canon "
REGISTRY_TSV = os.getenv("REVENANT_REGISTRY_TSV") or path.join(workspace.run("registry-export"), "carried-registry.tsv")

function registry_export()
    return REGISTRY_TSV
end

local SKIP_EXTENSIONS = {png = true, plist = true, nib = true, car = true, json = true, strings = true, storyboardc = true}

local function split_tabs(line)
    local fields, start = {}, 1
    while true do
        local tab = line:find("\t", start, true)
        if not tab then
            table.insert(fields, line:sub(start))
            return fields
        end
        table.insert(fields, line:sub(start, tab - 1))
        start = tab + 1
    end
end

function read_json(file)
    local held, err = json.decode(io.readfile(file))
    if held == nil then
        raise("demand.lua: %s is not readable JSON: %s", file, tostring(err))
    end
    return held
end

local function load_cache_tsv(stem, caches)
    local attr = {}
    for line in io.lines(path.join(caches or CACHES, stem .. ".tsv")) do
        local sym, fw = line:match("^([^\t]*)\t?(.*)$")
        if sym ~= "" and attr[sym] == nil then
            attr[sym] = fw
        end
    end
    return attr
end

local function build_index(caches)
    local b60 = load_cache_tsv("6.0", caches)
    local ladder = {}
    for _, rung in ipairs(LADDER) do
        table.insert(ladder, {band = rung.band, attr = load_cache_tsv(rung.stem, caches)})
    end
    return b60, ladder
end

local function macho_binaries(appdir)
    local out = {}
    for _, p in ipairs(os.files(path.join(appdir, "**"))) do
        local ext = p:match("%.([^./]+)$")
        if not (ext and SKIP_EXTENSIONS[ext]) and os.iorunv("file", {p}):find("Mach-O", 1, true) then
            table.insert(out, p)
        end
    end
    byteorder.sort(out)
    return out
end

local function scan_symbols(binary)
    local undefined, defined = {}, {}
    for line in os.iorunv("nm", {"-m", binary}):gmatch("[^\n]+") do
        local toks = {}
        for tok in line:gmatch("%S+") do
            table.insert(toks, tok)
        end
        local at = nil
        for index, tok in ipairs(toks) do
            if tok == "external" then
                at = index
                break
            end
        end
        local sym = at and toks[at + 1]
        if sym and sym:sub(1, 1) == "_" then
            if line:find("(undefined)", 1, true) then
                local previous = undefined[sym]
                if previous == nil then previous = true end
                undefined[sym] = previous and (line:find("weak external", 1, true) ~= nil)
            elseif at == 1 or toks[at - 1] ~= "non-external" then
                defined[sym] = true
            end
        end
    end
    return undefined, defined
end

local function sym_kind(sym)
    local name = sym:match("^_OBJC_CLASS_%$_(.+)$") or sym:match("^_OBJC_METACLASS_%$_(.+)$")
    if name then
        return "class", name
    end
    name = sym:match("^_OBJC_LABEL_PROTOCOL_%$_(.+)$") or sym:match("^_OBJC_PROTOCOL_%$_(.+)$")
    if name then
        return "protocol", name
    end
    return "symbol", sym
end

local function categorize(fw)
    if fw:sub(-6) ~= ".dylib" then
        return "FRAMEWORK"
    end
    if fw == "libsystem_kernel.dylib" then
        return "SYSCALL"
    end
    local stem = fw:sub(1, -7)
    for _, runtime in ipairs(RUNTIME_LIBS) do
        if stem:sub(1, #runtime) == runtime then
            return "RUNTIME"
        end
    end
    return "SYSLIB"
end

local function load_store(missing_ok)
    if os.isfile(STORE) then
        return read_json(STORE)
    end
    if not missing_ok then
        raise("demand.lua: no store at %s; run ingest first.", STORE)
    end
    return {apps = {}}
end

function ingest(app, appdir)
    if not os.isdir(appdir) then
        raise("demand.lua: %s is not a bundle directory; ingest reads the .app, not a scan of it.", appdir)
    end
    local b60, ladder = build_index()
    local bins = macho_binaries(appdir)
    local undefined = {}
    local defined = {}
    for _, binary in ipairs(bins) do
        local und, defd = scan_symbols(binary)
        for sym, weak in pairs(und) do
            local previous = undefined[sym]
            if previous == nil then previous = true end
            undefined[sym] = previous and weak
        end
        for sym in pairs(defd) do
            defined[sym] = true
        end
    end
    local demand = {}
    local residual, bundled = 0, 0
    for _, sym in ipairs(byteorder.keys(undefined)) do
        if b60[sym] == nil then
            if defined[sym] then
                bundled = bundled + 1
            else
                local band, fw = nil, nil
                for _, rung in ipairs(ladder) do
                    if rung.attr[sym] ~= nil then
                        band, fw = rung.band, rung.attr[sym]
                        break
                    end
                end
                if band == nil then
                    residual = residual + 1
                else
                    local kind, name = sym_kind(sym)
                    local key = kind .. "\1" .. name
                    local current = demand[key]
                    if current == nil then
                        demand[key] = {kind = kind, name = name, framework = fw, band = band,
                                       cat = categorize(fw), weak = undefined[sym]}
                    else
                        current.weak = current.weak and undefined[sym]
                    end
                end
            end
        end
    end
    local records, byband, classes = {}, {}, 0
    for _, key in ipairs(byteorder.keys(demand)) do
        local record = demand[key]
        table.insert(records, record)
        byband[record.band] = (byband[record.band] or 0) + 1
        if record.kind == "class" then
            classes = classes + 1
        end
    end
    local store = load_store(true)
    store.apps[app] = {binaries = #bins, demand = records, residual = residual}
    local text, err = json.encode(store, {pretty = true, indent = 1})
    if not text then
        raise("demand.lua: cannot encode the store: %s", tostring(err))
    end
    io.writefile(STORE, text)
    local shown = {}
    for _, band in ipairs(BAND_ORDER) do
        if byband[band] then
            table.insert(shown, string.format("'%s': %d", band, byband[band]))
        end
    end
    print(string.format("%s: %d binaries, %d system demands (%d classes, %d symbols) bands={%s} residual(non-Apple)=%d bundle-satisfied=%d",
        app, #bins, #records, classes, #records - classes, table.concat(shown, ", "), residual, bundled))
end

function load_registry()
    if not os.isfile(REGISTRY_TSV) then
        raise("demand.lua: registry export not found at %s (REVENANT_REGISTRY_TSV). Every row would "
            .. "silently read as undecided instead of raising.", REGISTRY_TSV)
    end
    local reg = {}
    local lines = io.lines(REGISTRY_TSV)
    local header = lines() or ""
    local new_format = header:sub(1, 10) == "framework\t"
    for line in lines do
        local p = split_tabs(line)
        local api, status
        if new_format then
            if #p >= 3 then api, status = p[2], p[3] end
        elseif #p >= 4 then
            status, api = p[1], p[4]
        end
        if api then
            local rank, held = STATUS_RANK[status] or 9, reg[api]
            if held == nil or rank < (STATUS_RANK[held] or 9) then
                reg[api] = status
            end
        end
    end
    return reg
end

local function load_reg_kinds()
    if not os.isfile(REGISTRY_TSV) then
        raise("demand.lua: registry export not found at %s (REVENANT_REGISTRY_TSV). load_reg_kinds() has "
            .. "nothing to read.", REGISTRY_TSV)
    end
    local kinds = {}
    local lines = io.lines(REGISTRY_TSV)
    local header = lines() or ""
    if header:sub(1, 10) ~= "framework\t" then
        return kinds
    end
    local cols = split_tabs(header)
    local ki = nil
    for index, col in ipairs(cols) do
        if col == "kind" then ki = index end
    end
    if not ki then
        return kinds
    end
    for line in lines do
        local p = split_tabs(line)
        if p[ki] and p[ki] ~= "" then
            kinds[p[2]] = p[ki]
        end
    end
    return kinds
end

local function carried_status(reg, kind, name, framework)
    if A5_UNREACHABLE[framework] then
        return "n/a-A5"
    end
    local api = name
    if kind ~= "class" and name:sub(1, 1) == "_" then
        api = name:sub(2)
    end
    if reg[api] ~= nil then return reg[api] end
    if reg[api .. "()"] ~= nil then return reg[api .. "()"] end
    return "gap?"
end

local function is_swift_mangled(name)
    return name:sub(1, 3) == "_$s" or name:sub(1, 3) == "_$S" or name:sub(1, 2) == "$s" or name:sub(1, 2) == "$S"
end

local function sorted_members(set)
    local out = {}
    for member in pairs(set) do
        table.insert(out, member)
    end
    byteorder.sort(out)
    return out
end

function report(only)
    local store = load_store(false)
    local reg = load_registry()
    local apps = byteorder.keys(store.apps)
    local rows, agg = {}, {}
    for _, app in ipairs(apps) do
        for _, r in ipairs(store.apps[app].demand) do
            if not is_swift_mangled(r.name) then
                local cat = r.cat or categorize(r.framework)
                if only == nil or only[cat] then
                    local key = table.concat({cat, r.kind, r.name, r.framework, r.band}, "\1")
                    local e = agg[key]
                    if e == nil then
                        e = {cat = cat, kind = r.kind, name = r.name, framework = r.framework, band = r.band,
                             apps = {}, strong = {}, order = #rows + 1}
                        agg[key] = e
                        table.insert(rows, e)
                    end
                    e.apps[app] = true
                    if not r.weak then
                        e.strong[app] = true
                    end
                end
            end
        end
    end
    local function count(set)
        local n = 0
        for _ in pairs(set) do n = n + 1 end
        return n
    end
    for _, e in ipairs(rows) do
        e.status = carried_status(reg, e.kind, e.name, e.framework)
        e.gap = GAP_STATUS[e.status] and 0 or 1
        e.na, e.ns = count(e.apps), count(e.strong)
    end
    local keyed = {}
    for _, e in ipairs(rows) do
        local key = string.format("%d\1%d\1%09d\1%09d\1%s\1%s\1%s\1%09d", CAT_ORDER[e.cat] or 9, e.gap,
            999999999 - e.ns, 999999999 - e.na, e.band, e.framework, e.name, e.order)
        keyed[key] = e
    end
    print(string.format("# Corpus system-API demand vs stock iOS 6.0  (%d apps: %s)", #apps, table.concat(apps, ", ")))
    print("# carried-status from registry (main 6318a82); gap?=undecided/not-listed=gap; n/a-A5=unreachable Metal")
    print("# columns: #apps  strong/weak  carried  band  route  framework  kind  name")
    for _, key in ipairs(byteorder.keys(keyed)) do
        local e = keyed[key]
        local flag = GAP_STATUS[e.status] and "GAP " or "    "
        print(string.format("%4d  s%d/w%-3d %s%-11s %-6s %-18s %-22s %-6s %s    [%s]",
            e.na, e.ns, e.na - e.ns, flag, e.status, e.band, BAND_ROUTE[e.band] or "?",
            e.framework, e.kind, e.name, table.concat(sorted_members(e.apps), ",")))
    end
end

function main(cmd, ...)
    cmd = cmd or "report"
    if cmd == "ingest" then
        local app, appdir = ...
        assert(app and appdir, "usage: demand.lua ingest <app> <path-to-.app>")
        ingest(app, appdir)
    elseif cmd == "report" then
        local only = nil
        local categories = ...
        if categories then
            only = {}
            for cat in categories:gmatch("[^,]+") do
                only[cat] = true
            end
        end
        report(only)
    else
        print("usage: demand.lua ingest <app> <path-to-.app> | report [cat,cat...]")
    end
end
