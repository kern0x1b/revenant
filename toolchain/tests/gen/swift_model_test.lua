local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")
local json = import("core.base.json")

local function by_kind(rows)
    local out = {}
    for _, r in ipairs(rows) do
        out[r.kind .. " " .. r.name] = r
    end
    return out
end

function main()
    local model = import("gen.swift_model", {rootdir = TOOLS, anonymous = true})
    local digest = import("gen.digest", {rootdir = TOOLS, anonymous = true})
    local failures = 0
    local function check(ok, label)
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end

    local text = io.open(path.join(os.scriptdir(), "input", "fixtures", "swift", "model.json"), "rb"):read("a")
    local root = json.decode(text).ABIRoot
    local rows = assert(model.rows(root, "Fixture"))
    local r = by_kind(rows)

    check(r["swift-typealias Handle"] ~= nil, "a typealias has a row")
    check(r["swift-typealias Handle"].container == "-" and r["swift-typealias Handle"].usr == "s:7Fixture6Handlea",
          "a module-level typealias sits at level -")
    check(r["swift-typealias __Float16x4_t"] == nil, "a clang importer declaration (moduleName __ObjC) is left out, as the shard does")

    check(r["swift-struct Point"] ~= nil, "a struct has a row")
    check(r["swift-struct Point"].conformances == "Swift.Equatable,Swift.Sendable", "a struct carries its conformances")
    check(r["swift-struct Point"].availability == "ios=13.0", "a struct carries its platform introductions")
    check(r["swift-struct Point"].declhash
          == digest.digest("swift-struct", "s:7Fixture5PointV", "-", "Point", "-", "-", "-", "-", "-", "-", ""),
          "a type's declaration hash is the shard's own digest of the same parts")

    check(r["swift-property x"] ~= nil and r["swift-property x"].container == "Point", "a member's container is its type's api")
    check(r["swift-property x"].type == "Swift.Int" and r["swift-property x"].params == "-", "a property carries its type and no parameters")
    check(r["swift-property x"].storage == "yes" and r["swift-property x"].is_let == "-", "a stored var is marked stored and not let")
    check(r["swift-property x"].accessors == "get", "a property carries its accessor kinds")

    check(r["swift-method moved(dx:)"] ~= nil, "a method has a row")
    check(r["swift-method moved(dx:)"].type == "Fixture.Point" and r["swift-method moved(dx:)"].params == "Swift.Int",
          "a method carries its result and parameter types, as the shard does")
    check(r["swift-method moved(dx:)"].throwing == "yes", "a throwing method is marked throwing")

    check(r["swift-class Box"].superclass == "Fixture.Base", "a class carries its superclass")
    check(r["swift-class Box"].is_open == "yes" and r["swift-class Box"].attributes == "Final", "a class carries isOpen and its attributes")
    check(r["swift-method init(value:)"].params == "Fixture.Box | Swift.Int", "a constructor's children are its parameters, as the shard does")
    check(r["swift-method init(value:)"].throwing == "yes", "a throwing constructor is marked throwing")

    check(r["swift-enum Direction"].raw == "Swift.Int", "an enum carries its raw type")
    check(r["swift-constant north"] ~= nil and r["swift-constant north"].container == "Direction", "an enum element is a constant of its enum")

    check(r["swift-protocol Renderer"].generic_sig == "<Self : Fixture.RendererP>", "a protocol carries its generic signature")
    check(r["swift-associatedtype Output"] ~= nil and r["swift-associatedtype Output"].requirement == "yes",
          "an associated type is a requirement of its protocol")
    check(r["swift-method render(_:)"].requirement == "yes", "a protocol requirement is marked a requirement")

    check(r["swift-struct URL"].owner_module == "Foundation", "a type of another module names its owner")
    check(r["swift-property tag"].in_extension == "yes" and r["swift-property tag"].owner_module == "Foundation",
          "an extension member names its owner and its extension state")
    check(r["swift-property tag"].is_let == "yes", "a stored let is marked let")

    local function member(container, name)
        for _, row in ipairs(rows) do
            if row.container == container and row.name == name then
                return row
            end
        end
    end
    check(member("Base", "describe()").overriding == "-" and member("Box", "describe()").overriding == "yes",
          "an overriding member is marked overriding, its base member is not")
    check(member("Base", "init()").attributes == "Required" and member("Base", "init()").init_kind == "Designated",
          "a required designated initializer carries its attribute and its init kind")
    check(member("Box", "init()").init_kind == "Convenience", "a convenience initializer carries its init kind")
    check(r["swift-class Worker"] ~= nil and r["swift-class Worker"].conformances == "_Concurrency.Actor",
          "an actor is a class row that carries its Actor conformance")
    check(r["swift-typealias Opaque"] ~= nil and r["swift-typealias Opaque"].alias == "some Swift.Sendable",
          "a typealias carries the type it aliases")

    local missing = 0
    for _, row in ipairs(rows) do
        for _, column in ipairs(model.columns()) do
            if row[column] == nil then
                missing = missing + 1
            end
        end
    end
    check(missing == 0, "every row carries every model column (" .. missing .. " missing)")

    local asked = {}
    model.annotate_async(rows, function(names)
        asked = names
        local out = {}
        for _, name in ipairs(names) do
            if name == "$s7Fixture5PointV5moved2dxACSi_tKF" then
                table.insert(out, name .. " ---> Fixture.Point.moved(dx: Swift.Int) async throws -> Fixture.Point")
            else
                table.insert(out, name .. " ---> Fixture.other")
            end
        end
        return out
    end)
    check(#asked == 1 and asked[1] == "$s7Fixture5PointV5moved2dxACSi_tKF", "the demangler is asked for each mangled name, in order")
    r = by_kind(rows)
    check(r["swift-method moved(dx:)"].async == "yes", "an async function is marked async from its demangled signature")
    check(r["swift-method render(_:)"].async == "-", "a declaration with no mangled name keeps the empty async cell")

    local reparsed = tsv_records(model.text(rows))
    check(#reparsed == #rows, "the model text holds one line per row")
    check(reparsed[1].kind ~= nil and reparsed[#reparsed].declhash ~= nil, "the model text is read back by column name")

    check(model.triple_of(path.join(os.scriptdir(), "sdk_fixture", "good")) == "arm64e-apple-ios9.9",
          "the triple of an SDK is its deployment target, read from its SDKSettings.json")

    local public = model.public_modules(path.join(os.scriptdir(), "input", "fixtures", "swift-interfaces"))
    check(public.Impl == "Public", "a module whose interface names another as its public module maps to it")
    check(public.Plain == nil and public.Public == nil, "a module that names itself, or no public module, is not in the map")

    local macron = "m\196\129ori"
    local canonical = "\207\132_0_0"
    local superclass = "Base<" .. canonical .. ">"
    local identifiers = model.non_ascii_identifiers({{name = macron, type = "Swift.String", superclass = superclass}})
    check(#identifiers == 1 and identifiers[1] == macron,
          "a non-ASCII identifier of the model is listed; a canonical parameter is not")
    local emit = import("gen.emit", {rootdir = TOOLS, anonymous = true})
    check(emit.refused("var " .. macron .. ": Int", {macron}) == nil, "a non-ASCII identifier the model gave is allowed")
    check(emit.refused("var " .. macron .. ": Int", {}) == macron, "the same identifier is refused when the model gave none")
    check(emit.refused("var " .. macron .. "X: Int", {macron}) == macron .. "X", "a model word inside a longer run is refused")
    check(emit.refused("let s = \"" .. canonical .. "\"", {}) == canonical, "a non-ASCII byte in a string is refused too")
    check(emit.refused("plain ASCII", {}) == nil, "ASCII is never refused")

    local function class(name, owner, superclass, conformances)
        return {kind = "swift-class", container = "-", name = name, owner_module = owner, superclass = superclass,
                conformances = conformances}
    end
    local index = model.add_classes({}, "Foundation", {
        class("NSObject", "ObjectiveC", "-", "NSObjectProtocol,CustomDebugStringConvertible"),
        class("NSObject", "ObjectiveC", "-", "CustomStringConvertible,NSObjectProtocol"),
        class("Own", "-", "ObjectiveC.NSObject", "-"),
    })
    local objc = index["ObjectiveC.NSObject"]
    check(objc ~= nil and index["Foundation.NSObject"] == nil, "a class is keyed by the module that declares it")
    check(objc ~= nil and string.find(objc.conformances, "CustomDebugStringConvertible", 1, true) ~= nil
          and string.find(objc.conformances, "CustomStringConvertible", 1, true) ~= nil
          and string.find(objc.conformances, "NSObjectProtocol", 1, true) ~= nil,
          "a class two modules give has the union of their conformances")
    check(index["Foundation.Own"] ~= nil and index["Foundation.Own"].superclass == "ObjectiveC.NSObject",
          "a class of the indexed module is keyed by that module, and names its superclass")

    print("swift model test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end

function tsv_records(text)
    local tsv = import("gen.tsv", {rootdir = TOOLS, anonymous = true})
    return tsv.records(text)
end
