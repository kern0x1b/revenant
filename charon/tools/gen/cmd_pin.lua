-- `pin`: records, in the framework's sidecar, the declaration hash each hand-written override was written against. A new pin is
-- a bootstrap (marked for review); `--repin KEY` re-pins one key by hand. An override with no spec member gets no pin.

local layout = import("layout", {anonymous = true})
local snapshot = import("spec", {anonymous = true})
local emit = import("emit", {anonymous = true})

-- Returns the exit status.
function run(args)
    local fw = args.framework
    local spec = snapshot.load(args.tree, fw)
    local by_api = snapshot.index(spec)
    local pins = snapshot.pins(args.tree, fw)
    local by_key = {}
    for _, p in ipairs(pins) do
        by_key[p.key] = p
    end
    local overrides, order = snapshot.overrides(args.tree, fw)
    local added = 0
    for _, api in ipairs(order) do
        local target = by_api[api]
        if target ~= nil then
            local key = target.key
            if by_key[key] == nil then
                local pin = {api = api, key = key, pinned = target.hash, ["pinned-by"] = "bootstrap",
                             registry = overrides[api].registry}
                table.insert(pins, pin)
                by_key[key] = pin
                added = added + 1
            elseif args.repin == key then
                by_key[key].pinned = target.hash
                by_key[key]["pinned-by"] = "repin"
            end
        end
    end
    emit.file(layout.pins_path(args.tree, fw), snapshot.pins_text(pins))
    print(string.format("pins %s: %d total, %d added", fw, #pins, added))
    return 0
end
