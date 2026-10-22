local tools = path.absolute(path.join(os.scriptdir(), "..", "tools"))
local scanner = import("demand_scan", {rootdir = tools, anonymous = true})

local function keys_of(set)
    local out = {}
    for key in pairs(set) do
        table.insert(out, key)
    end
    table.sort(out)
    return out
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
    expect("objc words UIView", {tostring(objc.words.UIView)}, {"true"})
    expect("objc words UILabel from a comment", {tostring(objc.words.UILabel)}, {"nil"})
    expect("objc words UIView from a string", {tostring(objc.words.comment)}, {"nil"})

    local swift = scanner.scan(path.join(data, "sample.swift"))
    expect("swift language", {swift.language}, {"swift"})
    expect("swift imports", keys_of(swift.imports), {"Foundation", "UIKit"})
    expect("swift declared", keys_of(swift.declared), {"Bar"})
    expect("swift declared members", keys_of(swift.declared_members), {"layoutSubviews", "s", "x"})
    expect("swift members", keys_of(swift.members), {"Date", "addSubview", "frame", "zero"})
    expect("swift messages", {tostring(#swift.messages)}, {"0"})
    expect("swift comments do not import", {tostring(swift.imports.Fake)}, {"nil"})
end
