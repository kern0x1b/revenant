import("core.base.json")

local TOOLS = path.join(os.scriptdir(), "..")
local REVENANT = path.join(TOOLS, "..", "..")
local swift = import("values_swift", {rootdir = TOOLS, anonymous = true})
local values_const = import("values_const", {rootdir = TOOLS, anonymous = true})
local common = import("values_common", {rootdir = TOOLS, anonymous = true})
local workspace = import("workspace", {rootdir = path.join(REVENANT, "modules"), anonymous = true})
local byteorder = import("byteorder", {rootdir = path.join(REVENANT, "modules"), anonymous = true})

local checks, failures = 0, {}

local function check(condition, message)
    checks = checks + 1
    if not condition then
        table.insert(failures, message)
        print("FAIL " .. message)
    end
end

local function skip(message)
    print("skip " .. message)
end

local function sorted_names(map)
    local out = table.keys(map)
    byteorder.sort(out)
    return table.concat(out, ", ")
end

local function test_pointer_width_round_trip(scratch)
    local width, pointer, text = values_const.classify("const CFStringRef", "const struct __CFString *", {})
    check(width == "p", "a pointer-typed constant is classified with the width 'p' (got " .. tostring(width) .. ")")
    check(pointer and text, "a CFStringRef is classified as a pointer to a constant string")
    local line = values_const.listing_line("NSDefaultRunLoopMode", width, pointer, text)
    check(common.split(line, "\t")[2] == "p", "the symbols file carries 'p' as the width, not 0 and not a number (" .. line .. ")")
    local reader = io.readfile(path.join(TOOLS, "cache-value.lua"))
    local pattern = reader:match('line:match%("([^"]+)"%)')
    check(pattern ~= nil, "the reader's symbols-file pattern was found")
    if pattern then
        check(not pattern:find("%d+", 1, true), "the reader's pattern has no digit-only width class (" .. pattern .. ")")
        check(pattern:find("%S+", 1, true) or pattern:find("%a+", 1, true) or pattern:find("([^\\t]*)", 1, true),
              "the reader's pattern accepts a non-numeric width (" .. pattern .. ")")
    end
    local cachefile = path.join(os.getenv("HOME"), ".revenant", "dyld", "6.1.3", "dyld_shared_cache_armv7")
    if not os.isfile(cachefile) then
        skip("the round trip through cache-value.lua: no 6.1.3 armv7 cache at " .. cachefile)
        return
    end
    local values = values_const.read_cache(cachefile, {{"NSDefaultRunLoopMode", width, pointer, text}}, scratch, REVENANT)
    local got = values.NSDefaultRunLoopMode
    check(got ~= nil, "the reader returned a row for NSDefaultRunLoopMode (none means the width contract is broken again)")
    if got then
        check(got.pointer ~= "-" and got.pointer ~= "", "the stored pointer was followed (" .. tostring(got.pointer) .. ")")
        check(got.text == "kCFRunLoopDefaultMode", "the constant string decoded to its real value (got " .. tostring(got.text) .. ")")
        check(got.width == 4, "the width column is the cache's pointer size (got " .. tostring(got.width) .. ")")
    end
end

local function test_empty_module_is_a_failed_read()
    local empty = {ABIRoot = {kind = "Root", children = {}}}
    local names, _, failure = swift.read_declarations(empty, "FoundationEssentials")
    check(names == nil and failure, "a 0-declaration dump is refused, not indexed as an empty module")
    check(failure and failure:find("FoundationEssentials", 1, true) and failure:find("not an empty one", 1, true),
          "and the refusal names the module and says what it is not: " .. tostring(failure))
    local canned = "<unknown>:0: error: missing required modules: 'RevenantFormat', 'RevenantPlatform', RevenantSysdir\n"
    names, _, failure = swift.read_declarations(empty, "FoundationEssentials", {canned})
    check(failure and failure:find("RevenantFormat", 1, true) and failure:find("RevenantSysdir", 1, true),
          "the refusal carries the digester's own line, naming the missing modules: " .. tostring(failure))
    names, _, failure = swift.read_declarations(empty, "FoundationEssentials", {""})
    check(failure and failure:find("not an empty one", 1, true), "and with no stderr it still says what it is refusing and why: " .. tostring(failure))
    local real = {ABIRoot = {kind = "Root", children = {
        {kind = "TypeDecl", printedName = "Date", children = {{kind = "Function", printedName = "timeInterval(since:)"}}}}}}
    local conformances
    names, conformances, failure = swift.read_declarations(real, "Foundation")
    check(names and not failure, "a module that does declare something is read, so the guard refuses nothing else")
    check(conformances ~= nil, "and its conformances come with it")
