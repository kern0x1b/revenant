-- The associated types of a protocol carry the bound the SDK's swiftinterface states (tools/gen/swift_model.lua associated_bounds,
-- tools/gen/swift_render.lua with_bounds): the digester's dump names an associated type and not its inheritance, so the skeleton's
-- "associatedtype Transformer : Fix.Transformer" was bare, and Transformer.Input was "is not a member type" (424 errors in
-- CreateMLComponents). Checked on a fixture interface: a bound, a bound with a where clause (the clause is not part of the bound), a bare
-- associated type, and the render. Run: xmake l tests/gen/swift_associated_test.lua (pure Lua: no toolchain)

local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")
local SCRATCH = path.join(os.scriptdir(), "..", "..", "build", "swift-associated-test")

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

local function write(filepath, text)
    os.mkdir(path.directory(filepath))
    local handle = assert(io.open(filepath, "wb"), "cannot write " .. filepath)
    handle:write(text)
    handle:close()
end

function main()
    local model = import("gen.swift_model", {rootdir = TOOLS, anonymous = true})
    local render = import("gen.swift_render", {rootdir = TOOLS, anonymous = true})
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
          "// swift-interface-format-version: 1.0\n"
          .. "public protocol Estimator<Annotation> {\n"
          .. "  associatedtype Transformer : Fix.Transformer\n"
          .. "  associatedtype Annotation\n"
          .. "  associatedtype Item : Swift.Hashable where Item == Swift.Int\n"
          .. "  func fit() -> Transformer\n"
          .. "}\n"
          .. "public protocol Transformer<Input> {\n"
          .. "  associatedtype Input\n"
          .. "  associatedtype Output\n"
          .. "}\n")
    local bounds = model.associated_bounds(sdk)
    local fix = bounds.Fix or {}
    check(fix.Estimator ~= nil and fix.Estimator.associated.Transformer == "Fix.Transformer", "the bound of Transformer is read: "
          .. tostring(fix.Estimator and fix.Estimator.associated.Transformer))
    check(fix.Estimator ~= nil and fix.Estimator.associated.Item == "Swift.Hashable", "a where clause is not part of the bound")
    check(fix.Estimator ~= nil and fix.Estimator.associated.Annotation == nil, "an associated type with no bound has none")
    check(fix.Estimator.primaries == "Annotation", "the primary associated types of the protocol are read: " .. tostring(fix.Estimator.primaries))
    check(fix.Transformer.associated.Input == nil and fix.Transformer.primaries == "Input", "a protocol with primaries and no bound has no bound")

    local rows = {
        row({kind = "swift-protocol", name = "Estimator", usr = "s:3Fix9EstimatorP"}),
        row({kind = "swift-protocol", name = "Transformer", usr = "s:3Fix11TransformerP"}),
        row({kind = "swift-associatedtype", container = "Estimator", name = "Transformer", usr = "s:3Fix9EstimatorP11Transformer"}),
        row({kind = "swift-associatedtype", container = "Estimator", name = "Annotation", usr = "s:3Fix9EstimatorP10Annotation"}),
    }
    local text = render.render(rows, "Fix", {Fix = true, Swift = true}, nil, nil, nil, fix)
    check(string.find(text, "public protocol Estimator<Annotation> {", 1, true) ~= nil, "the primary associated types are in the protocol's signature")
    check(string.find(text, "associatedtype Transformer : Fix.Transformer", 1, true) ~= nil, "the rendered Transformer carries its bound")
    -- the qualifier stays: Fix declares Transformer (a row of its own), so the bound names the protocol, not the associated type
    check(string.find(text, "associatedtype Annotation\n", 1, true) ~= nil, "a bare associated type stays bare")
    check(string.find(text, "associatedtype Transformer\n", 1, true) == nil, "the bound is not dropped")

    -- a generic parameter named like the protocol it conforms to shadows it: the conformance is spelled with the framework's qualifier
    -- (shadowed_rows; CreateMLComponents' PreprocessingEstimator<Preprocessor, Estimator>: Estimator)
    local shadow = {row({kind = "swift-protocol", name = "Estimator", usr = "s:3Fix9EstimatorP"}),
                    row({kind = "swift-struct", name = "Pre", usr = "s:3Fix3PreV", conformances = "Estimator",
                         generic_sig = "<Preprocessor, Estimator>"})}
    local shadow_text = render.render(shadow, "Fix", {Fix = true, Swift = true}, nil, nil, nil, nil)
    check(string.find(shadow_text, "Pre<Preprocessor, Estimator>: Fix.Estimator", 1, true) ~= nil,
          "a conformance shadowed by a generic parameter is qualified: " .. shadow_text)

    print("swift associated test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end
