local rt = import("runtime", {rootdir = os.scriptdir(), anonymous = true})
local parser = import("parser", {rootdir = os.scriptdir(), anonymous = true})

local None = rt.none()
local NotImplemented = rt.not_implemented()
local builtins = rt.get_builtins()
local classes = rt.get_classes()
local truth, binop, unop, compare = rt.truth, rt.binop, rt.unop, rt.compare
local getattr, setattr, delattr = rt.get_attribute, rt.setattr, rt.delattr
local getitem, setitem, delitem = rt.getitem, rt.setitem, rt.delitem
local call, throw, kind = rt.call_function, rt.throw_error, rt.kind
local new_list, new_tuple, new_dict, new_set = rt.new_list, rt.new_tuple, rt.new_dict, rt.new_set
local dict_set, iter, to_array = rt.dict_set, rt.iter, rt.to_array

local BREAK, CONTINUE, RETURN = "break", "continue", "return"

local cexpr, compile_body, compile_store, scan_expr, scan_body

local function new_scope(scope_kind, parent)
    return {kind = scope_kind, parent = parent, locals = {}, globals = {}, nonlocals = {}, generator = false}
end

local function function_scope_of(scope)
    local levels = 0
    while scope.kind == "comprehension" do
        scope = scope.parent
        levels = levels + 1
    end
    return scope, levels
end

local function bind_target(scope, target)
    local k = target.k
    if k == "Name" then
        scope.locals[target.id] = true
    elseif k == "Tuple" or k == "List" then
        for _, e in ipairs(target.elts) do
            bind_target(scope, e)
        end
    elseif k == "Starred" then
        bind_target(scope, target.value)
    else
        scan_expr(scope, target)
    end
end

local COMPREHENSIONS = {ListComp = true, SetComp = true, DictComp = true, GeneratorExp = true}

scan_expr = function(scope, e)
    if type(e) ~= "table" or not e.k then
        return
    end
    local k = e.k
    if k == "Lambda" then
        for _, p in ipairs(e.args.params) do
            scan_expr(scope, p.default)
        end
        for _, p in ipairs(e.args.kwonly) do
            scan_expr(scope, p.default)
        end
        return
    elseif COMPREHENSIONS[k] then
        scan_expr(scope, e.generators[1].iter)
        return
    elseif k == "Yield" or k == "YieldFrom" then
        scope.generator = true
    elseif k == "NamedExpr" then
        bind_target((function_scope_of(scope)), e.target)
        scan_expr(scope, e.value)
        return
    end
    for key, v in pairs(e) do
        if key ~= "k" and key ~= "line" and type(v) == "table" then
            if v.k then
                scan_expr(scope, v)
            else
                for _, item in ipairs(v) do
                    if type(item) == "table" then
                        if item.k then
                            scan_expr(scope, item)
                        elseif type(item.value) == "table" then
                            scan_expr(scope, item.value)
                        end
                    end
                end
            end
        end
    end
end

local function scan_stmt(scope, s)
    local k = s.k
    if k == "If" or k == "While" then
        scan_expr(scope, s.test)
        scan_body(scope, s.body)
        scan_body(scope, s.orelse)
    elseif k == "For" then
        bind_target(scope, s.target)
        scan_expr(scope, s.iter)
        scan_body(scope, s.body)
        scan_body(scope, s.orelse)
    elseif k == "Try" then
        scan_body(scope, s.body)
        for _, h in ipairs(s.handlers) do
            scan_expr(scope, h.type)
            if h.name then
                scope.locals[h.name] = true
            end
            scan_body(scope, h.body)
        end
        scan_body(scope, s.orelse)
        scan_body(scope, s.finalbody)
    elseif k == "With" then
        for _, item in ipairs(s.items) do
            scan_expr(scope, item.context)
            if item.target then
                bind_target(scope, item.target)
            end
        end
        scan_body(scope, s.body)
    elseif k == "FunctionDef" or k == "ClassDef" then
        scope.locals[s.name] = true
        for _, d in ipairs(s.decorators) do
            scan_expr(scope, d)
        end
        if k == "FunctionDef" then
            for _, p in ipairs(s.args.params) do
                scan_expr(scope, p.default)
            end
            for _, p in ipairs(s.args.kwonly) do
                scan_expr(scope, p.default)
            end
        else
            for _, b in ipairs(s.bases) do
                scan_expr(scope, b)
            end
        end
    elseif k == "Return" then
        scan_expr(scope, s.value)
    elseif k == "Raise" then
        scan_expr(scope, s.exc)
        scan_expr(scope, s.cause)
    elseif k == "Global" then
        for _, n in ipairs(s.names) do
            scope.globals[n] = true
        end
    elseif k == "Nonlocal" then
        for _, n in ipairs(s.names) do
            scope.nonlocals[n] = true
        end
    elseif k == "Delete" then
        bind_target(scope, s.targets)
    elseif k == "Assert" then
        scan_expr(scope, s.test)
        scan_expr(scope, s.msg)
    elseif k == "Import" then
        for _, a in ipairs(s.names) do
            scope.locals[a.asname or a.name:match("^[^%.]+")] = true
        end
    elseif k == "ImportFrom" then
        if s.names ~= "*" then
            for _, a in ipairs(s.names) do
                scope.locals[a.asname or a.name] = true
            end
        end
    elseif k == "AugAssign" then
        bind_target(scope, s.target)
        scan_expr(scope, s.value)
    elseif k == "Assign" then
        for _, t in ipairs(s.targets) do
            bind_target(scope, t)
        end
        scan_expr(scope, s.value)
    elseif k == "Expr" then
        scan_expr(scope, s.value)
    end
