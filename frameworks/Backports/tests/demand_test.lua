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

    local swift = scanner.scan(path.join(data, "sample.swift"))
    expect("swift language", {swift.language}, {"swift"})
    expect("swift imports", keys_of(swift.imports), {"Foundation", "UIKit"})
    expect("swift declared", keys_of(swift.declared), {"Bar"})
    expect("swift declared members", keys_of(swift.declared_members), {"layoutSubviews", "s", "x"})
    expect("swift members", keys_of(swift.members), {"Date", "addSubview", "frame", "zero"})
    expect("swift messages", {tostring(#swift.messages)}, {"0"})
    expect("swift comments do not import", {tostring(has(swift.imports, "Fake"))}, {"false"})
end
