local rt = import("runtime", {rootdir = os.scriptdir(), anonymous = true})
local lexer = import("lexer", {rootdir = os.scriptdir(), anonymous = true})
local compiler = import("compiler", {rootdir = os.scriptdir(), anonymous = true})

local None = rt.none()

DEFAULT_LINE_DIRECTIVE = '// ###sourceLocation(file: "%(file)s", line: %(line)d)'

local function count_newlines(s)
    local _, n = s:gsub("\n", "")
    return n
end

local function normalize_newlines(text)
    return (text:gsub("\r\n?", "\n"))
end

local function strip(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function get_line_starts(s)
    local starts = {0}
    local pos = 1
    while true do
        local e = s:find("\n", pos, true)
        local len = (e or #s + 1) - pos
        starts[#starts + 1] = starts[#starts] + len + 1
        if not e then
            break
        end
        pos = e + 1
    end
    starts[#starts] = starts[#starts] - 1
    return starts
end

local function bisect_right(list, x)
    local lo, hi = 1, #list + 1
    while lo < hi do
        local mid = (lo + hi) // 2
        if x < list[mid] then
            hi = mid
        else
            lo = mid + 1
        end
    end
    return lo - 1
end

local function dedent(text)
    local lines = {}
    local pos = 1
    while pos <= #text do
        local e = text:find("\n", pos, true)
        if e then
            lines[#lines + 1] = {body = text:sub(pos, e - 1), nl = "\n"}
            pos = e + 1
        else
            lines[#lines + 1] = {body = text:sub(pos), nl = ""}
            break
        end
    end
    local margin
    for _, line in ipairs(lines) do
        if line.body:find("^[ \t]+$") then
            line.body = ""
        end
        local indent = line.body:match("^([ \t]*)[^ \t\n]")
        if indent then
            if margin == nil then
                margin = indent
            elseif indent:sub(1, #margin) == margin then
            elseif margin:sub(1, #indent) == indent then
                margin = indent
            else
                for i = 1, math.min(#margin, #indent) do
                    if margin:sub(i, i) ~= indent:sub(i, i) then
                        margin = margin:sub(1, i - 1)
                        break
                    end
                end
            end
        end
    end
    local out = {}
    for i, line in ipairs(lines) do
        local body = line.body
        if margin and margin ~= "" and body:sub(1, #margin) == margin then
            body = body:sub(#margin + 1)
        end
        out[i] = body .. line.nl
    end
    return table.concat(out)
end

local function line_end(text, p)
    local e = text:find("\n", p + 1, true)
    if e then
        return e - 1
    end
    return #text
end

local function skip_blanks(text, p)
    local s = text:match("^[ \t]*", p + 1)
    return p + #s
end

local function lines_close_at(text, p)
    local q = skip_blanks(text, p)
    if text:sub(q + 1, q + 3) ~= "end" then
        return false
    end
    q = skip_blanks(text, q + 3)
    local c = text:sub(q + 1, q + 1)
    if c == "#" then
        q = line_end(text, q)
        c = text:sub(q + 1, q + 1)
    end
    return c == "" or c == "\n"
end

local function after_newline(text, p)
    if text:sub(p + 1, p + 1) == "\n" then
        return p + 1
    end
    return p
end

local function literal_text(text, q)
    local n = #text
    while q < n do
        local c = text:sub(q + 1, q + 1)
        if c == "\n" then
            break
        elseif c == "$" then
            local d = text:sub(q + 2, q + 2)
            if d == "$" or d == "{" then
                break
            end
        elseif c == "%" then
            if text:sub(q + 2, q + 2) == "%" then
                break
            end
        end
        q = q + 1
    end
    return q
end

local function match_token(text, p)
    local n = #text
    if p == 0 or text:sub(p, p) == "\n" then
        local q = skip_blanks(text, p)
        if text:sub(q + 1, q + 1) == "%" then
            local d = text:sub(q + 2, q + 2)
            if d ~= "{" and d ~= "%" then
                local r = skip_blanks(text, q + 1)
                if not lines_close_at(text, r) then
                    local indent = text:sub(p + 1, r)
                    local e = line_end(text, r)
                    while text:sub(e + 1, e + 1) == "\n" and text:sub(e + 2, e + 1 + #indent) == indent
                        and not lines_close_at(text, e + 1 + #indent) do
                        e = line_end(text, e + 1 + #indent)
                    end
                    return {kind = "gybLines", text = text:sub(p + 1, e), start = p, group_end = e,
                            indent = indent, finish = after_newline(text, e)}
                end
            end
            if lines_close_at(text, q + 1) then
                local e = line_end(text, q + 1)
                return {kind = "gybLinesClose", text = text:sub(p + 1, e), start = p, group_end = e, finish = after_newline(text, e)}
            end
            if d == "{" then
                local close = text:find("}%", q + 3, true)
                if close then
                    return {kind = "gybBlockOpen", text = "%{", start = q, group_end = q + 2, finish = after_newline(text, close + 1)}
                end
            end
        end
    end
    local c = text:sub(p + 1, p + 1)
    if c == "$" and text:sub(p + 2, p + 2) == "{" then
        local close = text:find("}", p + 3, true)
        if close then
            return {kind = "substitutionOpen", text = "${", start = p, group_end = p + 2, finish = close}
        end
    end
    if (c == "$" or c == "%") and text:sub(p + 2, p + 2) == c then
        return {kind = "symbol", text = c, start = p, group_end = p + 2, finish = p + 2}
    end
    local q = literal_text(text, p)
    while text:sub(q + 1, q + 1) == "\n" do
        local r = skip_blanks(text, q + 1)
        if text:sub(r + 1, r + 1) == "%" and r + 1 < n and text:sub(r + 2, r + 2) ~= "%" then
            break
        end
        q = literal_text(text, q + 1)
    end
    q = after_newline(text, q)
    if q == p then
        raise("gyb: cannot tokenize template text at offset " .. p)
    end
    return {kind = "literal", text = text:sub(p + 1, q), start = p, group_end = q, finish = q}
end

function tokenize_template(text)
    local self = {pos = 0}
    local saved, first, pending = {}, nil, nil
    local n = #text
    local function flush()
        local tok = {kind = "literal", text = table.concat(saved), start = first.kind == "literal" and first.start or -1}
        saved, first = {}, nil
        return tok
    end
    function self.next()
        if pending then
            local m = pending
            pending = nil
            return m
        end
        while self.pos < n do
            local m = match_token(text, self.pos)
            if m.kind == "literal" or m.kind == "symbol" then
                if #saved == 0 then
                    first = m
                end
                saved[#saved + 1] = m.text
                self.pos = m.finish
            else
                self.pos = m.finish
                if #saved > 0 then
                    pending = m
                    return flush()
                end
                return m
            end
        end
        if #saved > 0 then
            return flush()
        end
    end
    function self.send(pos)
        self.pos = pos
    end
    return self
end

local function token_pos_to_index(line, col, start, line_starts)
    local start_line_num = bisect_right(line_starts, start) - 1
    local abs_line = line - 1 + start_line_num
    if line == 1 then
        col = col + start - line_starts[start_line_num + 1]
    end
    if abs_line >= #line_starts then
        return line_starts[#line_starts]
    end
    return line_starts[abs_line + 1] + col
end

local function text_reader(text, start)
    local pos = start + 1
    return function()
        if pos > #text then
            return ""
        end
        local e = text:find("\n", pos, true) or #text
        local line = text:sub(pos, e)
        pos = e + 1
        return line
    end
end

local function tokenize_code_to_unmatched_close_curly(text, start, line_starts)
    local result
    try {
        function()
            local nesting = 0
            lexer.generate_tokens(text_reader(text, start), function(tok)
                if tok.string == "{" then
                    nesting = nesting + 1
                elseif tok.string == "}" then
                    nesting = nesting - 1
                    if nesting < 0 then
                        result = token_pos_to_index(tok.start[1], tok.start[2], start, line_starts)
                        return true
                    end
                end
            end)
        end,
        catch {
            function(e)
                if type(e) == "table" and e.tokenerror then
                    result = token_pos_to_index(e.line, e.col, start, line_starts)
                else
                    raise(e)
                end
            end
        }
    }
    return result or #text
end

function split_gyb_lines(source_lines)
    local last_text, last_kind = nil, nil
    local unmatched = {}
    local dedents = 0
    local failed = false
    try {
        function()
            lexer.generate_tokens(lexer.lines_reader(source_lines), function(tok)
                local kind, text = tok.type, tok.string
                if kind == "COMMENT" or kind == "ENDMARKER" then
                    return
                end
                if text == "\n" and last_text == ":" then
                    unmatched[#unmatched + 1] = tok.finish[1]
                end
                if last_kind == "DEDENT" then
                    dedents = dedents + 1
                end
                if kind ~= "DEDENT" and dedents > 0 then
                    for _ = 1, math.min(dedents, #unmatched) do
                        unmatched[#unmatched] = nil
                    end
                    dedents = 0
                end
                last_text, last_kind = text, kind
            end)
        end,
        catch {
            function(e)
                if type(e) == "table" and e.tokenerror then
                    failed = true
                else
                    raise(e)
                end
            end
        }
    }
    if failed then
        return {}
    end
    if last_text == ":" then
        unmatched[#unmatched + 1] = #source_lines
    end
    return unmatched
end

local DEDENT_KEYWORDS = {["else"] = true, elif = true, except = true, finally = true}

function code_starts_with_dedent_keyword(source_lines)
    local token_text
    lexer.generate_tokens(lexer.lines_reader(source_lines), function(tok)
        token_text = tok.string
        if tok.type ~= "COMMENT" and strip(tok.string) ~= "" then
            return true
        end
    end)
    return DEDENT_KEYWORDS[token_text] == true
end

local function join_lines(lines, first, last)
    last = math.min(last, #lines)
    if last < first then
        return ""
    end
    return table.concat(lines, "", first, last)
end

local function pos_to_line(ctx, pos)
    return bisect_right(ctx.line_starts, pos) - 1
end

local function token_generator(ctx, base)
    return coroutine.wrap(function()
        while true do
            local tok = base.next()
            if not tok then
                return nil
            end
            ctx.token_kind, ctx.token_text, ctx.token_match = tok.kind, tok.text, tok
            local kind = tok.kind
            ctx.code_text = nil
            ctx.close_lines = kind == "gybLinesClose"
            if kind == "gybBlockOpen" or kind == "substitutionOpen" then
                local code_start = tok.group_end
                ctx.code_start_line = pos_to_line(ctx, code_start)
                local close_pos = tokenize_code_to_unmatched_close_curly(ctx.template, code_start, ctx.line_starts)
                ctx.code_text = ctx.template:sub(code_start + 1, close_pos)
                coroutine.yield(kind)
                local next_pos
                if kind == "gybBlockOpen" then
                    if ctx.template:sub(close_pos + 1, close_pos + 2) ~= "}%" then
                        rt.throw_error("ValueError", "Invalid block closure")
                    end
                    next_pos = after_newline(ctx.template, skip_blanks(ctx.template, close_pos + 2))
                else
                    next_pos = close_pos + 1
                end
                base.send(next_pos)
            elseif kind == "gybLines" then
                ctx.code_start_line = pos_to_line(ctx, tok.start)
                local indentation = tok.indent
                local source_lines = {}
                for _, line in ipairs(lexer.split_keepends(tok.text .. "\n")) do
                    source_lines[#source_lines + 1] = line:sub(#indentation + 1)
                end
                if code_starts_with_dedent_keyword(source_lines) then
                    ctx.close_lines = true
                end
                local last_split = 0
                for _, line in ipairs(split_gyb_lines(source_lines)) do
                    ctx.token_kind = "gybLinesOpen"
                    ctx.code_text = join_lines(source_lines, last_split + 1, line)
                    coroutine.yield(ctx.token_kind)
                    last_split = line
                    ctx.close_lines = false
                end
                ctx.code_text = join_lines(source_lines, last_split + 1, #source_lines)
                if ctx.code_text ~= "" then
                    ctx.token_kind = "gybLines"
                    coroutine.yield(ctx.token_kind)
                end
            else
                coroutine.yield(ctx.token_kind)
            end
        end
    end)
end

local function next_token(ctx)
    if not ctx.finished then
        local kind = ctx.tokens()
        if kind ~= nil then
            return kind
        end
        ctx.finished = true
    end
    ctx.token_kind = nil
end

local new_block

local function as_native(node)
    return rt.new_native("ASTNode", {execute = function(args)
        node.execute(args[1].context)
        return None
    end})
end

local function append_text(context, text, file, line)
    local directive = context.line_directive
    if directive and directive ~= "" then
        if not (context.last_file == file and context.last_line == line) then
            local result = context.result_text
            if #result == 0 or result[#result]:sub(-1) == "\n" then
                local substitutions = rt.new_dict()
                rt.dict_set(substitutions, "file", file)
                rt.dict_set(substitutions, "line", line + 1)
                result[#result + 1] = rt.percent(directive .. "\n", substitutions)
            elseif text:find("\n", 1, true) then
                local i = text:find("\n", 1, true)
                result[#result + 1] = text:sub(1, i)
                append_text(context, text:sub(i + 1), file, line + 1)
                return
            end
        end
    end
    context.result_text[#context.result_text + 1] = text
    context.last_file, context.last_line = file, line + count_newlines(text)
end

local function new_literal(ctx)
    local node = {kind = "literal", text = ctx.token_text, start_line_number = pos_to_line(ctx, ctx.token_match.start), filename = ctx.filename}
    next_token(ctx)
    node.execute = function(context)
        append_text(context, node.text, node.filename, node.start_line_number)
    end
    return node
end

local function result_string(result)
    local k = rt.kind(result)
    if k == "float" then
        return rt.to_repr(result)
    elseif k == "int" or k == "bool" or k == "list" then
        return rt.to_str(result)
    elseif k == "str" then
        return result
    end
    rt.throw_error("TypeError", "sequence item: expected str instance, " .. k .. " found")
end

local function new_code(ctx)
    local children = {}
    local source, source_line_count = "", 0
    local function accumulate_code()
        local n = ctx.code_start_line - source_line_count
        local s = source .. (n > 0 and string.rep("\n", n) or "") .. dedent(ctx.code_text)
        local line_count = ctx.code_start_line + count_newlines(ctx.code_text)
        next_token(ctx)
        return s, line_count
    end
    local mode = "exec"
    if ctx.token_kind:sub(1, 12) == "substitution" then
        mode = "eval"
        source, source_line_count = accumulate_code()
        source = "(" .. strip(source) .. ")"
    else
        while ctx.token_kind == "gybLinesOpen" do
            source, source_line_count = accumulate_code()
            source = source .. string.format("    __children__[%d].execute(__context__)\n", #children)
            source_line_count = source_line_count + 1
            children[#children + 1] = new_block(ctx)
        end
        if ctx.token_kind == "gybLinesClose" then
            next_token(ctx)
        end
    end
    if ctx.token_kind == "gybLines" then
        source, source_line_count = accumulate_code()
    elseif ctx.token_kind == "gybBlockOpen" then
        source, source_line_count = accumulate_code()
    end
    local node = {kind = "code", children = children, filename = ctx.filename, start_line_number = ctx.code_start_line, source = source}
    if mode == "eval" then
        node.code = compiler.compile_eval(source, ctx.filename)
    else
        node.code = compiler.compile_module(source, ctx.filename)
    end
    local natives = {}
    for i, child in ipairs(children) do
        natives[i] = as_native(child)
    end
    local children_list = rt.new_list(natives)
    node.execute = function(context)
        local bindings = context.local_bindings
        local save = bindings.__children__
        if save == nil then
            save = None
        end
        bindings.__children__ = children_list
        bindings.__file__ = node.filename
        local result = node.code(bindings, context.env)
        if bindings.__children__ ~= children_list then
            rt.throw_error("ValueError", "The code is not allowed to mutate __children__")
        end
        bindings.__children__ = save
        if result ~= nil and result ~= None then
            append_text(context, result_string(result), node.filename, node.start_line_number)
        end
    end
    return node
end

new_block = function(ctx)
    local children = {}
    while ctx.token_kind and not ctx.close_lines do
        if ctx.token_kind == "literal" then
            children[#children + 1] = new_literal(ctx)
        else
            children[#children + 1] = new_code(ctx)
        end
    end
    return {kind = "block", children = children, execute = function(context)
        for _, child in ipairs(children) do
            child.execute(context)
        end
    end}
end

function parse_template(filename, text)
    local ctx = {filename = filename, template = text, line_starts = get_line_starts(text), code_start_line = -1, close_lines = false}
    ctx.tokens = token_generator(ctx, tokenize_template(text))
    next_token(ctx)
    return new_block(ctx)
end

local function error_message(e, env)
    local message = rt.exception_message(e)
    if env and env.line then
        return message .. " (line " .. env.line .. ")"
    end
    return message
end

local expand_file

local function gyb_module(opt)
    return function(env)
        local globals = {__name__ = "gyb"}
        globals.expand = function(args, kw)
            local defines, directive = {}, DEFAULT_LINE_DIRECTIVE
            for _, pair in ipairs(kw or {}) do
                if pair[1] == "line_directive" then
                    directive = pair[2]
                else
                    defines[pair[1]] = pair[2]
                end
            end
            return expand_file(args[1], {defines = defines, line_directive = args[2] or directive, paths = opt.paths})
        end
        return {__t = "module", name = "gyb", globals = globals}
    end
end

function execute_template(ast, opt)
    opt = opt or {}
    local env = compiler.new_env({paths = opt.paths or {}, modules = {gyb = gyb_module(opt)}})
    local bindings = {}
    for name, value in pairs(opt.defines or {}) do
        bindings[name] = value
    end
    local directive = opt.line_directive
    if directive == nil then
        directive = DEFAULT_LINE_DIRECTIVE
    end
    local context = {local_bindings = bindings, line_directive = directive, result_text = {}, env = env}
    bindings.__context__ = rt.new_native("ExecutionContext", {line_directive = directive})
    bindings.__context__.context = context
    local ok = true
    local failure
    try {
        function()
            ast.execute(context)
        end,
        catch {
            function(e)
                ok = false
                failure = e
            end
        }
    }
    if not ok then
        raise("gyb: " .. (opt.filename or "template") .. ": " .. error_message(failure, env))
    end
    return table.concat(context.result_text)
end

expand_file = function(filename, opt)
    opt = opt or {}
    local file = path.absolute(filename)
    local text = normalize_newlines(io.readfile(file))
    local ast = parse_template(file, text)
    local paths = {path.directory(file)}
    for _, dir in ipairs(opt.paths or {}) do
        paths[#paths + 1] = dir
    end
    return execute_template(ast, {defines = opt.defines, line_directive = opt.line_directive, paths = paths, filename = file})
end

function expand(filename, opt)
    return expand_file(filename, opt)
end

function expand_to(filename, output, opt)
    io.writefile(output, expand_file(filename, opt))
end
