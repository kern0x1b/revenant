local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")

local function row(fields)
    local out = {kind = "-", usr = "-", container = "-", name = "-", side = "-", type = "-", params = "-", generic_sig = "-",
                 conformances = "-", superclass = "-", throwing = "-", async = "-", mutating = "-", attributes = "-", accessors = "-",
                 storage = "-", is_let = "-", is_open = "-", requirement = "-", in_extension = "-", owner_module = "-", raw = "-",
                 alias = "-", overriding = "-", init_kind = "-", availability = "-", outer_names = "-"}
    for key, value in pairs(fields) do
        out[key] = value
    end
    return out
end

local function depths_of(text)
    local depths, depth = {}, 0
    for line in string.gmatch(text, "[^\n]*") do
        table.insert(depths, {line = line, depth = depth})
        local _, opened = string.gsub(line, "{", "")
        local _, closed = string.gsub(line, "}", "")
        depth = depth + opened - closed
    end
    return depths
end

function main()
    local render = import("gen.swift_render", {rootdir = TOOLS, anonymous = true})
    local failures = 0
    local function check(ok, label)
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end

    local rows = {
        row({kind = "swift-struct", name = "Outer", usr = "s:Fix.Outer"}),
        row({kind = "swift-struct", container = "Outer", name = "Inner", usr = "s:Fix.Outer.Inner"}),
        row({kind = "swift-protocol", container = "Outer.Inner", name = "P", usr = "s:Fix.Outer.Inner.P"}),
        row({kind = "swift-method", container = "Outer.Inner.P", name = "req()", side = "-", type = "Swift.Int",
             usr = "s:Fix.Outer.Inner.P.req", requirement = "yes"}),
        row({kind = "swift-method", container = "Outer.Inner.P", name = "twice()", side = "-", type = "Swift.Int",
             usr = "s:Fix.Outer.Inner.P.twice", in_extension = "yes"}),
    }

    local text = render.render(rows, "Fix", {}, nil, nil)
    local lines = depths_of(text)

    local at_extension, extension_depth = nil, nil
    for i, entry in ipairs(lines) do
        if entry.line == "extension Fix.Outer.Inner.P {" then
            at_extension, extension_depth = i, entry.depth
        end
    end
    check(at_extension ~= nil, "the extension of the nested protocol is declared under its qualified name: " .. text)
    check(extension_depth == 0, "the extension is at file scope (depth 0), not inside the type (depth " .. tostring(extension_depth) .. ")")

    local twice_depth, req_depth = nil, nil
    for _, entry in ipairs(lines) do
        if string.find(entry.line, "func twice()", 1, true) then
            twice_depth = entry.depth
        elseif string.find(entry.line, "func req()", 1, true) then
            req_depth = entry.depth
        end
    end
    check(twice_depth == 1, "the extension member is inside the extension: depth " .. tostring(twice_depth))
    check(req_depth == 3, "the protocol's requirement stays in the protocol (Outer, Inner, P): depth " .. tostring(req_depth))

    check(at_extension ~= nil and at_extension > #lines - 5, "the extension follows the types: line " .. tostring(at_extension))

    print("swift file scope test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end
