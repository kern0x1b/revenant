-- invented-test.lua: api-invented.lua reports declarations the port invented, and only declarations.
--
-- Run: xmake l bridge/tools/invented-test.lua
--
-- Each case writes a digester dump of a module (the shape swift-api-digester prints) and a surface file of the
-- Apple side, runs the gate on them and compares what it prints with what it must print. Every case has its
-- control: the gate has to keep reporting a declaration that is invented, or a case that passes by the gate saying
-- nothing would pass too.

import("core.base.json")
local text = import("lib.text", {rootdir = path.join(os.scriptdir(), "..", ".."), anonymous = true})

local HERE = os.scriptdir()
local GATE = path.join(HERE, "..", "api-invented.lua")
-- scratch goes under the repository's run folder, never the system temp path
local SCRATCH = path.join(HERE, "..", "..", ".agent-work", "runs", "invented-test")

local function decl(kind, name, decl_kind, children, spi, overriding)
    local node = {kind = kind, name = name, printedName = name, declKind = decl_kind, children = children or {}}
    if overriding then
        -- what it writes for `override func`: the name is the overridden declaration's, in a class this module may not own
        node.overriding = true
        node.declAttributes = {"Override"}
    end
    if spi then
        -- what the digester writes for `@_spi(Probe) public`
        node.declAttributes = {"SPIAccessControl"}
        node.spi_group_names = {"Probe"}
    end
    return node
end

-- a use of a type in a signature: no declKind, no usr, a printed name qualified by its module
local function reference(name, printed)
    return {kind = "TypeNameAlias", name = name, printedName = printed}
end

local function dump(members, extra)
    local children = {decl("TypeDecl", "Widget", "Struct", members)}
    for _, node in ipairs(extra or {}) do
        children[#children + 1] = node
    end
    return {ABIRoot = {kind = "Root", name = "SwiftUI", printedName = "SwiftUI", children = children}}
end

-- runs the gate on a module and a surface; returns the exit code and the names it reported
local function run(module, surface)
    os.mkdir(SCRATCH)
    local ours = path.join(SCRATCH, "ours.json")
    local apple = path.join(SCRATCH, "apple.tsv")
    io.writefile(ours, json.encode(module))
    io.writefile(apple, surface)
    -- the gate's own exit status is printed after its output, because a failing gate makes os.iorunv raise
    local out = os.iorunv("/bin/sh", {"-c", 'xmake l "$1" "$2"; echo "exit=$?"', "sh", GATE, ours},
        {envs = {APPLE_26_SURFACE = apple}})
    local names, code = {}, nil
    for line in string.gmatch(out, "[^\n]+") do
        local status = string.match(line, "^exit=(%d+)$")
        if status then
            code = tonumber(status)
        elseif text.strip(line) ~= "" then
            local last = nil
            for word in string.gmatch(line, "%S+") do
                last = word
            end
            names[#names + 1] = last
        end
    end
    return code, names
end

local function same(a, b)
    if #a ~= #b then
        return false
    end
    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

local function sorted_copy(list)
    local copy = {}
    for i, v in ipairs(list) do
        copy[i] = v
    end
    table.sort(copy)
    return copy
end

local function subset(part, whole)
    for _, want in ipairs(part) do
        if not text.contains(whole, want) then
            return false
        end
    end
    return true
end

-- a control asks only that the declaration is still reported; the others ask for exactly what is
local function case(name, module, surface, want, control)
    local code, names = run(module, surface)
    local ok
    if control then
        ok = code == 0 and subset(want, names)
    else
        ok = code == 0 and same(sorted_copy(names), sorted_copy(want))
    end
    local detail = ""
    if not ok then
        detail = ": exit " .. tostring(code) .. ", reported " .. text.join(",", names) .. ", wanted " .. text.join(",", want)
    end
    print((ok and "ok   " or "FAIL ") .. name .. detail)
    return ok
end

function main()
    local surface = "\tWidget\t\ttype\nWidget\tknown\t\tvar.var\n"
    local good = {}
    good[#good + 1] = case("control: a member Apple does not declare is reported",
        dump({decl("Var", "invention", "Var")}), surface, {"invention"}, true)
    good[#good + 1] = case("control: a typealias Apple does not declare is reported",
        dump({decl("TypeAlias", "InventedAlias", "TypeAlias")}), surface, {"InventedAlias"}, true)
    good[#good + 1] = case("a use of Swift.Void in a signature is a reference, not a declaration",
        dump({decl("Function", "known(action:)", "Func", {reference("Void", "Swift.Void")})}), surface, {})
    good[#good + 1] = case("a use of a nested alias in a signature is a reference, not a declaration",
        dump({decl("Function", "known(style:)", "Func", {reference("Configuration", "Self.Configuration")})}), surface, {})
    good[#good + 1] = case("the module root is not a declaration of the module", dump({}), surface, {})
    -- the surface is read from the source text, where a member named for a keyword is written in backticks; the dump
    -- writes the same member without them
    local keyword = "Widget\t`default`\t\tvar.let\nWidget\t`repeat`\t\tvar.var\n"
    good[#good + 1] = case("a member named for a keyword matches the one the surface writes in backticks",
        dump({decl("Var", "default", "Var"), decl("Var", "repeat", "Var")}), surface .. keyword, {})
    good[#good + 1] = case("control: a keyword-named member the surface lacks is still reported",
        dump({decl("Var", "default", "Var")}), surface, {"default"}, true)
    -- SPI: public to a client that imports its group by name, and to no other, so not part of the API
    good[#good + 1] = case("an @_spi member is not public API", dump({decl("Var", "hook", "Var", nil, true)}), surface, {})
    good[#good + 1] = case("nor is a member of an @_spi type, whatever it says of itself",
        dump({}, {decl("TypeDecl", "Hidden", "Struct", {decl("Var", "inside", "Var")}, true)}), surface, {})
    -- an override introduces no name: the declaration it overrides does, wherever that is (UIKit's are Objective-C and
    -- in no .swiftinterface)
    good[#good + 1] = case("an override is not an invented name",
        dump({decl("Function", "viewDidLoad()", "Func", nil, false, true)}), surface, {})
    good[#good + 1] = case("control: the same name declared, not overridden, is reported",
        dump({decl("Function", "viewDidLoad()", "Func")}), surface, {"viewDidLoad"}, true)

    local passed = 0
    for _, ok in ipairs(good) do
        if ok then
            passed = passed + 1
        end
    end
    print("\n" .. passed .. "/" .. #good .. " cases")
    if passed ~= #good then
        os.exit(1)
    end
end
