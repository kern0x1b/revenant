local swift_model = import("swift_model", {anonymous = true})
local swift_render = import("swift_render", {anonymous = true})
local order = import("order", {anonymous = true})

local function write_swift(folder, out_dir, name, known, classes, bounds)
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
    local identifiers = swift_model.non_ascii_identifiers(rows)
    local text, rendered = swift_render.render(rows, name, known, classes, nil, nil, bounds)
    emit.file(filepath, text, identifiers)
    emit.file(sidecar, table.concat(order.keys(rendered), "\n") .. "\n", identifiers)
    return #rows
end

function run(args)
    assert(args.sdk, "--sdk (the SDK folder) is required")
    assert(args.out, "--out (the folder to write the code into) is required")
    local all = swift_model.modules(args.sdk)
    local names = args.framework and {args.framework} or all
    local triple = swift_model.triple_of(args.sdk)
    local known = swift_model.module_set(args.sdk)
    os.mkdir(args.out)
    local started = os.mclock()
    local folder = swift_model.prefetch(args.sdk, triple, all)
    local classes, no_model = swift_model.class_index(folder, all)
    local bounds = swift_model.associated_bounds(args.sdk)
    for _, l in ipairs(no_model) do
        print("swiftcode: class index, no model: " .. l)
    end
    local written, missing, failed, total = 0, 0, 0, 0
    local first_failure = nil
    for _, name in ipairs(names) do
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
    return failed > 0 and 1 or 0, detail
end