end

scan_body = function(scope, body)
    for _, s in ipairs(body or {}) do
        scan_stmt(scope, s)
    end
end

local function global_lookup(f, name)
    local v = f.globals[name]
    if v == nil then
        v = builtins[name]
        if v == nil then
            throw("NameError", "name '" .. name .. "' is not defined")
        end
    end
    return v
end

local function resolve_outer(scope, name)
    local depth = 0
    local s = scope
    while s.parent do
        s = s.parent
        depth = depth + 1
        if s.kind == "module" then
            return "global"
        end
        if s.kind ~= "class" then
            if s.globals[name] then
                return "global"
            end
            if s.locals[name] and not s.nonlocals[name] then
                return "free", depth
            end
        end
    end
    return "global"
end

local function frame_at(f, depth)
    for _ = 1, depth do
        f = f.parent
    end
    return f
end

local function outer_loader(scope, name)
    local how, depth = resolve_outer(scope, name)
    if how == "global" then
        return function(f)
            return global_lookup(f, name)
        end
    end
    return function(f)
        local v = frame_at(f, depth).vars[name]
        if v == nil then
            throw("NameError", "free variable '" .. name .. "' referenced before assignment in enclosing scope")
        end
        return v
    end
end

local function make_loader(scope, name)
    if scope.kind == "module" then
        return function(f)
            local v = f.vars[name]
            if v == nil then
                v = builtins[name]
                if v == nil then
                    throw("NameError", "name '" .. name .. "' is not defined")
                end
            end
            return v
        end
    end
    if scope.kind == "class" then
        local fallback
        if scope.locals[name] or scope.globals[name] then
            fallback = function(f)
                return global_lookup(f, name)
            end
        else
            fallback = outer_loader(scope, name)
        end
        return function(f)
            local v = f.vars[name]
            if v ~= nil then
                return v
            end
            return fallback(f)
        end
    end
    if scope.globals[name] then
        return function(f)
            return global_lookup(f, name)
        end
    end
    if scope.locals[name] and not scope.nonlocals[name] then
        return function(f)
            local v = f.vars[name]
            if v == nil then
                throw("UnboundLocalError", "local variable '" .. name .. "' referenced before assignment")
            end
            return v
        end
    end
    return outer_loader(scope, name)
end

local function make_storer(scope, name)
    if scope.globals[name] then
        return function(f, v)
            f.globals[name] = v
        end
    end
    if scope.kind ~= "module" and scope.kind ~= "class" and scope.nonlocals[name] then
        local how, depth = resolve_outer(scope, name)
        if how == "global" then
            return function(f, v)
                f.globals[name] = v
            end
        end
        return function(f, v)
            frame_at(f, depth).vars[name] = v
        end
    end
    return function(f, v)
        f.vars[name] = v
    end
end

