-- walk-check.lua: the owner walk of lib/owners.lua over a planted interface, each line's owner written by hand.
--
--     xmake l walk-check.lua
--
-- The planted lines are the shapes the walk has to get right: a nested type's members, the closing brace that pops
-- it, an attribute and a preprocessor line that neither push nor pop, `@frozen public enum` as one declaration, and
-- an extension whose module prefix is dropped. A "-" is no owner at all.

local owners = import("lib.owners", {rootdir = path.join(os.scriptdir(), "..", ".."), anonymous = true})

local PLANTED = {
    {"public struct Image {", "Image"},
    {"  public enum ResizingMode {", "Image.ResizingMode"},
    {"    case tile", "Image.ResizingMode"},
    {"  }", "Image"},
    {"  public var size: Int", "Image"},
    {"#if compiler(>=5.3)", "Image"},
    {"  @available(iOS 14, *)", "Image"},
    {"  public func f() {", "Image"},
    {"}", "-"},
    {"@frozen public enum Orientation {", "Orientation"},
    {"  case up", "Orientation"},
    {"}", "-"},
    {"extension SwiftUICore.Image {", "Image"},
    {"  public static func make() -> Image {", "Image"},
    {"}", "-"},
    {"extension SwiftUI.Anchor.Source {", "Anchor.Source"},
    {"  var bounds: Int {", "Anchor.Source"},
    {"}", "-"},
}

function main(...)
    local lines = {}
    for i, record in ipairs(PLANTED) do
        lines[i] = record[1]
    end
    local failures = 0
    for i, row in ipairs(owners.walk(lines)) do
        local want = PLANTED[i][2]
        local got = row.owner or "-"
        if got ~= want then
            failures = failures + 1
            print(string.format("FAIL line %d %q: owner %s, want %s", i, lines[i], got, want))
        end
    end
    print(string.format("%d of %d planted lines have the owner written by hand", #PLANTED - failures, #PLANTED))
    if failures > 0 then
        os.exit(1)
    end
end
