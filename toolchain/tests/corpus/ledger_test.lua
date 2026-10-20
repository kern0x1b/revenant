local TOOLS = path.join(os.scriptdir(), "..", "..", "tools", "corpus")
local MODULES = path.join(TOOLS, "..", "..", "modules")
local classify = import("ledger_classify", {rootdir = TOOLS, anonymous = true})
local swiftmod = import("ledger_swift", {rootdir = TOOLS, anonymous = true})
local headers = import("ledger_headers", {rootdir = TOOLS, anonymous = true})
local inputs = import("ledger_inputs", {rootdir = TOOLS, anonymous = true})
local output = import("ledger_output", {rootdir = TOOLS, anonymous = true})
local ledger_json = import("ledger_json", {rootdir = TOOLS, anonymous = true})
local workspace = import("workspace", {rootdir = MODULES, anonymous = true})

local checks, failures = 0, {}

local function check(condition, message)
    checks = checks + 1
    if not condition then
        table.insert(failures, message)
        print("FAIL " .. message)
    end
end

local function contains(text, needle)
    return type(text) == "string" and text:find(needle, 1, true) ~= nil
end

local function raised(f)
    local message
    try {
        function ()
            f()
        end,
        catch {
            function (errors)
                message = tostring(errors)
            end
        }
    }
    return message
end

local function has(list, item)
    for _, held in ipairs(list) do
        if held == item then
            return true
        end
    end
    return false
end

local function set(list)
    local out = {}
    for _, item in ipairs(list) do
        out[item] = true
    end
    return out
end

local function entry(opt)
    return {instance = set(opt.instance or {}), class = set(opt.class or {}), protocols = {}, superclass = opt.superclass or "",
            image = "", library = opt.library, where = opt.where or {}}
end