end

local function test_cache_record_is_typed_and_versioned(scratch)
    local record = swift.cache_record_version()
    check(math.type(record) == "integer" and record >= 2, "the cache record carries a version number (" .. tostring(record) .. ")")
    local fresh = {version = record, names = {Date = "TypeDecl"}, conformances = {Date = swift.list({"Equatable"})}}
    local old_list = swift.list({{Date = "TypeDecl"}, {Date = swift.list({"Equatable"})}})
    local old_bare = {Date = "TypeDecl"}
    check(swift.read_cache_record(fresh) ~= nil, "a current record is accepted")
    check(swift.read_cache_record(old_list) == nil, "an old two-element list cache file is refused rather than misread")
    check(swift.read_cache_record(old_bare) == nil, "an old bare-names cache file is refused rather than misread")
    check(swift.read_cache_record({version = record - 1, names = {}, conformances = {}}) == nil, "a record of an older version is refused")
    local file = path.join(scratch, "record.json")
    swift.write_cache_record(file, {Date = "TypeDecl", ["Date.init(_:)"] = "Constructor"}, {Date = {"Hashable", "Equatable", "Hashable"}})
    local back = swift.read_cache_record(json.loadfile(file))
    check(back and back.names.Date == "TypeDecl" and back.names["Date.init(_:)"] == "Constructor",
          "a record written to disk reads back with its names")
    check(back and table.concat(back.conformances.Date, ",") == "Equatable,Hashable",
          "and its conformances, deduplicated and sorted")
    io.writefile(file, json.encode({{Date = "TypeDecl"}, {Date = {"Equatable"}}}))
    check(swift.read_cache_record(json.loadfile(file)) == nil, "an old two-element list read from disk is refused")
end

local function test_swift_index_file_is_written_flat(scratch)
    local modules = {Foundation = {Date = "TypeDecl", ["Date.timeInterval(since:)"] = "Function"}, Calendar = {Date = "TypeDecl"}}
    local index = {digester = "x", target = swift.target(), modules = modules, conformances = swift.sorted_conformances({Date = {"Equatable"}}),
                   references = {}, sources = {}, failures = swift.list()}
    local file = path.join(scratch, "swift-modules.json")
    io.writefile(file, swift.encode(index, 1))
    local loaded = json.loadfile(file)
    local flat = true
    for _, declared in pairs(loaded.modules) do
        for name, kind in pairs(declared) do
            if type(name) ~= "string" or type(kind) ~= "string" then
                flat = false
            end
        end
    end
    check(loaded.modules.Foundation and loaded.modules.Calendar and flat,
          "the written index holds every module as a flat map of names to kinds, the shape the ledger reads")
    check(loaded.modules.Foundation.version == nil, "and not a versioned cache record nested in it")
    check(io.readfile(file):find('\n "failures": [],\n', 1, true) ~= nil, "an empty list is written as Python's json.dump writes it")
end

local function test_declaration_count_survives_the_index(scratch)
    local names = {}
    for index = 1, 614 do
        names["BoostedTreeFitter.member" .. index .. "(_:)"] = "Function"
    end
    local file = path.join(scratch, "count.json")
    io.writefile(file, swift.encode({modules = {CreateMLComponents = names}}, 1))
    check(common.count(json.loadfile(file).modules.CreateMLComponents) == 614,
          "a module's whole declaration map reaches the index, so the ledger's coverage count (614 declarations) is the module's own")
end

