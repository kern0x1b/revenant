local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")
local SCRATCH = path.join(os.scriptdir(), "..", "..", "build", "swift-attribution-test")

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

local function write(filepath, text)
    os.mkdir(path.directory(filepath))
    local handle = assert(io.open(filepath, "wb"), "cannot write " .. filepath)
    handle:write(text)
    handle:close()
end

function main()
    local model = import("gen.swift_model", {rootdir = TOOLS, anonymous = true})
    local render = import("gen.swift_render", {rootdir = TOOLS, anonymous = true})
    local roundtrip = import("gen.swift_roundtrip", {rootdir = TOOLS, anonymous = true})
    local failures = 0
    local function check(ok, label)
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end

    os.rm(SCRATCH)
    local sdk = path.join(SCRATCH, "sdk")
    write(path.join(sdk, "System", "Library", "Frameworks", "Fix.framework", "Modules", "Fix.swiftmodule", "arm64e-apple-ios.swiftinterface"),
          "// swift-interface-format-version: 1.0\n@_exported import CoreFoundation\nimport Foundation\nimport Metal.MTLDevice\n"
          .. "@_exported public import RelevanceKit\nimport Swift\n\npublic struct Point {}\n")
    local graph = model.import_graph(sdk)
    check(graph.Fix ~= nil and graph.Fix.CoreFoundation and graph.Fix.Foundation and graph.Fix.Metal,
          "the graph reads the imports of Fix: the exported one, a plain one and a submodule's module")
    check(graph.Fix ~= nil and graph.Fix.RelevanceKit, "an export with an access level (@_exported public import) is read")
    check(graph.Fix ~= nil and graph.Fix.MTLDevice == nil, "a submodule is its module, not a module of its own")

    local chain = {A = {B = true}, C = {A = true}, D = {}, B = {}}
    local of_b = model.dependents_of(chain, "B")
    check(of_b.A and of_b.C and not of_b.D and not of_b.B, "the dependents of B are A (direct) and C (through A), not D, not B itself")
    local of_c = model.dependents_of(chain, "C")
    check(next_is_empty(of_c), "a module nothing imports has no dependents")

    local rows = {
        row({kind = "swift-struct", name = "Fixed", usr = "s:Fixed"}),
        row({kind = "swift-property", container = "Fixed", name = "size", side = "-", type = "CoreGraphics.CGFloat", accessors = "get",
             usr = "s:Fixed.size"}),
        row({kind = "swift-property", container = "Fixed", name = "count", side = "-", type = "Swift.Int", accessors = "get",
             usr = "s:Fixed.count"}),
    }
    local dependents = {CoreGraphics = true}
    local text = render.render(rows, "CoreFoundation", {CoreGraphics = true, CoreFoundation = true}, nil, nil, dependents)
    check(string.find(text, "CGFloat", 1, true) == nil, "a row naming a dependent module is not declared")
    check(string.find(text, "import CoreGraphics", 1, true) == nil, "the dependent module is not imported")
    check(string.find(text, "var count: Swift.Int", 1, true) ~= nil, "a row of this module's own names is declared")

    local sdk_rows = {rows[1], rows[2], rows[3]}
    local ours = {rows[1], rows[3]}
    local result = roundtrip.compare(sdk_rows, ours, nil, dependents)
    check(result.attributed == 1 and #result.missing == 0, "the SDK's size row is attributed, not missing: attributed " .. result.attributed)
    local strict = roundtrip.compare(sdk_rows, ours, nil, nil)
    check(#strict.missing == 1 and strict.attributed == 0, "without the dependents the same row is missing")

    local own = {rows[1], row({kind = "swift-property", container = "Fixed", name = "twin", side = "-",
                               type = "RealityFoundation.Thing", accessors = "get", usr = "s:Fixed.twin"})}
    local public_text = render.render(own, "RealityFoundation", {RealityFoundation = true, RealityKit = true}, nil,
                                      {RealityFoundation = "RealityKit"}, nil)
    check(string.find(public_text, "import RealityKit", 1, true) == nil, "a framework whose public name is its public module does not import it")
    check(string.find(public_text, "import RealityFoundation", 1, true) == nil, "a framework does not import itself")

    print("swift attribution test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end

function next_is_empty(set)
    for _ in pairs(set) do
        return false
    end
    return true
end
