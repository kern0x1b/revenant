-- The imports of the Swift skeletons (tools/gen/swift_model.lua clang_modules, module_set; tools/gen/swift_render.lua imports_of,
-- qualified_conformances, stdlib_qualified; tools/gen/swift_roundtrip.lua compile_item): a skeleton names a module the SDK has as a clang
-- module only (_LocationEssentials and Matter: a modulemap and a .tbd, no swiftinterface; os_object: the usr/include modulemap), and it
-- imports it, so the name resolves (the coordinator's run: 66 "cannot find type '_LocationEssentials'", 14 for Matter, 24 for os_object).
-- A Foundation protocol named bare (NSCopying in AVAudioCompressedBuffer, LocalizedError in Messages) is spelled Foundation.X and
-- imports Foundation. A row that names Builtin imports it, and the compile carries -enable-builtin-module (144 "cannot find type
-- 'Builtin'" in the coordinator's run). Checked here on fixtures: the
-- modulemap reads, the module set, the imports and spellings of rendered rows, the compile words. Run:
-- xmake l tests/gen/swift_imports_test.lua (pure Lua: no toolchain)

local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")
local SCRATCH = path.join(os.scriptdir(), "..", "..", "build", "swift-imports-test")

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
    local roundtrip = import("gen.swift_roundtrip", {rootdir = TOOLS, anonymous = true})
    local failures = 0
    local function check(ok, label)
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end

    -- the SDK: two frameworks with a clang modulemap and no swiftinterface, and the usr/include modulemap of os_object
    os.rm(SCRATCH)
    local sdk = path.join(SCRATCH, "sdk")
    local frameworks = path.join(sdk, "System", "Library", "Frameworks")
    write(path.join(frameworks, "_LocationEssentials.framework", "Modules", "module.modulemap"),
          "//  LocationEssentials.modulemap\nframework module _LocationEssentials [system] {\n    umbrella header \"x.h\"\n}\n")
    write(path.join(frameworks, "Matter.framework", "Modules", "module.modulemap"),
          "framework module Matter [system] {\n    umbrella header \"Matter.h\"\n    export *\n}\n")
    write(path.join(sdk, "usr", "include", "module.modulemap"), "extern module os \"os.modulemap\"\nextern module os_object \"os.modulemap\"\n")
    local clang = model.clang_modules(sdk)
    check(clang._LocationEssentials and clang.Matter and clang.os_object, "the clang modules of the SDK are read from their modulemaps")
    local known = model.module_set(sdk)
    check(known._LocationEssentials and known.Matter and known.os_object, "the module set holds the clang modules (they are importable)")

    -- ARKit names _LocationEssentials: the skeleton imports it
    local rows = {row({kind = "swift-method", container = "ARGeoAnchor", name = "init(coordinate:)", side = "-",
                       type = "-", params = "_LocationEssentials.CLLocationCoordinate2D", usr = "s:ARGeoAnchor.init"})}
    local text = render.render(rows, "ARKit", known, nil, nil, nil)
    check(string.find(text, "import _LocationEssentials", 1, true) ~= nil, "a clang module a row names is imported")

    -- AVFAudio names NSCopying bare: spelled Foundation.NSCopying and Foundation imported; Messages' LocalizedError likewise
    local avf = {row({kind = "swift-class", name = "Buffer", usr = "s:Buffer", conformances = "NSCopying,NSMutableCopying"})}
    local avf_text = render.render(avf, "AVFAudio", {AVFAudio = true, Foundation = true}, nil, nil, nil)
    check(string.find(avf_text, "Foundation.NSCopying", 1, true) ~= nil and string.find(avf_text, "Foundation.NSMutableCopying", 1, true) ~= nil,
          "a Foundation protocol named bare is spelled Foundation.X")
    check(string.find(avf_text, "import Foundation", 1, true) ~= nil, "the Foundation protocols import Foundation")
    local msg = {row({kind = "swift-enum", name = "Err", usr = "s:Err", conformances = "LocalizedError,Error"})}
    local msg_text = render.render(msg, "Messages", {Messages = true, Foundation = true}, nil, nil, nil)
    check(string.find(msg_text, "Foundation.LocalizedError", 1, true) ~= nil and string.find(msg_text, "Swift.Error", 1, true) ~= nil,
          "LocalizedError is spelled Foundation.LocalizedError, Error stays Swift.Error")

    -- a framework that a module depends on is no import of the dependent: CoreGraphics' Foundation cycle is the attribution's
    local attributed = {Foundation = true}
    local cg_text = render.render(avf, "CoreGraphics", {CoreGraphics = true, Foundation = true}, nil, nil, attributed)
    check(string.find(cg_text, "import Foundation", 1, true) == nil, "a module that depends on the framework is not imported")

    -- the implementation's own name: RealityFoundation's public name RealityKit is no import of RealityFoundation's (imports_of)
    local own = {row({kind = "swift-property", container = "Fixed", name = "twin", side = "-", type = "RealityFoundation.Thing",
                      accessors = "get", usr = "s:Fixed.twin"})}
    local rk_text = render.render(own, "RealityFoundation", {RealityFoundation = true, RealityKit = true}, nil,
                                  {RealityFoundation = "RealityKit"}, nil)
    check(string.find(rk_text, "import RealityKit", 1, true) == nil, "a public name that maps back to the framework is no import of it")

    -- Builtin: the stdlib modules name Builtin.Executor (Distributed); the module is known, and the skeleton imports it
    check(known.Builtin, "the Builtin module is importable")
    local builtin_text = render.render({row({kind = "swift-function", name = "task(_:)", side = "-", type = "Swift.Int",
                                             params = "Builtin.Executor", usr = "s:task"})}, "Distributed", known, nil, nil, nil)
    check(string.find(builtin_text, "import Builtin", 1, true) ~= nil, "a row that names Builtin imports it")

    -- the compile: the flag that makes the explicit import of Builtin legal is in the compile's words, once
    local item = roundtrip.compile_item("arm64e-apple-ios26.2", sdk, path.join(SCRATCH, "Fix.swift"), path.join(SCRATCH, "module"),
                                        "Fix", nil)
    local _, flag_count = string.gsub(item.command, "%-enable%-builtin%-module", "")
    check(flag_count == 1, "the compile carries -enable-builtin-module once")

    print("swift imports test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end