local function test_swift_normalisations()
    local payload = {ABIRoot = {kind = "Root", children = {
        {kind = "TypeNominal", printedName = "Publishers", children = {
            {kind = "TypeNominal", printedName = "AllSatisfy", children = {{kind = "Constructor", printedName = "() -> Swift.Bool"}}}}}}}}
    local indexed = swift.index_from_json(payload)
    check(indexed["Publishers.AllSatisfy"] ~= nil, "a payload case is indexed under its own name (got " .. sorted_names(indexed) .. ")")
    local typed = {ABIRoot = {kind = "Root", children = {
        {kind = "TypeNominal", printedName = "Publishers", children = {
            {kind = "TypeNominal", printedName = "AllSatisfy", children = {
                {kind = "TypeNominal", printedName = "() -> Swift.Bool", conformances = {{printedName = "Sendable"}}}}}}}}}}
    local typed_names, typed_conformances = swift.index_from_json(typed)
    check(typed_names["Publishers.AllSatisfy.() -> Swift.Bool"] == "TypeNominal" and typed_conformances["Publishers.AllSatisfy"]
          and table.contains(typed_conformances["Publishers.AllSatisfy"], "Sendable"),
          "a payload case's conformances are credited to the case's own name, the one its printed function type hides")
    local reduced = {ABIRoot = {kind = "Root", children = {
        {kind = "TypeDecl", printedName = "Date", children = {{kind = "Function", printedName = "timeInterval(since:)"}}}}}}
    local both = swift.index_from_json(reduced)
    check(both["Date.timeInterval(since:)"] and both["Date.timeInterval(_:)"],
          "a member is indexed under both label conventions (got " .. sorted_names(both) .. ")")
    local conformed = {ABIRoot = {kind = "Root", children = {
        {kind = "TypeDecl", printedName = "ActivityStyle", declKind = "Enum",
         conformances = {{kind = "Conformance", name = "Equatable", printedName = "Equatable"}}, children = {}}}}}
    local _, seen = swift.index_from_json(conformed)
    check(seen.ActivityStyle and table.contains(seen.ActivityStyle, "Equatable"), "a type's conformances are indexed")
    local labels = {ABIRoot = {kind = "Root", children = {
        {kind = "TypeDecl", printedName = "Foo", children = {
            {kind = "Subscript", printedName = "subscript(x: Int)"},
            {kind = "Function", printedName = "a(b:c:)"},
            {kind = "Function", printedName = "none()"}}}}}}
    local forms = swift.index_from_json(labels)
    check(forms["Foo.subscript(_)"] and forms["Foo.a(_:_:)"] and forms["Foo.none()"] and not forms["Foo.none(_)"],
          "the label reduction counts colons and keeps a trailing colon (got " .. sorted_names(forms) .. ")")
    local order = {ABIRoot = {kind = "Root", children = {
        {kind = "Var", printedName = "same"}, {kind = "Function", printedName = "same"}}}}
    check(swift.index_from_json(order).same == "Function",
          "the walk is the digester tree popped last child first, so the later sibling's kind is the one kept")
end

local function test_python_json_spelling()
    local text = swift.encode({b = {}, a = swift.list({"x"}), c = {d = true, e = false}, ["\195\169"] = "\127\n"}, 1)
    check(text == '{\n "a": [\n  "x"\n ],\n "b": {},\n "c": {\n  "d": true,\n  "e": false\n },\n "\\u00e9": "\\u007f\\n"\n}',
          "indent=1, sort_keys, booleans, empty maps and ensure_ascii escapes are Python's: " .. text)
    check(swift.encode({names = {Z = "a", A = "b"}, version = 2}) == '{"names": {"A": "b", "Z": "a"}, "version": 2}',
          "the compact form uses Python's default separators")
    local oracle = path.join(workspace.coordination(), "corpus", "ledger", "swift-modules.json")
    if not os.isfile(oracle) then
        skip("the committed swift-modules.json is not on this machine")
        return
    end
    local committed = io.readfile(oracle)
    local index = json.decode(committed)
    check(swift.encode(index, 1) == committed, "the writer spells the committed swift-modules.json byte for byte")
    local walked, matched = 0, 0
    for module, source in pairs(index.sources) do
        if source.manifest == "" then
            walked = walked + 1
            if swift.package_of(source.module).package == source.package then
                matched = matched + 1
            else
                print("  package_of(" .. module .. ") = " .. swift.package_of(source.module).package .. ", committed " .. source.package)
            end
        end
    end
    check(walked > 0 and matched == walked, string.format("the package a module without a manifest is credited to is the committed one (%d of %d)", matched, walked))
end

