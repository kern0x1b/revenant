-- gen-intents.lua: emit the Intents backport's data classes from the SDK's own declarations.
--
-- The Intents surface of SDK 26.2 is 3440 rows for the port, 308 of them classes. Writing them by hand would take a
-- month and get most of them wrong in the same way, so they are generated from what the compiler itself says a class
-- is: the Objective-C AST of the SDK the port compiles against, which is the one description of the contract that
-- cannot be a guess.
--
-- What is generated:
--
--   * one object file per release the release caches measure a class symbol first exported in, because an object
--     carries API of exactly one release (modules/apple/backports.lua's check_releases). The release is read from the
--     file the caller passes, which tools/intents/measure-intents.lua measured against the real caches; the header's
--     own availability annotation is not used for it, and it is wrong where the two disagree (INPaymentStatusResolutionResult
--     is exported by iOS 10.3, and the header says 10.0).
--   * for each class: an ivar per stored property, the synthesised properties, the setters with the ownership the
--     header declares, every declared initialiser, NSSecureCoding and NSCopying where the header asks for them, the
--     resolution result's value / values to disambiguate / value to confirm, and a body for every other method the
--     header declares.
--   * the properties a conformed protocol requires and the class does not declare itself, so a class really conforms
--     (INSpeakable's spokenPhrase and the rest).
--
-- What is not generated, because a generated body would be the silent fake the rules forbid: INIntent's identifier and
-- its image parameters, INInteraction's donation and deletion, INVocabulary's store, INPreferences' answers for a
-- release with no Siri, INImage's ways of being made, INPaymentMethod's Apple Pay method, INRideCompletionStatus'
-- derived answers, and INIntentResolutionResult's needsValue / notRequired / unsupported. Those are hand written in
-- CharonIntents100.m and this generator leaves their classes out.
--
-- A member whose type is an Intents class of a group this delivery does not carry is left out with `@dynamic` and
-- takes a registry entry of its own that says so, rather than answering nil or zero: the mark stays on the header, so
-- a port cannot call it, and respondsToSelector: says no instead of crashing.
--
-- Usage:
--     xmake l tools/intents/gen-intents.lua --sdk <iPhoneOS*.sdk> --dump <ast.json> --classes <file> --release <measured>
--         --carried <file> --intents <file> --out <file.m> [--dump-newer <ast.json>] [--report <file.json>]
--
--     --dump is
--         clang -target arm64-apple-ios<ver> -isysroot <sdk> -fsyntax-only
--               -x objective-c -Wno-everything -Xclang -ast-dump=json umbrella.m
--     where umbrella.m holds `#import <Intents/Intents.h>`, and --classes is one class name per line, the classes of
--     exactly one release.
--
-- The tables this reads are in intents-data.lua. The committed objects it writes are the reference
-- the output was checked byte for byte against; the regular expressions it used are the hand-written matchers below.

import("core.base.json")
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})

local D = import("intents-data", {rootdir = os.scriptdir()}).data()

-- Text helpers ---------------------------------------------------------------------------------------------------------

local function is_word(char)
    return char ~= "" and char:match("[%w_]") ~= nil
end

