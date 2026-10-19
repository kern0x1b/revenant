-- gyb.lua - renders the Spatial templates (packages/s/swift-runtime/files/Spatial/*.gyb) the way Swift's gyb.py does, in Lua.
-- `xmake l gyb.lua [-DNAME=VALUE]... [--line-directive X] -o OUT TEMPLATE`
--
-- It implements the subset of gyb those templates use and refuses anything else, so a template that starts using a
-- directive this file does not know is an error, not a silently wrong render:
--   % for a, b, ... in <literal>:   a loop over a Python list or tuple literal of strings, tuples and lists
--   % name = lambda p: <expression>  a one-argument function, called as ${name("x")}
--   % end                             closes the loop
--   ${<expression>}                  an expression: strings, names, calls, `+`, `==`/`!=`, and `A if C else B`
-- A line that is not a directive is copied with its ${...} substituted; the directive lines themselves are dropped.
-- `$` not followed by `{` (as in Swift's `$0`) is copied as it is.

local function fail(message)
    io.stderr:write("gyb.lua: " .. message .. "\n")
    os.exit(1)
end

-- Tokens: strings ("..." or '...'), names and numbers, and the operators the expressions use.
local function tokenize(text)
    local tokens, i = {}, 1
    while i <= #text do
        local c = text:sub(i, i)
        if c:match("%s") then
            i = i + 1
        elseif c == '"' or c == "'" then
            local close = text:find(c, i + 1, true)
            if not close then fail("unterminated string in " .. text) end
            table.insert(tokens, {kind = "string", value = text:sub(i + 1, close - 1)})
            i = close + 1
        elseif c:match("[%a_]") then
            local word = text:match("^[%w_]+", i)
            table.insert(tokens, {kind = "name", value = word})
            i = i + #word
        elseif text:sub(i, i + 1) == "==" or text:sub(i, i + 1) == "!=" then
            table.insert(tokens, {kind = "op", value = text:sub(i, i + 1)})
            i = i + 2
        elseif c:match("[%(%)%[%],:+]") then
            table.insert(tokens, {kind = "op", value = c})
            i = i + 1
        else
            fail("unsupported character " .. c .. " in " .. text)
        end
    end
    table.insert(tokens, {kind = "end"})
    return tokens
end

-- A cursor over tokens with the operations the grammar needs.
local function cursor(tokens)
    local at = 1
    local c = {}
    function c.peek() return tokens[at] end
    function c.take()
        local token = tokens[at]
        at = at + 1
        return token
    end
    function c.is(kind, value)
        local token = tokens[at]
        return token.kind == kind and (value == nil or token.value == value)
    end
    function c.expect(kind, value)
        if not c.is(kind, value) then
            fail("expected " .. (value or kind) .. " at token " .. at)
        end
        return c.take()
    end
    return c
end

local evaluate

-- A literal: a string, a tuple "(...)" or a list "[...]" of literals, with trailing commas allowed.
local function literal(c)
    if c.is("string") then return c.take().value end
    local close
    if c.is("op", "(") then close = ")" elseif c.is("op", "[") then close = "]" else fail("expected a literal") end
    c.take()
    local items = {}
    while not c.is("op", close) do
        table.insert(items, literal(c))
        if c.is("op", ",") then c.take() end
    end
    c.take()
    items.kind = close == ")" and "tuple" or "list"
    return items
end

-- The expression grammar: cond := concat [ "if" compare "else" cond ]; compare := concat [ ("=="|"!=") concat ];
-- concat := primary { "+" primary }; primary := string | name [ "(" args ")" ] | "(" cond ")".
local function primary(c, env)
    if c.is("string") then return c.take().value end
    if c.is("op", "(") then
        c.take()
        local value = evaluate(c, env)
        c.expect("op", ")")
        return value
    end
    local name = c.expect("name").value
    if c.is("op", "(") then
        c.take()
        local args = {}
        while not c.is("op", ")") do
            table.insert(args, evaluate(c, env))
            if c.is("op", ",") then c.take() end
        end
        c.take()
        local fn = env[name]
        if type(fn) ~= "table" or fn.kind ~= "lambda" then fail("call of " .. name .. ", which is not a lambda") end
        local inner = {}
        for key, value in pairs(env) do inner[key] = value end
        inner[fn.param] = args[1]
        return evaluate(cursor(tokenize(fn.body)), inner)
    end
    if env[name] == nil then fail("unbound name " .. name) end
    return env[name]
end

local function concat(c, env)
    local value = primary(c, env)
    while c.is("op", "+") do
        c.take()
        value = value .. primary(c, env)
    end
    return value
end

local function compare(c, env)
    local left = concat(c, env)
    if c.is("op", "==") or c.is("op", "!=") then
        local op = c.take().value
        local right = concat(c, env)
        if op == "==" then return left == right end
        return left ~= right
    end
    return left
end

function evaluate(c, env)
    local value = compare(c, env)
    if c.is("name", "if") then
        c.take()
        local condition = compare(c, env)
        c.expect("name", "else")
        local other = evaluate(c, env)
        if condition then return value end
        return other
    end
    return value
end

local function render_expression(text, env)
    local c = cursor(tokenize(text))
    local value = evaluate(c, env)
    if not c.is("end") then fail("trailing tokens in ${" .. text .. "}") end
    return value
end

local function substitute(line, env)
    return (line:gsub("%${(.-)}", function (expression)
        local value = render_expression(expression, env)
        if type(value) ~= "string" then fail("${" .. expression .. "} is not a string") end
        return value
    end))
end

local function parse_args(argv)
    local defines, output, template, line_directive = {}, nil, nil, nil
    local i = 1
    while i <= #argv do
        local arg = argv[i]
        local define, value = arg:match("^%-D([^=]+)=(.*)$")
        if define then
            defines[define] = value
        elseif arg == "-o" then
            i = i + 1
            output = argv[i]
        elseif arg == "--line-directive" then
            i = i + 1
            line_directive = argv[i]
        elseif arg:sub(1, 1) == "-" then
            fail("unknown option " .. arg)
        else
            template = arg
        end
        i = i + 1
    end
    if not output or not template then fail("usage: gyb.lua [-DNAME=VALUE] [--line-directive X] -o OUT TEMPLATE") end
    return defines, output, template
end

function main(...)
    local defines, output, template = parse_args({...})
    local env = {}
    for name, value in pairs(defines) do env[name] = value end
    local input = io.open(template, "r")
    if not input then fail("cannot read " .. template) end
    local lines = {}
    for line in input:lines() do table.insert(lines, line) end
    input:close()

    local out = {}
    -- A loop is collected from its header to its `% end`, then run once per item of its list.
    local loop = nil
    local function run_loop()
        for _, item in ipairs(loop.items) do
            local scope = {}
            for key, value in pairs(env) do scope[key] = value end
            for index, name in ipairs(loop.names) do scope[name] = item[index] end
            for _, body in ipairs(loop.body) do
                local lambda_name, param, expression = body:match("^%% *([%w_]+) *= *lambda *([%w_]+) *: *(.-) *$")
                if lambda_name then
                    scope[lambda_name] = {kind = "lambda", param = param, body = expression}
                elseif body:match("^%%") then
                    fail("unsupported directive in a loop: " .. body)
                else
                    table.insert(out, substitute(body, scope))
                end
            end
        end
    end

    for _, line in ipairs(lines) do
        local names_text = line:match("^%% *for (.-) *:%s*$")
        if loop then
            if line:match("^%% *end%s*$") then
                run_loop()
                loop = nil
            elseif line:match("^%%") then
                if not line:match("^%% *[%w_]+ *= *lambda ") then fail("unsupported directive in a loop: " .. line) end
                table.insert(loop.body, line)
            else
                table.insert(loop.body, line)
            end
        elseif names_text then
            local names_list, items_text = names_text:match("^(.-) +in +(.+)$")
            if not names_list then fail("for without in: " .. line) end
            local names = {}
            for name in names_list:gmatch("[%w_]+") do table.insert(names, name) end
            loop = {names = names, items = literal(cursor(tokenize(items_text))), body = {}}
        elseif line:match("^%%") then
            fail("unsupported directive outside a loop: " .. line)
        else
            table.insert(out, substitute(line, env))
        end
    end
    if loop then fail("a for loop without its end") end

    local file = io.open(output, "w")
    if not file then fail("cannot write " .. output) end
    file:write(table.concat(out, "\n"), "\n")
    file:close()
    return 0
end