local function unpack_into(stores, star, value)
    local items = to_array(value)
    local n = #stores
    if not star then
        if #items ~= n then
            if #items > n then
                throw("ValueError", "too many values to unpack (expected " .. n .. ")")
            end
            throw("ValueError", "not enough values to unpack (expected " .. n .. ", got " .. #items .. ")")
        end
        return items
    end
    if #items < n - 1 then
        throw("ValueError", "not enough values to unpack (expected at least " .. (n - 1) .. ", got " .. #items .. ")")
    end
    local out = {}
    for i = 1, star - 1 do
        out[i] = items[i]
    end
    local rest_count = n - star
    local middle = {}
    for i = star, #items - rest_count do
        middle[#middle + 1] = items[i]
    end
    out[star] = new_list(middle)
    for i = 1, rest_count do
        out[star + i] = items[#items - rest_count + i]
    end
    return out
end

compile_store = function(scope, target)
    local k = target.k
    if k == "Name" then
        return make_storer(scope, target.id)
    elseif k == "Tuple" or k == "List" then
        local stores = {}
        local star
        for i, e in ipairs(target.elts) do
            if e.k == "Starred" then
                star = i
                stores[i] = compile_store(scope, e.value)
            else
                stores[i] = compile_store(scope, e)
            end
        end
        return function(f, value)
            local items = unpack_into(stores, star, value)
            for i, store in ipairs(stores) do
                store(f, items[i])
            end
        end
    elseif k == "Attribute" then
        local obj = cexpr(scope, target.value)
        local attr = target.attr
        return function(f, value)
            setattr(obj(f), attr, value)
        end
    elseif k == "Subscript" then
        local obj = cexpr(scope, target.value)
        local key = cexpr(scope, target.slice)
        return function(f, value)
            local o = obj(f)
            setitem(o, key(f), value)
        end
    end
    throw("SyntaxError", "cannot assign to " .. tostring(k))
end

local function compile_delete(scope, target)
    local k = target.k
    if k == "Name" then
        local name = target.id
        local global = scope.kind == "module" or scope.globals[name]
        return function(f)
            local vars = global and f.globals or f.vars
            if vars[name] == nil then
                throw("NameError", "name '" .. name .. "' is not defined")
            end
            vars[name] = nil
        end
    elseif k == "Tuple" or k == "List" then
        local parts = {}
        for i, e in ipairs(target.elts) do
            parts[i] = compile_delete(scope, e)
        end
        return function(f)
            for _, p in ipairs(parts) do
                p(f)
            end
        end
    elseif k == "Attribute" then
        local obj = cexpr(scope, target.value)
        return function(f)
            delattr(obj(f), target.attr)
        end
    elseif k == "Subscript" then
        local obj = cexpr(scope, target.value)
        local key = cexpr(scope, target.slice)
        return function(f)
            local o = obj(f)
            delitem(o, key(f))
        end
    end
    throw("SyntaxError", "cannot delete " .. tostring(k))
end

local function compile_sequence(scope, elts)
    local fns, starred = {}, {}
    local any_star = false
    for i, e in ipairs(elts) do
        if e.k == "Starred" then
            fns[i] = cexpr(scope, e.value)
            starred[i] = true
            any_star = true
        else
            fns[i] = cexpr(scope, e)
        end
    end
    local n = #fns
    if not any_star then
        return function(f)
            local out = {}
            for i = 1, n do
                out[i] = fns[i](f)
            end
            return out
        end
    end
    return function(f)
        local out = {}
        for i = 1, n do
            local v = fns[i](f)
            if starred[i] then
                for item in iter(v) do
                    out[#out + 1] = item
                end
            else
                out[#out + 1] = v
            end
        end
        return out
    end
end

local function compile_call(scope, e)
    local fn = cexpr(scope, e.func)
    local args = compile_sequence(scope, e.args)
    if #e.keywords == 0 then
        return function(f)
            local fv = fn(f)
            return call(fv, args(f), nil)
        end
    end
    local kws = {}
    for i, kw in ipairs(e.keywords) do
        kws[i] = {name = kw.name, value = cexpr(scope, kw.value)}
    end
    return function(f)
        local fv = fn(f)
        local a = args(f)
        local kw = {}
        for _, item in ipairs(kws) do
            local v = item.value(f)
            if item.name then
                kw[#kw + 1] = {item.name, v}
            else
                if kind(v) ~= "dict" then
                    throw("TypeError", "argument after ** must be a mapping")
                end
                for i, key in ipairs(v.keys) do
                    if type(key) ~= "string" then
                        throw("TypeError", "keywords must be strings")
                    end
                    kw[#kw + 1] = {key, v.vals[i]}
                end
            end
        end
        return call(fv, a, kw)
    end
end

local function compile_function(scope, name, args, body_stmts, lambda_body)
    local fscope = new_scope("function", scope)
    for _, p in ipairs(args.params) do
        fscope.locals[p.name] = true
    end
    for _, p in ipairs(args.kwonly) do
        fscope.locals[p.name] = true
    end
    if args.vararg then
        fscope.locals[args.vararg] = true
    end
    if args.kwarg then
        fscope.locals[args.kwarg] = true
    end
    if lambda_body then
        scan_expr(fscope, lambda_body)
    else
        scan_body(fscope, body_stmts)
    end
    local defaults, kwdefaults = {}, {}
    for i, p in ipairs(args.params) do
        if p.default then
            defaults[i] = cexpr(scope, p.default)
        end
    end
    for i, p in ipairs(args.kwonly) do
        if p.default then
            kwdefaults[i] = cexpr(scope, p.default)
        end
    end
    local body
    if lambda_body then
        local ex = cexpr(fscope, lambda_body)
        body = function(fr)
            fr.ret = ex(fr)
            return RETURN
        end
    else
        body = compile_body(fscope, body_stmts)
    end
    local params, kwonly, vararg, kwarg = args.params, args.kwonly, args.vararg, args.kwarg
    local np = #params
    local index, kwindex = {}, {}
    for i, p in ipairs(params) do
        index[p.name] = i
    end
    for i, p in ipairs(kwonly) do
        kwindex[p.name] = i
    end
    local generator = fscope.generator
    local function bind(vars, a, kw, dvals, kwvals)
        local na = #a
        for i = 1, math.min(na, np) do
            vars[params[i].name] = a[i]
        end
        if na > np then
            if not vararg then
                throw("TypeError", name .. "() takes " .. np .. " positional arguments but " .. na .. " were given")
            end
            local extra = {}
            for i = np + 1, na do
                extra[#extra + 1] = a[i]
            end
            vars[vararg] = new_tuple(extra)
        elseif vararg then
            vars[vararg] = new_tuple({})
        end
        local kwdict
        if kwarg then
            kwdict = new_dict()
            vars[kwarg] = kwdict
        end
        if kw then
            for _, pair in ipairs(kw) do
                local key, val = pair[1], pair[2]
                if index[key] then
                    if vars[key] ~= nil then
                        throw("TypeError", name .. "() got multiple values for argument '" .. key .. "'")
                    end
                    vars[key] = val
                elseif kwindex[key] then
                    vars[key] = val
                elseif kwdict then
                    dict_set(kwdict, key, val)
                else
                    throw("TypeError", name .. "() got an unexpected keyword argument '" .. key .. "'")
                end
            end
        end
        for i = 1, np do
            local p = params[i].name
            if vars[p] == nil then
                local d = dvals[i]
                if d == nil then
                    throw("TypeError", name .. "() missing required positional argument: '" .. p .. "'")
                end
                vars[p] = d
            end
        end
        for i, p in ipairs(kwonly) do
            if vars[p.name] == nil then
                local d = kwvals[i]
                if d == nil then
                    throw("TypeError", name .. "() missing required keyword-only argument: '" .. p.name .. "'")
                end
                vars[p.name] = d
            end
        end
    end
    return function(f)
        local dvals, kwvals = {}, {}
        for i, d in pairs(defaults) do
            dvals[i] = d(f)
        end
        for i, d in pairs(kwdefaults) do
            kwvals[i] = d(f)
        end
        local closure, globals, env = f, f.globals, f.env
        local fobj = {__t = "func", name = name, attrs = {}}
        fobj.invoke = function(_, a, kw)
            local fr = {vars = {}, parent = closure, globals = globals, env = env}
            bind(fr.vars, a, kw, dvals, kwvals)
            if generator then
                local co = coroutine.wrap(function()
                    body(fr)
                    return nil
                end)
                local done = false
                return rt.new_iterator(function()
                    if done then
                        return nil
                    end
                    local v = co()
                    if v == nil then
                        done = true
                    end
                    return v
                end)
            end
            if body(fr) == RETURN then
                return fr.ret
            end
            return None
        end
        return fobj
    end
end

local function compile_comprehension(scope, e)
    local cscope = new_scope("comprehension", scope)
    for _, g in ipairs(e.generators) do
        bind_target(cscope, g.target)
    end
    for i, g in ipairs(e.generators) do
        if i > 1 then
            scan_expr(cscope, g.iter)
        end
        for _, c in ipairs(g.ifs) do
            scan_expr(cscope, c)
        end
    end
    scan_expr(cscope, e.elt)
    scan_expr(cscope, e.key)
    scan_expr(cscope, e.value)
    local first_iter = cexpr(scope, e.generators[1].iter)
    local gens = {}
    for i, g in ipairs(e.generators) do
        local ifs = {}
        for j, c in ipairs(g.ifs) do
            ifs[j] = cexpr(cscope, c)
        end
        gens[i] = {store = compile_store(cscope, g.target), iter = i > 1 and cexpr(cscope, g.iter) or nil, ifs = ifs}
    end
    local depth = #gens
    local function loop(cf, level, nextf, emit)
        local g = gens[level]
        for item in nextf do
            g.store(cf, item)
            local ok = true
            for _, c in ipairs(g.ifs) do
                if not truth(c(cf)) then
                    ok = false
                    break
                end
            end
            if ok then
                if level == depth then
                    emit(cf)
                else
                    loop(cf, level + 1, iter(gens[level + 1].iter(cf)), emit)
                end
            end
        end
    end
    local function frame(f)
        return {vars = {}, parent = f, globals = f.globals, env = f.env}
    end
    local k = e.k
    if k == "ListComp" then
        local elt = cexpr(cscope, e.elt)
        return function(f)
            local nextf = iter(first_iter(f))
            local out = {}
            loop(frame(f), 1, nextf, function(cf)
                out[#out + 1] = elt(cf)
            end)
            return new_list(out)
        end
    elseif k == "SetComp" then
        local elt = cexpr(cscope, e.elt)
        return function(f)
            local nextf = iter(first_iter(f))
            local out = new_set()
            loop(frame(f), 1, nextf, function(cf)
                dict_set(out.d, elt(cf), true)
            end)
            return out
        end
    elseif k == "DictComp" then
        local key, value = cexpr(cscope, e.key), cexpr(cscope, e.value)
        return function(f)
            local nextf = iter(first_iter(f))
            local out = new_dict()
            loop(frame(f), 1, nextf, function(cf)
                local kv = key(cf)
                dict_set(out, kv, value(cf))
            end)
            return out
        end
    end
    local elt = cexpr(cscope, e.elt)
    return function(f)
        local nextf = iter(first_iter(f))
        local cf = frame(f)
        local co = coroutine.wrap(function()
            loop(cf, 1, nextf, function(c)
                coroutine.yield(elt(c))
            end)
            return nil
        end)
        local done = false
        return rt.new_iterator(function()
            if done then
                return nil
            end
            local v = co()
            if v == nil then
                done = true
            end
            return v
        end)
    end
end

local function compile_joined(scope, e)
    local parts = {}
    for i, p in ipairs(e.parts) do
        if p.k == "Const" then
            local s = p.value
            parts[i] = function()
                return s
            end
        else
            local value = cexpr(scope, p.value)
            local conversion = p.conversion
            local spec = p.spec and compile_joined(scope, p.spec)
            parts[i] = function(f)
                return rt.format_field(value(f), conversion, spec and spec(f) or "")
            end
        end
    end
    return function(f)
        local out = {}
        for i, p in ipairs(parts) do
            out[i] = p(f)
        end
        return table.concat(out)
    end
end

local CONSTS = {None = None, True = true, False = false}

cexpr = function(scope, e)
    local k = e.k
    if k == "Const" then
        local v
        if e.named then
            v = CONSTS[e.named]
        else
            v = e.value
        end
        return function()
            return v
        end
    elseif k == "Name" then
        return make_loader(scope, e.id)
    elseif k == "Attribute" then
        local obj = cexpr(scope, e.value)
        local attr = e.attr
        return function(f)
            return getattr(obj(f), attr)
        end
    elseif k == "Subscript" then
        local obj = cexpr(scope, e.value)
        local key = cexpr(scope, e.slice)
        return function(f)
            local o = obj(f)
            return getitem(o, key(f))
        end
    elseif k == "Slice" then
        local lower = e.lower and cexpr(scope, e.lower)
        local upper = e.upper and cexpr(scope, e.upper)
        local step = e.step and cexpr(scope, e.step)
        return function(f)
            return rt.new_slice(lower and lower(f) or None, upper and upper(f) or None, step and step(f) or None)
        end
    elseif k == "Call" then
        return compile_call(scope, e)
    elseif k == "BinOp" then
        local left, right, op = cexpr(scope, e.left), cexpr(scope, e.right), e.op
        return function(f)
            local a = left(f)
            return binop(op, a, right(f))
        end
    elseif k == "UnaryOp" then
        local operand, op = cexpr(scope, e.operand), e.op
        if op == "not" then
            return function(f)
                return not truth(operand(f))
            end
        end
        return function(f)
            return unop(op, operand(f))
        end
    elseif k == "BoolOp" then
        local values = {}
        for i, v in ipairs(e.values) do
            values[i] = cexpr(scope, v)
        end
        local n = #values
        if e.op == "and" then
            return function(f)
                local v
                for i = 1, n do
                    v = values[i](f)
                    if not truth(v) then
                        return v
                    end
                end
                return v
            end
        end
        return function(f)
            local v
            for i = 1, n do
                v = values[i](f)
                if truth(v) then
                    return v
                end
            end
            return v
        end
    elseif k == "Compare" then
        local left = cexpr(scope, e.left)
        local ops, comps = e.ops, {}
        for i, c in ipairs(e.comparators) do
            comps[i] = cexpr(scope, c)
        end
        local n = #ops
        if n == 1 then
            local op, right = ops[1], comps[1]
            return function(f)
                local a = left(f)
                return compare(op, a, right(f))
            end
        end
        return function(f)
            local a = left(f)
            for i = 1, n do
                local b = comps[i](f)
                if not compare(ops[i], a, b) then
                    return false
                end
                a = b
            end
            return true
        end
    elseif k == "IfExp" then
        local test, body, orelse = cexpr(scope, e.test), cexpr(scope, e.body), cexpr(scope, e.orelse)
        return function(f)
            if truth(test(f)) then
                return body(f)
            end
            return orelse(f)
        end
    elseif k == "Tuple" then
        local seq = compile_sequence(scope, e.elts)
        return function(f)
            return new_tuple(seq(f))
        end
    elseif k == "List" then
        local seq = compile_sequence(scope, e.elts)
        return function(f)
            return new_list(seq(f))
        end
    elseif k == "Set" then
        local seq = compile_sequence(scope, e.elts)
        return function(f)
            return new_set(seq(f))
        end
    elseif k == "Dict" then
        local keys, values = {}, {}
        for i, key in ipairs(e.keys) do
            keys[i] = key and cexpr(scope, key) or false
            values[i] = cexpr(scope, e.values[i])
        end
        return function(f)
            local d = new_dict()
            for i, key in ipairs(keys) do
                if key then
                    local kv = key(f)
                    dict_set(d, kv, values[i](f))
                else
                    local other = values[i](f)
                    if kind(other) ~= "dict" then
                        throw("TypeError", "'" .. kind(other) .. "' object is not a mapping")
                    end
                    for j, ok in ipairs(other.keys) do
                        dict_set(d, ok, other.vals[j])
                    end
                end
            end
            return d
        end
    elseif COMPREHENSIONS[k] then
        return compile_comprehension(scope, e)
    elseif k == "Lambda" then
        return compile_function(scope, "<lambda>", e.args, nil, e.body)
    elseif k == "JoinedStr" then
        return compile_joined(scope, e)
    elseif k == "Yield" then
        local value = e.value and cexpr(scope, e.value)
        return function(f)
            coroutine.yield(value and value(f) or None)
            return None
        end
    elseif k == "YieldFrom" then
        local value = cexpr(scope, e.value)
        return function(f)
            for item in iter(value(f)) do
                coroutine.yield(item)
            end
            return None
        end
    elseif k == "NamedExpr" then
        local target_scope, levels = function_scope_of(scope)
        local store = compile_store(target_scope, e.target)
        local value = cexpr(scope, e.value)
        return function(f)
            local v = value(f)
            store(frame_at(f, levels), v)
            return v
        end
    elseif k == "Starred" then
        throw("SyntaxError", "can't use starred expression here")
    end
    throw("SyntaxError", "unsupported expression " .. tostring(k))
end

local function inplace(op, a, b)
    local ka = kind(a)
    if ka == "list" then
        if op == "+" then
            for _, v in ipairs(to_array(b)) do
                a[#a + 1] = v
            end
            return a
        elseif op == "*" then
            local items = to_array(a)
            local n = rt.to_integer(b)
            for i = #a, 1, -1 do
                a[i] = nil
            end
            for _ = 1, n do
                for _, v in ipairs(items) do
                    a[#a + 1] = v
                end
            end
            return a
        end
    elseif ka == "dict" and op == "|" then
        for i, key in ipairs(b.keys) do
            dict_set(a, key, b.vals[i])
        end
        return a
    elseif ka == "set" and (op == "|" or op == "&" or op == "-" or op == "^") then
        local r = binop(op, a, b)
        a.d = r.d
        return a
    elseif ka == "object" then
        local names = {["+"] = "__iadd__", ["-"] = "__isub__", ["*"] = "__imul__", ["|"] = "__ior__", ["&"] = "__iand__"}
        local name = names[op]
        local m = name and getattr(a, name, true)
        if m then
            local r = call(m, {b})
            if r ~= NotImplemented then
                return r
            end
        end
    end
    return binop(op, a, b)
end

local function protected(fn)
    local ok, result, err = true, nil, nil
    try {
        function()
            result = fn()
        end,
        catch {
            function(e)
                ok = false
                err = e
            end
        }
    }
    return ok, result, err
end

local function compile_try(scope, s)
    local body = compile_body(scope, s.body)
    local orelse = #s.orelse > 0 and compile_body(scope, s.orelse)
    local finalbody = #s.finalbody > 0 and compile_body(scope, s.finalbody)
    local handlers = {}
    for i, h in ipairs(s.handlers) do
        handlers[i] = {
            type = h.type and cexpr(scope, h.type),
            store = h.name and make_storer(scope, h.name),
            body = compile_body(scope, h.body)
        }
    end
    local function core(f)
        local ok, sig, err = protected(function()
            return body(f)
        end)
        if ok then
            if orelse then
                return orelse(f)
            end
            return sig
        end
        local inst = rt.caught_exception(err)
        for _, h in ipairs(handlers) do
            local matches
            if h.type then
                matches = inst ~= nil and rt.exception_matches(inst, h.type(f))
            else
                matches = true
            end
            if matches then
                if h.store and inst then
                    h.store(f, inst)
                end
                local stack = f.env.exc_stack
                stack[#stack + 1] = inst or err
                local hok, hsig, herr = protected(function()
                    return h.body(f)
                end)
                stack[#stack] = nil
                if not hok then
                    raise(herr)
                end
                return hsig
            end
        end
        raise(err)
    end
    if not finalbody then
        return core
    end
    return function(f)
        local ok, sig, err = protected(function()
            return core(f)
        end)
        local fsig = finalbody(f)
        if fsig then
            return fsig
        end
        if not ok then
            raise(err)
        end
        return sig
    end
end

local function compile_stmt(scope, s)
    local k = s.k
    local line = s.line
    local inner
    if k == "Expr" then
        local value = cexpr(scope, s.value)
        inner = function(f)
            value(f)
        end
    elseif k == "Assign" then
        local value = cexpr(scope, s.value)
        local stores = {}
        for i, t in ipairs(s.targets) do
            stores[i] = compile_store(scope, t)
        end
        if #stores == 1 then
            local store = stores[1]
            inner = function(f)
                store(f, value(f))
            end
        else
            inner = function(f)
                local v = value(f)
                for _, store in ipairs(stores) do
                    store(f, v)
                end
            end
        end
    elseif k == "AugAssign" then
        local op = s.op
        local value = cexpr(scope, s.value)
        local t = s.target
        if t.k == "Name" then
            local load, store = make_loader(scope, t.id), make_storer(scope, t.id)
            inner = function(f)
                local old = load(f)
                store(f, inplace(op, old, value(f)))
            end
        elseif t.k == "Attribute" then
            local obj = cexpr(scope, t.value)
            inner = function(f)
                local o = obj(f)
                local old = getattr(o, t.attr)
                setattr(o, t.attr, inplace(op, old, value(f)))
            end
        elseif t.k == "Subscript" then
            local obj, key = cexpr(scope, t.value), cexpr(scope, t.slice)
            inner = function(f)
                local o = obj(f)
                local kv = key(f)
                local old = getitem(o, kv)
                setitem(o, kv, inplace(op, old, value(f)))
            end
        else
            throw("SyntaxError", "illegal expression for augmented assignment")
        end
    elseif k == "If" then
        local test, body = cexpr(scope, s.test), compile_body(scope, s.body)
        local orelse = #s.orelse > 0 and compile_body(scope, s.orelse)
        inner = function(f)
            if truth(test(f)) then
                return body(f)
            elseif orelse then
                return orelse(f)
            end
        end
    elseif k == "For" then
        local iterable, store = cexpr(scope, s.iter), compile_store(scope, s.target)
        local body = compile_body(scope, s.body)
        local orelse = #s.orelse > 0 and compile_body(scope, s.orelse)
        inner = function(f)
            for item in iter(iterable(f)) do
                store(f, item)
                local sig = body(f)
                if sig == BREAK then
                    return nil
                elseif sig == RETURN then
                    return RETURN
                end
            end
            if orelse then
                return orelse(f)
            end
        end
    elseif k == "While" then
        local test, body = cexpr(scope, s.test), compile_body(scope, s.body)
        local orelse = #s.orelse > 0 and compile_body(scope, s.orelse)
        inner = function(f)
            while truth(test(f)) do
                local sig = body(f)
                if sig == BREAK then
                    return nil
                elseif sig == RETURN then
                    return RETURN
                end
            end
            if orelse then
                return orelse(f)
            end
        end
    elseif k == "Pass" or k == "Global" or k == "Nonlocal" then
        inner = function()
        end
    elseif k == "Break" then
        inner = function()
            return BREAK
        end
    elseif k == "Continue" then
        inner = function()
            return CONTINUE
        end
    elseif k == "Return" then
        local value = s.value and cexpr(scope, s.value)
        inner = function(f)
            f.ret = value and value(f) or None
            return RETURN
        end
    elseif k == "FunctionDef" then
        local make = compile_function(scope, s.name, s.args, s.body, nil)
        local decorators = {}
        for i, d in ipairs(s.decorators) do
            decorators[i] = cexpr(scope, d)
        end
        local store = make_storer(scope, s.name)
        inner = function(f)
            local decs = {}
            for i, d in ipairs(decorators) do
                decs[i] = d(f)
            end
            local fn = make(f)
            for i = #decs, 1, -1 do
                fn = call(decs[i], {fn})
            end
            store(f, fn)
        end
    elseif k == "ClassDef" then
        local cscope = new_scope("class", scope)
        scan_body(cscope, s.body)
        local body = compile_body(cscope, s.body)
        local bases = {}
        for i, b in ipairs(s.bases) do
            bases[i] = cexpr(scope, b)
        end
        local decorators = {}
        for i, d in ipairs(s.decorators) do
            decorators[i] = cexpr(scope, d)
        end
        local store = make_storer(scope, s.name)
        local name = s.name
        inner = function(f)
            local decs = {}
            for i, d in ipairs(decorators) do
                decs[i] = d(f)
            end
            local bvals = {}
            for i, b in ipairs(bases) do
                bvals[i] = b(f)
            end
            if #bvals == 0 then
                bvals[1] = classes.object
            end
            local cf = {vars = {}, parent = f, globals = f.globals, env = f.env}
            cf.vars.__module__ = f.globals.__name__ or "__main__"
            cf.vars.__qualname__ = name
            body(cf)
            local cls = rt.new_class(name, bvals, cf.vars)
            for i = #decs, 1, -1 do
                cls = call(decs[i], {cls})
            end
            store(f, cls)
        end
    elseif k == "Raise" then
        local exc = s.exc and cexpr(scope, s.exc)
        local cause = s.cause and cexpr(scope, s.cause)
        inner = function(f)
            if not exc then
                local stack = f.env.exc_stack
                local current = stack[#stack]
                if current == nil then
                    throw("RuntimeError", "No active exception to reraise")
                end
                if type(current) == "string" then
                    raise(current)
                end
                rt.raise_exception(current)
            end
            local v = exc(f)
            if cause then
                cause(f)
            end
            if kind(v) == "class" then
                v = call(v, {})
            end
            if not rt.isinstance(v, classes.BaseException) then
                throw("TypeError", "exceptions must derive from BaseException")
            end
            rt.raise_exception(v)
        end
    elseif k == "Try" then
        inner = compile_try(scope, s)
    elseif k == "With" then
        local items = {}
        for i, item in ipairs(s.items) do
            items[i] = {context = cexpr(scope, item.context), store = item.target and compile_store(scope, item.target)}
        end
        local body = compile_body(scope, s.body)
        local function run(f, level)
            if level > #items then
                return body(f)
            end
            local item = items[level]
            local mgr = item.context(f)
            local exit = getattr(mgr, "__exit__")
            local value = call(getattr(mgr, "__enter__"), {})
            if item.store then
                item.store(f, value)
            end
            local ok, sig, err = protected(function()
                return run(f, level + 1)
            end)
            if ok then
                call(exit, {None, None, None})
                return sig
            end
            local inst = rt.caught_exception(err)
            if inst and truth(call(exit, {inst.cls, inst, None})) then
                return nil
            end
            raise(err)
        end
        inner = function(f)
            return run(f, 1)
        end
    elseif k == "Delete" then
        inner = compile_delete(scope, s.targets)
    elseif k == "Assert" then
        local test = cexpr(scope, s.test)
        local msg = s.msg and cexpr(scope, s.msg)
        inner = function(f)
            if not truth(test(f)) then
                if msg then
                    rt.raise_exception(call(classes.AssertionError, {msg(f)}))
                end
                throw("AssertionError")
            end
        end
    elseif k == "Import" then
        local entries = {}
        for i, a in ipairs(s.names) do
            local bound = a.asname or a.name:match("^[^%.]+")
            entries[i] = {name = a.name, asname = a.asname, store = make_storer(scope, bound)}
        end
        inner = function(f)
            for _, entry in ipairs(entries) do
                local m = f.env.import(entry.name)
                if not entry.asname and entry.name:find(".", 1, true) then
                    m = f.env.import(entry.name:match("^[^%.]+"))
                end
                entry.store(f, m)
            end
        end
    elseif k == "ImportFrom" then
        if s.level > 0 then
            throw("ImportError", "relative imports are not supported")
        end
        local module = s.module
        if s.names == "*" then
            inner = function(f)
                local m = f.env.import(module)
                local all = m.globals.__all__
                if all ~= nil then
                    for _, name in ipairs(to_array(all)) do
                        f.vars[name] = m.globals[name]
                    end
                else
                    for name, v in pairs(m.globals) do
                        if name:sub(1, 1) ~= "_" then
                            f.vars[name] = v
                        end
                    end
                end
            end
        else
            local entries = {}
            for i, a in ipairs(s.names) do
                entries[i] = {name = a.name, store = make_storer(scope, a.asname or a.name)}
            end
            inner = function(f)
                local m = f.env.import(module)
                for _, entry in ipairs(entries) do
                    local v = getattr(m, entry.name, true)
                    if v == nil then
                        throw("ImportError", "cannot import name '" .. entry.name .. "' from '" .. module .. "'")
                    end
                    entry.store(f, v)
                end
            end
        end
    else
        throw("SyntaxError", "unsupported statement " .. tostring(k))
    end
    return function(f)
        f.env.line = line
        return inner(f)
    end
end

compile_body = function(scope, stmts)
    local fns = {}
    for i, s in ipairs(stmts) do
        fns[i] = compile_stmt(scope, s)
    end
    local n = #fns
    if n == 1 then
        return fns[1]
    end
    return function(f)
        for i = 1, n do
            local sig = fns[i](f)
            if sig then
                return sig
            end
        end
    end
end

function compile_module(source, filename)
    local body = parser.parse_module(source, filename)
    local scope = new_scope("module", nil)
    scan_body(scope, body)
    local run = compile_body(scope, body)
    return function(globals, env)
        run({vars = globals, globals = globals, env = env})
    end
end

function compile_eval(source, filename)
    local e = parser.parse_eval(source, filename)
    local scope = new_scope("module", nil)
    scan_expr(scope, e)
    local ex = cexpr(scope, e)
    return function(globals, env)
        return ex({vars = globals, globals = globals, env = env})
    end
end

local function normalize_newlines(text)
    return (text:gsub("\r\n?", "\n"))
end

function new_env(opt)
    opt = opt or {}
    local env = {paths = opt.paths or {}, modules = {}, factories = {}, exc_stack = {}}
    for name, factory in pairs(rt.native_modules()) do
        env.factories[name] = factory
    end
    for name, factory in pairs(opt.modules or {}) do
        env.factories[name] = factory
    end
    env.import = function(name)
        local m = env.modules[name]
        if m then
            return m
        end
        local factory = env.factories[name]
        if factory then
            m = factory(env)
            env.modules[name] = m
            return m
        end
        for _, dir in ipairs(env.paths) do
            local file = path.join(dir, name .. ".py")
            if os.isfile(file) then
                local globals = {__name__ = name, __file__ = file}
                m = {__t = "module", name = name, globals = globals}
                env.modules[name] = m
                local run = compile_module(normalize_newlines(io.readfile(file)), file)
                run(globals, env)
                return m
            end
        end
        throw("ModuleNotFoundError", "No module named '" .. name .. "'")
    end
    return env
end