local function a_clang()
    local named = os.getenv("LEDGER_CLANG")
    if named and named ~= "" then
        return {named}
    end
    local home = os.getenv("HOME") or ""
    local found = os.files(path.join(home, ".xmake", "packages", "l", "llvm", "*", "*", "bin", "clang"))
    local byteorder = import("byteorder", {rootdir = MODULES, anonymous = true})
    byteorder.sort(found)
    if #found > 0 then
        return {found[#found]}
    end
    if os.isfile("/usr/bin/xcrun") then
        return {"xcrun", "clang"}
    end
    return nil
end

local function run_clang(command, extra, folder)
    local arguments = {}
    for index = 2, #command do
        table.insert(arguments, command[index])
    end
    table.join2(arguments, extra)
    local out = path.join(folder, "clang.out")
    os.execv(command[1], arguments, {stdout = out, stderr = out, try = true})
    local text = io.readfile(out) or ""
    os.rm(out)
    local lines = {}
    for line in text:gmatch("[^\n]+") do
        table.insert(lines, line)
    end
    return lines
end

local function dump(source, folder, sdk)
    local clang = a_clang()
    local file = path.join(folder, "storage_probe.c")
    io.writefile(file, source)
    local extra = {"-fsyntax-only", "-w", "-target", "armv7-apple-ios6.1.3"}
    if sdk then
        table.join2(extra, {"-isysroot", sdk})
    end
    table.join2(extra, {"-Xclang", "-ast-dump", file})
    return run_clang(clang, extra, folder)
end

local function test_platform_check()
    local tv_only = {api = "TVOnlyThing", kind = "constant", lang = "objc", framework = "SomeFramework"}
    local index = {rows = {TVOnlyThing = {"constant", nil, true, true}}, macros = {}, flags = {}, typedefs = {}, compiled = {}, failed = {}}
    local status, reason = classify.classify_from_headers("TVOnlyThing", tv_only, index, "6.1.3", {}, {})
    check(status == "not-ios", "a row marked API_UNAVAILABLE(ios) reads not-ios (got " .. tostring(status) .. ")")
    check(contains(reason, "leaves the denominator"), "and the reason says it leaves the denominator")
    local here = {api = "DeliberatelyUnavailable", kind = "constant", lang = "objc", framework = "SomeFramework"}
    local index2 = {rows = {DeliberatelyUnavailable = {"constant", nil, true, false}}, macros = {}, flags = {}, typedefs = {}, compiled = {}, failed = {}}
    local status2, reason2 = classify.classify_from_headers("DeliberatelyUnavailable", here, index2, "6.1.3", {}, {})
    check(status2 == "missing" and contains(reason2, "NS_UNAVAILABLE"), "NS_UNAVAILABLE stays a row, read missing with that reason")
end

local function test_a_row_whose_line_does_not_compile_is_reported_as_failing(folder)
    local clang = a_clang()
    if not clang then
        print("skip: no clang to compile the generated unit with")
        return
    end
    local work = path.join(folder, "named")
    os.mkdir(work)
    io.writefile(path.join(work, "revenant_probe.h"), "#define REVENANT_PROBE_TWICE 2\n")
    local command = table.join(clang, {"-w", "-target", "armv7-apple-ios6.1.3", "-I", work})
    local out = headers.compile_named_rows({"revenant_probe.h"}, command, {{"constant", "REVENANT_PROBE_TWICE"}, {"constant", "REVENANT_PROBE_MISSING"}},
                                           work, "revenant_probe")
    check(out.REVENANT_PROBE_TWICE == "", "a row whose line compiles comes back clean (got " .. tostring(out.REVENANT_PROBE_TWICE) .. ")")
    local missing = out.REVENANT_PROBE_MISSING
    check(missing ~= nil and missing ~= "", "a row whose line does NOT compile comes back with the diagnostic on it")
    check(contains(missing, "undeclared"), "and the diagnostic is the compiler's own (got " .. tostring(missing) .. ")")
    check(io.readfile(path.join(work, "named-revenant_probe.m")) ==
          "#import <revenant_probe.h>\n\n__typeof__(REVENANT_PROBE_TWICE) revenantLedger0 = REVENANT_PROBE_TWICE;\n__typeof__(REVENANT_PROBE_MISSING) revenantLedger1 = REVENANT_PROBE_MISSING;\n",
          "the generated unit names every row on a line of its own, after the imports and one blank line")
end

local function every_spatial_function_is_header_only(folder)
    local sdk
    try {
        function ()
            sdk = workspace.sdk()
        end,
        catch {
            function ()
                sdk = nil
            end
        }
    }
    if not sdk or not os.isfile(path.join(sdk, "usr", "include", "Spatial", "Spatial.h")) then
        print("skip: no 26.2 SDK with Spatial's umbrella, so the 640 rows are not checked")
        return
    end
    local lines = dump("#import <Spatial/Spatial.h>\n", folder, sdk)
    local flags = {}
    headers.scan_storage(lines, flags)
    local names, static, externs = 0, 0, {}
    for name, held in pairs(flags) do
        if name:sub(1, 2) == "SP" then
            names = names + 1
            if held[2] and not held[1] then
                static = static + 1
            elseif held[1] then
                table.insert(externs, name)
            end
        end
    end
    check(names >= 640, "the dump names Spatial's functions (" .. names .. ")")
    check(static == names and names >= 640, string.format("every one of them reads static and not extern (%d of %d static; extern: %s)",
                                                          static, names, table.concat(externs, ", "):sub(1, 120)))
end

local function test_static_inline_through_a_macro_is_header_only(folder)
    if not a_clang() then
        print("skip: no clang to read the storage class with")
        return
    end
    local source = "#define CH_M static inline\nCH_M int revenant_header_only(int);\nint revenant_header_only(int x) { return x; }\n"
                   .. "extern int revenant_extern_function(int);\nextern int revenant_extern_variable;\nint main(void) { return revenant_extern_function(0); }\n"
    local lines = dump(source, folder)
    local decl = {}
    for _, line in ipairs(lines) do
        if line:sub(1, 14) == "|-FunctionDecl" and contains(line, " revenant_header_only ") then
            table.insert(decl, line)
        end
    end
    check(#decl == 2, "the dump prints the header-only function twice (got " .. #decl .. ")")
    if #decl == 2 then
        check(contains(decl[1], " static"), "the declaration line carries `static`")
        check(not contains(decl[2], " static"), "and the definition line does not")
        check(contains(decl[2], " implicit-inline") or contains(decl[2], " inline"), "the definition line says inline")
    end
    local flags = {}
    headers.scan_storage(lines, flags)
    local header_only = flags.revenant_header_only or {}
    flags.RevenantInlineMacro = flags.revenant_header_only
    check(header_only[2] == true, "a function declared `static inline` through a macro reads static")
    check(header_only[1] == false, "and not extern")
    check((flags.revenant_extern_function or {})[1] == true, "a real extern function still reads extern")
    check((flags.revenant_extern_function or {})[2] == false, "and does not read static")
    check((flags.revenant_extern_variable or {})[1] == true, "a real extern variable still reads extern")
    local row = {api = "RevenantInlineMacro()", kind = "function", lang = "objc", framework = "SomeFramework"}
    local index = {rows = {["RevenantInlineMacro()"] = {"function", nil, nil, false}}, macros = {}, flags = flags, typedefs = {},
                   compiled = {RevenantInlineMacro = ""}, failed = {}}
    local status, reason = classify.classify_from_headers("RevenantInlineMacro()", row, index, "6.1.3", {}, {})
    check(status == "header-ok", "a function declared `static inline` through a macro is header-ok (got " .. tostring(status) .. ": " .. tostring(reason) .. ")")
    check(contains(reason, "no run-time symbol"), "and the reason says there is no run-time symbol to export")
    every_spatial_function_is_header_only(folder)
end

local function test_scan_storage_merges_lines()
    local flags, typedefs = {}, {}
    headers.scan_storage({
        "|-TypedefDecl 0x1 <line:1:1> col:2 referenced CFNotificationName 'CFStringRef':'const struct __CFString *'",
        "|-VarDecl 0x2 <line:2:1> col:3 kFoo 'const CGFloat':'float' extern",
        "| |-VarDecl 0x3 <line:3:1> col:3 kNested 'int' extern",
        "|-FunctionDecl 0x4 <line:4:1> col:5 F 'int (int)' static inline",
        "|-FunctionDecl 0x5 <line:5:1> col:5 F 'int (int)' implicit-inline",
        "|-EnumConstantDecl 0x6 <line:6:1> col:5 kCase 'int'",
    }, flags, typedefs)
    check(typedefs.CFNotificationName == "const struct __CFString *", "a typedef keeps the canonical end of its sugar chain")
    check(flags.kFoo ~= nil and flags.kFoo[1] == true and flags.kFoo[4] == "const CGFloat" and flags.kFoo[5] == "float",
          "a variable keeps its extern flag and both ends of its type")
    check(flags.kNested == nil, "a declaration below the top level is not scanned")
    check(flags.kCase == nil, "an enum case is not a storage declaration")
    check(flags.F ~= nil and flags.F[2] == true and flags.F[3] == true, "the flags of two lines of one function are merged, the wider answer standing")
end

local function test_built_tree_reads_a_real_run_directory(folder)
    local run = path.join(folder, "gate-6.1.3")
    os.mkdir(run)
    check(contains(inputs.built_tree(run), "tree not recorded"), "a directory with no tree file says so, with its own age")
    check(contains(inputs.built_tree(nil), "no --gate"), "and no directory at all says so rather than raising")
    io.writefile(path.join(run, "tree"), "revision\t68befacae0337a1b2c3\ncheckout\t/revenant\ndirty\tno\n")
    check(inputs.built_tree(run) == "68befacae033", "a tree file is read and the revision is the short form (" .. inputs.built_tree(run) .. ")")
    io.writefile(path.join(run, "tree"), "revision\t68befacae0337a1b2c3\ncheckout\t/revenant\ndirty\tyes\n")
    check(contains(inputs.built_tree(run), "dirty"), "a dirty build is marked as one")
    io.writefile(path.join(run, "tree"), "revision\tunknown\ncheckout\t/revenant\n")
    check(contains(inputs.built_tree(run), "tree not recorded"), "a tree file that says it does not know is treated as not recorded")
end

local function disagreeing(section)
    local bad = 0
    for line in section:gmatch("[^\n]+") do
        if line:sub(1, 2) == "| " then
            local cells = {}
            for cell in line:gsub("^|", ""):gsub("|$", ""):gmatch("[^|]+") do
                table.insert(cells, (cell:gsub("^%s+", ""):gsub("%s+$", "")))
            end
            local numeric = #cells >= 3
            for index = 2, #cells do
                if not cells[index]:match("^%-?%d+$") then
                    numeric = false
                end
            end
            if numeric then
                local sum = 0
                for index = 2, #cells - 1 do
                    sum = sum + tonumber(cells[index])
                end
                if sum ~= tonumber(cells[#cells]) then
                    bad = bad + 1
                end
            end
        end
    end
    return bad
end

local function test_write_output_writes_files_a_reader_can_use(folder)
    local work = path.join(folder, "output")
    os.mkdir(work)
    local args = {out = work, release = "6.1.3", gate = nil, jobs = 4, release_cache = "/nowhere/dyld_shared_cache_armv7",
                  sdk = "/nowhere/iPhoneOS26.2.sdk", surface = path.join(work, "surface.tsv"), vfs = path.join(work, "vfs.yaml")}
    io.writefile(args.surface, "framework\tapi\n")
    io.writefile(args.vfs, "[]\n")
    local results = {
        {{kind = "constant", lang = "objc", api = "kA", framework = "Alpha", introduced = "9.0"}, "implemented", "built", nil, nil},
        {{kind = "constant", lang = "objc", api = "kB", framework = "Alpha", introduced = "9.0"}, "missing", "no symbol", nil, "code"},
        {{kind = "constant", lang = "objc", api = "kC", framework = "Beta", introduced = "9.0"}, "not-ios", "API_UNAVAILABLE(ios)", nil, "none"},
        {{kind = "constant", lang = "objc", api = "kD", framework = "Beta", introduced = "9.0"}, "declared", "registry only", nil, "build"},
    }
    output.write_output(results, args, 12.0, {}, 0, 1.0, nil)
    local summary = io.readfile(path.join(work, "SUMMARY.md"))
    check(contains(summary, "leave the denominator"), "the not-ios row is reported in prose at the top")
    local by_kind = summary:match("## By kind(.*)") or ""
    local third = {}
    for line in by_kind:gmatch("[^\n]*\n") do
        table.insert(third, line)
    end
    check(contains(third[3], "not-ios") and contains(third[3], "declared"), "and both statuses have a column in By kind: " .. tostring(third[3]))
    check(disagreeing(by_kind) == 0, "every By kind row's total is the sum of its columns")
    local by_framework = (summary:match("## By framework(.-)\n## ") or "")
    check(disagreeing(by_framework) == 0, "every By framework row's total is the sum of its columns")
    local header = by_framework:match("\n(| framework[^\n]*)") or ""
    for _, status in ipairs({"implemented", "missing", "not-ios", "declared"}) do
        check(contains(header, status), "the By framework header has a column for " .. status)
    end
    local alpha = io.readfile(path.join(work, "Alpha.tsv")) or ""
    check(alpha ~= "" and not contains(alpha, "kA"), "a fully implemented row is not listed in its framework's todo file")
    local beta = io.readfile(path.join(work, "Beta.tsv")) or ""
    check(contains(beta, "not-ios") and contains(beta, "declared") and contains(beta, "kC"), "and an unimplemented one carries its rows with their status")
    check(io.readfile(path.join(work, "not-ios.tsv")) == "api\tframework\treason\nkC\tBeta\tnot-ios\n", "not-ios.tsv names the row that left the denominator")
    check(contains(summary, "Frameworks holding them: Beta 1, Alpha 0.\n"), "the frameworks holding not-ios rows are listed by count, ties in first-seen order")
    check(contains(summary, "| missing | 1 |\n| declared | 1 |\n| implemented | 1 |") == false and contains(summary, "| implemented | 1 |\n| missing | 1 |\n| declared | 1 |\n| **total** | **3** |"),
          "Totals is ordered by count, ties in the order the statuses were first seen")
    check(contains(summary, "| built 6.1.3 libraries | `` |\n| the tree those libraries were built from | no --gate given"),
          "a run with no gate says so in the inputs table")
    check(alpha == "kind\tlang\tapi\tintroduced\theader-introduced\tstatus\tneeds\treason\nconstant\tobjc\tkB\t9.0\t\tmissing\tcode\tno symbol\n",
          "a todo file's columns and one row, byte for byte")
end

local function test_todo_order_is_stable()
    local work = workspace.fresh("ledger-test-order")
    local rows = {
        {{kind = "enum", lang = "objc", api = "B", framework = "F", introduced = ""}, "header-ok", "h", nil, nil},
        {{kind = "class", lang = "objc", api = "Z", framework = "F", introduced = ""}, "undecided", "u", nil, nil},
        {{kind = "enum", lang = "objc", api = "A", framework = "F", introduced = ""}, "decided", "d", nil, "none"},
        {{kind = "class", lang = "objc", api = "Y", framework = "F", introduced = ""}, "missing", "m", {7, 0}, nil},
        {{kind = "enum", lang = "objc", api = "A", framework = "F", introduced = ""}, "header-ok", "second", nil, nil},
        {{kind = "property", lang = "objc", api = "A0", framework = "F", introduced = ""}, "header-ok", "p", nil, nil},
        {{kind = "class", lang = "objc", api = "C", framework = "F", introduced = ""}, "header-ok", "c", nil, nil},
    }
    output.write_todo(path.join(work, "F.tsv"), rows, "6.1.3")
    local text = io.readfile(path.join(work, "F.tsv"))
    os.tryrm(work)
    check(text == "kind\tlang\tapi\tintroduced\theader-introduced\tstatus\tneeds\treason\n"
                  .. "class\tobjc\tY\t\t7.0\tmissing\tcode+lift\tm\n"
                  .. "class\tobjc\tZ\t\t\tundecided\tdecide\tu\n"
                  .. "class\tobjc\tC\t\t\theader-ok\tnone\tc\n"
                  .. "enum\tobjc\tA\t\t\tdecided\tnone\td\n"
                  .. "enum\tobjc\tA\t\t\theader-ok\tnone\tsecond\n"
                  .. "enum\tobjc\tB\t\t\theader-ok\tnone\th\n"
                  .. "property\tobjc\tA0\t\t\theader-ok\tnone\tp\n",
          "a todo file lists missing, undecided, unmeasured, then the rest by kind and api, keeping equal rows in their order")
end

local function swift_base()
    return {names = {}, modules = {}, registries = {}, conformances = {}, references = {}, digester = "x", target = "armv7-apple-ios6.1.3",
            sources = {}, ["search-dirs"] = {}, ["extra-module-maps"] = {}}
end

local function test_swift_row_from_a_registry()
    local swift = swift_base()
    swift.registries = {ColumnarTransformer = {"implemented", "packages/frameworks/createml", "shape"}}
    local row = {api = "ColumnarTransformer", kind = "protocol", lang = "swift", framework = "CreateMLComponents"}
    local status, reason, _, needs = swiftmod.classify_swift("ColumnarTransformer", row, swift)
    check(status == "declared", "a Swift row only a registry records reads declared (got " .. tostring(status) .. ")")
    check(contains(reason, "packages/frameworks/createml"), "and the reason names the package it came from")
    check(needs == "build", "and the row says what is left: build the module")
    local swift2 = swift_base()
    swift2.registries = swift.registries
    swift2.names = {ColumnarTransformer = {{"CreateMLComponents", "TypeDecl"}}}
    swift2.modules = {CreateMLComponents = true}
    local status2 = swiftmod.classify_swift("ColumnarTransformer", row, swift2)
    check(status2 == "implemented", "with a built module carrying it, the row reads implemented, not declared")
    local objc = {api = "NSString.length", kind = "method", lang = "objc", framework = "Foundation"}
    local swift3 = swift_base()
    swift3.registries = {["NSString.length"] = {"implemented", "packages/frameworks/y", "r"}}
    local status3 = swiftmod.classify_swift("NSString.length", objc, swift3)
    check(status3 ~= "implemented" and status3 ~= "declared", "an Objective-C row is not placed from a registry even when one has its name")
end

local function test_uncovered_module_leaves_rows_undecided()
    local swift = swift_base()
    swift.names = {BoostedTreeFitter = {{"CreateMLComponents", "TypeDecl"}}}
    swift.modules = {CreateMLComponents = true}
    swift["matched-by-framework"] = {CreateMLComponents = 0}
    swift["declaration-count"] = {CreateMLComponents = 614}
    local row = {api = "AudioReader.microphoneAuthorizationDenied", kind = "property", lang = "swift", framework = "CreateMLComponents"}
    local status, reason, _, needs = swiftmod.classify_swift(row.api, row, swift)
    check(status == "undecided" and needs == "swift-module", "a framework the module does not cover stays undecided")
    check(contains(reason, "coverage, not the matcher") and contains(reason, "614 declarations"), "and the reason says what it is, with the count")
    swift["matched-by-framework"] = {CreateMLComponents = 40}
    local status2, _, _, needs2 = swiftmod.classify_swift(row.api, row, swift)
    check(status2 == "missing" and needs2 == "code", "but where the module does place some rows, the rest are a real gap")
    local results = {{row, "undecided", reason, nil, "swift-module"}}
    local matched = {CreateMLComponents = 3}
    swift["matched-by-framework"] = {}
    check(swiftmod.resolve_swift_coverage(results, swift, matched) == 1 and results[1][2] == "missing",
          "the second pass re-classifies a held-back row once its framework has placed a row")
end

local function test_swift_index_file_is_loaded_from_disk(folder)
    local flat = path.join(folder, "flat.json")
    io.writefile(flat, '{"digester": "x", "target": "armv7-apple-ios6.1.3", "modules": {"Foundation": {"Date": "TypeDecl"}, "Calendar": {"Date": "TypeDecl"}}, "conformances": {"Date": ["Equatable"]}, "references": {}, "sources": {}}')
    local loaded = swiftmod.load_swift_modules(flat)
    check(loaded.modules.Foundation and loaded.names.Date ~= nil and #loaded.names.Date == 2, "a real index file loads, a name in two modules held for both")
    local wrapped = path.join(folder, "wrapped.json")
    io.writefile(wrapped, '{"digester": "x", "target": "t", "modules": {"Foundation": {"version": 2, "names": {"Date": "TypeDecl"}, "conformances": {}}, "Calendar": {"version": 2, "names": {"Date": "TypeDecl"}, "conformances": {}}}, "conformances": {}, "references": {}, "sources": {}}')
    local modules = 0
    for _ in pairs(swiftmod.load_swift_modules(wrapped).modules) do
        modules = modules + 1
    end
    check(modules == 2, "a module wrapped in a versioned record loads too, rather than raising")
    local broken = path.join(folder, "broken.json")
    io.writefile(broken, '{"digester": "x", "target": "t", "modules": {"Foundation": {"names": {"Date": "TypeDecl"}, "conformances": {}}, "HalfWritten": "Foundation"}, "conformances": {}, "references": {}, "sources": {}}')
    local message = raised(function ()
        swiftmod.load_swift_modules(broken)
    end)
    check(contains(message, "not a map of names to kinds") and contains(message, "it is str"), "a half-written index module is refused with what it is: " .. tostring(message))
    local listed = path.join(folder, "listed.json")
    io.writefile(listed, '{"modules": {"Foundation": []}}')
    check(contains(raised(function () swiftmod.load_swift_modules(listed) end), "it is list"), "an empty list is not an empty map")
end

local function test_swift_normalisations()
    local cases = {
        {"argument labels", "CGAffineTransform.==(lhs:rhs:)", "CGAffineTransform.==(_:_:)"},
        {"failable initialiser", "CGPathFillRule.init?(rawValue:)", "CGPathFillRule.init(_:)"},
        {"failable subscript", "Foo.subscript?(x: Int)", "Foo.subscript(_:)"},
        {"operator", "Foo.~=(a:)", "Foo.~="},
        {"subscript labels", "Foo.subscript(index: Int)", "Foo.subscript(_:)"},
        {"generic parameter list, composed", "Foo.Bar.init?<Value.UnwrappedType>(_ value: Value)", "Foo.Bar.init(_:)"},
        {"payload case", "Publishers.AllSatisfy.() -> Swift.Bool", "Publishers.AllSatisfy"},
    }
    for _, case in ipairs(cases) do
        local forms = swiftmod.swift_forms(case[2])
        check(has(forms, case[3]), string.format("normalisation %s: %s reaches %s (forms: %s)", case[1], case[2], case[3], table.concat(forms, " | ")))
    end
    for _, case in ipairs({{"Foo.Bar.init?<Value.UnwrappedType>(_ value: Value)", "Foo.Bar"}, {"A.b.c(d:)", "A.b"}, {"NoOwner", ""}}) do
        local owner = swiftmod.split_qualified(case[1])
        check(owner == case[2], string.format("split_qualified(%s) gives owner %s (got %s)", case[1], case[2], owner))
    end
    check(swiftmod.strip_payload_case("A.B") == "A.B", "a name with no payload shape is kept")
    check(swiftmod.swift_forms("Foo.bar(x:y:)")[2] == "Foo.bar(_:_:)", "the label rule counts the colons, not the last character")
    local swift = swift_base()
    swift.conformances = {ActivityStyle = {"Equatable"}}
    local row = {api = "ActivityStyle.==(lhs:rhs:)", kind = "method", lang = "swift", framework = "ActivityKit"}
    local status, reason = swiftmod.classify_swift(row.api, row, swift)
    check(status == "implemented" and contains(reason, "conforms to Equatable"), "an operator a conformance synthesises is placed from the conformance")
    swift.conformances = {ActivityStyle = {"Hashable"}}
    check(swiftmod.classify_swift(row.api, row, swift) ~= "implemented", "and from nothing weaker")
end

local function test_classify_class()
    local built = {Built = entry({library = "Lib"})}
    local release = {Rel = entry({})}
    local bproto = {BP = entry({library = "PLib"})}
    local rproto = {RP = entry({})}
    local s, r = classify.classify_class("Built", built, bproto, release, rproto)
    check(s == "implemented" and r == "built: Lib", "a class a built library carries is implemented and names the library")
    s, r = classify.classify_class("Rel", built, bproto, release, rproto)
    check(s == "implemented" and r == "release-native: 6.1.3 dyld cache", "a class the release carries is release-native")
    s, r = classify.classify_class("BP", built, bproto, release, rproto)
    check(r == "built protocol: PLib", "a class row that is a built protocol is present")
    s, r = classify.classify_class("RP", built, bproto, release, rproto)
    check(r == "release-native: a protocol in the 6.1.3 dyld cache", "a class row that is a release protocol is present")
    s, r = classify.classify_class("None", built, bproto, release, rproto)
    check(s == "missing" and r == "no class or protocol None in the built libraries or the 6.1.3 cache", "anything else is missing, by name")
end

local function test_classify_method()
    local release = {
        NSObject = entry({class = {"-new"}, instance = {"-init"}}),
        UICommand = entry({superclass = "NSObject", instance = {"-action", "-title"}, class = {"-commandWithTitle:image:action:propertyList:"}}),
        UIKeyCommand = entry({superclass = "UICommand"}),
        SKOverlay = entry({superclass = "SKLayer"}),
        SKLayer = entry({superclass = "CALayer"}),
        CALayer = entry({superclass = "NSObject", instance = {"-delegate"}}),
        Orphan = entry({superclass = "Gone"}),
    }
    local built = {}
    local s, r = classify.classify_method("-[UIKeyCommand title]", built, release, {}, {})
    check(s == "implemented" and r == "release-native: 6.1.3 dyld cache (inherited from UICommand)", "a member a superclass declares is answered up the chain (" .. tostring(r) .. ")")
    s, r = classify.classify_method("+[UIKeyCommand commandWithTitle:image:action:propertyList:]", built, release, {}, {}, {}, "yes")
    check(s == "missing" and contains(r, "marks this row NS_UNAVAILABLE"), "a row Apple marks NS_UNAVAILABLE is not walked")
    s, r = classify.classify_method("-[UIKeyCommand title]", built, release, {}, {}, {["-[UIKeyCommand title]"] = true})
    check(s == "missing" and contains(r, "a registry has decided this row"), "a row a registry has decided is not walked")
    s, r = classify.classify_method("+[UIKeyCommand new]", built, release, {}, {})
    check(s == "implemented" and contains(r, "+new is NSObject's"), "+new is answered for any class")
    s, r = classify.classify_method("+[UIKeyCommand new]", built, release, {}, {}, {["+[UIKeyCommand new]"] = true})
    check(s ~= "implemented" or not contains(r, "+new is NSObject's"), "but not for a row a registry has decided")
    local header = {framework = "StoreKit", supers = {SKOverlay = {NSObject = true}}}
    s, r = classify.classify_method("-[SKOverlay delegate]", built, release, {}, {}, {}, "", header)
    check(s == "missing" and contains(r, "the 6.1.3 cache's SKOverlay has superclass SKLayer where StoreKit's 26.2 header declares NSObject"),
          "the release chain is not climbed past a superclass the 26.2 header disagrees with (" .. tostring(r) .. ")")
    s, r = classify.classify_method("-[SKOverlay delegate]", built, release, {}, {}, {}, "", nil)
    check(s == "implemented" and contains(r, "inherited from CALayer"), "and without the header the chain is climbed")
    s, r = classify.classify_method("-[Orphan thing]", built, release, {}, {})
    check(s == "missing" and contains(r, "the superclass Gone above Orphan is in neither"), "a walk that cannot go on says where it stopped")
    s, r = classify.classify_method("-[CLDelegate locationManager:didDetermineLocation:error:]", built, release, {}, {CLDelegate = entry({instance = {"-locationManager:didDetermineLocation:error:"}})})
    check(s == "implemented" and r == "release-native: 6.1.3 dyld cache (the protocol CLDelegate declares it)", "a protocol that declares the selector answers it")
    s, r = classify.classify_method("-[Nobody x]", built, release, {}, {})
    check(r == "owner Nobody is neither a class nor a protocol in the built libraries or the 6.1.3 cache", "an owner in neither inventory is named")
    s, r = classify.classify_method("not a method", built, release, {}, {})
    check(s == "undecided" and r == "method api does not parse as +/-[Class sel]: 'not a method'", "an api that does not parse is undecided, quoted as the original quoted it")
    s, r = classify.classify_method("-[NSString(Cat) foo:]", {NSString = entry({instance = {"-foo:"}, library = "Foundation", where = {}})}, release, {}, {})
    check(s == "implemented" and r == "built: Foundation", "a category-qualified owner is read as its class")
    local merged = {NSString = entry({instance = {"-a", "-b"}, library = "Foundation", where = {["-b"] = "SensorKit"}})}
    s, r = classify.classify_method("-[NSString b]", merged, release, {}, {})
    check(r == "built: SensorKit", "the library that carries the selector is named, not the first one")
end

local function test_classify_property()
    local release = {
        AVAudioSessionCapability = entry({instance = {"-isSupported"}}),
        NSUnitLength = entry({class = {"-meters"}}),
        UIKeyCommand = entry({superclass = "UICommand"}),
        UICommand = entry({instance = {"-title", "-setTitle:"}}),
    }
    local s, r = classify.classify_property("AVAudioSessionCapability.supported", {}, release, {}, {}, "isSupported")
    check(s == "implemented", "a property read through the getter its header declares is found by that getter")
    s, r = classify.classify_property("AVAudioSessionCapability.supported", {}, release, {}, {}, "")
    check(s == "missing" and r == "AVAudioSessionCapability is there, neither -supported nor -setSupported: is an instance or a class selector",
          "with no declared getter the accessors come from the name (" .. tostring(r) .. ")")
    s, r = classify.classify_property("NSUnitLength.meters", {}, release, {}, {})
    check(r == "release-native: 6.1.3 dyld cache (a class property: read through -meters)", "a class property is read through a class selector")
    s, r = classify.classify_property("UIKeyCommand.title", {}, release, {}, {})
    check(r == "release-native: 6.1.3 dyld cache (inherited from UICommand)", "a property a superclass carries is answered up the chain")
    s, r = classify.classify_property("Gone.thing", {}, release, {}, {})
    check(r == "owner class Gone not in the built libraries or the 6.1.3 cache", "an owner in neither inventory is named")
    s, r = classify.classify_property("-[A b]", {}, release, {}, {})
    check(s == "undecided", "a property api that does not parse is undecided")
end

local function test_classify_symbol_and_decide()
    local s, r = classify.classify_symbol("CGFoo()", {_CGFoo = "CoreGraphics"}, {})
    check(s == "implemented" and r == "built: CoreGraphics", "a function row's () is dropped and the built export named")
    s, r = classify.classify_symbol("kBar", {}, {_kBar = true})
    check(r == "release-native: 6.1.3 dyld cache", "a symbol the release exports is release-native")
    s = classify.classify_symbol("kNone", {}, {})
    check(s == nil, "a symbol in neither goes to the header pass")
    local keys = classify.registry_keys_for("UIView.hidden")
    check(table.concat(keys, " ") == "UIView.hidden -[UIView hidden] -[UIView setHidden:] +[UIView hidden]", "a property is asked for under its accessor forms too")
    local registries = {["-[UIView setHidden:]"] = {"absent", "", "packages/frameworks/apple-backports"}, ["Done.x"] = {"implemented", "", "p"}}
    local diagnostics = {}
    local decided = classify.decide({api = "UIView.hidden", lang = "objc"}, registries, diagnostics)
    check(decided and decided[1] == "decided" and decided[2] == "absent in packages/frameworks/apple-backports's registry: no reason recorded" and decided[4] == "none",
          "a registry that records the row absent decides it, saying so")
    check(classify.decide({api = "Done.x", lang = "objc"}, registries, diagnostics) == nil and #diagnostics == 1, "an implemented entry decides nothing and is reported")
    check(classify.decide({api = "UIView.hidden", lang = "swift"}, registries, {}) == nil, "a Swift row is never decided from a registry")
end

local function test_headers_and_needs()
    local index = {rows = {kM = {"constant", nil, false, false}, kE = {"constant", {7, 0}, false, false}, kS = {"function", nil, false, false},
                           ["kS()"] = {"function", nil, false, false}, E = {"enum", {7, 0}, false, false}},
                   flags = {kE = {true, false, false, "", ""}, kS = {false, true, true, "", ""}},
                   compiled = {E = "", kS = "", kM = ""}, macros = {kM = "kOther", kOther = "kReal"}, failed = {"a.h: x"}}
    local s, r = classify.classify_from_headers("kM", {kind = "constant"}, index, "6.1.3", {}, {_kReal = true})
    check(s == "implemented" and r == "a macro for kOther, which the release's own cache exports: the name resolves to a value the release already has, and the availability above the declaration in the header does not gate it",
          "a macro that resolves through another macro to an exported name is implemented (" .. tostring(r) .. ")")
    s, r = classify.classify_from_headers("kM", {kind = "constant"}, index, "6.1.3", {}, {})
    check(s == "header-ok" and r == "a macro: its value is in the header (kOther), so no symbol is needed", "a macro naming nothing exported is header-ok")
    local status, reason, introduced = classify.classify_from_headers("kE", {kind = "constant"}, index, "6.1.3", {}, {})
    check(status == "missing" and contains(reason, "declared extern in the lifted headers") and classify.what_this_row_needs(status, introduced, "6.1.3") == "code+lift",
          "an extern constant with no symbol is missing, and a 7.0 header introduction makes it code+lift")
    s, r = classify.classify_from_headers("kS()", {kind = "function"}, index, "6.1.3", {}, {})
    check(s == "header-ok" and r == "static, in the header, no run-time symbol", "a static function is header-ok")
    status, reason, introduced = classify.classify_from_headers("E", {kind = "enum"}, index, "6.1.3", {}, {})
    check(status == "header-ok" and reason == "enum declared in the lifted headers and the generated unit naming it compiles for 6.1.3"
          and classify.what_this_row_needs(status, introduced, "6.1.3") == "lift", "a type that compiles is header-ok, and its 7.0 introduction is the lift's work")
    s, r = classify.classify_from_headers("Gone", {kind = "enum"}, index, "6.1.3", {}, {})
    check(s == "undecided" and contains(r, "(1 headers of this framework clang rejected)"), "a declaration the target does not see is undecided with needs=declare")
    check(classify.what_this_row_needs("undecided", nil, "6.1.3", nil) == "decide" and classify.what_this_row_needs("unmeasured", nil, "6.1.3", "x") == "swift-pass"
          and classify.what_this_row_needs("declared", nil, "6.1.3", nil) == "build" and classify.what_this_row_needs("missing", {6, 1}, "6.1.3", nil) == "code"
          and classify.what_this_row_needs("implemented", {6, 1, 3}, "6.1.3", nil) == "none", "needs follows the status, the override and the header's introduction")
    s, r = classify.classify_from_headers("x", {kind = "enum"}, {error = "the walk read nothing"}, "6.1.3", {}, {})
    check(s == "undecided" and r == "the walk read nothing", "an unreadable framework leaves its rows undecided with the walk's own error")
end

local function test_inputs(folder)
    local surface = path.join(folder, "surface.tsv")
    local head = "framework\tkind\tlang\tapi\tintroduced\tdeprecated\tobsoleted\tunavailable\tvia\tgetter\tregistry\towner-registry\tdemand-rank\tdemand-severity\tdemand-apps\tdemand-telegram\timpl-lead\timpl-file-lead\n"
    io.writefile(surface, head .. "F\tclass\tobjc\tA\t7.0\t\t\t\town\t\tnone\t\t\t\t\t\t\t\n\nF\tconstant\tobjc\t\"q\"\"t\"\t\t\t\t\t\t\t\t\t\t\t\t\t\t\n")
    local rows = inputs.load_surface(surface)
    check(#rows == 2 and rows[1].api == "A" and rows[1].via == "own" and rows[2].api == 'q"t', "the surface is read as tab-separated with csv quoting, blank lines skipped")
    io.writefile(surface, "framework\tkind\n")
    check(contains(raised(function () inputs.load_surface(surface) end), "surface tsv header changed shape"), "a surface of another shape is refused")
    local checkout = path.join(folder, "checkout")
    os.mkdir(path.join(checkout, "packages", "frameworks", "apple-backports", "registry", "UIKit"))
    os.mkdir(path.join(checkout, "packages", "frameworks", "combine", "registry"))
    io.writefile(path.join(checkout, "packages", "frameworks", "apple-backports", "registry", "UIKit", "view.json"),
                 '{"entries": [{"api": "UIView.hidden", "status": "absent", "reason": "r"}, {"api": "", "status": "absent"}]}')
    io.writefile(path.join(checkout, "packages", "frameworks", "combine", "registry", "Swift.json"), '[{"api": "Foo.bar", "status": "implemented"}]')
    io.writefile(path.join(checkout, "packages", "frameworks", "combine", "registry", "broken.json"), '{')
    local read = inputs.read_package_registries(checkout)
    check(read["UIView.hidden"] and read["UIView.hidden"][1] == "absent" and read["UIView.hidden"][3] == "packages/frameworks/apple-backports",
          "a registry nested under a package is read with its package")
    check(read["Foo.bar"] and read["Foo.bar"][3] == "packages/frameworks/combine" and read["Foo.bar"][2] == "", "a registry that is a bare list is read too")
    check(read[""] == nil, "an entry with no api is skipped")
    check(inputs.short((os.getenv("HOME") or "") .. "/x") == "$HOME/x", "a path under the home folder is written with $HOME")
    local text = "@interface A : NSObject\n@interface B\n  : UIView\n@interface C (Cat)\n @interface D : E\n"
    local found = {}
    for _, pair in ipairs(inputs.interfaces(text)) do
        table.insert(found, pair[1] .. "=" .. pair[2])
    end
    check(table.concat(found, " ") == "A=NSObject B=UIView C=", "an @interface at a line start is read with its superclass, across a newline")
    local vfs = path.join(folder, "vfs.yaml")
    io.writefile(vfs, '{"a": ".../headers\\/System\\/Library\\/Frameworks\\/ARKit.framework\\/Headers\\/x.h", "b": "headers/System/Library/PrivateFrameworks/P.framework"}')
    local lifted = inputs.lifted_frameworks(vfs)
    check(lifted.ARKit and not lifted.P, "the lifted frameworks are read off the overlay's escaped paths")
end

local function test_json()
    local text = ledger_json.encode(ledger_json.object({{"a", ledger_json.array({true, false, ledger_json.null(), 7, "x"})}, {"b", "é\"\\\n\127"}, {"c", ledger_json.object()}}))
    check(text == '{"a": [true, false, null, 7, "x"], "b": "\\u00e9\\"\\\\\\n\\u007f", "c": {}}', "the index is written as Python's json.dump writes it: " .. text)
    check(ledger_json.string_text("\240\159\152\128") == '"\\ud83d\\ude00"', "a character above the BMP is written as a surrogate pair")
end

local function test_framework_index_format(folder)
    if not os.isfile("/usr/bin/xcrun") then
        print("skip: no xcrun, so the walk's clang command cannot run")
        return
    end
    local sdk = path.join(folder, "Fake.sdk")
    local framework_headers = path.join(sdk, "System", "Library", "Frameworks", "Probe.framework", "Headers")
    os.mkdir(framework_headers)
    io.writefile(path.join(framework_headers, "Probe.h"),
                 "#define PROBE_ALIAS kProbeValue\nextern const int kProbeValue;\nstatic inline int ProbeInline(int x) { return x; }\n"
                 .. "typedef int ProbeIndex;\nenum ProbeKind { ProbeKindA = 1 };\n")
    local vfs = path.join(folder, "probe-vfs.yaml")
    io.writefile(vfs, '{"version": 0, "roots": []}\n')
    local cache_dir = path.join(folder, "index")
    local work = path.join(cache_dir, "generated")
    os.mkdir(work)
    local index, cached = headers.framework_index("Probe", sdk, vfs, cache_dir, work, false)
    local text = io.readfile(path.join(cache_dir, "Probe.json")) or ""
    check(not cached and index.error == nil, "a framework with a header is walked and indexed (" .. tostring(index.error) .. ")")
    local stamp = string.format('{"stamp": {"sdk": %s, "vfs": %s, "vfs_mtime": %d, "target": "armv7-apple-ios6.1.3", "tool": "',
                                ledger_json.string_text(inputs.realpath(sdk)), ledger_json.string_text(inputs.realpath(vfs)), os.mtime(vfs))
    check(text:sub(1, #stamp) == stamp, "the cache file opens with the stamp, its keys in the order const-values reads them: " .. text:sub(1, 160))
    local keys = {}
    for key in text:gmatch('%]?%}?, "(%l+)": [{%[%d]') do
        table.insert(keys, key)
    end
    check(table.concat(keys, " "):find("rows flags typedefs compiled macros failed headers", 1, true) ~= nil,
          "the record's keys are rows, flags, typedefs, compiled, macros, failed, headers in that order: " .. table.concat(keys, " "))
    check(contains(text, '"kProbeValue": [true, false, false, "const int", "const int"]'), "a flag is a five-element list: extern, static, inline, sugared and canonical type")
    check(contains(text, '"ProbeInline": [false, true, true, "int (int)", "int (int)"]'), "a static inline function reads static and inline")
    check(contains(text, '"ProbeIndex": "int"'), "a typedef maps to its underlying type")
    check(contains(text, '"macros": {') and contains(text, '"PROBE_ALIAS": "kProbeValue"'), "the framework's macros are recorded")
    check(contains(text, '"ProbeKindA": ["constant", null, false, false]'), "a row is [kind, introduced, unavailable, unavailable_ios]")
    check(text:sub(-1) ~= "\n" and contains(text, ', "failed": [], "headers": 1}'), "the record ends with the header count and no newline, as json.dump leaves it")
    local again, hit = headers.framework_index("Probe", sdk, vfs, cache_dir, work, false)
    check(hit and again.flags.kProbeValue[1] == true, "a second run reads the cached record back")
    local _, refreshed = headers.framework_index("Probe", sdk, vfs, cache_dir, work, true)
    check(not refreshed, "and --refresh walks again")
    local missing_index = headers.framework_index("include/nothing-here", sdk, vfs, cache_dir, work, false)
    check(contains(missing_index.error, "no header directory or usr/include library for include/nothing-here"), "an unknown usr/include library is an error index")
end

function main()
    local folder = workspace.fresh("ledger-test")
    local ok, failure = true, nil
    try {
        function ()
            test_platform_check()
            test_a_row_whose_line_does_not_compile_is_reported_as_failing(folder)
            test_static_inline_through_a_macro_is_header_only(folder)
            test_scan_storage_merges_lines()
            test_built_tree_reads_a_real_run_directory(folder)
            test_write_output_writes_files_a_reader_can_use(folder)
            test_todo_order_is_stable()
            test_swift_row_from_a_registry()
            test_uncovered_module_leaves_rows_undecided()
            test_swift_index_file_is_loaded_from_disk(folder)
            test_swift_normalisations()
            test_classify_class()
            test_classify_method()
            test_classify_property()
            test_classify_symbol_and_decide()
            test_headers_and_needs()
            test_inputs(folder)
            test_json()
            test_framework_index_format(folder)
        end,
        catch {
            function (errors)
                ok, failure = false, tostring(errors)
            end
        }
    }
    os.tryrm(folder)
    if not ok then
        table.insert(failures, "raised: " .. failure)
        print("FAIL raised: " .. failure)
    end
    print(string.format("ledger_test: %d checks, %d failed", checks, #failures))
    if #failures > 0 then
        os.exit(1)
    end
end
