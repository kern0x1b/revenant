local swift = import("swiftinterface", {rootdir = path.join(os.scriptdir(), "..", "..", "tools", "corpus"), anonymous = true})
local surface = import("sdk-surface", {rootdir = path.join(os.scriptdir(), "..", "..", "tools", "corpus"), anonymous = true})

local INTERFACE = table.concat({
    "// swift-interface-format-version: 1.0",
    "import Swift",
    "@available(iOS 13.0, *)",
    "public struct Box {",
    "  public var size: Swift.Int",
    "  internal var hidden: Swift.Int",
    "  @usableFromInline var usable: Swift.Int",
    "  @_spi(Private) public var secret: Swift.Int",
    "  nonisolated(unsafe) public var shared: Swift.Int",
    "  public var `default`: Swift.Int",
    "  @inlinable public func double() -> Swift.Int {",
    "    let local = { () -> Swift.Int in if size > 0 {",
    "      return size * 2",
    "    }",
    "    return 0 }()",
    "    return local",
    "  }",
    "  @available(iOS 15.0, *)",
    "  public init?(size: Swift.Int, _ other: Swift.Int)",
    "  public subscript(index: Swift.Int) -> Swift.Int {",
    "    get",
    "  }",
    "  public static func + (lhs: Kit.Box, rhs: Kit.Box) -> Kit.Box",
    "  public class Inner {",
    "    public class func make<T>(_ value: T, label name: Swift.String) -> Kit.Box.Inner",
    "  }",
    "}",
    "public func quoted(_ text: Swift.String = \"{\")",
    "public protocol Shape {",
    "  func area() -> Swift.Double",
    "  var name: Swift.String { get }",
    "}",
    "public enum Mode {",
    "  case on, off",
    "  case custom(Swift.Int)",
    "}",
    "extension Kit.Box : Kit.Shape {",
    "  public func area() -> Swift.Double",
    "}",
    "@available(iOS 14.0, *)",
    "extension SwiftUI.View {",
    "  public func tinted() -> some SwiftUI.View",
    "}",
    "#if compiler(>=5.3)",
    "@available(iOS 16.0, *)",
    "public func helper(value: Swift.Int)",
    "#else",
    "@available(iOS 15.0, *)",
    "public func helper(value: Swift.Int)",
    "#endif",
    "@available(iOS, introduced: 9.0, deprecated: 12.0, obsoleted: 14.0)",
    "public let legacy: Swift.Int",
    "@available(*, deprecated)",
    "public typealias Old = Swift.Int",
    "@available(*, unavailable)",
    "public class Gone {",
    "  public func call()",
    "}",
    "public actor Worker {",
    "}",
    "@available(iOS, deprecated: 100000.0)",
    "public func later()",
    "@available(macOS 10.15, *)",
    "public func macOnly()",
    "@available(iOS 13, *)",
    "public func short()",
    "@available(iOS 13.0.1, *)",
    "public func patch()",
    "public macro Make() = #externalMacro(module: \"M\", type: \"T\")",
    "#if compiler(>=5.3)",
    "@available(iOS 15.0, *)",
    "public func assist()",
    "#else",
    "@available(iOS 16.0, *)",
    "public func assist()",
    "#endif",
    "",
}, "\n")

