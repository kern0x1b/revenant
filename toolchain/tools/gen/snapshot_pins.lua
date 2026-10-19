local files = import("files", {anonymous = true})
local tsv = import("tsv", {anonymous = true})
local digest = import("digest", {anonymous = true})
local emit = import("emit", {anonymous = true})
local layout = import("layout", {anonymous = true})
local order = import("order", {anonymous = true})

local SNAPSHOTS = {"protocols.tsv", "functions.tsv"}
local COLUMNS = {"framework", "file", "sha256"}

function pin_path(tree)
    return path.join(tree, layout.constants().SNAP_ROOT, "snapshots.tsv")
end

function pin_read(tree)
    local pins = {}
    for _, r in ipairs(tsv.records(files.read_text(pin_path(tree)) or "")) do
        pins[r.framework .. "\t" .. r.file] = r.sha256
    end
    return pins
end

local function pin_text(pins)
    local keys = {}
    for key in pairs(pins) do
        table.insert(keys, key)
    end
    table.sort(keys, order.less)
    local rows = {}
    for _, key in ipairs(keys) do
        local framework, file = string.match(key, "^(.-)\t(.*)$")
        table.insert(rows, {framework, file, pins[key]})
    end
    return tsv.table_text(COLUMNS, rows)
end

function pin_record(tree, fw, file)
    local pins = pin_read(tree)
    local text = files.read_text(path.join(layout.snap_dir(tree, fw), file))
    pins[fw .. "\t" .. file] = text ~= nil and digest.digest_of(text) or nil
    emit.file(pin_path(tree), pin_text(pins))
end

function pin_keys(tree)
    local root = path.join(tree, layout.constants().SNAP_ROOT)
    local base = path.absolute(root)
    local keys = {}
    for _, filepath in ipairs(files.glob(path.join(root, "**.tsv"))) do
        local rel = string.sub(path.absolute(filepath), #base + 2)
        local framework, file = string.match(rel, "^(.*)/([^/]+)$")
        if framework ~= nil and (file == SNAPSHOTS[1] or file == SNAPSHOTS[2]) then
            table.insert(keys, {framework, file})
        end
    end
    return keys
end

function pin_problems(tree)
    local pins = pin_read(tree)
    local root = path.join(tree, layout.constants().SNAP_ROOT)
    local out, seen = {}, {}
    for _, key in ipairs(pin_keys(tree)) do
        local framework, file = key[1], key[2]
        local pin = framework .. "\t" .. file
        local text = files.read_text(path.join(root, framework, file)) or ""
        seen[pin] = true
        if pins[pin] == nil then
            table.insert(out, framework .. " " .. file .. ": not pinned (the command that writes it records the pin)")
        elseif digest.digest_of(text) ~= pins[pin] then
            table.insert(out, framework .. " " .. file .. ": differs from its pin (re-run the command that writes it)")
        end
    end
    for pin in pairs(pins) do
        if not seen[pin] then
            local framework, file = string.match(pin, "^(.-)\t(.*)$")
            table.insert(out, framework .. " " .. file .. ": pinned, but the file is gone")
        end
    end
    table.sort(out, order.less)
    return out
end
