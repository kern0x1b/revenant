import("core.base.json")
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})

local D = import("intents-data", {rootdir = os.scriptdir()}).data()

local function is_word(char)
    return char ~= "" and char:match("[%w_]") ~= nil
end

local function trim(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function starts_with(text, prefix)
    return text:sub(1, #prefix) == prefix
end

local function split_colon(text)
    local pieces, at = {}, 1
    while true do
        local first = text:find(":", at, true)
        if first == nil then
            table.insert(pieces, text:sub(at))
            return pieces
        end
        table.insert(pieces, text:sub(at, first - 1))
        at = first + 1
    end
end

local function words_of(text)
    local found = {}
    for word in text:gmatch("%S+") do
        table.insert(found, word)
    end
    return found
end

local function replace_word(text, word, repl)
    local out, at = {}, 1
    while true do
        local first, last = text:find(word, at, true)
        if first == nil then
            break
        end
        local before, after = text:sub(first - 1, first - 1), text:sub(last + 1, last + 1)
        if not is_word(before) and not is_word(after) then
            table.insert(out, text:sub(at, first - 1))
            table.insert(out, repl)
        else
            table.insert(out, text:sub(at, last))
        end
        at = last + 1
    end
    table.insert(out, text:sub(at))
    return table.concat(out)
end

local function strip_innermost(text, open, close)
    local out, at, length = {}, 1, #text
    local start = 1
    while at <= length do
        local char = text:sub(at, at)
        if char == open then
            local probe = at + 1
            while probe <= length and text:sub(probe, probe) ~= open and text:sub(probe, probe) ~= close do
                probe = probe + 1
            end
            if probe <= length and text:sub(probe, probe) == close then
                table.insert(out, text:sub(start, at - 1))
                start = probe + 1
                at = probe + 1
            else
                at = at + 1
            end
        else
            at = at + 1
        end
    end
    table.insert(out, text:sub(start))
    return table.concat(out)
end

local function remove_nullability(text)
    local out, at, length = {}, 1, #text
    local start = 1
    while at <= length do
        if text:sub(at, at) == "_" then
            local probe = at + 1
            while probe <= length and text:sub(probe, probe):match("%s") do
                probe = probe + 1
            end
            local word = nil
            if text:sub(probe, probe + 6) == "Nonnull" then
                word = "Nonnull"
            elseif text:sub(probe, probe + 7) == "Nullable" then
                word = "Nullable"
            end
            if word and not is_word(text:sub(probe + #word, probe + #word)) then
                table.insert(out, text:sub(start, at - 1))
                start = probe + #word
                at = probe + #word
            else
                at = at + 1
            end
        else
            at = at + 1
        end
    end
    table.insert(out, text:sub(start))
    return table.concat(out)
end

local function find_macro(text, from)
    local length = #text
    for at = from, length do
        local char = text:sub(at, at)
        if char:match("[A-Z]") and not is_word(text:sub(at - 1, at - 1)) then
            local probe = at + 1
            while probe <= length and text:sub(probe, probe):match("[A-Z0-9]") do
                probe = probe + 1
            end
            local groups = 0
            while probe <= length and text:sub(probe, probe) == "_" and text:sub(probe + 1, probe + 1):match("[A-Z0-9]") do
                probe = probe + 1
                while probe <= length and text:sub(probe, probe):match("[A-Z0-9]") do
                    probe = probe + 1
                end
                groups = groups + 1
            end
            if groups > 0 and not is_word(text:sub(probe, probe)) then
                return at, probe - 1
            end
        end
    end
    return nil
end

local function clean(text)
    text = remove_nullability(text or "")
    while true do
        local first, last = find_macro(text, 1)
        if not first then
            return trim(text)
        end
        local keep_from = last + 1
        if text:sub(keep_from, keep_from) == "(" then
            local depth, index = 0, keep_from
            while index <= #text do
                local char = text:sub(index, index)
                if char == "(" then
                    depth = depth + 1
                elseif char == ")" then
                    depth = depth - 1
                    if depth == 0 then
                        index = index + 1
                        break
                    end
                end
                index = index + 1
            end
            keep_from = index
        end
        text = text:sub(1, first - 1) .. " " .. text:sub(keep_from)
    end
end

local function spelled(qual)
    local text = clean(qual):gsub("%s+", " ")
    text = trim(text)
    if text == "" then
        text = "id"
    end
    if text:find("ObjectType", 1, true) then
        text = strip_innermost(text, "<", ">")
        text = replace_word(text, "ObjectType", "id")
    end
    return text
end

local function base_type(qual)
    local text = spelled(qual)
    if text:sub(1, 6) == "void (^" or text:sub(1, 5) == "block" then
        return "block"
    end
    text = strip_innermost(text, "<", ">")
    text = text:gsub("%*", "")
    text = strip_innermost(text, "(", ")")
    text = text:gsub("const", ""):gsub("volatile", ""):gsub("struct", "")
    text = trim(text)
    local parts = words_of(text)
    if #parts > 0 then
        return parts[1]
    end
    return text
end

local function type_of(member)
    local qual = member["type"] and member["type"].qualType
    return qual or "id"
end

local function returns_of(method)
    local qual = method.returnType and method.returnType.qualType
    return qual or "id"
end

local function parameters_of(method)
    local found = {}
    for _, child in ipairs(method.inner or {}) do
        if child.kind == "ParmVarDecl" then
            table.insert(found, {type_of(child), child.name or "value"})
        end
    end
    return found
end

local function has_attr(node, kind)
    for _, child in ipairs(node.inner or {}) do
        if child.kind == kind then
            return true
        end
    end
    return false
end

local function setter_name(name)
    return "set" .. name:sub(1, 1):upper() .. name:sub(2) .. ":"
end

local function is_copy(member, kind)
    if member.copy then
        return true
    end
    if member.retain or member.strong then
        return false
    end
    return D.copied[base_type(kind)] == true
end

local function ends_with_pointer(text)
    return text:match("%*%s*$") ~= nil
end

local function sorted_keys(map)
    local keys = {}
    for key in pairs(map) do
        table.insert(keys, key)
    end
    byteorder.sort(keys)
    return keys
end

local function match_synthesised(line)
    return line:match("^%s*@synthesize ([%a_][%w_]*)%s*=")
end

local function match_dynamic(line)
    return line:match("^%s*@dynamic ([%a_][%w_]*)%s*;")
end

local function match_definition(line)
    local sign, kind, rest = line:match("^%s*([%-%+]) %(([^%)]*)%)(.*)$")
    return sign, kind, rest
end

local function selector_parts(text)
    local parts, at, length = {}, 1, #text
    while at <= length do
        local char = text:sub(at, at)
        if char:match("[%a_]") then
            local probe = at
            while probe <= length and text:sub(probe, probe):match("[%w_]") do
                probe = probe + 1
            end
            if text:sub(probe, probe) == ":" and text:sub(probe + 1, probe + 1) == "(" then
                table.insert(parts, text:sub(at, probe - 1))
                at = probe + 2
            else
                at = at + 1
            end
        else
            at = at + 1
        end
    end
    return parts
end

local ALONE_REASON = [==[
%(name)s is an object file of its own because a release below this group's own already
exports it: the armv7s cache of iOS %(below)s has it, and the caches of this group's own
release do not have the classes it would share an object with. One object that defines
both is what the band check refuses, and a one-class object is consistent in every band:
the release that has it re-exports the object, and every release that does not keeps it.
The measurement is tools/intents/measure-group.lua, and the reason is the comment above
ALONE in the generator that wrote this file.
]==]

local SUCCESS_VALUE = "successWithResolvedValue:"
local DISAMBIGUATION_VALUE = "disambiguationWithValueToDisambiguate:"
local CONFIRMATION_VALUE = "confirmationRequiredWithValueToConfirm:"

local SYSTEM_PREFIXES = {"NS", "CL", "CF", "CG", "UI", "WK", "CA", "AV", "SK", "MK", "QL", "AL", "SCN", "PH", "MP"}

local function is_system(name)
    for _, prefix in ipairs(SYSTEM_PREFIXES) do
        if name:sub(1, #prefix) == prefix and name:sub(#prefix + 1, #prefix + 1):match("%u") then
            return true
        end
    end
    return false
end

local function new_interface(node)
    local self = {
        node = node,
        name = node.name,
        superclass = node.super and node.super.name or nil,
        protocols = {},
        properties = {},
        methods = {},
    }
    for _, protocol in ipairs(node.protocols or {}) do
        if protocol.name then
            table.insert(self.protocols, protocol.name)
        end
    end
    for _, child in ipairs(node.inner or {}) do
        if child.kind == "ObjCPropertyDecl" then
            table.insert(self.properties, child)
        elseif child.kind == "ObjCMethodDecl" then
            table.insert(self.methods, child)
        end
    end
    return self
end

local function method_of(interface, selector)
    for _, candidate in ipairs(interface.methods) do
        if candidate.name == selector then
            return candidate
        end
    end
    return nil
end

local function designated(interface, interfaces)
    local seen, name = {}, interfaces[interface.superclass]
    while name and not seen[name.name] do
        seen[name.name] = true
        for _, method in ipairs(name.methods) do
            if has_attr(method, "ObjCDesignatedInitializerAttr") and (method.name or ""):find(":", 1, true) then
                return method
            end
        end
        name = interfaces[name.superclass]
    end
    return nil
end

local function ancestor_property(interface, property, interfaces)
    local seen, name = {}, interfaces[interface.superclass]
    while name and not seen[name.name] do
        seen[name.name] = true
        for _, member in ipairs(name.properties) do
            if member.name == property then
                return member
            end
        end
        name = interfaces[name.superclass]
    end
    return nil
end

local function ancestor_property_owner(interface, property, interfaces)
    local seen, name = {}, interfaces[interface.superclass]
    while name and not seen[name.name] do
        seen[name.name] = true
        for _, member in ipairs(name.properties) do
            if member.name == property then
                return name.name
            end
        end
        name = interfaces[name.superclass]
    end
    return nil
end

local function inherited_readonly(interface, interfaces, spellings)
    local found = {}
    for _, method in ipairs(interface.methods) do
        local selector = method.name or ""
        if method.instance ~= false and selector:sub(1, 4) == "init" and selector:find(":", 1, true) then
            for _, parameter in ipairs(parameters_of(method)) do
                local name = spellings[parameter[2]] or parameter[2]
                local member = ancestor_property(interface, name, interfaces)
                if member and member.readonly and not member.category
                        and ancestor_property_owner(interface, name, interfaces) ~= interface.name then
                    if found[name] == nil then
                        found[name] = {type_of(member), member, member.name}
                    end
                end
            end
        end
    end
    return found
end

local function zero_of(qual)
    local kind = spelled(qual)
    if ends_with_pointer(kind) or kind == "id" or kind == "instancetype" then
        return "nil"
    end
    if kind == "BOOL" then
        return "NO"
    end
    return "0"
end

local function own_init_unavailable(interface, interfaces)
    local seen, name = {}, interface
    while name and not seen[name.name] do
        seen[name.name] = true
        local declared = method_of(name, "init")
        if declared and has_attr(declared, "UnavailableAttr") then
            return true
        end
        name = interfaces[name.superclass]
    end
    return false
end

local function own_init_blocked_here(interface, interfaces)
    local seen, name = {}, interface
    while name and not seen[name.name] do
        seen[name.name] = true
        local declared = method_of(name, "init")
        if declared and has_attr(declared, "UnavailableAttr") then
            return name.name ~= interface.name or (declared.params ~= nil and #declared.params == 0)
        end
        name = interfaces[name.superclass]
    end
    return false
end

local function init_shape_of(interface, interfaces)
    if own_init_unavailable(interface, interfaces)
            and (method_of(interface, "init") ~= nil or own_init_blocked_here(interface, interfaces)) then
        return "unavailable"
    end
    local declared = method_of(interface, "init")
    if declared ~= nil and not has_attr(declared, "UnavailableAttr") then
        return "designated"
    end
    return nil
end

local function resolution_result(name, interfaces)
    local seen = {}
    while name and not seen[name] do
        if name == D.resolution_base then
            return true
        end
        seen[name] = true
        local found = interfaces[name]
        name = found and found.superclass or nil
    end
    return false
end

local function parameter_named(cls, selector, parameter)
    for _, entry in ipairs(D.parameter_properties) do
        if entry[1] == cls and entry[2] == selector and entry[3] == parameter then
            return entry[4]
        end
    end
    for _, entry in ipairs(D.parameter_properties) do
        if entry[1] == cls and entry[2] == false and entry[3] == parameter then
            return entry[4]
        end
    end
    return nil
end

local function parameter_stop(message)
    raise("%s", message)
end

local function spelled_selector(method)
    local parts = {}
    local parameters = parameters_of(method)
    local pieces = split_colon(method.name or "")
    table.remove(pieces)
    for index, part in ipairs(pieces) do
        local kind, parameter = "id", "value"
        if parameters[index] then
            kind, parameter = parameters[index][1], parameters[index][2]
        end
        table.insert(parts, part .. ":(" .. spelled(kind) .. ")" .. parameter)
    end
    return table.concat(parts, " ")
end

local function initialiser(interface, method, states, spellings, interfaces)
    local selector = method.name or ""
    local lines = {"- (instancetype)" .. spelled_selector(method), "{"}

    local given, given_order, after, adopt, chained = {}, {}, {}, {}, false
    local function give(name, kind, parameter)
        if given[name] == nil then
            table.insert(given_order, name)
        end
        given[name] = {kind, parameter}
    end
    for _, parameter_entry in ipairs(parameters_of(method)) do
        local kind, parameter = parameter_entry[1], parameter_entry[2]
        if resolution_result(base_type(kind), interfaces) then
            table.insert(adopt, parameter)
        else
            local name = spellings[parameter] or parameter
            give(name, kind, parameter)
            if states["_" .. name] == nil then
                local member = ancestor_property(interface, name, interfaces)
                if member == nil then
                    local named = parameter_named(interface.name, selector, parameter) or {}
                    if #named == 0 then
                        parameter_stop(string.format("%s: the parameter %s of %s names no property of the class or of"
                            .. " a superclass, and PARAMETER_PROPERTIES says nowhere it goes, so this generator stops"
                            .. " rather than drop it", interface.name, parameter, selector))
                    end
                    for _, property_name in ipairs(named) do
                        if states["_" .. property_name] == nil then
                            parameter_stop(string.format("%s: PARAMETER_PROPERTIES sends the parameter %s of %s to %s,"
                                .. " which is not a property of the class", interface.name, parameter, selector,
                                property_name))
                        end
                        if given[property_name] == nil then
                            give(property_name, kind, parameter)
                        end
                    end
                elseif not member.readonly then
                    table.insert(after, {name, kind, parameter})
                else
                    chained = true
                end
            end
        end
    end

    if chained then
        local parent = designated(interface, interfaces)
        if not parent then
            return nil
        end
        for _, parameter_entry in ipairs(parameters_of(parent)) do
            if ends_with_pointer(spelled(parameter_entry[1])) then
                return nil
            end
        end
        local pieces = {}
        local keywords = split_colon(parent.name or "")
        table.remove(keywords)
        for index, parameter_entry in ipairs(parameters_of(parent)) do
            local kind, parameter = parameter_entry[1], parameter_entry[2]
            local supplied = given[parameter]
            local keyword = index <= #keywords and keywords[index] or parameter
            table.insert(pieces, keyword .. ":" .. (supplied and supplied[2] or zero_of(kind)))
        end
        table.insert(lines, "    if ((self = [super " .. table.concat(pieces, " ") .. "])) {")
    elseif own_init_unavailable(interface, interfaces) then
        table.insert(lines, "    // The header marks this class's -init unavailable, so the superclass's own")
        table.insert(lines, "    // -init is called through CharonCoding.h's one definition of it.")
        table.insert(lines, "    if ((self = charon_intents_super_init(self, [" .. interface.superclass .. " class]))) {")
    else
        table.insert(lines, "    if ((self = [super init])) {")
    end

    for _, name in ipairs(sorted_keys(given)) do
        if states["_" .. name] ~= nil then
            local kind, parameter = given[name][1], given[name][2]
            local copied = ends_with_pointer(spelled(kind))
            table.insert(lines, "        _" .. name .. " = " .. (copied and ("[" .. parameter .. " copy]") or parameter) .. ";")
        end
    end
    for _, parameter in ipairs(adopt) do
        table.insert(lines, "        [self charon_adoptResolutionOf:" .. parameter .. "];")
    end
    table.insert(lines, "    }")
    for _, entry in ipairs(after) do
        local name, kind, parameter = entry[1], entry[2], entry[3]
        local copied = ends_with_pointer(spelled(kind))
        table.insert(lines, "    self." .. name .. " = " .. (copied and ("[" .. parameter .. " copy]") or parameter) .. ";")
    end
    table.insert(lines, "    return self;")
    table.insert(lines, "}")
    return lines
end

local function single_item_factory(interface, plural, interfaces)
    local stem = plural:match("^([^:]*)")
    if stem:sub(1, 9) ~= "successes" then
        return nil
    end
    local rest = stem:sub(10)
    local wanted = "success" .. rest
    if rest:sub(-1) == "s" then
        wanted = "success" .. rest:sub(1, -2)
    end
    local seen, name = {}, interface.name
    while interfaces and name and not seen[name] do
        seen[name] = true
        for _, candidate in ipairs(interfaces[name].methods) do
            if candidate.instance == false and (candidate.name or "") == wanted .. ":" then
                return candidate
            end
        end
        name = interfaces[name].superclass
    end
    return nil
end

local function factory(interface, method, resolution, interfaces)
    local selector = method.name or ""
    if not resolution or has_attr(method, "UnavailableAttr") then
        return {}
    end
    local returns = spelled(returns_of(method))
    if (ends_with_pointer(returns) and returns:find("NSArray", 1, true))
            or starts_with(selector, "successesWithResolved") then
        local single = single_item_factory(interface, selector, interfaces)
        if not single then
            return false
        end
        local keyword = (single.name or ""):match("^([^:]*)")
        local parameters = parameters_of(single)
        local item = #parameters > 0 and parameters[1][2] or "item"
        local input_parameters = parameters_of(method)
        local input = #input_parameters > 0 and input_parameters[1][2] or "items"
        return {"+ (" .. returns .. ")" .. spelled_selector(method), "{",
                "    // One result per item, each made by this class's own single-item factory",
                "    // +" .. keyword .. ", and an empty array for an input that is nil or empty - the",
                "    // host's own answer, measured on all five of these factories.",
                "    NSMutableArray *results = [NSMutableArray arrayWithCapacity:" .. input .. ".count];",
                "    for (id " .. item .. " in " .. input .. ") {",
                "        [results addObject:[self " .. keyword .. ":" .. item .. "]];",
                "    }",
                "    return results;",
                "}"}
    end
    local parameters = parameters_of(method)
    if #parameters ~= 1 then
        return {}
    end
    returns = spelled(returns_of(method))
    if returns ~= "instancetype" and returns ~= interface.name and returns ~= interface.name .. " *" then
        return {}
    end
    local kind, name = parameters[1][1], parameters[1][2]
    local value
    if ends_with_pointer(spelled(kind)) then
        value = "[" .. name .. " copy]"
    elseif spelled(kind) == "BOOL" then
        value = "@(" .. name .. ")"
    elseif ({NSInteger = true, NSUInteger = true, int = true, long = true, short = true, unsigned = true})[spelled(kind)] then
        value = "[NSNumber numberWithInteger:(NSInteger)" .. name .. "]"
    elseif ({double = true, float = true, NSTimeInterval = true, CGFloat = true})[spelled(kind)] then
        value = "[NSNumber numberWithDouble:(double)" .. name .. "]"
    else
        local suffix = ({["char"] = "Char", ["unsigned char"] = "UnsignedChar", ["long long"] = "LongLong"})[spelled(kind)]
            or "Integer"
        value = "[NSNumber numberWith" .. suffix .. ":" .. name .. "]"
    end
    local head = "+ (" .. returns .. ")" .. spelled_selector(method)
    if selector:match("^successWithResolved(.*):$") or selector == SUCCESS_VALUE then
        return {head, "{",
                "    // The host re-forms a success carrying the zero case of its type as a",
                "    // notRequired - a success with nothing to say - and leaves any other value a",
                "    // success (measured on the host's own Intents, 17 enumerations).",
                "    return [self charon_resolutionWithStatus:" .. name .. " == 0 ? CharonIntentsResolutionNotRequired",
                "                                                : CharonIntentsResolutionSuccess",
                " resolvedValue:" .. value .. " valuesToDisambiguate:nil valueToConfirm:nil];", "}"}
    end
    if selector:match("^disambiguationWith(.*)ToDisambiguate:$") or selector == DISAMBIGUATION_VALUE then
        return {head, "{",
                "    return [self charon_resolutionWithStatus:CharonIntentsResolutionDisambiguation"
                    .. " resolvedValue:nil valuesToDisambiguate:" .. value .. " valueToConfirm:nil];", "}"}
    end
    if selector == "unsupportedForReason:" or selector == "unsupportedWithReason:" then
        return {head, "{",
                "    return [self charon_resolutionWithStatus:CharonIntentsResolutionUnsupported"
                    .. " resolvedValue:nil valuesToDisambiguate:nil valueToConfirm:nil"
                    .. " unsupportedReason:" .. name .. "];", "}"}
    end
    if selector:match("^confirmationRequiredWith(.*)ToConfirm:$") or selector == CONFIRMATION_VALUE then
        return {head, "{",
                "    return [self charon_resolutionWithStatus:CharonIntentsResolutionConfirmationRequired"
                    .. " resolvedValue:nil valuesToDisambiguate:nil valueToConfirm:" .. value .. "];", "}"}
    end
    return {}
end

local function definitions(lines)
    local joined, current = {}, nil
    for _, line in ipairs(lines) do
        if current ~= nil then
            current = current .. " " .. trim(line)
            local ending = line:gsub("%s+$", "")
            if ending:sub(-1) == "{" or ending:sub(-1) == ";" then
                table.insert(joined, current)
                current = nil
            end
        else
            local ending = line:gsub("%s+$", "")
            if match_definition(line) and ending:sub(-1) ~= "{" then
                current = trim(line)
            end
        end
    end
    if current ~= nil then
        table.insert(joined, current)
    end
    return joined
end

local function answer_of(lines, name, causes)
    local properties, dynamic, methods = {}, {}, {}
    local all = {}
    for _, line in ipairs(lines) do
        table.insert(all, line)
    end
    for _, line in ipairs(definitions(lines)) do
        table.insert(all, line)
    end
    for _, line in ipairs(all) do
        local found = match_synthesised(line)
        if found then
            properties[found] = true
        else
            found = match_dynamic(line)
            if found then
                dynamic[found] = true
            else
                local sign, _, spelled_text = match_definition(line)
                if sign then
                    local parts = selector_parts(spelled_text)
                    local selector = ""
                    for _, part in ipairs(parts) do
                        selector = selector .. part .. ":"
                    end
                    if selector == "" then
                        selector = trim(spelled_text)
                    end
                    if selector ~= "" then
                        methods[sign .. "[" .. name .. " " .. selector .. "]"] = true
                    end
                end
            end
        end
    end
    return {
        properties = sorted_keys(properties),
        dynamic = sorted_keys(dynamic),
        methods = sorted_keys(methods),
        causes = causes or {},
    }
end

local function top_level(file)
    local found = {}
    local node = json.decode(io.readfile(file, {encoding = "binary"}))
    if node.kind == "TranslationUnitDecl" then
        for _, child in ipairs(node.inner or {}) do
            table.insert(found, child)
        end
    else
        table.insert(found, node)
    end
    return found
end

local function collect(file)
    local interfaces, protocols, forward = {}, {}, {}
    local categories, category_owners = {}, {}
    for _, node in ipairs(top_level(file)) do
        local kind, name = node.kind, node.name
        if name then
            if kind == "ObjCInterfaceDecl" then
                if #(node.inner or {}) == 0 then
                    forward[name] = true
                elseif interfaces[name] == nil or #node.inner > #interfaces[name].node.inner then
                    interfaces[name] = new_interface(node)
                end
            elseif kind == "ObjCProtocolDecl" then
                if protocols[name] == nil or #(node.inner or {}) > #(protocols[name].inner or {}) then
                    protocols[name] = node
                end
            elseif kind == "ObjCCategoryDecl" then
                local owner = node.interface and node.interface.name
                if owner then
                    if categories[owner] == nil then
                        categories[owner] = {}
                        table.insert(category_owners, owner)
                    end
                    table.insert(categories[owner], node)
                end
            end
        end
    end
    for _, owner in ipairs(category_owners) do
        local interface = interfaces[owner]
        if interface then
            for _, node in ipairs(categories[owner]) do
                for _, member in ipairs(node.inner or {}) do
                    if member.kind == "ObjCPropertyDecl" then
                        local copy = {}
                        for key, value in pairs(member) do
                            copy[key] = value
                        end
                        copy.category = node.name
                        table.insert(interface.properties, copy)
                    elseif member.kind == "ObjCMethodDecl" then
                        table.insert(interface.methods, member)
                    end
                end
            end
        end
    end
    return interfaces, protocols, forward
end

local function property_names(members)
    local found = {}
    for _, member in ipairs(members) do
        local name = member.name
        if name and not member["class"] then
            found[name] = name
            local getter = member.getter and member.getter.name
            if getter and getter ~= name then
                found[getter] = name
            end
        end
    end
    return found
end

local function required_properties(protocol)
    local found = {}
    for _, member in ipairs(protocol.inner or {}) do
        if member.kind == "ObjCPropertyDecl" and member.name and not has_attr(member, "OptionalAttr") then
            found[member.name] = member
        end
    end
    return found
end

local function conformed_by(interface, interfaces)
    local found, seen, name = {}, {}, interface
    while name and not seen[name.name] do
        seen[name.name] = true
        for _, protocol in ipairs(name.protocols) do
            local present = false
            for _, known in ipairs(found) do
                if known == protocol then
                    present = true
                end
            end
            if not present then
                table.insert(found, protocol)
            end
        end
        name = interfaces[name.superclass]
    end
    return found
end

local function deferred_type(qual, known, carried, forward)
    local name = base_type(qual)
    if known[name] and not carried[name] then
        return name
    end
    if forward[name] and not carried[name] and not is_system(name) then
        return name
    end
    return nil
end

local function banner(name, classes, release, deferred)
    local text = [==[
//
//  {{name}}
//  Intents
//
//  Generated by tools/intents/gen-intents.lua from the Objective-C declarations of the
//  SDK's own headers, for the {{count}} classes the armv7 release caches measure as first
//  exported in iOS {{release}}. Do not edit: change the generator and run it again.
//
//  Every method the header declares here has a body that stores or returns the class's own
//  state, the coding and copying helpers walk the whole ivar chain so a subclass keeps its
//  parent's state, and {{deferred}} member(s) are left dynamic - a class property of the
//  class's own type, or a property of a class of a later group - and answered in
//  registry/Intents instead of with nil.
//
//  The classes whose behaviour is more than storage are hand written in
//  CharonIntents{{release}}.m, and the generator leaves them out.
//

#import <Intents/Intents.h>
#import <objc/runtime.h>
#import "../../../c/charon-coding/files/CharonCoding.h"
#import "CharonIntentsResolution.h"
#import "CharonIntents262.h"

// The SDK marks each class's initialiser as the designated one, in a header this package does not
// own and cannot add a marking to, so clang reads the -initWithCoder: and -copyWithZone: every
// class carries here as convenience initialisers of a class that has a designated one. The
// warning is about a convention and not about behaviour: the chain below is the header's own.
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
]==]
    local values = {name = name, count = classes, release = release, deferred = deferred}
    return (text:gsub("{{(%w+)}}", function(key) return tostring(values[key]) end))
end

local function conformed_has(conformed, protocol)
    for _, name in ipairs(conformed) do
        if name == protocol then
            return true
        end
    end
    return false
end

local function capitalised(text)
    return text:sub(1, 1):upper() .. text:sub(2)
end

local function implementation(interface, protocols, carried, intents, interfaces, forward)
    local resolution = resolution_result(interface.superclass, interfaces)
    local conformed = conformed_by(interface, interfaces)
    local name = interface.name

    local class_properties, own = {}, {}
    for _, member in ipairs(interface.properties) do
        if member.name and member["class"] then
            class_properties[member.name] = member
        end
    end
    for _, member in ipairs(interface.properties) do
        if member.name and not member["class"] then
            own[member.name] = member
        end
    end

    local accessors = {}
    for _, method in ipairs(interface.methods) do
        local selector = method.name or ""
        if own[selector] ~= nil and #parameters_of(method) == 0 then
            accessors[selector] = true
        else
            local captured = selector:match("^set(%%a[%w_]*):$")
            if captured and own[setter_name(captured)] ~= nil and #parameters_of(method) == 1 then
                accessors[selector] = true
            end
        end
    end

    local stored, synthesised, dynamic, setters, skipped, members = {}, {}, {}, {}, {}, {}
    local causes_by_name = {}
    for _, cname in ipairs(sorted_keys(class_properties)) do
        if D.extra_methods[name .. " " .. cname] == nil then
            causes_by_name[cname] = "class_property"
            table.insert(dynamic, {cname, class_properties[cname].category, "class_property"})
        end
    end
    for _, pname in ipairs(sorted_keys(own)) do
        local member = own[pname]
        local kind = type_of(member)
        if base_type(kind) == name then
            causes_by_name[pname] = "class_property"
            table.insert(dynamic, {pname, member.category, "class_property"})
        else
            local withheld = deferred_type(kind, intents, carried, forward)
            if withheld then
                local cause = "later_group"
                if forward[withheld] and not is_system(withheld) then
                    cause = "forward_only_class"
                end
                causes_by_name[pname] = cause
                table.insert(dynamic, {pname, member.category, cause})
            else
                table.insert(stored, {"_" .. pname, spelled(kind), pname})
                table.insert(members, {pname, spelled(kind), member})
                if not member.category then
                    table.insert(synthesised, "    @synthesize " .. pname .. " = _" .. pname .. ";")
                end
                if not member.readonly and accessors[setter_name(pname)] == nil then
                    table.insert(setters, {pname, kind, member})
                end
            end
        end
    end

    local spellings = property_names(interface.properties)
    local kept = {}
    local ivar_names = {}
    for _, entry in ipairs(stored) do
        ivar_names[entry[1]] = true
    end
    local inherited_map = inherited_readonly(interface, interfaces, spellings)
    for _, pname in ipairs(sorted_keys(inherited_map)) do
        if own[pname] == nil and not ivar_names["_" .. pname] then
            local kind = inherited_map[pname][1]
            kept[pname] = kind
            table.insert(stored, {"_" .. pname, spelled(kind), pname})
            ivar_names["_" .. pname] = true
        end
    end

    for _, protocol_name in ipairs(conformed) do
        local protocol = protocols[protocol_name]
        if protocol and protocol_name ~= "NSObject" then
            local required = required_properties(protocol)
            for _, pname in ipairs(sorted_keys(required)) do
                local member = required[pname]
                if not member["class"] and own[pname] == nil and accessors[pname] == nil
                        and not deferred_type(type_of(member), intents, carried, forward) then
                    local kind = type_of(member)
                    table.insert(stored, {"_" .. pname, spelled(kind), pname})
                    table.insert(synthesised, "    @synthesize " .. pname .. " = _" .. pname .. ";")
                    table.insert(setters, {pname, kind, member})
                end
            end
        end
    end

    local by_category = {}
    for _, entry in ipairs(members) do
        local category = entry[3].category
        if category then
            by_category[category] = by_category[category] or {}
            table.insert(by_category[category], entry)
        end
    end

    local out = {}
    local extra = D.extra_ivars[name]
    if #stored > 0 or extra then
        table.insert(out, "@interface " .. name .. " ()")
        table.insert(out, "{")
        for _, line in ipairs(extra or {}) do
            table.insert(out, line)
        end
        if #stored > 0 then
            local width = 0
            for _, entry in ipairs(stored) do
                width = math.max(width, #entry[2])
            end
            local ordered = {}
            for _, entry in ipairs(stored) do
                table.insert(ordered, entry)
            end
            table.sort(ordered, function(a, b) return byteorder.less(a[1], b[1]) end)
            for _, entry in ipairs(ordered) do
                table.insert(out, string.format("    %-" .. width .. "s %s;  // %s", entry[2], entry[1], entry[3]))
            end
        end
        table.insert(out, "}")
        table.insert(out, "@end")
        table.insert(out, "")
    end
    table.insert(out, "@implementation " .. name)
    for _, line in ipairs(synthesised) do
        table.insert(out, line)
    end
    for _, entry in ipairs(dynamic) do
        if not entry[2] then
            table.insert(out, "    @dynamic " .. entry[1] .. ";  // " .. (D.cause_labels[entry[3]] or entry[3])
                .. ": see registry/Intents")
        end
    end

    if D.hand_written[name] then
        for _, line in ipairs({"", "@end", ""}) do
            table.insert(out, line)
        end
        return out, {
            properties = {}, dynamic = {}, methods = {}, causes = {},
            init_shape = init_shape_of(interface, interfaces) or "absent",
        }
    end

    table.insert(out, "")
    local deferred_names = {}
    for _, entry in ipairs(dynamic) do
        deferred_names[entry[1]] = true
    end
    local states = {}
    for _, entry in ipairs(stored) do
        local ivar, kind, pname = entry[1], entry[2], entry[3]
        local member = own[pname]
        if member == nil and kept[pname] ~= nil then
            states[ivar] = ends_with_pointer(kind) and "copy" or "retain"
        else
            states[ivar] = (member and is_copy(member, kind)) and "copy" or "retain"
        end
    end

    for _, pname in ipairs(sorted_keys(kept)) do
        for _, line in ipairs({"- (" .. kept[pname] .. ")" .. pname, "{", "    return _" .. pname .. ";", "}", ""}) do
            table.insert(out, line)
        end
    end

    for _, entry in ipairs(setters) do
        local pname, member = entry[1], entry[3]
        local kind = spelled(entry[2])
        local copied = is_copy(member, kind) and ends_with_pointer(kind)
        local assigned = copied and ("[" .. pname .. " copy]") or pname
        for _, line in ipairs({"- (void)set" .. capitalised(pname) .. ":(" .. kind .. ")" .. pname,
                               "{", "    _" .. pname .. " = " .. assigned .. ";", "}", ""}) do
            table.insert(out, line)
        end
    end

    local init_shape = init_shape_of(interface, interfaces)
    if init_shape == "designated" then
        for _, line in ipairs({
            "- (instancetype)init", "{",
            "    // The header declares this -init as the class's designated initialiser, and nothing",
            "    // in its chain marks the selector unavailable, so the superclass's own -init is",
            "    // called by name.  On this class that is INIntent's, which is what makes the",
            "    // identifier an interaction donated with this intent is keyed by.",
            "    return [super init];",
            "}", ""}) do
            table.insert(out, line)
        end
    elseif init_shape == "unavailable" then
        for _, line in ipairs({
            "- (instancetype)init", "{",
            "    // The header marks this class's -init unavailable.  The system still answers one:",
            "    // measured, [[" .. name .. " alloc] init] returns an object with every property nil.  So the",
            "    // method is defined here, and the superclass's own -init is reached through its",
            "    // IMP, because the header forbids naming the selector.",
            "    Class parent = [" .. interface.superclass .. " class];",
            "    SEL selector = @selector(init);",
            "    IMP forward = parent ? class_getMethodImplementation(parent, selector) : NULL;",
            "    return forward ? ((id (*)(id, SEL))forward)(self, selector) : nil;",
            "}", ""}) do
            table.insert(out, line)
        end
    end

    for _, method in ipairs(interface.methods) do
        local selector = method.name or ""
        if method.instance ~= false and not has_attr(method, "UnavailableAttr") and starts_with(selector, "init")
                and selector:find(":", 1, true) and selector ~= "initWithCoder:" then
            local deferred = false
            for _, parameter in ipairs(parameters_of(method)) do
                if deferred_names[parameter[2]] or deferred_type(parameter[1], intents, carried, forward) then
                    deferred = true
                end
            end
            if deferred then
                table.insert(skipped, {selector, "deferred_value"})
            else
                local written = D.extra_methods[name .. " " .. selector]
                if written == nil then
                    local body = initialiser(interface, method, states, spellings, interfaces)
                    if body == nil then
                        table.insert(skipped, {selector, "chain_nonnull"})
                    else
                        for _, line in ipairs(body) do
                            table.insert(out, line)
                        end
                        table.insert(out, "")
                    end
                elseif #written > 0 then
                    for _, line in ipairs(written) do
                        table.insert(out, line)
                    end
                    table.insert(out, "")
                end
            end
        end
    end

    for _, method in ipairs(interface.methods) do
        local selector = method.name or ""
        local hand_written = D.extra_methods[name .. " " .. selector] ~= nil
            and not (starts_with(selector, "init") and selector:find(":", 1, true) ~= nil)
        local skip = false
        if has_attr(method, "UnavailableAttr") and D.extra_methods[name .. " " .. selector] == nil
                and accessors[selector] == nil and own[selector] == nil then
            table.insert(skipped, {selector, "unavailable"})
            skip = true
        end
        if not skip then
            local withheld = deferred_type(returns_of(method), intents, carried, forward)
            if withheld and not hand_written and method.instance ~= false and not has_attr(method, "UnavailableAttr")
                    and accessors[selector] == nil and own[selector] == nil
                    and ends_with_pointer(spelled(returns_of(method))) then
                table.insert(skipped, {selector, "foreign_class"})
                skip = true
            end
        end
        if not skip then
            local built = factory(interface, method, resolution, interfaces)
            if built == false then
                local sign = method.instance == false and "+" or "-"
                causes_by_name[sign .. "[" .. name .. " " .. selector .. "]"] = "collection_factory"
            else
                if hand_written then
                    built = D.extra_methods[name .. " " .. selector]
                end
                for _, line in ipairs(built) do
                    table.insert(out, line)
                end
                table.insert(out, "")
            end
        end
    end

    if conformed_has(conformed, "NSSecureCoding") then
        local parent = interfaces[interface.superclass]
        local own_init = nil
        for _, candidate in ipairs({interface, parent or false}) do
            if candidate and own_init == nil then
                local declared = method_of(candidate, "init")
                if declared and has_attr(declared, "UnavailableAttr") then
                    own_init = declared
                end
            end
        end
        local start
        if own_init ~= nil then
            start = {
                "    // The header marks this class's -init unavailable, so the superclass's own",
                "    // -init is called through CharonCoding.h's one definition of it.",
                "    if ((self = charon_intents_super_init(self, [" .. interface.superclass .. " class])))",
            }
        else
            start = {"    if ((self = [super init]))"}
        end
        for _, line in ipairs({"+ (BOOL)supportsSecureCoding", "{", "    return YES;", "}", "",
                               "- (instancetype)initWithCoder:(NSCoder *)coder", "{"}) do
            table.insert(out, line)
        end
        for _, line in ipairs(start) do
            table.insert(out, line)
        end
        for _, line in ipairs({"        charon_intents_decode(self, coder);", "    return self;", "}", "",
                               "- (void)encodeWithCoder:(NSCoder *)coder", "{",
                               "    charon_intents_encode(self, coder);", "}"}) do
            table.insert(out, line)
        end
        table.insert(out, "")
    end
    if conformed_has(conformed, "NSCopying") then
        for _, line in ipairs({"- (id)copyWithZone:(NSZone *)zone", "{",
                               "    " .. name .. " *copy = [[[self class] allocWithZone:zone] init];",
                               "    charon_intents_copy(copy, self);", "    return copy;", "}"}) do
            table.insert(out, line)
        end
        table.insert(out, "")
    end

    for _, key in ipairs(sorted_keys(D.charon_readers)) do
        if key:match("^(%S+) ") == name then
            for _, line in ipairs(D.charon_readers[key]) do
                table.insert(out, line)
            end
            table.insert(out, "")
        end
    end
    table.insert(out, "@end")
    table.insert(out, "")

    for _, category in ipairs(sorted_keys(by_category)) do
        local found = by_category[category]
        table.insert(out, string.format("@implementation %s (Charon%s%s)", name, name, category))
        for _, entry in ipairs(dynamic) do
            if entry[2] == category then
                table.insert(out, "    @dynamic " .. entry[1] .. ";  // " .. (D.cause_labels[entry[3]] or entry[3])
                    .. ": see registry/Intents")
            end
        end
        table.sort(found, function(a, b) return byteorder.less(a[1], b[1]) end)
        for _, entry in ipairs(found) do
            local pname, kind, member = entry[1], entry[2], entry[3]
            local getter = (member.getter and member.getter.name) or pname
            for _, line in ipairs({"", "- (" .. kind .. ")" .. getter, "{", "    return _" .. pname .. ";", "}"}) do
                table.insert(out, line)
            end
            if not member.readonly then
                local copied = is_copy(member, kind) and ends_with_pointer(kind)
                for _, line in ipairs({"", "- (void)set" .. capitalised(pname) .. ":(" .. kind .. ")" .. pname, "{",
                                       "    _" .. pname .. " = " .. (copied and ("[" .. pname .. " copy]") or pname) .. ";",
                                       "}"}) do
                    table.insert(out, line)
                end
            end
        end
        for _, line in ipairs({"", "@end", ""}) do
            table.insert(out, line)
        end
    end

    local causes = {}
    for key, value in pairs(causes_by_name) do
        causes[key] = value
    end
    for _, entry in ipairs(skipped) do
        causes[entry[1]] = entry[2]
    end
    local report = answer_of(out, name)
    report.causes = causes

    local written = {}
    for _, entry in ipairs(report.methods) do
        if starts_with(entry, "+[") then
            local after = entry:sub(entry:find("[", 1, true) + 1)
            local token = after:match("([^ ]*)$"):gsub("%]+$", "")
            written[token] = true
        end
    end
    report.class_properties = {}
    for _, cname in ipairs(sorted_keys(class_properties)) do
        if written[cname] then
            table.insert(report.class_properties, cname)
        end
    end
    report.init_shape = init_shape or "absent"
    return out, report
end

local function json_string(text)
    local escaped = text:gsub("\\", "\\\\"):gsub('"', '\\"')
    return '"' .. escaped .. '"'
end

local function json_object(entries, depth)
    if #entries == 0 then
        return "{}"
    end
    local parts = {}
    for _, entry in ipairs(entries) do
        table.insert(parts, string.rep(" ", depth + 1) .. json_string(entry[1]) .. ": " .. entry[2])
    end
    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. string.rep(" ", depth) .. "}"
end

local function json_list(items, depth)
    if #items == 0 then
        return "[]"
    end
    local parts = {}
    for _, item in ipairs(items) do
        table.insert(parts, string.rep(" ", depth + 1) .. json_string(item))
    end
    return "[\n" .. table.concat(parts, ",\n") .. "\n" .. string.rep(" ", depth) .. "]"
end

local function report_json(report, depth)
    local entries = {}
    for _, key in ipairs(sorted_keys(report)) do
        local value = report[key]
        local text
        if key == "causes" then
            local causes = {}
            for _, cause in ipairs(sorted_keys(value)) do
                table.insert(causes, {cause, json_string(value[cause])})
            end
            text = json_object(causes, depth + 1)
        elseif type(value) == "string" then
            text = json_string(value)
        else
            text = json_list(value, depth + 1)
        end
        table.insert(entries, {key, text})
    end
    return json_object(entries, depth)
end

local function options_of(arguments)
    local options = {}
    local index = 1
    while index <= #arguments do
        local key = arguments[index]:match("^%-%-(.+)$")
        if key == nil or arguments[index + 1] == nil then
            raise("usage: xmake l tools/intents/gen-intents.lua --sdk <sdk> --dump <ast.json> --classes <file> "
                .. "--release <release> --carried <file> --intents <file> --out <file.m> "
                .. "[--dump-newer <ast.json>] [--report <file.json>]")
        end
        options[key] = arguments[index + 1]
        index = index + 2
    end
    return options
end

local function lines_of(file)
    local found, seen = {}, {}
    for line in io.lines(file) do
        local name = trim(line)
        if name ~= "" then
            table.insert(found, name)
            seen[name] = true
        end
    end
    return found, seen
end

function main(...)
    local options = options_of({...})
    for _, required in ipairs({"sdk", "dump", "classes", "release", "carried", "intents", "out"}) do
        if options[required] == nil then
            raise("missing --" .. required)
        end
    end

    local interfaces, protocols, forward = collect(options.dump)
    if options["dump-newer"] then
        local fresh, newer_protocols = collect(options["dump-newer"])
        for name, value in pairs(fresh) do
            if interfaces[name] == nil then
                interfaces[name] = value
            end
        end
        for name, value in pairs(newer_protocols) do
            if protocols[name] == nil then
                protocols[name] = value
            end
        end
    end
    local names, _ = lines_of(options.classes)
    local _, carried = lines_of(options.carried)
    local _, intents = lines_of(options.intents)
    local missing = {}
    for _, name in ipairs(names) do
        if interfaces[name] == nil then
            table.insert(missing, name)
        end
    end
    if #missing > 0 then
        raise("not in the SDK's headers: %s", table.concat(missing, ", "))
    end

    local generated, alone = {}, {}
    for _, name in ipairs(names) do
        if not D.hand_written[name] then
            table.insert(generated, name)
        end
    end
    local kept = {}
    for _, name in ipairs(generated) do
        if D.alone[name] then
            table.insert(alone, {name, D.alone[name]})
        else
            table.insert(kept, name)
        end
    end
    generated = kept

    local out_name = options.out:match("([^/]*)$")
    local out_dir = options.out:match("^(.*)/") or "."
    local answered = {}
    local body_lines = {}
    local deferred = 0
    for _, name in ipairs(generated) do
        local body, report = implementation(interfaces[name], protocols, carried, intents, interfaces, forward)
        table.insert(body_lines, "")
        for _, line in ipairs(body) do
            table.insert(body_lines, line)
        end
        answered[name] = report
        deferred = deferred + #report.dynamic
    end
    local squeezed = {banner(out_name, #generated, options.release, deferred)}
    for _, line in ipairs(body_lines) do
        if not (line == "" and squeezed[#squeezed] == "") then
            table.insert(squeezed, line)
        end
    end

    for _, entry in ipairs(alone) do
        local name, below = entry[1], entry[2]
        local file = out_dir .. "/" .. name .. below .. ".m"
        local body, report = implementation(interfaces[name], protocols, carried, intents, interfaces, forward)
        local text = {banner(file:match("([^/]*)$"), 1, options.release, #report.dynamic)}
        local reason = ("\n" .. ALONE_REASON):gsub("%%%(name%)s", name):gsub("%%%(below%)s", below)
        for line in (reason .. "\n"):gmatch("(.-)\n") do
            table.insert(text, "//  " .. line)
        end
        table.insert(text, "")
        for _, line in ipairs(body) do
            table.insert(text, line)
        end
        io.writefile(file, table.concat(text, "\n"):gsub("\n+$", "") .. "\n", {encoding = "binary"})
        print(string.format("%s: %s alone, %d members", file, name, #report.methods + #report.properties))
        answered[name] = report
    end

    io.writefile(options.out, table.concat(squeezed, "\n"):gsub("\n+$", "") .. "\n", {encoding = "binary"})
    if options.report then
        io.writefile(options.report, report_json_top(answered), {encoding = "binary"})
    end
    return 0
end

function report_json_top(answered)
    local entries = {}
    for _, name in ipairs(sorted_keys(answered)) do
        table.insert(entries, {name, report_json(answered[name], 1)})
    end
    return json_object(entries, 0) .. "\n"
end

function answer(lines, name)
    return answer_of(lines, name)
end