local function trim(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function starts_with(text, prefix)
    return text:sub(1, #prefix) == prefix
end

-- Python's str.split(":"): every piece, a trailing empty one included.
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

-- Python's str.split() with no argument: the whitespace-separated words.
local function words_of(text)
    local found = {}
    for word in text:gmatch("%S+") do
        table.insert(found, word)
    end
    return found
end

-- Replaces every \bword\b, left to right, with repl.
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

-- Removes every match of <open>[^<open><close>]*<close>, the innermost bracketed run without another bracket of the
-- same kind inside it, left to right: Python's re.sub(r"<[^<>]*>", "", text) and its (...) twin.
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

-- Python's re.sub(r"_\s*(Nonnull|Nullable)\b", "", text).
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

-- Finds the next match of the SDK macro pattern \b[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+\b at or after from, as first and last
-- (inclusive) positions, or nil.
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

-- A type as the compiler spells it, without the SDK's macros or its nullability.
local function clean(text)
    text = remove_nullability(text or "")
    while true do
        local first, last = find_macro(text, 1)
        if not first then
            return trim(text)
        end
        -- keep_from is the first character that survives the macro: the one after it, or after its argument list
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

-- A type as a definition spells it: the macros off, nullability kept, spacing even. A lightweight generic parameter is
-- the caller's type and not this package's: an INObjectSection<ObjectType> is an INObjectSection here.
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

-- The name a type is written with, its pointers and qualifiers off.
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

-- Properties whose ownership is copy: the setter copies, the rest retain.
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

-- Python's sorted() of a set or dict's keys.
local function sorted_keys(map)
    local keys = {}
    for key in pairs(map) do
        table.insert(keys, key)
    end
    byteorder.sort(keys)
    return keys
end

-- The @synthesize, @dynamic and method-definition lines the answer is read back from.
local function match_synthesised(line)
    return line:match("^%s*@synthesize ([%a_][%w_]*)%s*=")
end

local function match_dynamic(line)
    return line:match("^%s*@dynamic ([%a_][%w_]*)%s*;")
end

-- ^\s*([-+]) \(([^)]*)\)(.*)$ as a triple: the sign, the type, the rest.
local function match_definition(line)
    local sign, kind, rest = line:match("^%s*([%-%+]) %(([^%)]*)%)(.*)$")
    return sign, kind, rest
end

-- The selector parts of a definition: each identifier followed by ":(", in order.
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

-- The `ALONE` reason text, from the generator. A class that must be an object file of its own, with the measurement
-- that says why.
local ALONE_REASON = [==[
%(name)s is an object file of its own because a release below this group's own already
exports it: the armv7s cache of iOS %(below)s has it, and the caches of this group's own
release do not have the classes it would share an object with. One object that defines
both is what the band check refuses, and a one-class object is consistent in every band:
the release that has it re-exports the object, and every release that does not keeps it.
The measurement is tools/intents/measure-group.lua, and the reason is the comment above
ALONE in the generator that wrote this file.
]==]

-- The three answers a resolution result gives.
local SUCCESS_VALUE = "successWithResolvedValue:"
local DISAMBIGUATION_VALUE = "disambiguationWithValueToDisambiguate:"
local CONFIRMATION_VALUE = "confirmationRequiredWithValueToConfirm:"

-- The SYSTEM framework prefixes: a type of one of these names is a class the release carries.
local SYSTEM_PREFIXES = {"NS", "CL", "CF", "CG", "UI", "WK", "CA", "AV", "SK", "MK", "QL", "AL", "SCN", "PH", "MP"}

local function is_system(name)
    for _, prefix in ipairs(SYSTEM_PREFIXES) do
        if name:sub(1, #prefix) == prefix and name:sub(#prefix + 1, #prefix + 1):match("%u") then
            return true
        end
    end
    return false
end

-- Interfaces ---------------------------------------------------------------------------------------------------------

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

-- The method of this selector the interface declares, or nil.
local function method_of(interface, selector)
    for _, candidate in ipairs(interface.methods) do
        if candidate.name == selector then
            return candidate
        end
    end
    return nil
end

-- The initialiser the header marks as the class's own, and its parameters: a subclass's own designated initialiser is
-- not what a subclass chains to, it chains to the one its superclass declares.
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

-- Where a property of a superclass is declared, and whether it can be written.
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

-- Which class of the chain declares the property.
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

-- The read-only values of a superclass that this class's own initialisers name. The class keeps its own copy, in its
-- own ivar, and answers the getter with it.
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

-- The zero a parameter of this type takes when a superclass initialiser is called without the value.
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

-- The superclass chain's own -init, reached through its IMP, when the SDK marks it unavailable.
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

-- Whether the -init a bare -init would chain to is the marked one, and not this class's own.
local function own_init_blocked_here(interface, interfaces)
    local seen, name = {}, interface
    while name and not seen[name.name] do
        seen[name.name] = true
        local declared = method_of(name, "init")
        if declared and has_attr(declared, "UnavailableAttr") then
            -- the header's own "params" key is never written by clang, so only its absence is ever seen here
            return name.name ~= interface.name or (declared.params ~= nil and #declared.params == 0)
        end
        name = interfaces[name.superclass]
    end
    return false
end

-- Which of the two shapes a header has for -init this class is, or nil for no -init at all.
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

-- Whether a class name is a resolution result, by the superclass chain the SDK gives it.
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

-- The parameter a superclass initialiser's keyword is for, when the header's own names differ.
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

-- A method's selector as a definition spells it: each keyword with the type and name of its parameter.
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

-- The body of an initialiser: every parameter kept, in the state the class really has. A parameter that names a
-- property of this class goes in that class's own ivar. One that names a writable property of a superclass goes
-- through its setter, after the class's own state is in place. One that names a read-only property of a superclass
-- can only be kept by the superclass's own designated initialiser, so that is what is called.
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
        -- A parameter the header does not mark nullable cannot be handed a nil: the port refuses to chain rather than
        -- make a call the SDK forbids.
        for _, parameter_entry in ipairs(parameters_of(parent)) do
            if ends_with_pointer(spelled(parameter_entry[1])) then
                return nil
            end
        end
        local pieces = {}
        -- the parent's keywords: its selector split at the colons, without the empty piece after the last one
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

-- Factories -----------------------------------------------------------------------------------------------------------

-- The class's own factory for one item, for a factory that answers a collection of them: the singular is looked for by
-- name among the class's own methods, and the whole superclass chain is asked.
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

-- The body of a resolution result's class method, or nothing: a list of lines, or false when a collection has no
-- single-item factory to map with.
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

-- Reports ---------------------------------------------------------------------------------------------------------------

-- What the emitted @implementation of one class carries, read back out of the text. The registry is written from this,
-- not from the declarations the generator read, so an entry can never say a member is implemented when the file does
-- not implement it.
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

-- AST ------------------------------------------------------------------------------------------------------------------

-- The translation unit's own declarations, in order. clang writes one JSON object for the whole translation unit, so the
-- declarations are its `inner`, one entry per header.
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

-- Every real @interface, @protocol and typedef name in a dump. A category on a class is part of that class's surface,
-- so its properties and methods are folded into the class here.
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

-- The names a property answers to: its own, and the getter the header gives it.
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

-- The properties a protocol requires, so a conformer really conforms.
local function required_properties(protocol)
    local found = {}
    for _, member in ipairs(protocol.inner or {}) do
        if member.kind == "ObjCPropertyDecl" and member.name and not has_attr(member, "OptionalAttr") then
            found[member.name] = member
        end
    end
    return found
end

-- The protocols a class really conforms to, its own and its superclasses'.
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

-- The class a type names that this delivery does not carry, or nil. Two ways a type names a class that is not here: an
-- Intents class of a group this delivery does not carry, and a class the SDK's headers only forward declare.
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

-- The file's header: the banner every generated object file opens with.
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

-- The @implementation of one generated class, and what it answers of the class's surface. The second value is the
-- report the registry is written from: what the emitted text carries, read back out of the text.
local function implementation(interface, protocols, carried, intents, interfaces, forward)
    local resolution = resolution_result(interface.superclass, interfaces)
    local conformed = conformed_by(interface, interfaces)
    local name = interface.name

    -- A class property is dropped here and was dropped silently before: it reached neither `stored`, `dynamic` nor
    -- `skipped`, so no cause was recorded and the registry fell back to the group's blanket reason. It is recorded as
    -- dynamic under class_property instead, and an EXTRA_METHODS body that answers it is what makes it not dynamic.
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

    -- clang dumps a property's accessors as declarations of their own, so every method in an @interface is a
    -- declaration: the ones that are a property's getter or setter are never given a body here.
    local accessors = {}
    for _, method in ipairs(interface.methods) do
        local selector = method.name or ""
        if own[selector] ~= nil and #parameters_of(method) == 0 then
            accessors[selector] = true
        else
            -- The Python pattern is "^set(%a[%w_]*):$" read as a regular expression, whose "%a" is a literal percent
            -- sign, so it matches a selector that spells one and none does. It is kept as written.
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
            -- The runtime already holds the class, so there is no storage an ivar could keep the class in.
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

    -- The read-only values of a superclass that this class's own initialisers take: the class keeps a copy in its own
    -- ivar, the initialiser stores the value it was given in it, and the getter answers with it.
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

    -- The properties a conformed protocol requires and the class does not declare itself.
    for _, protocol_name in ipairs(conformed) do
        local protocol = protocols[protocol_name]
        -- NSObject's own properties are the root superclass's and are not this class's to synthesise.
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

    -- A property a category of the class declares is carried by a category of Charon's own, because clang will not
    -- let a class implementation synthesise one.
    local by_category = {}
    for _, entry in ipairs(members) do
        local category = entry[3].category
        if category then
            by_category[category] = by_category[category] or {}
            table.insert(by_category[category], entry)
        end
    end

    -- Every ivar of the class, the ones a category declared included, is in one class extension in this file, so the
    -- class's own initialisers reach all of them and a category implementation has a place to synthesise from.
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
        -- A class this package writes by hand: this file emits no method of it, so the shape of its -init is the shape
        -- its header has, which is what init_shape_of reads here.
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
            -- a value this class keeps a copy of for a superclass: a pointer is copied, a value is retained
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

    -- A class whose own header marks -init NS_UNAVAILABLE still answers one, and the SYSTEM does: measured on the
    -- host's own Intents, a compile-time call does not build, which is the point, and the marked classes each returned
    -- an object with every property present and nil. So the port emits -init too: refusing to define the method leaves
    -- a caller that sends it reaching a NULL IMP. The superclass's own -init is reached through its IMP, not by name.
    local init_shape = init_shape_of(interface, interfaces)
    if init_shape == "designated" then
        -- The header declares -init as the class's designated initialiser and nothing in the chain marks it unavailable,
        -- so the ordinary body is the right one: the superclass's own -init, which is what the identifier an
        -- interaction donated with this intent is keyed by is made by.
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

    -- The initialisers: each one a body the generator writes from the header, or one written by hand.
    for _, method in ipairs(interface.methods) do
        local selector = method.name or ""
        if method.instance ~= false and not has_attr(method, "UnavailableAttr") and starts_with(selector, "init")
                and selector:find(":", 1, true) and selector ~= "initWithCoder:" then
            -- An initialiser that takes a value this delivery does not carry is not given a body: a body that dropped
            -- the value would answer with a class that looks filled and is not. The header's mark stays on it.
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

    -- The methods that are not initialisers.
    for _, method in ipairs(interface.methods) do
        local selector = method.name or ""
        -- A member the header marks UNAVAILABLE is not answered, and the cause is the mark: a port cannot call it.
        local hand_written = D.extra_methods[name .. " " .. selector] ~= nil
            and not (starts_with(selector, "init") and selector:find(":", 1, true) ~= nil)
        local skip = false
        if has_attr(method, "UnavailableAttr") and D.extra_methods[name .. " " .. selector] == nil
                and accessors[selector] == nil and own[selector] == nil then
            table.insert(skipped, {selector, "unavailable"})
            skip = true
        end
        if not skip then
            -- An accessor whose return type is a class this package does not carry has nothing to keep its value in,
            -- so a body would not compile. A hand-written body is not generated from that type and is not subject to
            -- this guard.
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
        -- A class whose header marks -init unavailable, its own or the one [super init] would reach, cannot spell
        -- [super init] in a file that reads that header, so the superclass's own -init is called by name instead.
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

    -- Charon's own readers for this class's stores, inside the @implementation and after everything the header
    -- declares: emitted after the @end, clang reads a method declaration with no @implementation in scope and stops.
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

    -- A property the SDK declares in a category of the class is answered by accessors in a category of Charon's own.
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

    -- A class property is answered by its +accessor, the only thing in the emitted text that carries the name. So it is
    -- matched against an accessor that was actually written: +name is the shape, and it has to be in the emitted methods.
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

-- JSON, as json.dump(indent=1, sort_keys=True) writes the report -----------------------------------------------------

local function json_string(text)
    local escaped = text:gsub("\\", "\\\\"):gsub('"', '\\"')
    return '"' .. escaped .. '"'
end

-- entries are {key, text} pairs, text already rendered; a key sorts in the order the caller gives
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

-- The command line -----------------------------------------------------------------------------------------------------

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
        -- The names the port's own SDK does not declare, from the newer SDK that does. A class both declare is taken
        -- from the port's SDK: its declaration is the one the implementation compiles against.
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

    -- One file per class that must be alone, named for the release below the group's own that already exports it, so
    -- the name says which band re-exports the object and which keeps it.
    for _, entry in ipairs(alone) do
        local name, below = entry[1], entry[2]
        local file = out_dir .. "/" .. name .. below .. ".m"
        local body, report = implementation(interfaces[name], protocols, carried, intents, interfaces, forward)
        local text = {banner(file:match("([^/]*)$"), 1, options.release, #report.dynamic)}
        -- The file says why it is alone, in a comment: a line that starts with a hash at column zero would be a
        -- preprocessing directive, so every line of the reason is prefixed.
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

-- The report of every class, keyed by name, as json.dump(answered, indent=1, sort_keys=True) writes it.
function report_json_top(answered)
    local entries = {}
    for _, name in ipairs(sorted_keys(answered)) do
        table.insert(entries, {name, report_json(answered[name], 1)})
    end
    return json_object(entries, 0) .. "\n"
end
