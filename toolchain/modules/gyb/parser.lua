local lexer = import("lexer", {rootdir = os.scriptdir(), anonymous = true})
local bigint = import("bigint", {rootdir = os.scriptdir(), anonymous = true})

local KEYWORDS = {}
for word in ("False None True and as assert async await break class continue def del elif else except finally for from global if import in is lambda nonlocal not or pass raise return try while with yield"):gmatch("%S+") do
    KEYWORDS[word] = true
end

local AUGMENTED = {["+="] = "+", ["-="] = "-", ["*="] = "*", ["/="] = "/", ["//="] = "//", ["%="] = "%", ["**="] = "**",
                   [">>="] = ">>", ["<<="] = "<<", ["&="] = "&", ["|="] = "|", ["^="] = "^", ["@="] = "@"}

local Parser = {}

local function syntax_error(filename, line, message)
    raise({syntaxerror = true, filename = filename, line = line, message = message})
end

function Parser:error(message, tok)
    tok = tok or self:peek()
    syntax_error(self.filename, (tok and tok.start[1] or 0) + self.line_offset, message)
end

function Parser:peek(offset)
    return self.tokens[self.pos + (offset or 0)]
end

function Parser:next()
    local tok = self.tokens[self.pos]
    self.pos = self.pos + 1
    return tok
end

function Parser:is_op(value, offset)
    local tok = self:peek(offset)
    return tok.type == "OP" and tok.string == value
end

function Parser:is_kw(value, offset)
    local tok = self:peek(offset)
    return tok.type == "NAME" and tok.string == value
end

function Parser:accept_op(value)
    if self:is_op(value) then
        return self:next()
    end
end

function Parser:accept_kw(value)
    if self:is_kw(value) then
        return self:next()
    end
end

function Parser:expect_op(value)
    local tok = self:accept_op(value)
    if not tok then
        self:error("expected '" .. value .. "' but found '" .. tostring(self:peek().string) .. "'")
    end
    return tok
end

function Parser:expect_kw(value)
    local tok = self:accept_kw(value)
    if not tok then
        self:error("expected '" .. value .. "'")
    end
    return tok
end

function Parser:expect_type(kind)
    local tok = self:peek()
    if tok.type ~= kind then
        self:error("expected " .. kind .. " but found '" .. tostring(tok.string) .. "'")
    end
    return self:next()
end

function Parser:expect_name()
    local tok = self:peek()
    if tok.type ~= "NAME" or KEYWORDS[tok.string] then
        self:error("expected a name but found '" .. tostring(tok.string) .. "'")
    end
    return self:next().string
end

function Parser:line()
    return self:peek().start[1] + self.line_offset
end

local function node(kind, line, fields)
    fields.k = kind
    fields.line = line
    return fields
end

function Parser:file_input()
    local body = {}
    while self:peek().type ~= "ENDMARKER" do
        if self:peek().type == "NEWLINE" then
            self:next()
        else
            self:statement(body)
        end
    end
    return body
end