local EXPECTED = {
    "struct\tBox\t13.0\t\t\t\town",
    "property\tBox.size\t13.0\t\t\t\tcontainer",
    "property\tBox.shared\t13.0\t\t\t\tcontainer",
    "property\tBox.default\t13.0\t\t\t\tcontainer",
    "method\tBox.double()\t13.0\t\t\t\tcontainer",
    "method\tBox.init?(size:_:)\t15.0\t\t\t\town",
    "method\tBox.subscript(index:)\t13.0\t\t\t\tcontainer",
    "method\tBox.+(lhs:rhs:)\t13.0\t\t\t\tcontainer",
    "class\tBox.Inner\t13.0\t\t\t\tcontainer",
    "method\tBox.Inner.make(_:label:)\t13.0\t\t\t\tcontainer",
    "function\tquoted(_:)\t\t\t\t\tnone",
    "protocol\tShape\t\t\t\t\tnone",
    "method\tShape.area()\t\t\t\t\tnone",
    "property\tShape.name\t\t\t\t\tnone",
    "enum\tMode\t\t\t\t\tnone",
    "constant\tMode.on\t\t\t\t\tnone",
    "constant\tMode.off\t\t\t\t\tnone",
    "constant\tMode.custom\t\t\t\t\tnone",
    "method\tBox.area()\t\t\t\t\tnone",
    "method\tView.tinted()\t14.0\t\t\t\tcontainer",
    "function\thelper(value:)\t15.0\t\t\t\town",
    "constant\tlegacy\t9.0\t12.0\t14.0\t\town",
    "typealias\tOld\t\tyes\t\t\tnone",
    "class\tGone\t\t\t\tyes\tnone",
    "method\tGone.call()\t\t\t\tyes\tnone",
    "class\tWorker\t\t\t\t\tnone",
    "function\tlater()\t\tyes\t\t\tnone",
    "function\tmacOnly()\t\t\t\t\tnone",
    "function\tshort()\t13.0\t\t\t\town",
    "function\tpatch()\t13.0.1\t\t\t\town",
    "function\tMake()\t\t\t\t\tnone",
    "function\tassist()\t15.0\t\t\t\town",
}

local function serialized(rows)
    local out = {}
    for _, row in ipairs(rows) do
        local shown = swift.shown(row)
        table.insert(out, table.concat({shown.kind, shown.api, shown.introduced, shown.deprecated, shown.obsoleted, shown.unavailable, shown.via},
                                       "\t"))
    end
    return out
end

local function parsed(text, problems)
    return serialized(swift.parse_text(text, "Kit", {Kit = true, SwiftUI = true}, problems))
end

local function find(lines, wanted)
    for _, line in ipairs(lines) do
        if line == wanted then
            return true
        end
    end
    return false
end

