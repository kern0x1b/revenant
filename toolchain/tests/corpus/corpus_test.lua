local objc = import("objc_text", {rootdir = path.join(os.scriptdir(), "..", "..", "tools", "corpus")})
local declares, declares_keyword, declares_selector = objc.declares, objc.declares_keyword, objc.declares_selector
local directive_names, implementations, c_declares, whole_word = objc.directive_names, objc.implementations, objc.c_declares, objc.whole_word
local json_order = import("json_order", {rootdir = path.join(os.scriptdir(), "..", "..", "tools", "corpus")})
local workspace = import("workspace", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})

local function keys_joined(text)
    return table.concat(json_order.top_level_keys(text), "\1")
end

local function raised(f)
    local caught = false
    try {
        function ()
            f()
        end,
        catch {
            function ()
                caught = true
            end
        }
    }
    return caught
end

local CASES = {
    {"declares: a declaration ending in a semicolon", function ()
        return declares("- (BOOL)isFoo;\n", "isFoo") == true end},
    {"declares: a longer selector is not the shorter one", function ()
        return declares("- (BOOL)isFooBar;", "isFoo") == false end},
    {"declares: a definition with its brace on the line", function ()
        return declares("-(BOOL)isFoo{ return 1; }", "isFoo") == true end},
    {"declares: the end of the text ends the declaration", function ()
        return declares("- (void)foo", "foo") == true end},
    {"declares: a C function without a sign is not a method", function ()
        return declares("(void)foo;", "foo") == false end},
    {"declares: a return type with a nested parenthesis is not matched past the close", function ()
        return declares("- (void (^)(int))foo;", "foo") == false end},
    {"declares: a nested parenthesis after the sign still matches", function ()
        return declares("- (void (x)foo;", "foo") == true end},
    {"declares_keyword: a setter with its colon", function ()
        return declares_keyword("- (void)setFoo:(int)x;", "setFoo") == true end},
    {"declares_keyword: no colon, no keyword", function ()
        return declares_keyword("- (int)setFoo;", "setFoo") == false end},
    {"declares_selector: two keywords on one declaration", function ()
        return declares_selector("- (void)foo:(int)a bar:(int)b;", {"foo", "bar"}) == true end},
    {"declares_selector: a statement end between keywords breaks the chain", function ()
        return declares_selector("- (void)foo:(int)a;\n- (void)bar:(int)b;", {"foo", "bar"}) == false end},
    {"directive_names: @dynamic names the selector", function ()
        return directive_names("@dynamic foo;", "@dynamic", "foo") == true end},
    {"directive_names: a longer name is not the selector", function ()
        return directive_names("@dynamic foo2;", "@dynamic", "foo") == false end},
    {"directive_names: a later statement is not the same directive", function ()
        return directive_names("@dynamic bar; @synthesize foo;", "@dynamic", "foo") == false end},
    {"directive_names: @synthesize on the same line", function ()
        return directive_names("@synthesize foo = _foo;", "@synthesize", "foo") == true end},
    {"implementations: the body of one class, its line break kept", function ()
        local impls = implementations("@implementation Foo\n- (void)a;\n@end\n")
        return impls.Foo ~= nil and #impls.Foo == 1 and impls.Foo[1] == "- (void)a;\n" end},
    {"implementations: an empty body", function ()
        local impls = implementations("@implementation Bar\n@end\n")
        return impls.Bar ~= nil and impls.Bar[1] == "" end},
    {"implementations: a category shares the class key", function ()
        local impls = implementations("@implementation Foo (Cat)\n- (int)b;\n@end\n")
        return impls.Foo ~= nil and impls.Foo[1] == "- (int)b;\n" end},
    {"implementations: no @end, no body", function ()
        local impls = implementations("@implementation Baz\n- (void)c;\n")
        local any = false
        for _ in pairs(impls) do any = true end
        return not any end},
    {"c_declares: a C prototype", function ()
        return c_declares("int foo(void);\n", "foo") == true end},
    {"c_declares: an indented statement with an assignment is not a declaration", function ()
        return c_declares("  x = foo(1);", "foo") == false end},
    {"c_declares: a declared variable", function ()
        return c_declares("int foo = 3;", "foo") == true end},
    {"whole_word: the word among other words", function ()
        return whole_word("a foo_bar foo", "foo") == true end},
    {"whole_word: the word only inside an identifier", function ()
        return whole_word("foo_bar", "foo") == false end},
    {"json_order: keys come in text order, not sorted", function ()
        return keys_joined('{"b": [1], "a": [2]}') == "b\1a" end},
    {"json_order: nested objects and arrays add no top-level keys", function ()
        return keys_joined('{"x": [{"k": 1}, [2, {"z": 3}]], "y": {"m": []}}') == "x\1y" end},
    {"json_order: braces, colons and brackets inside a string are text", function ()
        return keys_joined([==[{"a{:[": [1], "}]\"": [2]}]==]) == "a{:[\1}]\"" end},
    {"json_order: escaped quotes and backslashes decode as JSON does", function ()
        return keys_joined([==[{"a\\b": [], "c\"d": []}]==]) == "a\\b\1c\"d" end},
    {"json_order: a top level that is not an object raises", function ()
        return raised(function () json_order.top_level_keys("[1]") end) end},
    {"json_order: a \\u escape raises rather than guessing", function ()
        return raised(function () json_order.top_level_keys("{\"\\u0041\": []}") end) end},
}

function failures(opt)
    local found = {}
    for _, case in ipairs(CASES) do
        local passed = false
        local ok = try {
            function ()
                passed = case[2]()
                return true
            end,
            catch {
                function (err)
                    table.insert(found, case[1] .. ": raised " .. tostring(err))
                end
            }
        }
        if ok and not passed then
            table.insert(found, case[1])
        end
    end
    return found
end

local SUITES = {"registry_files_test", "walk_test", "surface_table_test", "ledger_test", "values_test"}

local function suite_failures()
    local found = {}
    local scratch = workspace.fresh("corpus-test")
    for _, name in ipairs(SUITES) do
        local suite = path.join(os.scriptdir(), name .. ".lua")
        if os.isfile(suite) then
            local log = path.join(scratch, name .. ".log")
            local out = io.open(log, "w")
            local status = os.execv(os.programfile(), {"l", suite}, {stdout = out, stderr = out, try = true})
            out:close()
            local text = (io.readfile(log):gsub("%s+$", ""))
            if status ~= 0 then
                table.insert(found, name .. " (exit " .. tostring(status) .. "): " .. text)
            else
                print(text)
            end
        end
    end
    os.tryrm(scratch)
    return found
end

function main()
    local found = failures({})
    table.join2(found, suite_failures())
    if #found == 0 then
        print(string.format("corpus_test: OK (%d checks)", #CASES))
    else
        for _, line in ipairs(found) do
            print("corpus_test FAIL: " .. line)
        end
        raise("corpus_test: %d failure(s)", #found)
    end
end
