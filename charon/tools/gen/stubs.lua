local decl = import("decl", {anonymous = true})
local surface = import("surface", {anonymous = true})
local order = import("order", {anonymous = true})


local MACRO_PREFIXES = {"NS_", "API_", "CF_"}

local function add_member(found, cls, member)
    if found.members[cls] == nil then
        found.members[cls] = {}
        table.insert(found.order, cls)
    end
    table.insert(found.members[cls], member)
end

local function leave_out(skipped, api, reason)
    table.insert(skipped, {api = api, reason = reason})
end

local function has_hand(hand, cls, selector)
    return hand[cls] ~= nil and hand[cls][selector] ~= nil
end

local function undeclared_types(text, declared)
    local seen, out = {}, {}
    for word in string.gmatch(text, "[%w_]+") do
        local macro = false
        for _, prefix in ipairs(MACRO_PREFIXES) do
            macro = macro or string.sub(word, 1, #prefix) == prefix
        end
        if string.match(word, "^%u") and not declared[word] and not macro and not seen[word] then
            seen[word] = true
            table.insert(out, word)
        end
    end
    table.sort(out, order.less)
    return out
end

local function method_parameter(p)
    return "(" .. p.type .. ")" .. p.name
end

local function function_parameter(p)
    if p.name == nil then
        return p.type
    end
    local at = string.find(p.type, "(^)", 1, true)
    if at then
        return string.sub(p.type, 1, at + 1) .. p.name .. string.sub(p.type, at + 2)
    end
    local bracket = string.find(p.type, "[", 1, true)
    if bracket then
        return string.sub(p.type, 1, bracket - 1) .. " " .. p.name .. string.sub(p.type, bracket)
    end
    local sep = string.sub(p.type, -1) == "*" and "" or " "
    return p.type .. sep .. p.name
end

local function method_selector(selector, params)
    local pieces = {}
    for piece in string.gmatch(selector, "[^:]*:") do
        table.insert(pieces, piece .. method_parameter(params[#pieces + 1]))
    end
    if #pieces == 0 then
        return selector
    end
    return table.concat(pieces, " ")
end

function signature(m)
    if m.kind == "function" then
        local params = {}
        for _, p in ipairs(m.params) do
            table.insert(params, function_parameter(p))
        end
        local list = #params == 0 and "void" or table.concat(params, ", ")
        local sep = string.sub(m.type_text, -1) == "*" and "" or " "
        return m.type_text .. sep .. m.selector .. "(" .. list .. ")"
    elseif m.kind == "property-set" then
        return m.sign .. " (void)" .. m.selector .. "(" .. m.type_text .. ")value"
    elseif m.kind == "property-get" then
        return m.sign .. " (" .. m.type_text .. ")" .. m.selector
    end
    return m.sign .. " (" .. m.type_text .. ")" .. method_selector(m.selector, m.params)
end

local function consider_property(r, fact, env, found, skipped, seen)
    local cls = r.cls
    local name = decl.member_name(r.api)
    local selector = decl.attribute_value(fact.attrs, "getter") or name
    if env.overridden[r.api] or has_hand(env.hand, cls, name) or has_hand(env.hand, cls, selector) then
        return leave_out(skipped, r.api, "override or hand implementation")
    end
    local type_text = decl.canonical(fact.type, env.index)
    if type_text == "" then
        return leave_out(skipped, r.api, "no property type in the shard")
    end
    local zero = decl.kind_of(type_text, env.index)
    if zero == nil then
        return leave_out(skipped, r.api, "type not resolved: " .. type_text)
    end
    local readwrite = not decl.has_attribute(fact.attrs, "readonly")
    local sign = string.sub(r.api, 1, 1)
    local key = sign .. cls .. "\t" .. selector
    if seen[key] then
        return leave_out(skipped, r.api, "same selector declared twice in the class")
    end
    seen[key] = true
    add_member(found, cls, {api = sign .. "[" .. cls .. " " .. selector .. "]", kind = "property-get", selector = selector,
                            type_text = type_text, zero = zero, params = {}, name = name, sign = sign})
    local setter = "set" .. string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2) .. ":"
    if readwrite and not has_hand(env.hand, cls, setter) and not env.overridden[sign .. "[" .. cls .. " " .. setter .. "]"] then
        add_member(found, cls, {api = sign .. "[" .. cls .. " " .. setter .. "]", kind = "property-set", selector = setter,
                                type_text = type_text, zero = "void", params = {}, name = name, sign = sign})
    end
end

local function consider_method(r, fact, params, env, found, skipped, seen)
    local cls = r.cls
    local selector = string.match(string.gsub(r.api, "%]+$", ""), "^[^ ]* (.*)$")
    assert(selector, "a method api names no selector: " .. r.api)
    if env.overridden[r.api] or has_hand(env.hand, cls, selector) then
        return leave_out(skipped, r.api, "override or hand implementation")
    end
    local ret = decl.canonical(fact.type, env.index)
    if ret == "" then
        return leave_out(skipped, r.api, "no return type in the shard")
    end
    local _, colons = string.gsub(selector, ":", "")
    if colons ~= #params then
        return leave_out(skipped, r.api, "parameters do not match the selector")
    end
    local zero = decl.kind_of(ret, env.index)
    if zero == nil then
        return leave_out(skipped, r.api, "type not resolved: " .. ret)
    end
    local key = string.sub(r.api, 1, 1) .. cls .. "\t" .. selector
    if seen[key] then
        return leave_out(skipped, r.api, "same selector declared twice in the class")
    end
    seen[key] = true
    local error_arg = nil
    for i, p in ipairs(params) do
        p.name = p.name or ("arg" .. i)
        if error_arg == nil and decl.is_error_out(p.type, env.index) then
            error_arg = p.name
        end
    end
    add_member(found, cls, {api = r.api, kind = "method", sign = string.sub(r.api, 1, 1), selector = selector, type_text = ret,
                            zero = zero, params = params, error_arg = error_arg, availability = fact.availability})
end

local function consider(r, env, found, skipped, seen)
    if env.release_missing ~= nil then
        local ledger_api = r.kind == "method" and r.api or (r.cls .. "." .. decl.member_name(r.api))
        if env.release_missing[surface.key(r.kind, ledger_api)] == nil then
            return leave_out(skipped, r.api, surface.not_checked_state())
        end
    end
    local fact = env.members[r.api]
    if fact == nil then
        return leave_out(skipped, r.api, "no typed fact in the shard")
    end
    local params = decl.parse_params(fact.params, env.index)
    local texts = {decl.canonical(fact.type, env.index)}
    for _, p in ipairs(params) do
        table.insert(texts, p.type)
    end
    local undeclared = undeclared_types(table.concat(texts, " "), env.declared)
    if #undeclared > 0 then
        return leave_out(skipped, r.api, "type not declared for iOS: " .. table.concat(undeclared, ","))
    end
    if r.kind == "property" then
        return consider_property(r, fact, env, found, skipped, seen)
    end
    return consider_method(r, fact, params, env, found, skipped, seen)
end

function members(spec, env)
    local found = {order = {}, members = {}}
    local skipped, seen = {}, {}
    for _, r in ipairs(spec) do
        if r.kind == "method" or r.kind == "property" then
            consider(r, env, found, skipped, seen)
        end
    end
    return found, skipped
end

function functions(rows, env, skipped)
    local out = {}
    for _, row in ipairs(rows) do
        local key = row.api .. "()"
        local fact = env.functions[row.api]
        if env.overridden[key] or env.hand_functions[row.api] then
            leave_out(skipped, key, "override or hand implementation")
        elseif fact == nil then
            leave_out(skipped, key, "no typed fact in the shard")
        else
            local ret = decl.function_return(fact.type, env.index)
            if ret == nil then
                leave_out(skipped, key, "no return type in the shard")
            elseif string.find(ret, "^", 1, true) then
                leave_out(skipped, key, "returns a block")
            elseif decl.kind_of(ret, env.index) == nil then
                leave_out(skipped, key, "type not resolved: " .. ret)
            else
                local params = decl.parse_params(fact.params, env.index)
                local error_arg = nil
                for _, p in ipairs(params) do
                    if error_arg == nil and p.name ~= nil and decl.is_error_out(p.type, env.index) then
                        error_arg = p.name
                    end
                end
                table.insert(out, {api = row.api, kind = "function", sign = "", selector = row.api, type_text = ret,
                                   zero = decl.kind_of(ret, env.index), params = params, error_arg = error_arg})
            end
        end
    end
    return out
end

function stub_text(fw, m)
    local log = 'static BOOL charon_logged = NO; if (!charon_logged) { charon_logged = YES; fprintf(stderr, "unimplemented: '
        .. fw .. ' %s\\n", "' .. m.api .. '"); }'
    local error_code = ""
    if m.error_arg then
        error_code = "if (" .. m.error_arg .. ") { *" .. m.error_arg .. ' = [NSError errorWithDomain:@"' .. fw
            .. '.Unimplemented" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"' .. m.api .. ' is not implemented by the port"}]; } '
    end
    local zero
    if m.zero == "void" then
        zero = ""
    elseif m.zero == "object" then
        zero = m.kind == "function" and "return NULL;" or "return nil;"
    elseif m.zero == "scalar" then
        zero = "return 0;"
    else
        zero = "return (" .. m.type_text .. "){0};"
    end
    local sep = error_code ~= "" and (" " .. error_code) or " "
    return signature(m) .. " { " .. log .. sep .. zero .. " }"
end