local function prefixed(lines, prefix)
    for _, line in ipairs(lines) do
        if line:sub(1, #prefix) == prefix then
            return true
        end
    end
    return false
end

local function surface_row(lang, kind, api, introduced, via, extra)
    local row = {framework = "Kit", kind = kind, lang = lang, api = api, introduced = introduced, deprecated = "", obsoleted = "",
                 unavailable = "", via = via or "own"}
    for key, value in pairs(extra or {}) do
        row[key] = value
    end
    return row
end

local function apis(rows)
    local out = {}
    for _, row in ipairs(rows) do
        table.insert(out, (row.row or row).api .. (row.state and ("=" .. row.state) or ""))
    end
    return table.concat(out, ",")
end

local function impl_repos()
    local entries = {}
    for _, entry in ipairs(surface.repositories()) do
        entries[entry.repo] = entry
    end
    return {
        surface.index_repo(entries["swiftlang/swift-corelibs-foundation"], {sha = "a", files = {
            "Sources/Foundation/NSCalendar.swift", "Sources/Foundation/Calendar.swift", "Tests/Foundation/TestCalendar.swift"}}),
        surface.index_repo(entries["apple-oss-distributions/CF"], {sha = "b", files = {"CFArray.c", "CFArray.h", "docs/CFBag.c"}}),
        surface.index_repo(entries["microsoft/WinObjC"], {sha = "c", files = {
            "Frameworks/UIKit/UIView.mm", "Frameworks/UIKit/Deep/UIView.mm", "Frameworks/UIKit/UIView+Layout.mm", "Frameworks/Loose.mm"}}),
    }
end

local CASES = {
    {"the whole interface gives its public rows in declaration order", function ()
        return table.concat(parsed(INTERFACE), "\n") == table.concat(EXPECTED, "\n")
    end},
    {"internal, @usableFromInline and @_spi declarations are not rows", function ()
        local lines = parsed(INTERFACE)
        return not prefixed(lines, "property\tBox.hidden") and not prefixed(lines, "property\tBox.usable")
            and not prefixed(lines, "property\tBox.secret")
    end},
    {"a local let in an inlinable body is not a row", function ()
        return not prefixed(parsed(INTERFACE), "property\tBox.local") and not prefixed(parsed(INTERFACE), "constant\tlocal")
    end},
    {"a conformance is not a row and an extension of SwiftUI.View is owned by View", function ()
        local lines = parsed(INTERFACE)
        return not prefixed(lines, "class\tBox\t") and not prefixed(lines, "struct\tShape") and find(lines, "method\tView.tinted()\t14.0\t\t\t\tcontainer")
    end},
    {"both branches of an #if are one row with the lower version", function ()
        local count = 0
        for _, line in ipairs(parsed(INTERFACE)) do
            if line:find("helper(value:)", 1, true) then
                count = count + 1
            end
        end
        return count == 1 and find(parsed(INTERFACE), "function\thelper(value:)\t15.0\t\t\t\town")
            and find(parsed(INTERFACE), "function\tassist()\t15.0\t\t\t\town")
    end},
    {"a member takes the container's version and unavailability where it has none", function ()
        local lines = parsed(INTERFACE)
        return find(lines, "property\tBox.size\t13.0\t\t\t\tcontainer") and find(lines, "method\tGone.call()\t\t\t\tyes\tnone")
    end},
    {"deprecated alone and deprecated 100000 both say yes", function ()
        local lines = parsed(INTERFACE)
        return find(lines, "typealias\tOld\t\tyes\t\t\tnone") and find(lines, "function\tlater()\t\tyes\t\t\tnone")
    end},
    {"a scope left open and a brace with none open are named as problems", function ()
        local problems = {}
        swift.parse_text("public struct A {\n", "Kit", {}, problems)
        swift.parse_text("}\npublic func f()\n", "Kit", {}, problems)
        return #problems == 2 and problems[1] == "Kit: 1 scope(s) open at the end of the file, 0 closing brace(s) with none open"
            and problems[2] == "Kit: 0 scope(s) open at the end of the file, 1 closing brace(s) with none open"
    end},
    {"labels: an operator, a failable initializer, generics and attributes on a parameter", function ()
        return swift.function_name("func + (lhs: A, rhs: A) -> A") == "+(lhs:rhs:)"
            and swift.function_name("init?<T>(x: T)") == "init?(x:)"
            and swift.function_name("func map<T>(_ transform: @escaping (Int) -> T, on q: Q)") == "map(_:on:)"
            and swift.function_name("subscript<K>(key: K) -> V") == "subscript(key:)"
            and swift.function_name("func `default`()") == "default()"
    end},
    {"availability: the shorthand, labels, every platform, and none for iOS", function ()
        local a = swift.ios_availability("@available(iOS 13.0, macOS 10.15, *)")
        local b = swift.ios_availability("@available(iOS, introduced: 9.0, deprecated: 12.0, obsoleted: 14.0)")
        local c = swift.ios_availability("@available(*, unavailable)")
        local d = swift.ios_availability("@available(macOS 10.15, *)")
        local e = swift.ios_availability("@available(*, introduced: 5.0)")
        return swift.show(a[1]) == "13.0" and swift.show(b[1]) == "9.0" and swift.show(b[2]) == "12.0" and swift.show(b[3]) == "14.0"
            and c[1] == nil and c[4] == true and d == nil and e == nil
    end},
    {"text helpers keep Python's whitespace and line rules", function ()
        local lines = swift.splitlines("a\r\nb\rc\xC2\x85d\xE2\x80\xA8e\n")
        local words = swift.split(" a\xC2\xA0b\tc ")
        return #lines == 5 and lines[5] == "e" and swift.strip("\xE3\x80\x80 x \xC2\xA0") == "x" and #words == 3 and words[2] == "b"
            and swift.decode("a\xFFb") == "a\xEF\xBF\xBDb" and swift.decode("\xE2\x80x") == "\xEF\xBF\xBDx"
    end},
    {"names: a Latin letter is a word character, a combining mark and an operator symbol are not", function ()
        return swift.name_match("\xC3\xA5landIslands: X") == "\xC3\xA5landIslands" and swift.name_match("q\xCC\x82 = 1") == "q"
            and swift.name_match("\xE2\x89\x88 (a: A)") == nil
    end},
    {"surface: after 6.1 only, unannotated and floors counted, sorted by version then names, ties stable", function ()
        local rows = {surface_row("objc", "class", "B", "7.0"), surface_row("objc", "class", "A", "6.1"),
                      surface_row("objc", "class", "C", "6.1.1"), surface_row("objc", "method", "-[A x]", "", "none"),
                      surface_row("swift", "method", "A.y()", "5.0", "container"), surface_row("objc", "class", "D", "7"),
                      surface_row("objc", "class", "B", "7.0", "container")}
        local out, unannotated, before = surface.surface_rows(rows)
        return apis(out) == "C,D,B,B" and out[3].via == "own" and out[4].via == "container" and unannotated["objc\tKit"] == 1
            and before["objc\town"] == 1 and before["swift\tfloor"] == 1
    end},
    {"registry: the api, the dotted selector, a property's getter or setter, and the strongest status", function ()
        local registry = surface.registry_from({{api = "UIView", status = "implemented"}, {api = "UIView", status = "absent"},
                                                {api = "UIView.foo:", status = "inert"}, {api = "-[UIView setBar:]", status = "ignored"},
                                                {api = "Empty", status = ""}})
        return registry.UIView == "implemented" and surface.registry_status(registry, "method", "-[UIView foo:]") == "inert"
            and surface.registry_status(registry, "property", "UIView.bar") == "ignored"
            and surface.registry_status(registry, "property", "UIView.baz") == nil
            and surface.registry_status(registry, "method", "-[UIView baz]") == nil
            and surface.show_registry("implemented") == "carried" and surface.show_registry(nil) == "none"
            and surface.show_registry(surface.registry_status(registry, "class", "Empty")) == "none"
    end},
    {"owners: an Objective-C method or property, a nested Swift member, an operator, a type", function ()
        local function joined(list)
            return table.concat(list, "|")
        end
        return joined(surface.owners("method", "objc", "-[UIView foo:]")) == "UIView"
            and joined(surface.owners("property", "objc", "UIView.layer.x")) == "UIView"
            and joined(surface.owners("method", "swift", "Publishers.Map.foo(x.y:)")) == "Publishers.Map|Publishers"
            and joined(surface.owners("method", "swift", "SIMD2..<(a:b:)")) == "SIMD2.|SIMD2"
            and joined(surface.owners("class", "swift", "A.B")) == "" and joined(surface.owners("method", "swift", "f()")) == ""
    end},
    {"enrich: the owner's status for a member with no row, demand by name or linker symbol, Telegram", function ()
        local registry = surface.registry_from({{api = "UIView", status = "implemented"}, {api = "Known", status = "absent"}})
        local demand = surface.demand_from({{api = "UIView.bar", rank = "3", severity = "LOAD-FAIL", apps = "2", crash_callers = "ish,telegram"},
                                            {api = "UIView.bar", rank = "9", severity = "SOFT", apps = "1", crash_callers = ""},
                                            {api = "_CFThing", rank = "5", severity = "SOFT", apps = "1", crash_callers = "telegrams"}})
        local member = surface.enrich(surface_row("objc", "property", "UIView.bar", "9.0"), registry, demand, {})
        local fn = surface.enrich(surface_row("objc", "function", "CFThing()", "9.0"), registry, demand, {})
        local typed = surface.enrich(surface_row("objc", "class", "Known", "9.0"), registry, demand, {})
        local orphan = surface.enrich(surface_row("objc", "property", "Other.x", "9.0"), registry, demand, {})
        return table.concat(member, "|") == "none|carried|3|LOAD-FAIL|2|yes||" and table.concat(fn, "|") == "none||5|SOFT|1|||"
            and table.concat(typed, "|") == "absent|||||||" and table.concat(orphan, "|") == "none|||||||"
    end},
    {"impl leads: a stripped prefix, the longest C prefix, a framework directory, the shortest path, a category file", function ()
        local repos = impl_repos()
        local function lead(framework, kind, lang, api)
            local files = {}
            for _, hit in ipairs(surface.lookup(repos, framework, kind, api, surface.owners(kind, lang, api))) do
                table.insert(files, hit.source .. "=" .. hit.file)
            end
            return table.concat(files, ";")
        end
        return lead("Foundation", "class", "objc", "NSCalendar") == "swift-corelibs-foundation=swiftlang/swift-corelibs-foundation:Sources/Foundation/NSCalendar.swift"
            and lead("Foundation", "method", "swift", "Calendar.date(byAdding:)") == "swift-corelibs-foundation=swiftlang/swift-corelibs-foundation:Sources/Foundation/Calendar.swift"
            and lead("CoreFoundation", "function", "objc", "CFArrayCreateMutable()") == "apple-oss=apple-oss-distributions/CF:CFArray.c"
            and lead("CoreFoundation", "constant", "objc", "kCFArrayCallBacks") == "apple-oss=apple-oss-distributions/CF:CFArray.c"
            and lead("CoreFoundation", "function", "objc", "CFBagCreate()") == ""
            and lead("UIKit", "method", "objc", "-[UIView layoutIfNeeded]") == "WinObjC=microsoft/WinObjC:Frameworks/UIKit/UIView.mm"
            and lead("UIKit", "class", "objc", "UIView+Layout") == "WinObjC=microsoft/WinObjC:Frameworks/UIKit/UIView+Layout.mm"
            and lead("Loose", "class", "objc", "Loose") == "" and lead("AppKit", "class", "objc", "UIView") == ""
    end},
    {"dropped: removed, unavailable, obsoleted at or below the SDK, changed only under labels the old SDK lacked", function ()
        local new_rows = {surface_row("objc", "class", "Kept", "7.0"), surface_row("objc", "class", "Hidden", "7.0", "own", {unavailable = "yes"}),
                          surface_row("objc", "class", "Old", "7.0", "own", {obsoleted = "26.2"}),
                          surface_row("objc", "class", "Later", "7.0", "own", {obsoleted = "27.0"}),
                          surface_row("objc", "class", "Twice", "7.0", "own", {unavailable = "yes"}), surface_row("objc", "class", "Twice", "7.0"),
                          surface_row("swift", "function", "f(isolation:function:)", "17.0"),
                          surface_row("swift", "function", "g(b:)", "13.0")}
        local old_rows = {surface_row("objc", "class", "Kept", "7.0"), surface_row("objc", "class", "Hidden", "7.0"),
                          surface_row("objc", "class", "Old", "7.0"), surface_row("objc", "class", "Later", "7.0"),
                          surface_row("objc", "class", "Twice", "7.0"), surface_row("objc", "class", "Gone", "7.0"),
                          surface_row("objc", "class", "Dead", "7.0", "own", {unavailable = "yes"}),
                          surface_row("swift", "function", "f(function:)", "13.0"), surface_row("swift", "function", "g(a:)", "13.0"),
                          surface_row("swift", "function", "g(b:)", "13.0")}
        local removed = surface.removed_rows(new_rows, old_rows, {26, 2}, {16, 4})
        return apis(removed) == "f(function:)=changed,Old=obsoleted,Gone=removed,g(a:)=removed,Hidden=unavailable"
            and removed[1].current.api == "f(isolation:function:)"
    end},
}

function main()
    local failed = 0
    for _, case in ipairs(CASES) do
        local ok = false
        local message = nil
        try {
            function ()
                ok = case[2]() == true
            end,
            catch {
                function (errors)
                    message = tostring(errors)
                end
            }
        }
        if not ok then
            failed = failed + 1
            print("FAIL: " .. case[1] .. (message and (": " .. message) or ""))
        end
    end
    print(string.format("surface_table_test: %d checks, %d failed", #CASES, failed))
    if failed > 0 then
        os.exit(1)
    end
end
