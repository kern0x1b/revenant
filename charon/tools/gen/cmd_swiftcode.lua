-- `swiftcode`: writes each Swift module's compilable skeleton (swift_render.lua) from the full model (swift_model.lua) under --out,
-- one .swift per module. A build product, never committed. --sdk is the SDK, --out the folder, --framework runs one module (a
-- measurement). The digester runs through heavy.sh; --coordination names the corpus folder heavy.sh sits beside (default: the
-- workspace's). Beside each module's .swift it writes <module>.rendered: the keys (swift_shard.key_of) of the rows the skeleton declares,
-- which scope reads (--swift-rendered) to state those rows as generated stubs.

local swift_model = import("swift_model", {anonymous = true})
local swift_render = import("swift_render", {anonymous = true})
local order = import("order", {anonymous = true})

-- Renders one module's model into out_dir/<name>.swift and out_dir/<name>.rendered. Returns the number of rows rendered, or nil and the
-- reason it has none.
local function write_swift(folder, out_dir, name, known, classes, bounds)
    -- a sidecar of an earlier run is removed first: a module this run does not render has none
    local sidecar = path.join(out_dir, name .. ".rendered")
    if os.isfile(sidecar) then
        os.rm(sidecar)
    end
    local rows, reason = swift_model.model(folder, name)
    if rows == nil then
        return nil, reason
    end
    local filepath = path.join(out_dir, name .. ".swift")
    local emit = import("emit", {anonymous = true})
    -- the SDK's non-ASCII identifiers are written as the SDK spells them (an identifier is a fact of the SDK, and this file is not
    -- committed); any other non-ASCII text is still refused
    local identifiers = swift_model.non_ascii_identifiers(rows)
    local text, rendered = swift_render.render(rows, name, known, classes, nil, nil, bounds)
    emit.file(filepath, text, identifiers)
    emit.file(sidecar, table.concat(order.keys(rendered), "\n") .. "\n", identifiers)
    return #rows
end

-- Returns the exit status.
function run(args)
    assert(args.sdk, "--sdk (the SDK folder) is required")
    assert(args.out, "--out (the folder to write the code into) is required")
    local heavy = swift_model.heavy_path(args.coordination)
    assert(os.isfile(heavy), "no heavy.sh: " .. heavy)
    local all = swift_model.modules(args.sdk)
    local names = args.framework and {args.framework} or all
    local triple = swift_model.triple_of(args.sdk)
    local known = swift_model.module_set(args.sdk)
    os.mkdir(args.out)
    local started = os.mclock()
    -- the digester's dumps of every module, run as one batch first: the superclass chains of every module are read from them, and each
    -- module's model is read from the same cache
    local folder = swift_model.prefetch(args.tree, heavy, args.sdk, triple, all)
    -- the superclass chains of every module, read first (a class's inherited conformances come from the module it inherits from)
    local classes, no_model = swift_model.class_index(folder, all)
    local bounds = swift_model.associated_bounds(args.sdk)
    for _, l in ipairs(no_model) do
        print("swiftcode: class index, no model: " .. l)
    end
    local written, missing, failed, total = 0, 0, 0, 0
    local first_failure = nil
    for _, name in ipairs(names) do
        -- a module whose skeleton cannot be rendered (the emitted text is refused, or the renderer or the digester raises) is named with
        -- its error and counted; the others are still written, and the step then fails (see the return)
        local rows, reason, failure = nil, nil, nil
        try {
            function()
                rows, reason = write_swift(folder, args.out, name, known, classes, bounds[name])
            end,
            catch {
                function(err)
                    failure = tostring(err)
                end
            }
        }
        if failure ~= nil then
            failed = failed + 1
            first_failure = first_failure or (name .. ": " .. failure)
            print(string.format("swiftcode: %s not rendered: %s", name, failure))
        elseif rows then
            written = written + 1
            total = total + rows
            print(string.format("swiftcode: %s %d declarations", name, rows))
        else
            missing = missing + 1
            print(string.format("swiftcode: %s no code: %s", name, reason))
        end
    end
    local seconds = (os.mclock() - started) / 1000
    print(string.format("swiftcode: %d modules, %d declarations, %d modules without code, %d not rendered, %.1fs", written, total,
                        missing, failed, seconds))
    local detail = string.format("%d modules, %d declarations, %d without code, %d not rendered", written, total, missing, failed)
    if first_failure ~= nil then
        detail = detail .. " (first: " .. first_failure .. ")"
    end
    -- a module that is not rendered is a failure of the step (and of the sdk run): the others are written first. A module with no
    -- declaration of its own is counted (the digester's rule), not a failure.
    return failed > 0 and 1 or 0, detail
end