local function test_constant_types()
    check(values_const.strip_type("const NSString * _Nonnull const") == "NSString *", "qualifiers that do not change a width are stripped")
    check(values_const.strip_type("constant _Nullable_result x") == "constant x", "a qualifier is stripped only as a whole word")
    local resolved, finished = values_const.resolve_type("A", {A = "B", B = "A"})
    check(not finished and resolved == "A", "a typedef cycle stops instead of looping")
    local width, pointer, text, kind = values_const.classify("const CGFloat", "const float", {})
    check(width == "p" and not pointer and not text and kind == "float", "a CGFloat is read at the cache's width whatever armv7 made of it")
    width = values_const.classify("BOOL", "signed char", {})
    check(width == 1, "a BOOL is one byte")
    width, pointer = values_const.classify("struct CGSize", "struct CGSize", {})
    check(width == 0 and not pointer, "a struct is not read")
    width, pointer, text = values_const.classify("Fn", "void (int)", {})
    check(width == "p" and pointer and not text, "a function type is a pointer and not a string")
    width = values_const.classify("Index", "MyIndex", {MyIndex = "const long long"})
    check(width == 8, "a typedef the header declares is followed to its width")
end

local function test_constant_values()
    local value, detail = values_const.format_value("float", 4, false, "-", 0x3f000000, 0x3f000000, 0, "0000003f")
    check(value == "0.5" and detail == "float", "a float is spelled as Python's repr spells it (" .. value .. ")")
    value = values_const.format_value("float", 4, false, "-", 0x3e4ccccd, 0, 0, "cdcc4c3e")
    check(value == "0.20000000298023224", "a float32 widened to a double keeps every digit repr gives it (" .. value .. ")")
    value = values_const.format_value("float", 4, false, "-", 0x7f7fffff, 0, 0, "ffff7f7f")
    check(value == "3.4028234663852886e+38", "a large float switches to Python's exponent form (" .. value .. ")")
    value, detail = values_const.format_value("double", 4, false, "-", 0, 0, 0, "00000000")
    check(value == "0.0" and detail == "CGFloat, 4 bytes in this cache", "a 4-byte double is a CGFloat of a 32-bit cache")
    value, detail = values_const.format_value("double", 8, false, "-", 0, 0, 0, "0000000000409f40")
    check(value == "0" and detail == "double", "an 8-byte double prints the reader's double column as int() parsed it, which is 0")
    check(values_const.parse_reader("x\t/i\t0x1\t00\t1\t1\t1.5e+00\t-\t-\t8\t8\n").x.f64 == 0,
          "the reader's double column is not an integer, so it parses as 0, as int() refused it")
    value, detail = values_const.format_value("NSString *", 4, true, "birthday", 1, 1, 0, "88b39030")
    check(value == '"birthday"' and detail == "constant string", "a constant string is quoted")
    value = values_const.format_value("long", 8, false, "-", -1, -1, 0, "ffffffffffffffff")
    check(value == "-1", "a 64-bit integer is the reader's signed column")
    local status, why = values_const.sentinel_reason("double", "const NSTimeInterval", 4, 0, 0xffffffff, 0)
    check(status == "read-sentinel" and why:find("0xffffffff", 1, true), "a CGFloat-width placeholder is a sentinel, not a value")
    status = values_const.sentinel_reason("int", "int", 8, 4, 0, 0)
    check(status == "read-too-wide", "a read wider than the symbol's storage is refused")
    check(values_const.sentinel_reason("int", "int", 4, 0, 0, 0) == nil, "storage 0 means unknown, not narrower")
    check(values_const.repr("it's") == '"it\'s"' and values_const.repr("a\\b") == "'a\\\\b'", "a string is quoted as Python's %r quotes it")
end

function main()
    local scratch = workspace.fresh("values-test")
    try {
        function ()
            test_pointer_width_round_trip(scratch)
            test_empty_module_is_a_failed_read()
            test_cache_record_is_typed_and_versioned(scratch)
            test_swift_index_file_is_written_flat(scratch)
            test_declaration_count_survives_the_index(scratch)
            test_swift_normalisations()
            test_python_json_spelling()
            test_constant_types()
            test_constant_values()
        end,
        finally {
            function ()
                os.tryrm(scratch)
            end
        }
    }
    print(string.format("values: %d checks, %d failed", checks, #failures))
    if #failures > 0 then
        raise("values: %d of %d checks failed", #failures, checks)
    end
end
