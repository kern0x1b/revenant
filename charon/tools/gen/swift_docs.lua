local json = import("core.base.json")
local files = import("files", {anonymous = true})
local stream = import("stream", {anonymous = true})
local sdk_info = import("sdk", {anonymous = true})
local sdk_modules = import("sdk_modules", {anonymous = true})

local memo = {}

local function heavy_path()
    return path.join(os.getenv("HOME"), "Git", "projects", "ios", "coordination", "heavy.sh")
end

local function escaped(text)
    local out = string.gsub(text or "", "\\", "\\\\")
    out = string.gsub(out, "\t", "\\t")
    out = string.gsub(out, "\n", "\\n")
    out = string.gsub(out, "\r", "\\r")
    return out
end

local function spelled(fragments)
    local parts = {}
    for _, fragment in ipairs(fragments or {}) do
        table.insert(parts, fragment.spelling or "")
    end
    return table.concat(parts)
end

local function comment_lines(symbol)
    local out = {}
    for _, line in ipairs(symbol.docComment and symbol.docComment.lines or {}) do
        table.insert(out, line.text or "")
    end
    return out
end

local function brief_of(lines)
    local out = {}
    for _, text in ipairs(lines) do
        if text == "" then
            break
        end
        table.insert(out, text)
    end
    return table.concat(out, " ")
end

local function side_of(symbol)
    for _, fragment in ipairs(symbol.declarationFragments or {}) do
        if fragment.kind == "keyword" and (fragment.spelling == "static" or fragment.spelling == "class") then
            return "+"
        end
    end
    return "-"
end

local function params_of(symbol)
    local names = {}
    for _, parameter in ipairs(symbol.functionSignature and symbol.functionSignature.parameters or {}) do
        table.insert(names, parameter.name or parameter.internalName or "_")
    end
    return table.concat(names, " | ")
end

local function row_of(name, symbol)
    local components = symbol.pathComponents or {}
    local container = #components > 1 and components[#components - 1] or "-"
    local lines = comment_lines(symbol)
    local cells = {
        name,
        string.gsub(symbol.kind and symbol.kind.identifier or "unknown", "^swift%.", ""),
        symbol.identifier and symbol.identifier.precise or "-",
        container,
        symbol.names and symbol.names.title or "-",
        side_of(symbol),
        params_of(symbol),
        brief_of(lines),
        table.concat(lines, "\n"),
        spelled(symbol.declarationFragments),
    }
    for i, cell in ipairs(cells) do
        cells[i] = escaped(tostring(cell))
    end
    return table.concat(cells, "\t")
end

function lines(tree, sdk, name)
    local key = sdk .. "\t" .. name
    if memo[key] ~= nil then
        return memo[key]
    end
    local record = sdk_modules.module_of(sdk, name)
    assert(record ~= nil, "swift docs: the SDK holds no module " .. name)
    local out = path.join(tree, ".agent-work", "symbolgraph", (string.gsub(name, "/", "_")))
    os.tryrm(out)
    os.mkdir(out)
    local target = "arm64-apple-ios" .. sdk_info.discover(sdk).version
    local search = record.kind == "swift" and {"-I", path.directory(record.root)} or {"-F", path.directory(record.root)}
    local argv = {"xcrun", "swift-symbolgraph-extract", "-module-name", record.base, "-sdk", sdk, "-target", target}
    for _, value in ipairs(search) do
        table.insert(argv, value)
    end
    table.insert(argv, "-output-dir")
    table.insert(argv, out)
    table.insert(argv, "-minimum-access-level")
    table.insert(argv, "public")
    local status, _, errors = stream.heavy_text(heavy_path(), argv)
    assert(status == 0, string.format("swift docs %s: swift-symbolgraph-extract exits with status %s: %s", name, tostring(status),
        string.sub(errors or "", -300)))
    local file = path.join(out, record.base .. ".symbols.json")
    local data = json.decode(files.read_text(file) or "")
    assert(data ~= nil, "swift docs " .. name .. ": no symbol graph was written to " .. file)
    local rows = {}
    for _, symbol in ipairs(data.symbols or {}) do
        table.insert(rows, row_of(name, symbol))
    end
    memo[key] = rows
    return rows
end