function Parser:statement(body)
    local tok = self:peek()
    if tok.type == "INDENT" then
        self:error("unexpected indent")
    end
    if tok.type == "NAME" then
        local word = tok.string
        if word == "if" then
            body[#body + 1] = self:if_stmt()
            return
        elseif word == "for" then
            body[#body + 1] = self:for_stmt()
            return
        elseif word == "while" then
            body[#body + 1] = self:while_stmt()
            return
        elseif word == "def" then
            body[#body + 1] = self:funcdef({})
            return
        elseif word == "class" then
            body[#body + 1] = self:classdef({})
            return
        elseif word == "try" then
            body[#body + 1] = self:try_stmt()
            return
        elseif word == "with" then
            body[#body + 1] = self:with_stmt()
            return
        end
    elseif tok.type == "OP" and tok.string == "@" then
        local decorators = {}
        while self:accept_op("@") do
            decorators[#decorators + 1] = self:test()
            self:expect_type("NEWLINE")
        end
        if self:is_kw("def") then
            body[#body + 1] = self:funcdef(decorators)
        else
            body[#body + 1] = self:classdef(decorators)
        end
        return
    end
    self:simple_stmt(body)
end

function Parser:simple_stmt(body)
    repeat
        body[#body + 1] = self:small_stmt()
        if not self:accept_op(";") then
            break
        end
    until self:peek().type == "NEWLINE" or self:peek().type == "ENDMARKER"
    if self:peek().type ~= "ENDMARKER" then
        self:expect_type("NEWLINE")
    end
end

function Parser:suite()
    if self:peek().type == "NEWLINE" then
        self:next()
        while self:peek().type == "NEWLINE" do
            self:next()
        end
        self:expect_type("INDENT")
        local body = {}
        while self:peek().type ~= "DEDENT" and self:peek().type ~= "ENDMARKER" do
            if self:peek().type == "NEWLINE" then
                self:next()
            else
                self:statement(body)
            end
        end
        self:accept_dedent()
        return body
    end
    local body = {}
    self:simple_stmt(body)
    return body
end

function Parser:accept_dedent()
    if self:peek().type == "DEDENT" then
        self:next()
    end
end

function Parser:if_stmt()
    local line = self:line()
    self:next()
    local test = self:namedexpr_test()
    self:expect_op(":")
    local body = self:suite()
    local orelse = {}
    if self:is_kw("elif") then
        orelse = {self:if_stmt()}
    elseif self:accept_kw("else") then
        self:expect_op(":")
        orelse = self:suite()
    end
    return node("If", line, {test = test, body = body, orelse = orelse})
end

function Parser:for_stmt()
    local line = self:line()
    self:next()
    local target = self:exprlist()
    self:expect_kw("in")
    local iter = self:testlist()
    self:expect_op(":")
    local body = self:suite()
    local orelse = {}
    if self:accept_kw("else") then
        self:expect_op(":")
        orelse = self:suite()
    end
    return node("For", line, {target = target, iter = iter, body = body, orelse = orelse})
end

function Parser:while_stmt()
    local line = self:line()
    self:next()
    local test = self:namedexpr_test()
    self:expect_op(":")
    local body = self:suite()
    local orelse = {}
    if self:accept_kw("else") then
        self:expect_op(":")
        orelse = self:suite()
    end
    return node("While", line, {test = test, body = body, orelse = orelse})
end

function Parser:try_stmt()
    local line = self:line()
    self:next()
    self:expect_op(":")
    local body = self:suite()
    local handlers, orelse, finalbody = {}, {}, {}
    while self:is_kw("except") do
        local hline = self:line()
        self:next()
        local kind, name
        if not self:is_op(":") then
            kind = self:test()
            if self:accept_kw("as") then
                name = self:expect_name()
            end
        end
        self:expect_op(":")
        handlers[#handlers + 1] = {type = kind, name = name, body = self:suite(), line = hline}
    end
    if self:accept_kw("else") then
        self:expect_op(":")
        orelse = self:suite()
    end
    if self:accept_kw("finally") then
        self:expect_op(":")
        finalbody = self:suite()
    end
    return node("Try", line, {body = body, handlers = handlers, orelse = orelse, finalbody = finalbody})
end

function Parser:with_stmt()
    local line = self:line()
    self:next()
    local items = {}
    repeat
        local context = self:test()
        local target
        if self:accept_kw("as") then
            target = self:expr()
        end
        items[#items + 1] = {context = context, target = target}
    until not self:accept_op(",")
    self:expect_op(":")
    return node("With", line, {items = items, body = self:suite()})
end

function Parser:parameters(closing, annotations)
    local args = {params = {}, kwonly = {}, vararg = nil, kwarg = nil}
    local seen_star = false
    local seen_default = false
    while not self:is_op(closing) do
        if self:accept_op("**") then
            args.kwarg = self:expect_name()
            if annotations and self:accept_op(":") then
                self:test()
            end
        elseif self:accept_op("*") then
            seen_star = true
            if not self:is_op(",") and not self:is_op(closing) then
                args.vararg = self:expect_name()
                if annotations and self:accept_op(":") then
                    self:test()
                end
            end
        elseif self:accept_op("/") then
        else
            local name = self:expect_name()
            if annotations and self:accept_op(":") then
                self:test()
            end
            local default
            if self:accept_op("=") then
                default = self:test()
                seen_default = true
            elseif seen_default and not seen_star then
                self:error("non-default argument follows default argument")
            end
            if seen_star then
                args.kwonly[#args.kwonly + 1] = {name = name, default = default}
            else
                args.params[#args.params + 1] = {name = name, default = default}
            end
        end
        if not self:accept_op(",") then
            break
        end
    end
    return args
end

function Parser:funcdef(decorators)
    local line = self:line()
    self:expect_kw("def")
    local name = self:expect_name()
    self:expect_op("(")
    local args = self:parameters(")", true)
    self:expect_op(")")
    if self:accept_op("->") then
        self:test()
    end
    self:expect_op(":")
    local body = self:suite()
    return node("FunctionDef", line, {name = name, args = args, body = body, decorators = decorators})
end

function Parser:classdef(decorators)
    local line = self:line()
    self:expect_kw("class")
    local name = self:expect_name()
    local bases, keywords = {}, {}
    if self:accept_op("(") then
        if not self:is_op(")") then
            bases, keywords = self:arglist(")")
        end
        self:expect_op(")")
    end
    self:expect_op(":")
    local body = self:suite()
    return node("ClassDef", line, {name = name, bases = bases, body = body, decorators = decorators})
end

function Parser:dotted_name()
    local parts = {self:expect_name()}
    while self:accept_op(".") do
        parts[#parts + 1] = self:expect_name()
    end
    return table.concat(parts, ".")
end

function Parser:small_stmt()
    local tok = self:peek()
    local line = self:line()
    if tok.type == "NAME" then
        local word = tok.string
        if word == "pass" then
            self:next()
            return node("Pass", line, {})
        elseif word == "break" then
            self:next()
            return node("Break", line, {})
        elseif word == "continue" then
            self:next()
            return node("Continue", line, {})
        elseif word == "return" then
            self:next()
            local value
            if not self:at_statement_end() then
                value = self:testlist_star_expr()
            end
            return node("Return", line, {value = value})
        elseif word == "raise" then
            self:next()
            local exc, cause
            if not self:at_statement_end() then
                exc = self:test()
                if self:accept_kw("from") then
                    cause = self:test()
                end
            end
            return node("Raise", line, {exc = exc, cause = cause})
        elseif word == "global" or word == "nonlocal" then
            self:next()
            local names = {self:expect_name()}
            while self:accept_op(",") do
                names[#names + 1] = self:expect_name()
            end
            return node(word == "global" and "Global" or "Nonlocal", line, {names = names})
        elseif word == "del" then
            self:next()
            return node("Delete", line, {targets = self:exprlist()})
        elseif word == "assert" then
            self:next()
            local test = self:test()
            local msg
            if self:accept_op(",") then
                msg = self:test()
            end
            return node("Assert", line, {test = test, msg = msg})
        elseif word == "import" then
            self:next()
            local names = {}
            repeat
                local name = self:dotted_name()
                local asname
                if self:accept_kw("as") then
                    asname = self:expect_name()
                end
                names[#names + 1] = {name = name, asname = asname}
            until not self:accept_op(",")
            return node("Import", line, {names = names})
        elseif word == "from" then
            self:next()
            local level = 0
            while self:is_op(".") or self:is_op("...") do
                level = level + #self:next().string
            end
            local module
            if not self:is_kw("import") then
                module = self:dotted_name()
            end
            self:expect_kw("import")
            local names = {}
            if self:accept_op("*") then
                names = "*"
            else
                local paren = self:accept_op("(")
                repeat
                    if paren and self:is_op(")") then
                        break
                    end
                    local name = self:expect_name()
                    local asname
                    if self:accept_kw("as") then
                        asname = self:expect_name()
                    end
                    names[#names + 1] = {name = name, asname = asname}
                until not self:accept_op(",")
                if paren then
                    self:expect_op(")")
                end
            end
            return node("ImportFrom", line, {module = module, names = names, level = level})
        end
    end
    return self:expr_stmt()
end

function Parser:at_statement_end()
    local tok = self:peek()
    return tok.type == "NEWLINE" or tok.type == "ENDMARKER" or (tok.type == "OP" and tok.string == ";")
end

function Parser:expr_stmt()
    local line = self:line()
    local first = self:is_kw("yield") and self:yield_expr() or self:testlist_star_expr()
    local tok = self:peek()
    if tok.type == "OP" and AUGMENTED[tok.string] then
        self:next()
        local value = self:is_kw("yield") and self:yield_expr() or self:testlist()
        return node("AugAssign", line, {target = first, op = AUGMENTED[tok.string], value = value})
    end
    if tok.type == "OP" and tok.string == ":" then
        self:next()
        self:test()
        if self:accept_op("=") then
            return node("Assign", line, {targets = {first}, value = self:testlist_star_expr()})
        end
        return node("Pass", line, {})
    end
    if self:is_op("=") then
        local targets = {first}
        local value
        while self:accept_op("=") do
            value = self:is_kw("yield") and self:yield_expr() or self:testlist_star_expr()
            targets[#targets + 1] = value
        end
        targets[#targets] = nil
        return node("Assign", line, {targets = targets, value = value})
    end
    return node("Expr", line, {value = first})
end

function Parser:yield_expr()
    local line = self:line()
    self:expect_kw("yield")
    if self:accept_kw("from") then
        return node("YieldFrom", line, {value = self:test()})
    end
    local value
    if not self:at_statement_end() and not self:is_op(")") and not self:is_op("=") then
        value = self:testlist_star_expr()
    end
    return node("Yield", line, {value = value})
end

function Parser:starts_expression()
    local tok = self:peek()
    if tok.type == "NAME" then
        return not KEYWORDS[tok.string] or tok.string == "None" or tok.string == "True" or tok.string == "False"
            or tok.string == "not" or tok.string == "lambda" or tok.string == "await"
    end
    if tok.type == "NUMBER" or tok.type == "STRING" then
        return true
    end
    if tok.type == "OP" then
        local s = tok.string
        return s == "(" or s == "[" or s == "{" or s == "-" or s == "+" or s == "~" or s == "*" or s == "..."
    end
    return false
end

function Parser:testlist_star_expr()
    local line = self:line()
    local first = self:star_or_test()
    if not self:is_op(",") then
        return first
    end
    local elts = {first}
    while self:accept_op(",") do
        if not self:starts_expression() then
            break
        end
        elts[#elts + 1] = self:star_or_test()
    end
    return node("Tuple", line, {elts = elts})
end

function Parser:star_or_test()
    if self:is_op("*") then
        local line = self:line()
        self:next()
        return node("Starred", line, {value = self:expr()})
    end
    return self:test()
end

function Parser:testlist()
    local line = self:line()
    local first = self:test()
    if not self:is_op(",") then
        return first
    end
    local elts = {first}
    while self:accept_op(",") do
        if not self:starts_expression() then
            break
        end
        elts[#elts + 1] = self:test()
    end
    return node("Tuple", line, {elts = elts})
end

function Parser:exprlist()
    local line = self:line()
    local first = self:star_or_expr()
    if not self:is_op(",") then
        return first
    end
    local elts = {first}
    while self:accept_op(",") do
        if not self:starts_expression() then
            break
        end
        elts[#elts + 1] = self:star_or_expr()
    end
    return node("Tuple", line, {elts = elts})
end

function Parser:star_or_expr()
    if self:is_op("*") then
        local line = self:line()
        self:next()
        return node("Starred", line, {value = self:expr()})
    end
    return self:expr()
end

function Parser:namedexpr_test()
    local line = self:line()
    local value = self:test()
    if self:accept_op(":=") then
        return node("NamedExpr", line, {target = value, value = self:test()})
    end
    return value
end

function Parser:test()
    if self:is_kw("lambda") then
        return self:lambdef(false)
    end
    local line = self:line()
    local body = self:or_test()
    if self:is_kw("if") then
        self:next()
        local test = self:or_test()
        self:expect_kw("else")
        local orelse = self:test()
        return node("IfExp", line, {test = test, body = body, orelse = orelse})
    end
    return body
end

function Parser:test_nocond()
    if self:is_kw("lambda") then
        return self:lambdef(true)
    end
    return self:or_test()
end

function Parser:lambdef(nocond)
    local line = self:line()
    self:expect_kw("lambda")
    local args = self:parameters(":", false)
    self:expect_op(":")
    local body = nocond and self:test_nocond() or self:test()
    return node("Lambda", line, {args = args, body = body})
end

function Parser:or_test()
    local line = self:line()
    local first = self:and_test()
    if not self:is_kw("or") then
        return first
    end
    local values = {first}
    while self:accept_kw("or") do
        values[#values + 1] = self:and_test()
    end
    return node("BoolOp", line, {op = "or", values = values})
end

function Parser:and_test()
    local line = self:line()
    local first = self:not_test()
    if not self:is_kw("and") then
        return first
    end
    local values = {first}
    while self:accept_kw("and") do
        values[#values + 1] = self:not_test()
    end
    return node("BoolOp", line, {op = "and", values = values})
end

function Parser:not_test()
    if self:is_kw("not") then
        local line = self:line()
        self:next()
        return node("UnaryOp", line, {op = "not", operand = self:not_test()})
    end
    return self:comparison()
end

function Parser:comp_op()
    local tok = self:peek()
    if tok.type == "OP" then
        local s = tok.string
        if s == "<" or s == ">" or s == "==" or s == ">=" or s == "<=" or s == "!=" then
            self:next()
            return s
        end
    elseif tok.type == "NAME" then
        if tok.string == "in" then
            self:next()
            return "in"
        elseif tok.string == "not" and self:is_kw("in", 1) then
            self:next()
            self:next()
            return "not in"
        elseif tok.string == "is" then
            self:next()
            if self:accept_kw("not") then
                return "is not"
            end
            return "is"
        end
    end
end

function Parser:comparison()
    local line = self:line()
    local left = self:expr()
    local ops, comparators = {}, {}
    while true do
        local op = self:comp_op()
        if not op then
            break
        end
        ops[#ops + 1] = op
        comparators[#comparators + 1] = self:expr()
    end
    if #ops == 0 then
        return left
    end
    return node("Compare", line, {left = left, ops = ops, comparators = comparators})
end

function Parser:binary(next_level, operators)
    local line = self:line()
    local left = next_level(self)
    while true do
        local tok = self:peek()
        if tok.type == "OP" and operators[tok.string] then
            self:next()
            left = node("BinOp", line, {op = tok.string, left = left, right = next_level(self)})
        else
            return left
        end
    end
end

local OR_OPS, XOR_OPS, AND_OPS = {["|"] = true}, {["^"] = true}, {["&"] = true}
local SHIFT_OPS, ARITH_OPS = {["<<"] = true, [">>"] = true}, {["+"] = true, ["-"] = true}
local TERM_OPS = {["*"] = true, ["/"] = true, ["%"] = true, ["//"] = true, ["@"] = true}

function Parser:expr()
    return self:binary(Parser.xor_expr, OR_OPS)
end

function Parser:xor_expr()
    return self:binary(Parser.and_expr, XOR_OPS)
end

function Parser:and_expr()
    return self:binary(Parser.shift_expr, AND_OPS)
end

function Parser:shift_expr()
    return self:binary(Parser.arith_expr, SHIFT_OPS)
end

function Parser:arith_expr()
    return self:binary(Parser.term, ARITH_OPS)
end

function Parser:term()
    return self:binary(Parser.factor, TERM_OPS)
end

function Parser:factor()
    local tok = self:peek()
    if tok.type == "OP" and (tok.string == "-" or tok.string == "+" or tok.string == "~") then
        local line = self:line()
        self:next()
        return node("UnaryOp", line, {op = tok.string, operand = self:factor()})
    end
    return self:power()
end

function Parser:power()
    local line = self:line()
    local base = self:atom_expr()
    if self:accept_op("**") then
        return node("BinOp", line, {op = "**", left = base, right = self:factor()})
    end
    return base
end

function Parser:atom_expr()
    if self:is_kw("await") then
        self:next()
    end
    local value = self:atom()
    while true do
        local line = self:line()
        if self:accept_op("(") then
            local args, keywords = {}, {}
            if not self:is_op(")") then
                args, keywords = self:arglist(")")
            end
            self:expect_op(")")
            value = node("Call", line, {func = value, args = args, keywords = keywords})
        elseif self:accept_op("[") then
            local index = self:subscriptlist()
            self:expect_op("]")
            value = node("Subscript", line, {value = value, slice = index})
        elseif self:accept_op(".") then
            value = node("Attribute", line, {value = value, attr = self:expect_name()})
        else
            return value
        end
    end
end

function Parser:arglist(closing)
    local args, keywords = {}, {}
    while not self:is_op(closing) do
        local line = self:line()
        if self:accept_op("**") then
            keywords[#keywords + 1] = {name = nil, value = self:test()}
        elseif self:accept_op("*") then
            args[#args + 1] = node("Starred", line, {value = self:test()})
        elseif self:peek().type == "NAME" and self:is_op("=", 1) then
            local name = self:next().string
            self:next()
            keywords[#keywords + 1] = {name = name, value = self:test()}
        else
            local value = self:test()
            if self:is_kw("for") or self:is_kw("async") then
                value = node("GeneratorExp", line, {elt = value, generators = self:comp_for()})
            elseif self:accept_op(":=") then
                value = node("NamedExpr", line, {target = value, value = self:test()})
            end
            args[#args + 1] = value
        end
        if not self:accept_op(",") then
            break
        end
    end
    return args, keywords
end

function Parser:subscriptlist()
    local line = self:line()
    local first = self:subscript()
    if not self:is_op(",") then
        return first
    end
    local elts = {first}
    while self:accept_op(",") do
        if self:is_op("]") then
            break
        end
        elts[#elts + 1] = self:subscript()
    end
    return node("Tuple", line, {elts = elts})
end

function Parser:subscript()
    local line = self:line()
    local lower, upper, step
    if not self:is_op(":") then
        lower = self:test()
        if not self:is_op(":") then
            return lower
        end
    end
    self:expect_op(":")
    if not self:is_op("]") and not self:is_op(":") and not self:is_op(",") then
        upper = self:test()
    end
    if self:accept_op(":") then
        if not self:is_op("]") and not self:is_op(",") then
            step = self:test()
        end
    end
    return node("Slice", line, {lower = lower, upper = upper, step = step})
end

function Parser:comp_for()
    local generators = {}
    while self:is_kw("for") or self:is_kw("async") do
        self:accept_kw("async")
        self:expect_kw("for")
        local target = self:exprlist()
        self:expect_kw("in")
        local iter = self:or_test()
        local ifs = {}
        while self:is_kw("if") do
            self:next()
            ifs[#ifs + 1] = self:test_nocond()
        end
        generators[#generators + 1] = {target = target, iter = iter, ifs = ifs}
    end
    return generators
end

function Parser:atom()
    local tok = self:peek()
    local line = self:line()
    if tok.type == "OP" then
        if tok.string == "(" then
            self:next()
            if self:accept_op(")") then
                return node("Tuple", line, {elts = {}})
            end
            if self:is_kw("yield") then
                local value = self:yield_expr()
                self:expect_op(")")
                return value
            end
            local first = self:namedexpr_or_star()
            if self:is_kw("for") or self:is_kw("async") then
                local generators = self:comp_for()
                self:expect_op(")")
                return node("GeneratorExp", line, {elt = first, generators = generators})
            end
            if self:accept_op(")") then
                return first
            end
            local elts = {first}
            while self:accept_op(",") do
                if self:is_op(")") then
                    break
                end
                elts[#elts + 1] = self:namedexpr_or_star()
            end
            self:expect_op(")")
            return node("Tuple", line, {elts = elts})
        elseif tok.string == "[" then
            self:next()
            if self:accept_op("]") then
                return node("List", line, {elts = {}})
            end
            local first = self:namedexpr_or_star()
            if self:is_kw("for") or self:is_kw("async") then
                local generators = self:comp_for()
                self:expect_op("]")
                return node("ListComp", line, {elt = first, generators = generators})
            end
            local elts = {first}
            while self:accept_op(",") do
                if self:is_op("]") then
                    break
                end
                elts[#elts + 1] = self:namedexpr_or_star()
            end
            self:expect_op("]")
            return node("List", line, {elts = elts})
        elseif tok.string == "{" then
            self:next()
            if self:accept_op("}") then
                return node("Dict", line, {keys = {}, values = {}})
            end
            if self:accept_op("**") then
                local keys, values = {false}, {self:expr()}
                return self:dict_rest(line, keys, values)
            end
            local first = self:star_or_test()
            if self:accept_op(":") then
                local value = self:test()
                if self:is_kw("for") or self:is_kw("async") then
                    local generators = self:comp_for()
                    self:expect_op("}")
                    return node("DictComp", line, {key = first, value = value, generators = generators})
                end
                return self:dict_rest(line, {first}, {value})
            end
            if self:is_kw("for") or self:is_kw("async") then
                local generators = self:comp_for()
                self:expect_op("}")
                return node("SetComp", line, {elt = first, generators = generators})
            end
            local elts = {first}
            while self:accept_op(",") do
                if self:is_op("}") then
                    break
                end
                elts[#elts + 1] = self:star_or_test()
            end
            self:expect_op("}")
            return node("Set", line, {elts = elts})
        elseif tok.string == "..." then
            self:next()
            return node("Const", line, {value = {__t = "ellipsis"}})
        end
    elseif tok.type == "NAME" then
        local word = tok.string
        if word == "None" or word == "True" or word == "False" then
            self:next()
            return node("Const", line, {named = word})
        end
        if KEYWORDS[word] then
            self:error("invalid syntax at '" .. word .. "'")
        end
        self:next()
        return node("Name", line, {id = word})
    elseif tok.type == "NUMBER" then
        self:next()
        return node("Const", line, {value = self:number(tok.string)})
    elseif tok.type == "STRING" then
        local parts = {}
        while self:peek().type == "STRING" do
            local t = self:next()
            parts[#parts + 1] = self:string_literal(t.string, t)
        end
        return self:join_strings(line, parts)
    end
    self:error("invalid syntax at '" .. tostring(tok.string) .. "'")
end

function Parser:namedexpr_or_star()
    if self:is_op("*") then
        return self:star_or_test()
    end
    return self:namedexpr_test()
end

function Parser:dict_rest(line, keys, values)
    while self:accept_op(",") do
        if self:is_op("}") then
            break
        end
        if self:accept_op("**") then
            keys[#keys + 1] = false
            values[#values + 1] = self:expr()
        else
            keys[#keys + 1] = self:test()
            self:expect_op(":")
            values[#values + 1] = self:test()
        end
    end
    self:expect_op("}")
    return node("Dict", line, {keys = keys, values = values})
end

function Parser:number(text)
    local clean = text:gsub("_", "")
    if clean:find("[jJ]$") then
        self:error("imaginary numbers are not supported")
    end
    local lower = clean:lower()
    local base
    if lower:find("^0x") then
        base = 16
    elseif lower:find("^0o") then
        base = 8
    elseif lower:find("^0b") then
        base = 2
    end
    if base then
        return bigint.parse(clean:sub(3), base)
    end
    if clean:find("[%.eE]") then
        return tonumber(clean) + 0.0
    end
    return bigint.parse(clean, 10)
end

local SIMPLE_ESCAPES = {["\\"] = "\\", ["'"] = "'", ['"'] = '"', a = "\a", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t", v = "\v"}

function unescape(body, is_bytes)
    local out = {}
    local i = 1
    local n = #body
    while i <= n do
        local c = body:sub(i, i)
        if c ~= "\\" or i == n then
            local j = body:find("\\", i + 1, true) or n + 1
            if c == "\\" then
                j = n + 1
            end
            out[#out + 1] = body:sub(i, j - 1)
            i = j
        else
            local e = body:sub(i + 1, i + 1)
            if SIMPLE_ESCAPES[e] then
                out[#out + 1] = SIMPLE_ESCAPES[e]
                i = i + 2
            elseif e == "\n" then
                i = i + 2
            elseif e == "\r" then
                i = i + 2
                if body:sub(i, i) == "\n" then
                    i = i + 1
                end
            elseif e:find("[0-7]") then
                local oct = body:match("^[0-7][0-7]?[0-7]?", i + 1)
                local code = tonumber(oct, 8)
                out[#out + 1] = is_bytes and string.char(code % 256) or utf8.char(code)
                i = i + 1 + #oct
            elseif e == "x" then
                local hex = body:match("^%x%x", i + 2)
                if not hex then
                    raise({syntaxerror = true, message = "truncated \\xXX escape"})
                end
                local code = tonumber(hex, 16)
                out[#out + 1] = is_bytes and string.char(code) or utf8.char(code)
                i = i + 4
            elseif (e == "u" or e == "U") and not is_bytes then
                local len = e == "u" and 4 or 8
                local hex = body:sub(i + 2, i + 1 + len)
                if #hex ~= len or not hex:find("^%x+$") then
                    raise({syntaxerror = true, message = "truncated \\" .. e .. " escape"})
                end
                out[#out + 1] = utf8.char(tonumber(hex, 16))
                i = i + 2 + len
            elseif e == "N" and not is_bytes then
                raise({syntaxerror = true, message = "\\N{...} escapes are not supported"})
            else
                out[#out + 1] = "\\" .. e
                i = i + 2
            end
        end
    end
    return table.concat(out)
end

local function split_literal(text)
    local prefix = text:match("^[rRbBuUfF]*")
    local rest = text:sub(#prefix + 1)
    local quote = rest:sub(1, 1)
    local qlen = rest:sub(1, 3) == quote:rep(3) and 3 or 1
    return prefix:lower(), rest:sub(qlen + 1, #rest - qlen)
end

function Parser:string_literal(text, tok)
    local prefix, body = split_literal(text)
    local raw = prefix:find("r") ~= nil
    local is_bytes = prefix:find("b") ~= nil
    if prefix:find("f") then
        return {fstring = self:fstring_parts(body, raw, tok)}
    end
    return {value = raw and body or unescape(body, is_bytes)}
end

local function find_field_end(body, i)
    local depth = 0
    local n = #body
    local quote
    local expr_end, conversion, spec_start
    while i <= n do
        local c = body:sub(i, i)
        if quote then
            if body:sub(i, i + #quote - 1) == quote then
                i = i + #quote
                quote = nil
            else
                i = i + 1
            end
        elseif c == "'" or c == '"' then
            if body:sub(i, i + 2) == c:rep(3) then
                quote = c:rep(3)
                i = i + 3
            else
                quote = c
                i = i + 1
            end
        elseif c == "(" or c == "[" or c == "{" then
            depth = depth + 1
            i = i + 1
        elseif (c == ")" or c == "]" or c == "}") and depth > 0 then
            depth = depth - 1
            i = i + 1
        elseif depth == 0 and c == "!" and body:sub(i + 1, i + 1) ~= "=" then
            return i, "conversion"
        elseif depth == 0 and c == ":" then
            return i, "spec"
        elseif depth == 0 and c == "}" then
            return i, "end"
        else
            i = i + 1
        end
    end
    return nil
end

function Parser:fstring_parts(body, raw, tok)
    local parts = {}
    local literal = {}
    local i = 1
    local n = #body
    local function flush()
        if #literal > 0 then
            local text = table.concat(literal)
            parts[#parts + 1] = {k = "Const", value = raw and text or unescape(text, false)}
            literal = {}
        end
    end
    while i <= n do
        local c = body:sub(i, i)
        if c == "{" and body:sub(i + 1, i + 1) == "{" then
            literal[#literal + 1] = "{"
            i = i + 2
        elseif c == "}" and body:sub(i + 1, i + 1) == "}" then
            literal[#literal + 1] = "}"
            i = i + 2
        elseif c == "{" then
            flush()
            local stop, kind = find_field_end(body, i + 1)
            if not stop then
                self:error("f-string: expecting '}'", tok)
            end
            local expr_text = body:sub(i + 1, stop - 1)
            local field = {k = "FormattedValue", value = parse_expression(expr_text, self.filename, tok.start[1] + self.line_offset)}
            i = stop
            if kind == "conversion" then
                field.conversion = body:sub(i + 1, i + 1)
                i = i + 2
                kind = body:sub(i, i) == ":" and "spec" or "end"
            end
            if kind == "spec" then
                local depth = 0
                local j = i + 1
                while j <= n do
                    local d = body:sub(j, j)
                    if d == "{" then
                        depth = depth + 1
                    elseif d == "}" then
                        if depth == 0 then
                            break
                        end
                        depth = depth - 1
                    end
                    j = j + 1
                end
                field.spec = {k = "JoinedStr", parts = self:fstring_parts(body:sub(i + 1, j - 1), raw, tok)}
                i = j
            end
            if body:sub(i, i) ~= "}" then
                self:error("f-string: expecting '}'", tok)
            end
            parts[#parts + 1] = field
            i = i + 1
        else
            literal[#literal + 1] = c
            i = i + 1
        end
    end
    flush()
    return parts
end

function Parser:join_strings(line, parts)
    local any_f = false
    for _, p in ipairs(parts) do
        if p.fstring then
            any_f = true
        end
    end
    if not any_f then
        local values = {}
        for _, p in ipairs(parts) do
            values[#values + 1] = p.value
        end
        return node("Const", line, {value = table.concat(values)})
    end
    local joined = {}
    for _, p in ipairs(parts) do
        if p.fstring then
            for _, q in ipairs(p.fstring) do
                joined[#joined + 1] = q
            end
        else
            joined[#joined + 1] = {k = "Const", value = p.value}
        end
    end
    return node("JoinedStr", line, {parts = joined})
end

local function new_parser(source, filename, line_offset)
    local tokens = {}
    local ok = true
    lexer.generate_tokens(lexer.lines_reader(lexer.split_keepends(source)), function(tok)
        if tok.type ~= "COMMENT" and tok.type ~= "NL" then
            if tok.type == "ERRORTOKEN" and not tok.string:find("^%s*$") then
                syntax_error(filename, tok.start[1] + (line_offset or 0), "invalid token '" .. tok.string .. "'")
            end
            if tok.type ~= "ERRORTOKEN" then
                tokens[#tokens + 1] = tok
            end
        end
    end)
    local p = {tokens = tokens, pos = 1, filename = filename, line_offset = line_offset or 0}
    for name, fn in pairs(Parser) do
        if type(fn) == "function" then
            p[name] = fn
        end
    end
    return p
end

function parse_module(source, filename)
    local p = new_parser(source, filename, 0)
    return p:file_input()
end

function parse_expression(source, filename, line_offset)
    local stripped = source:gsub("^%s+", "")
    local p = new_parser("(" .. stripped .. "\n)", filename, (line_offset or 1) - 1)
    local value = p:testlist()
    while p:peek().type == "NEWLINE" do
        p:next()
    end
    if p:peek().type ~= "ENDMARKER" then
        p:error("invalid syntax")
    end
    return value
end

function parse_eval(source, filename)
    local p = new_parser(source, filename, 0)
    local value = p:testlist()
    while p:peek().type == "NEWLINE" do
        p:next()
    end
    if p:peek().type ~= "ENDMARKER" then
        p:error("invalid syntax")
    end
    return value
end
