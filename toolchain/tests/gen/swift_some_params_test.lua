local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")

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

function main()
    local render = import("gen.swift_render", {rootdir = TOOLS, anonymous = true})
    local failures = 0
    local function check(ok, label)
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end
    local known = {_StringProcessing = true, RegexBuilder = true, Swift = true}

    local builder = {row({kind = "swift-struct", name = "Builder", usr = "s:Builder"}),
                     row({kind = "swift-method", container = "Builder", name = "buildPartialBlock(accumulated:next:)", side = "+",
                          params = "some _StringProcessing.RegexComponent|some _StringProcessing.RegexComponent",
                          type = "_StringProcessing.Regex<C1>", usr = "s:Builder.buildPartialBlock",
                          generic_sig = "<W0, W1, C1 where W0 : _StringProcessing.RegexComponent, W1 : _StringProcessing.RegexComponent, "
                                        .. "C1 : _StringProcessing.RegexComponent>"})}
    local text = render.render(builder, "RegexBuilder", known, nil, nil, nil)
    check(string.find(text, "buildPartialBlock<W0, W1, C1>(accumulated: W0, next: W1)", 1, true) ~= nil,
          "a some parameter is named by the unused generic its constraint names")
    check(string.find(text, "where W0 : _StringProcessing.RegexComponent, W1 : _StringProcessing.RegexComponent", 1, true) ~= nil,
          "the constraints on the named parameters stay")

    local bare = {row({kind = "swift-struct", name = "Comp", usr = "s:Comp"}),
                  row({kind = "swift-method", container = "Comp", name = "buildPartialBlock(accumulated:next:)", side = "+",
                       params = "some _StringProcessing.RegexComponent|some _StringProcessing.RegexComponent",
                       type = "_StringProcessing.Regex<C1>", usr = "s:Comp.buildPartialBlock", generic_sig = "<W0, W1, C1>"})}
    local bare_text = render.render(bare, "RegexBuilder", known, nil, nil, nil)
    check(string.find(bare_text, "<W0, W1, C1>(accumulated: W0, next: W1)", 1, true) ~= nil,
          "unconstrained unused generics take the some parameters in order")
    check(string.find(bare_text, "where W0 : _StringProcessing.RegexComponent, W1 : _StringProcessing.RegexComponent", 1, true) ~= nil,
          "the some parameter's type becomes the constraint of its generic")

    local closure = {row({kind = "swift-struct", name = "Loop", usr = "s:Loop"}),
                     row({kind = "swift-constructor", container = "Loop", name = "init(_:_:)", side = "-",
                          params = "_StringProcessing.RegexRepetitionBehavior?|() -> some _StringProcessing.RegexComponent", type = "-",
                          usr = "s:Loop.init", generic_sig = "<W, C1 where Output == (Swift.Substring, C1)>"})}
    local closure_text = render.render(closure, "RegexBuilder", known, nil, nil, nil)
    check(string.find(closure_text, "_ p1: () -> W)", 1, true) ~= nil or string.find(closure_text, "() -> W", 1, true) ~= nil,
          "a closure parameter whose result is some X names the generic for X")

    local plain = {row({kind = "swift-struct", name = "Box", usr = "s:Box"}),
                   row({kind = "swift-method", container = "Box", name = "put(_:)", side = "+", params = "some Swift.Int", type = "-",
                        usr = "s:Box.put", generic_sig = "<T where T : Swift.Equatable>"})}
    local plain_text = render.render(plain, "Box", known, nil, nil, nil)
    check(string.find(plain_text, "put<T>(_ p0: some Swift.Int)", 1, true) ~= nil, "a some parameter with no constrained generic stays")

    local capture = {row({kind = "swift-struct", name = "Capture", usr = "s:Capture"}),
                     row({kind = "swift-constructor", container = "Capture", name = "init(_:as:)", side = "-",
                          params = "some _StringProcessing.RegexComponent|RegexBuilder.Reference<W>", type = "-",
                          usr = "s:Capture.init", generic_sig = "<W where Output == (Swift.Substring, W)>"})}
    local capture_text = render.render(capture, "RegexBuilder", known, nil, nil, nil)
    check(string.find(capture_text, "where Output == (Swift.Substring, W)", 1, true) ~= nil,
          "a constraint with a parenthesised comma is kept whole")

    local nested = {row({kind = "swift-struct", name = "Nest", usr = "s:Nest"}),
                    row({kind = "swift-method", container = "Nest", name = "take(_:)", side = "+",
                         params = "Swift.Array<some _StringProcessing.RegexComponent>", type = "-", usr = "s:Nest.take",
                         generic_sig = "<W where W : _StringProcessing.RegexComponent>"})}
    local nested_text = render.render(nested, "Nest", known, nil, nil, nil)
    check(string.find(nested_text, "take<W>(_ p0: Swift.Array<some _StringProcessing.RegexComponent>)", 1, true) ~= nil,
          "a some nested in another type stays as it is")

    print("swift some params test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end
