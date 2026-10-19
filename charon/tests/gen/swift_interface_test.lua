local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")
local reader = import("gen.swift_interface", {rootdir = TOOLS, anonymous = true})

local NAME = "norwegianBokm\195\165l"

local FIXTURE = [[
// swift-interface-format-version: 1.0
// swift-module-flags: -module-name Fixture
import Swift
import Foundation
@available(iOS 8.0, tvOS 9.0, *)
public struct Outer {
  @_Concurrency.MainActor @preconcurrency public var shown: Swift.Int { get set }
  @available(iOS, introduced: 9.0, deprecated: 12.0, obsoleted: 15.0)
  public func keyed() {}
  @available(iOS, deprecated, introduced: 7.0, renamed: "Outer.shown")
  public var bare: Swift.Int { get }
  @available(iOS 10.0, deprecated: 100000, message: "Use shown")
  public func sentinel() {}
  @available(*, unavailable, message: "Use 'shown() -> Int' instead")
  public func gone() -> Swift.Int?
  @available(macOS, unavailable)
  public func mac() {}
  #if compiler(>=5.3) && $NonescapableTypes
  public func guarded() {}
  #endif
  public init(_ title: Swift.String, @ViewBuilder content: () -> Swift.Int)
  public func callback(handler: (Swift.Int) -> Swift.Void, count: Swift.Int)
  public static func == (a: Outer, b: Outer) -> Swift.Bool { true }
  public static func < (lhs: Outer, rhs: Outer) -> Swift.Bool
  public struct Inner {
    public func run() {}
  }
  public enum Mode {
    case first, second
  }
}
extension Outer.Inner {
  public func extended() {}
}
@available(iOS 16.0, *)
extension Outer.Inner where Value == Swift.Int {
  public var constrained: Swift.Int { get }
}
@available(iOS 17.0, *)
@available(tvOS, unavailable)
extension Outer {
  public func inExtension() {}
  public func ]] .. NAME .. [[() {}
}
@available(iOS, unavailable)
public class Hidden {
  public func hiddenMember() {}
}
]]

local EXPECTED = {
    "struct Outer 8.0 - - - own",
    "property Outer.shown 8.0 - - - container",
    "method Outer.keyed() 9.0 12.0 15.0 - own",
    "property Outer.bare 7.0 yes - - own",
    "method Outer.sentinel() 10.0 yes - - own",
    "method Outer.gone() 8.0 - - yes container",
    "method Outer.mac() 8.0 - - - container",
    "method Outer.guarded() 8.0 - - - container",
    "method Outer.init(_:content:) 8.0 - - - container",
    "method Outer.callback(handler:count:) 8.0 - - - container",
    "method Outer.==(a:b:) 8.0 - - - container",
    "method Outer.<(lhs:rhs:) 8.0 - - - container",
    "struct Outer.Inner 8.0 - - - container",
    "method Outer.Inner.run() 8.0 - - - container",
    "enum Outer.Mode 8.0 - - - container",
    "constant Outer.Mode.first 8.0 - - - container",
    "constant Outer.Mode.second 8.0 - - - container",
    "method Outer.Inner.extended() - - - - none",
    "property Outer.Inner.constrained 16.0 - - - container",
    "method Outer.inExtension() 17.0 - - - container",
    "method Outer." .. NAME .. "() 17.0 - - - container",
    "class Hidden - - - yes none",
    "method Hidden.hiddenMember() - - - yes none",
}

local function line_of(record)
    local function cell(value)
        return (value == nil or value == "") and "-" or value
    end
    return table.concat({record.kind, record.api, cell(record.introduced), cell(record.deprecated), cell(record.obsoleted),
                         cell(record.unavailable), record.via}, " ")
end

function main()
    local failures = 0
    local function check(ok, label)
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end

    local records = reader.parse_interface(FIXTURE, "Fixture")
    local got = {}
    for _, record in ipairs(records) do
        table.insert(got, line_of(record))
    end
    local want = {}
    for _, text in ipairs(EXPECTED) do
        table.insert(want, text)
    end
    local have = {}
    for _, text in ipairs(got) do
        have[text] = (have[text] or 0) + 1
    end
    for _, text in ipairs(want) do
        check((have[text] or 0) > 0, "missing " .. text)
        have[text] = (have[text] or 0) - 1
    end
    for text, n in pairs(have) do
        for _ = 1, n do
            check(false, "unexpected " .. text)
        end
    end
    check(#records == #want, "the fixture has " .. #want .. " declarations (got " .. #records .. ")")

    local text, count = reader.shard_text(FIXTURE, "Fixture")
    check(count == #records, "shard_text counts the declarations it writes")
    local header = string.match(text, "^[^\n]*")
    check(header == "module\tkind\tapi\tintroduced\tdeprecated\tobsoleted\tunavailable\tvia", "the shard's header has the columns in order")
    check(string.find(text, "method\tOuter.norwegianBokm\\xe5l()\t17.0\t\t\t\tcontainer", 1, true) ~= nil,
          "a non-ASCII name is written with a backslash escape")
    check(string.find(text, "[\128-\255]") == nil, "the shard text is ASCII")

    print("swift interface test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end
