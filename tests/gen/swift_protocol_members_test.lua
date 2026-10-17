-- The members of a protocol in the Swift skeleton (tools/gen/swift_render.lua): a protocol's requirements take no access modifier (the compiler
-- refuses "'public' modifier cannot be used in protocols" on a typealias or any other member), and a subscript states its accessors, as
-- the compiler requires ("subscript in protocol must have explicit { get } or { get set } specifier": 40 errors in the coordinator's sdk
-- run, CoreML). The model here is a protocol with a read-write subscript, a read-only one, an associated type, a typealias and a
-- method; the rendered protocol body must hold each in its kind's form, with no `public` at any depth inside it. Run:
-- xmake l tests/gen/swift_protocol_members_test.lua (pure Lua: no toolchain)

local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")

-- A model row with every cell the renderer reads, "-" where the row says nothing.
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
        row({kind = "swift-protocol", name = "Store", usr = "s:Store"}),
        row({kind = "swift-method", container = "Store", name = "subscript(_:)", side = "-", type = "Swift.String",
             params = "Swift.Int", accessors = "get,set", usr = "s:Store.subscript.rw", requirement = "yes"}),
        row({kind = "swift-method", container = "Store", name = "subscript(_:)", side = "-", type = "Swift.String",
             params = "Swift.String", accessors = "get", usr = "s:Store.subscript.ro", requirement = "yes"}),
        row({kind = "swift-associatedtype", container = "Store", name = "Element", usr = "s:Store.Element"}),
        row({kind = "swift-typealias", container = "Store", name = "Key", alias = "Swift.Int", usr = "s:Store.Key"}),
        row({kind = "swift-method", container = "Store", name = "reset()", side = "-", type = "-", usr = "s:Store.reset",
             requirement = "yes"}),
    }

    local text = render.render(rows, "Fix", {}, nil, nil)
    local lines = {}
    for line in string.gmatch(text, "[^\n]*") do
        table.insert(lines, line)
    end

    -- the subscripts: read-write is get and set, read-only is get, each with its parameter and result
    local has_rw, has_ro = false, false
    for _, line in ipairs(lines) do
        if line == "    subscript(_ p0: Swift.Int) -> Swift.String { get set }" then
            has_rw = true
        elseif line == "    subscript(_ p0: Swift.String) -> Swift.String { get }" then
            has_ro = true
        end
    end
    check(has_rw, "a read-write protocol subscript states get and set")
    check(has_ro, "a read-only protocol subscript states get")

    -- the other members, and no access modifier anywhere in the protocol's body
    local inside, body, closed = false, {}, false
    for _, line in ipairs(lines) do
        if line == "public protocol Store {" then
            inside = true
        elseif inside and line == "}" then
            closed = true
            inside = false
        elseif inside then
            table.insert(body, line)
        end
    end
    check(closed, "the protocol is declared and closed")
    local any_public = false
    for _, line in ipairs(body) do
        if string.find(line, "public", 1, true) then
            any_public = true
        end
    end
    check(not any_public, "no member of the protocol carries an access modifier")
    local has_assoc, has_alias, has_reset = false, false, false
    for _, line in ipairs(body) do
        if line == "    associatedtype Element" then
            has_assoc = true
        elseif line == "    typealias Key = Swift.Int" then
            has_alias = true
        elseif line == "    func reset()" then
            has_reset = true
        end
    end
    check(has_assoc, "the associated type is declared without an access modifier")
    check(has_alias, "the typealias is declared without an access modifier")
    check(has_reset, "the method requirement has no body and no access modifier")

    print("swift protocol members test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end
