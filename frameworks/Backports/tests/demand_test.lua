local tools = path.absolute(path.join(os.scriptdir(), "..", "tools"))
local scanner = import("demand_scan", {rootdir = tools, anonymous = true})

local function keys_of(list)
    local out = {}
    for _, item in ipairs(list) do
        table.insert(out, item)
    end
    table.sort(out, scanner.bytes_less)
    return out
end

local function has(list, name)
    for _, item in ipairs(list) do
        if item == name then
            return true
        end
    end
    return false
end

local function expect(label, got, want)
    local a, b = table.concat(got, ","), table.concat(want, ",")
    assert(a == b, label .. ": got [" .. a .. "], want [" .. b .. "]")
end

local function message_text(message)
    local receiver = message.class and (message.class .. (message.class_method and "+" or " ")) or "- "
    return receiver .. message.selector
end

function main()
    local data = path.absolute(path.join(os.scriptdir(), "data", "demand"))

    local objc = scanner.scan(path.join(data, "sample.m"))
    expect("objc language", {objc.language}, {"objc"})
    expect("objc imports", keys_of(objc.imports), {"UIKit"})
    expect("objc declared", keys_of(objc.declared), {"Foo"})
    expect("objc declared members", keys_of(objc.declared_members), {"panel"})
    local messages = {}
    for _, message in ipairs(objc.messages) do
        table.insert(messages, message_text(message))
    end
    expect("objc messages", messages, {"UIView initWithFrame:", "UIView+alloc", "- setBackgroundColor:", "UIColor+redColor",
        "- addSubview:", "NSString+stringWithFormat:", "- addObserver:selector:name:object:",
        "NSNotificationCenter+defaultCenter", "- tag", "- run:", "Foo init", "Foo+alloc", "Foo init", "Foo+alloc"})
    expect("objc selectors", objc.selectors, {"viewDidLoad", "foo:bar:"})
    expect("objc calls", keys_of(objc.calls), {"CGRectMake", "property", "selector"})
    expect("objc words UIView", {tostring(has(objc.words, "UIView"))}, {"true"})
    expect("objc words UILabel from a comment", {tostring(has(objc.words, "UILabel"))}, {"false"})
    expect("objc words UIView from a string", {tostring(has(objc.words, "comment"))}, {"false"})

    local c = scanner.scan(path.join(data, "sample.c"))
    expect("c language", {c.language}, {"c"})
    expect("c imports", keys_of(c.imports), {"UIKit"})
    expect("c subscripts are not messages", {tostring(#c.messages)}, {"0"})

    local cast = scanner.scan(path.join(data, "sample_cast.m"))
    expect("forward declarations and categories declare nothing", keys_of(cast.declared), {"Row"})
    expect("typed local variable", {tostring(cast.var_types.other)}, {"Row"})
    expect("typed variable names", keys_of(cast.var_names), {"other"})
    expect("import directives are not code", {tostring(has(cast.words, "NSInputStream"))}, {"false"})
    expect("import directives still import", keys_of(cast.imports), {"LegacyComponents"})
    expect("own methods", keys_of(cast.method_declarations), {"contentSize", "layout", "setValue:animated:"})
    local casted = {}
    for _, message in ipairs(cast.messages) do
        table.insert(casted, tostring(message.class) .. " " .. tostring(message.own) .. " " .. message.selector)
    end
    expect("cast and self messages", casted, {"nil true contentSize", "nil true setValue:animated:",
        "nil false setNeedsDisplay", "Row false type", "UIView false setTag:"})

    local enum = scanner.scan(path.join(data, "sample_enum.swift"))
    expect("enum case with values is declared", keys_of(enum.declared), {"System", "Transition"})

    local swift = scanner.scan(path.join(data, "sample.swift"))
    expect("swift language", {swift.language}, {"swift"})
    expect("swift imports", keys_of(swift.imports), {"Foundation", "UIKit"})
    expect("swift declared", keys_of(swift.declared), {"Bar"})
    expect("swift declared members", keys_of(swift.declared_members), {"layoutSubviews", "s", "x"})
    expect("swift members", keys_of(swift.members), {"addSubview", "frame", "zero"})
    expect("swift import statements are not code", {tostring(has(swift.words, "Date"))}, {"false"})
    expect("swift import statements still import", keys_of(swift.imports), {"Foundation", "UIKit"})
    expect("swift messages", {tostring(#swift.messages)}, {"0"})
    expect("swift comments do not import", {tostring(has(swift.imports, "Fake"))}, {"false"})

    local directives = scanner.scan(path.join(data, "sample_directives.m"))
    expect("the app declares its methods", keys_of(directives.method_declarations), {"copy:", "shade"})
    expect("pragma and warning text is not code", {tostring(has(directives.words, "Handle")),
        tostring(has(directives.words, "Platform"))}, {"false", "false"})
    expect("a call on the app's own method is a message", {tostring(#directives.messages >= 1)}, {"true"})
end
