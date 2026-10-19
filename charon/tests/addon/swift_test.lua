import("fixtures")

local SHAPES = [[
protocol Shape { func area() -> Double }
struct Rect: Shape { var w, h: Double; func area() -> Double { w * h } }
final class Counter { var n = 0; func bump() -> Int { n += 1; return n } }
]]

local PROBE = [[
@_cdecl("swift_probe")
public func probe(_ x: Int32) -> Int32 {
    let counter = Counter()
    _ = counter.bump()
    var names: [String: Int] = ["one": 1, "two": 2]
    names["three"] = 3
    let shapes: [any Shape] = [Rect(w: 2, h: 3), Rect(w: 1, h: 1)]
    let odd = (1...Int(x)).map { $0 * $0 }.filter { $0 % 2 == 1 }
    let text = "sum=\(odd.reduce(0, +)) keys=\(names.count) area=\(Int(shapes.map { $0.area() }.reduce(0, +)))"
    print(text)
    return Int32(truncatingIfNeeded: text.utf8.count + counter.bump())
}
]]

local MAIN = "#include <stdio.h>\nextern int swift_probe(int);\nint main(void) { printf(\"%d\\n\", swift_probe(9)); return 0; }\n"

local function build(folder, opt, swift, architecture, deployment)
    local work = path.join(folder, architecture)
    os.mkdir(work)
    local source = path.join(opt.swift, "share", "swift-source")
    local modules = path.join(work, "embedded")
    swift.build_module({swiftc = path.join(opt.swift, "bin", "swiftc"), source = source, architecture = architecture,
                        deployment = deployment, sdk = opt.sdk, output = modules, workdir = work})
    local common = {"-target", swift.triple(architecture, deployment), "-isysroot", opt.sdk, "-Wno-incompatible-sysroot", "-w",
                    "-mlinker-version=" .. fixtures.linker_version(opt.ld64)}
    local objects = {}
    local tables = swift.unicode_tables(source)
    local generated = path.join(work, "generated")
    io.writefile(path.join(generated, "swift", "Runtime", "CMakeConfig.h"), swift.runtime_config("6.4"))
    local includes = {"-I" .. generated}
    for _, folder in ipairs(tables.includedirs) do
        table.insert(includes, "-I" .. folder)
    end
    for _, define in ipairs(tables.defines) do
        table.insert(includes, "-D" .. define)
    end
    for _, file in ipairs(os.files(path.join(tables.folder, "*.cpp"))) do
        local object = path.join(work, path.basename(file) .. ".o")
        fixtures.run(work, opt.clang .. "++", table.join(common, includes, tables.cxxflags, {"-Os", "-c", file, "-o", object}))
        table.insert(objects, object)
    end
    io.writefile(path.join(work, "shapes.swift"), SHAPES)
    io.writefile(path.join(work, "probe.swift"), PROBE)
    io.writefile(path.join(work, "main.c"), MAIN)
    fixtures.run(work, path.join(opt.swift, "bin", "swiftc"), table.join(
        swift.compile_flags({architecture = architecture, deployment = deployment, sdk = opt.sdk, modules = modules,
                             module = "probe", optimize = "smallest"}),
        {"-emit-bc", "shapes.swift", "probe.swift", "-o", "probe.bc"}))
    fixtures.run(work, opt.clang, table.join(common, swift.codegen_flags({optimize = "smallest"}), {"-c", "probe.bc", "-o", "probe.o"}))
    fixtures.run(work, opt.clang, table.join(common, {"-c", "main.c", "-o", "main.o"}))
    fixtures.run(work, opt.clang, table.join(common, {"-fuse-ld=" .. opt.ld64, "main.o", "probe.o"}, objects, {"-o", "probe"}))
    return path.join(work, "probe"), path.join(work, "probe.o")
end

-- The availability macros of the standard library name the releases whose Swift runtime carries a feature; a runtime that
-- ships with the program has them all, so every macro is rewritten to "always".
local function bundled_availability(swift, source, found)
    local written = swift.bundled_availability(source)
    local defined, all = 0, 0
    for line in written:gmatch("[^\n]+") do
        if not line:startswith("#") then
            all = all + 1
            defined = defined + (line:match("^[^:]+: %*$") and 1 or 0)
        end
    end
    if all == 0 or defined ~= all then
        table.insert(found, string.format("every availability macro must be rewritten to always available, not %d of %d", defined, all))
    end
    for _, name in ipairs({"SwiftStdlib 5.1", "SwiftStdlib 6.0"}) do
        if not written:find(name .. ": *", 1, true) then
            table.insert(found, name .. " must stay a macro the standard library can name: " .. written:sub(1, 200))
        end
    end
end

function failures(opt)
    local swift = import("apple.swift", {rootdir = opt.modules, anonymous = true})
    local dyld = import("apple.dyld", {rootdir = opt.modules, anonymous = true})
    local firmware = import("apple.firmware", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local folder = fixtures.scratch()
    bundled_availability(swift, path.join(opt.swift, "share", "swift-source"), found)
    for _, case in ipairs({{"armv7", "6.0"}, {"armv7s", "6.0"}, {"arm64", "7.0"}}) do
        local architecture, deployment = case[1], case[2]
        local label = architecture .. " iOS " .. deployment
        local errors = fixtures.refusal(function ()
            local binary, object = build(folder, opt, swift, architecture, deployment)
            local version = fixtures.run(folder, "xcrun", {"otool", "-l", object}):match("LC_VERSION_MIN_IPHONEOS.-version (%S+)")
            if version ~= deployment then
                table.insert(found, label .. ": the Swift object must record the release it was compiled for, not " .. tostring(version))
            end
            local header = fixtures.run(folder, "xcrun", {"otool", "-hv", binary})
            if not header:find(" PIE", 1, true) then
                table.insert(found, label .. ": the executable must stay position independent, which absolute addressing in Swift code turns off")
            end
            local loaded = {}
            for library in fixtures.run(folder, "xcrun", {"otool", "-L", binary}):gmatch("\n%s+(%S+)") do
                table.insert(loaded, library)
            end
            if #loaded ~= 1 or loaded[1] ~= "/usr/lib/libSystem.B.dylib" then
                table.insert(found, label .. ": Embedded Swift must load nothing but libSystem, not " .. table.concat(loaded, " "))
            end
            local cache, release = firmware.source(architecture, deployment)
            if not os.exists(cache) then
                table.insert(found, string.format("%s: the imports are checked against iOS %s, whose libraries are not held; run xmake firmware --arch=%s fetch %s", label, release, architecture, release))
            else
                for _, missing in ipairs((dyld.missing_imports(cache, {binary}))) do
                    table.insert(found, label .. ": imports " .. missing[2] .. ", which iOS " .. release .. " lacks")
                end
            end
        end)
        if errors then
            table.insert(found, label .. ": " .. errors)
        end
    end
    os.tryrm(folder)
    return found
end
