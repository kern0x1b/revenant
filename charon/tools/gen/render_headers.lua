-- The headers of one framework, rendered from the typed columns of the declaration IR (design-foundation.md 5.1), in our own layout.
-- Pure: the rows of a framework and the definitions of the whole IR go in, the files' text comes out; cmd_headers.lua reads and
-- writes. The columns read are 1 to 16 (framework, kind, usr, container, name, side, header, line, availability, nullability, type,
-- params, attrs, value, declhash, availhash) and the three facts 19 to 21 (typeparams, anon, category). The declaration as written (17)
-- and the messages (18) are never read, and no comment and no SDK header text is: the text is ours, from the typed cells only.
--
-- defs_of(all_rows) indexes the whole IR by the names it defines (an import is resolved from it). render(framework, rows, defs, has_map,
-- has_sdk_headers, usr_dirs) returns
-- { files = {path under the framework's folder -> text}, counts = {...} }, the paths
-- being Headers/<header> and Modules/module.modulemap (the module map only when has_map: the SDK's framework has one). has_sdk_headers
-- says the SDK's folder holds headers: a framework with no module map and no declaration then keeps one empty header, so decls can
-- read the folder when the fallback list names it. usr_dirs is cmd_headers' usr_dirs_of: the import prefix of each usr/include module
-- (prefix) and the umbrella header of a folder that has one (umbrella). compare(ir_rows,
-- decl_rows) matches the IR's rows with the rows decls prints for the same framework, by the key (kind, usr, container, name,
-- side), and groups each difference by its cause.

local sha256 = import("sha256", {anonymous = true})

local COL = {framework = 1, kind = 2, usr = 3, container = 4, name = 5, side = 6, header = 7, line = 8, avail = 9,
             nullability = 10, type = 11, params = 12, attrs = 13, value = 14, declhash = 15, availhash = 16,
             typeparams = 19, anon = 20, category = 21}

-- Nullability letters of column 10 (n nonnull, l nullable, L nullable result, u unspecified, - none): the declarator keyword, and the
-- property attribute.
local DECLARATOR = {n = "_Nonnull", l = "_Nullable", L = "_Nullable", u = "_Null_unspecified"}
-- r is not an IR letter: a property the render marks null_resettable (see render's getters).
local ATTRIBUTE = {n = "nonnull", l = "nullable", L = "nullable", u = "null_unspecified", r = "null_resettable"}

-- Every generated header is a system header, as the SDK's framework headers are (they are read through the sysroot). clang gives a
-- typedef in a header that is not a system header a USR with the file's name (c:File.h@T@Name), where the SDK's is c:@T@Name, and
-- the declhash covers the USR (measured on Speech: the enum typedefs differ until the pragma is there).
local SYSTEM_HEADER = "#pragma clang system_header"

-- The kinds that define a name a type can use: the definitions an import is resolved from.
local DEFINING = {interface = true, protocol = true, typedef = true, enum = true, struct = true, union = true}
-- The rows that are not declarations of the headers: the IR's bookkeeping. Accessors are not rendered (clang synthesises them).
local BOOKKEEPING = {census = true, ["census-file"] = true, unparsed = true, meta = true}
-- The words of the C type grammar and of Objective-C's type keywords: never a name a file has to declare.
local KEYWORDS = {void = true, char = true, int = true, long = true, short = true, unsigned = true, signed = true, float = true,
                  double = true, const = true, volatile = true, _Bool = true, bool = true, id = true, Class = true, SEL = true,
                  instancetype = true, struct = true, union = true, enum = true, _Nullable = true, _Nonnull = true,
                  _Null_unspecified = true, _Nullable_result = true, __kindof = true}

-- The first n cells of a line. The cells after them are not split, so the declaration and the message are never read.
local function split_cells(line, n)
    local cells, pos = {}, 1
    for i = 1, n do
        local tab = string.find(line, "\t", pos, true)
        if tab then
            cells[i] = string.sub(line, pos, tab - 1)
            pos = tab + 1
        else
            cells[i] = string.sub(line, pos)
            pos = #line + 2
        end
    end
    return cells
end

-- The pieces of a text between a plain separator.
local function split(text, sep)
    local out, pos = {}, 1
    while true do
        local at = string.find(text, sep, pos, true)
        if not at then
            out[#out + 1] = string.sub(text, pos)
            return out
        end
        out[#out + 1] = string.sub(text, pos, at - 1)
        pos = at + #sep
    end
end

local function trim(text)
    return (string.gsub(string.gsub(text, "^%s+", ""), "%s+$", ""))
end

-- A parameter entry ("NSURL * languageModel") as its type and its name. The name is the last word of the entry, unless that word is
-- a C word ("unsigned int") or the entry ends in a sign ("NSURL *", "void (^)(NSError *)"): then the parameter is unnamed.
local function parameter(entry)
    entry = trim(entry)
    local name = string.match(entry, "([%a_][%w_]*)$")
    if name == nil or KEYWORDS[name] or name == entry then return entry, "" end
    return trim(string.sub(entry, 1, #entry - #name)), name
end

-- The parameters of a row, each { type, name, nullability }; the nullability letters are one per parameter, comma separated.
local function parameters_of(params, nullability)
    local out = {}
    if params == "-" then return out end
    local nulls = split(nullability, ",")
    for i, entry in ipairs(split(params, " | ")) do
        local ty, name = parameter(entry)
        out[i] = {type = ty, name = name, nullability = nulls[i] or "-"}
    end
    return out
end

local function split_suffix(ty)
    if string.sub(ty, -1) ~= ")" then return ty, "" end
    local depth = 0
    for i = #ty, 1, -1 do
        local ch = string.sub(ty, i, i)
        if ch == ")" then
            depth = depth + 1
        elseif ch == "(" then
            depth = depth - 1
            if depth == 0 then return trim(string.sub(ty, 1, i - 1)), string.sub(ty, i) end
        end
    end
    return ty, ""
end

-- A declarator: the type with its name and nullability. A keyword follows a pointer or a typedef name ("NSURL * _Nonnull name"),
-- and sits inside a block's declarator ("void (^ _Nullable name)(...)"). A name of "" is the bare type of a parameter or a result.
local function declare(ty, name, nullability)
    local keyword = DECLARATOR[nullability]
    -- a block (^) or a function pointer (*) puts the name, and its nullability, inside the declarator: void (^ _Nullable name)(...).
    -- The IR's type may already carry the keyword in there (void (^ _Nullable)(BOOL)): then it is kept, not added again.
    local s, e, mark, existing = string.find(ty, "%(([%^%*])%s*([_%a]*)%s*%)")
    -- a block inside a generic's arguments (NSArray<void (^)(void)> *) is not the declarator: the name follows the pointer
    local _, opened = string.gsub(string.sub(ty, 1, (s or 1) - 1), "<", "")
    local _, closed = string.gsub(string.sub(ty, 1, (s or 1) - 1), ">", "")
    if s and opened == closed then
        local kw = existing ~= "" and existing or keyword
        local inner = (kw and (" " .. kw) or "") .. (name ~= "" and ((kw and " " or "") .. name) or "")
        return string.sub(ty, 1, s) .. mark .. inner .. string.sub(ty, e)
    end
    -- a vector type's attribute follows its name: typedef float Name __attribute__((ext_vector_type(3))), not float __attribute__ Name(...)
    local vector, attribute = string.match(ty, "^([^()]-)%s*(__attribute__%(%(.*%)%))$")
    if vector and vector ~= "" and name ~= "" then return vector .. " " .. name .. " " .. attribute end
    -- a function type (a typedef's: typedef void Name(NSException * _Nonnull)) has its name before the parameter list
    local result, parameters = split_suffix(ty)
    if parameters ~= "" and name ~= "" then return result .. " " .. name .. parameters end
    -- an array's dimensions follow the name: unsigned long name[5]
    -- (the nullability of an array parameter is its size's: id _Nullable [_Nonnull] buffer, and float name[_Nonnull 2] when sized)
    local dims = string.find(ty, "[", 1, true)
    if dims then
        local sized = string.sub(ty, dims)
        if keyword and string.find(sized, keyword, 1, true) == nil then
            local size = string.match(sized, "^%[(.+)%]$")
            sized = size and ("[" .. keyword .. " " .. size .. "]") or ("[" .. keyword .. "]")
        end
        return trim(string.sub(ty, 1, dims - 1)) .. " " .. name .. sized
    end
    local out = ty
    if keyword then out = out .. " " .. keyword end
    if name ~= "" then out = out .. " " .. name end
    return out
end

-- A method's result. instancetype carries its nullability as a prefix: "nonnull instancetype".
local function result_of(ty, nullability)
    if ty == "instancetype" and ATTRIBUTE[nullability] then return ATTRIBUTE[nullability] .. " instancetype" end
    return declare(ty, "", nullability)
end

-- A function's type is "RESULT (ARGUMENT TYPES)": the result, and the argument list (the text of the last balanced parentheses).
-- The availability of column 9 as attributes. *unavailable and *deprecated are for every platform; a platform token is
-- platform=introduced/deprecated/obsoleted/unavailable, - when absent, and 1 for an unavailable platform. Attributes come in the
-- order of the column.
local function availability(text)
    if text == "-" then return "" end
    local out = {}
    for token in string.gmatch(text, "[^,]+") do
        -- a flag for every platform leads the column, alone or before the first platform ("*unavailable ios=10.0/-/-/0")
        local star, rest = string.match(token, "^%*(%a+)%s*(.*)$")
        if star == "unavailable" or star == "deprecated" then
            out[#out + 1] = "__attribute__((" .. star .. "))"
            token = rest
        end
        if token ~= "" then
            local plat, intro, dep, obs, flag = string.match(token, "^([^=]+)=([^/]+)/([^/]+)/([^/]+)/(%d+)$")
            assert(plat, "availability token: " .. token)
            local parts = {}
            if flag == "1" then parts[#parts + 1] = "unavailable" end
            if intro ~= "-" then parts[#parts + 1] = "introduced=" .. intro end
            if dep ~= "-" then parts[#parts + 1] = "deprecated=" .. dep end
            if obs ~= "-" then parts[#parts + 1] = "obsoleted=" .. obs end
            if #parts > 0 then
                out[#out + 1] = "__attribute__((availability(" .. plat .. "," .. table.concat(parts, ",") .. ")))"
            end
        end
    end
    return table.concat(out, " ")
end

-- The names a type text uses, into out: name -> "def" (its definition is needed: a typedef, a tag, a non-pointer use), "class" (a
-- word followed by *: a forward declaration is enough), or "protocol" (a word inside <...>).
-- The number of type arguments of a generic class's use (NSArray<A, B *> has two): the commas at the top level of the <...> at open.
local function arity_of(text, open)
    local depth, count = 0, 1
    for i = open, #text do
        local c = string.sub(text, i, i)
        if c == "<" then
            depth = depth + 1
        elseif c == ">" then
            depth = depth - 1
            if depth == 0 then return count end
        elseif c == "," and depth == 1 then
            count = count + 1
        end
    end
    return count
end

-- Whether the IR defines the name as a kind (protocol, class, ...).
local function defined_as(defs, name, kind)
    for _, def in ipairs(defs[name] or {}) do
        if def.kind == kind then return true end
    end
    return false
end

-- Whether a generic class bounds one of its type parameters (its typeparams cell has a bound other than id). clang checks such a
-- bound through a type argument's superclasses and protocols, so the argument must be complete, not forward-declared.
local function bounded_class(defs, name)
    for _, def in ipairs(defs[name] or {}) do
        if def.kind == "interface" and def.typeparams ~= nil and def.typeparams ~= "-" then
            for _, entry in ipairs(split(def.typeparams, " | ")) do
                if string.match(entry, "^[^:]+:(.*)$") ~= "id" then return true end
            end
        end
    end
    return false
end

-- The names a type text uses, with how each is used (see note). defs is the IR's definitions: a name in <...> after a class is a
-- protocol when the IR defines it as one (UIResponder<UITextInput> *, a class qualified by protocols), else a type argument.
local function type_names(text, out, defs)
    -- a text that uses a class with a bounded parameter: the names in its <...> are complete definitions (see bounded_class)
    local bounded_use = false
    for name in string.gmatch(text, "([%a_][%w_]*)%s*<") do
        if bounded_class(defs, name) then bounded_use = true end
    end
    for start, word in string.gmatch(text, "()([%a_][%w_]*)") do
        if not KEYWORDS[word] then
            local before = string.match(string.sub(text, 1, start - 1), "(%S+)%s*$") or ""
            local after = string.match(text, "^%s*(.)", start + #word) or ""
            -- the word that owns the <...> this name is in (id for a protocol list, NSArray for NSArray<NSString *>)
            local owner = string.match(string.sub(text, 1, start - 1), "([%w_]+)%s*<[^<>]*$")
            local kind
            if before == "struct" or before == "union" or before == "enum" then
                kind = "def"
            elseif after == "<" then
                local open = string.find(text, "<", start + #word, true)
                local first = string.match(text, "^<%s*([%a_][%w_]*)", open)
                if first and defined_as(defs, first, "protocol") then
                    -- a class qualified by protocols (UIResponder<UITextInput> *): a forward declaration of the class is enough
                    kind = "class"
                else
                    -- a generic class: a forward declaration with its arity (@class NSArray<T1>;) is enough for a use as a pointer,
                    -- and an import would make the class's header and its users include each other
                    kind = "generic:" .. arity_of(text, open)
                end
            elseif after == "*" then
                kind = (bounded_use and owner ~= nil) and "def" or "class"
            elseif owner ~= nil then
                -- inside <...>: a protocol list (id<P>, or P of a class qualified by it) names a protocol; any other bare name there is
                -- a type argument, a type parameter of the class (never a declaration of its own), or a value name of the IR
                kind = (owner == "id" or defined_as(defs, word, "protocol")) and "protocol" or "def"
                if bounded_use and word ~= "id" then kind = "def" end
            else
                kind = "def"
            end
            if out[word] ~= "def" then out[word] = kind end
        end
    end
    return out
end

-- The names of the whole IR: name -> the rows that define it (framework and header), in IR order.
function defs_of(rows)
    local defs = {}
    -- the enums the IR gives constants (an enum with none is a declaration of its fixed type: see render's enum branch)
    local with_constants = {}
    for _, row in ipairs(rows) do
        if row[COL.kind] == "enumconst" then with_constants[row[COL.container]] = true end
    end
    for _, row in ipairs(rows) do
        local name = row[COL.name]
        local defines = DEFINING[row[COL.kind]] and (row[COL.kind] ~= "enum" or with_constants[name])
        if defines and row[COL.header] ~= "-" and name ~= "-" then
            local list = defs[name] or {}
            list[#list + 1] = {framework = row[COL.framework], header = row[COL.header], kind = row[COL.kind],
                typeparams = row[COL.typeparams], row = row}
            defs[name] = list
        end
    end
    return defs
end

-- The definition a name is imported from: the framework's own when it has one, else the first one of another framework.
local function pick(list, framework)
    if list == nil then return nil end
    for _, def in ipairs(list) do
        if def.framework == framework then return def end
    end
    return list[1]
end

-- The definition a header imports for a name it uses: one that another header gives, the framework's own first. A typedef of a tag
-- (typedef enum X X;) is not the tag's definition, and the header that has it may come first in the IR (PDFKit's PDFDocument.h sorts
-- before PDFSelection.h, which defines the enum): the typedef's own row is skipped, and nil when no other header gives the name.
-- A header of another framework with the same file name (WebKit and UIKit both have NSAttributedString.h) is another header.
local function pick_other(list, framework, header)
    local other = nil
    for _, def in ipairs(list or {}) do
        if def.framework ~= framework or def.header ~= header then
            if def.framework == framework then return def end
            other = other or def
        end
    end
    return other
end

-- The interface that defines a class, the one whose typeparams cell gives the class's type parameters (the framework's own when it
-- has one). nil when the IR defines no interface of that name.
local function generic_definition(defs, name, framework)
    local interfaces = {}
    for _, def in ipairs(defs[name] or {}) do
        if def.kind == "interface" then interfaces[#interfaces + 1] = def end
    end
    return pick(interfaces, framework)
end

-- A framework is imported by its last name segment (Outer/Inner is Inner).
local function module_name(framework)
    return string.match(framework, "([^/]+)$")
end

-- The quoted name of another header of this framework, from the folder of the header that includes it: a quoted name is looked up in
-- the including file's folder first, so BNNS/bnns.h includes bnns_structures.h (the SDK's form), and a top-level header is ../ away.
local function name_from(header, includer)
    local target, from = {}, {}
    for part in string.gmatch(header, "[^/]+") do target[#target + 1] = part end
    for part in string.gmatch(includer, "[^/]+") do from[#from + 1] = part end
    table.remove(from)
    local common = 0
    while common < #from and common + 1 < #target and from[common + 1] == target[common + 1] do common = common + 1 end
    local parts = {}
    for _ = common + 1, #from do parts[#parts + 1] = ".." end
    for i = common + 1, #target do parts[#parts + 1] = target[i] end
    return table.concat(parts, "/")
end

-- The #import of a definition, or nil. A definition whose header is an absolute path is one of the SDK's own headers: a framework's
-- Headers/ folder (<Name>/<header>, the innermost framework of a nested path) or usr/include (<header>). This framework's own header
-- is quoted (from the including header's folder), another framework's is <Name/header>.
local function import_of(def, framework, header, usr_dirs)
    local dir = usr_dirs.prefix[def.framework]
    -- a module map's prefix counts only where the header is in that folder (the 16.4 SDK's Darwin module names sys/_pthread, which has no socket.h)
    if dir and usr_dirs.exists(dir .. "/" .. def.header) then return "#import <" .. dir .. "/" .. def.header .. ">" end
    if usr_dirs.bare[def.framework] then return "#import <" .. def.header .. ">" end
    if string.sub(def.header, 1, 1) == "/" then
        local name, rest = string.match(def.header, "([^/]+)%.framework/Headers/(.+)$")
        if name then return "#import <" .. name .. "/" .. rest .. ">" end
        -- a typedef clang's own headers give (va_list in __stdarg_va_list.h, size_t in __stddef_size_t.h) is imported by the public
        -- header clang names it for: __<public>_<name>.h is <public>.h
        local public = string.match(def.header, "/include/__(%a+)_[^/]*%.h$")
        if public then return "#import <" .. public .. ".h>" end
        rest = string.match(def.header, "/usr/include/(.+)$")
        if rest then return "#import <" .. (usr_dirs.umbrella[string.match(rest, "^([^/]+)/") or ""] or usr_dirs.target(rest)) .. ">" end
        -- a fragment of the compiler's own headers: __stddef_size_t.h is part of stddef.h, which is what the SDK's headers include
        local stem = string.match(def.header, "/include/__(%a+)_[^/]+%.h$")
        if stem then return "#import <" .. stem .. ".h>" end
        return nil
    end
    if def.framework == framework then
        if def.header == header then return nil end
        return '#import "' .. name_from(def.header, header) .. '"'
    end
    -- a usr/include module no module map names (pre-26 SDKs): the folder that holds the header is its prefix
    local folder = usr_dirs.folder and usr_dirs.folder[def.header]
    if folder and not usr_dirs.sdk_framework(def.framework) then return "#import <" .. usr_dirs.target(folder .. "/" .. def.header) .. ">" end
    -- a private framework's header is not in the port (and the SDK's own headers do not import it): the public framework whose umbrella
    -- re-exports it is imported instead, by its umbrella
    local public = usr_dirs.reexport and usr_dirs.reexport[def.framework]
    if public then return "#import <" .. public .. "/" .. public .. ".h>" end
    return "#import <" .. module_name(def.framework) .. "/" .. def.header .. ">"
end

-- The swift_name attribute the SDK's apinotes give a class ("interface") or a protocol ("protocol") of a framework, as a line in front of
-- the @interface or @protocol (clang reads an attribute there; after the name it is refused), or "" when no apinotes entry gives one.
-- The IR records no Swift name, so the apinotes are read by the headers command (usr_dirs.swift).
local function swift_attribute(usr_dirs, framework, kind, name)
    local names = usr_dirs and usr_dirs.swift and usr_dirs.swift[framework] and usr_dirs.swift[framework][kind]
    local swift = names and names[name]
    if swift == nil then return "" end
    return '__attribute__((swift_name("' .. swift .. '")))\n'
end

-- The owner of a member by its USR: cs:<class> or pl:<protocol>; a category member's class is its (cs) name too.
local function owner_of(usr)
    local name = string.match(usr, "%(cs%)([^%(]+)")
    if name then return "cs:" .. name end
    name = string.match(usr, "%(pl%)([^%(]+)")
    if name then return "pl:" .. name end
    return nil
end

-- The owner of a conformance by its usr (the class, class extension or protocol that lists it): cs:<class>, cs:<class> for an extension's
-- (ext) name, or pl:<protocol>. The same name can be both a class and a protocol, so the kind is part of the key.
local function conformance_owner(usr)
    local name = string.match(usr, "%(cs%)([^%(]+)") or string.match(usr, "%(ext%)([^%(@]+)")
    if name then return "cs:" .. name end
    name = string.match(usr, "%(pl%)([^%(]+)")
    if name then return "pl:" .. name end
    return nil
end

local function class_of(usr)
    return string.match(usr, "%(cs%)([^%(]+)")
end

local function is_optional(row)
    for attr in string.gmatch(row[COL.attrs], "[^,]+") do
        if attr == "optional" then return true end
    end
    return false
end

-- The USR of a property's getter, which is the accessor row's USR: its selector is the getter= attribute's when the property has one
-- (ready with getter=isReady is (im)isReady), else the property's own name. A class property's getter is a class method ((cm)).
local function getter_of(row)
    local head, property, name = string.match(row[COL.usr], "^(.*)%((c?py)%)([^()]*)$")
    assert(head, "a property's USR has no (py) or (cpy) selector: " .. row[COL.usr])
    local method = property == "cpy" and "(cm)" or "(im)"
    for attr in string.gmatch(row[COL.attrs], "[^,]+") do
        local selector = string.match(attr, "^getter=(.+)$")
        if selector then return head .. method .. selector end
    end
    return head .. method .. name
end

-- The pointers of a type that are not inside its <...> (a generic's arguments): NSSet<ARReferenceImage *> * has one.
local function top_level_pointers(ty)
    local depth, count = 0, 0
    for i = 1, #ty do
        local c = string.sub(ty, i, i)
        if c == "<" then
            depth = depth + 1
        elseif c == ">" then
            depth = depth - 1
        elseif c == "*" and depth == 0 then
            count = count + 1
        end
    end
    return count
end

-- A method or a property as its declaration (without the section it sits in).
local function member_text(row)
    local avail = availability(row[COL.avail])
    local suffix = avail ~= "" and (" " .. avail) or ""
    if row[COL.kind] == "property" then
        local attrs, has_class, has_nsobject = {}, false, false
        for attr in string.gmatch(row[COL.attrs], "[^,]+") do
            if attr == "class" then has_class = true end
            if attr == "NSObject" then
                has_nsobject = true
            elseif attr ~= "optional" and attr ~= "-" then
                attrs[#attrs + 1] = attr
            end
        end
        -- a nullable attribute is rejected on a multi-level pointer (float * _Nonnull * buffer): its keyword goes in the declarator. The
        -- pointers of the type that count are the top-level ones: NSSet<ARReferenceImage *> * is one pointer, and null_resettable has
        -- no keyword, so it stays an attribute
        local keyword = "-"
        if top_level_pointers(row[COL.type]) > 1 and DECLARATOR[row[COL.nullability]] then
            keyword = row[COL.nullability]
        elseif ATTRIBUTE[row[COL.nullability]] then
            attrs[#attrs + 1] = ATTRIBUTE[row[COL.nullability]]
        end
        if row[COL.side] == "+" and not has_class then attrs[#attrs + 1] = "class" end
        local head = #attrs > 0 and ("@property (" .. table.concat(attrs, ", ") .. ") ") or "@property "
        -- the NSObject attribute follows the name (the SDK's form): it makes a CF pointer an object type for retain or strong
        local name = has_nsobject and (row[COL.name] .. " __attribute__((NSObject))") or row[COL.name]
        return head .. declare(row[COL.type], name, keyword) .. suffix .. ";"
    end
    local sign = row[COL.side] == "+" and "+" or "-"
    local result_nullability, param_nullability = string.match(row[COL.nullability], "^([^|]*)|(.*)$")
    assert(result_nullability, "nullability column without |: " .. row[COL.nullability])
    local params = parameters_of(row[COL.params], param_nullability)
    local selector = row[COL.name]
    local result = "(" .. result_of(row[COL.type], result_nullability) .. ")"
    if #params == 0 then
        return sign .. " " .. result .. selector .. suffix .. ";"
    end
    local pieces = {}
    for piece in string.gmatch(selector, "[^:]*:") do pieces[#pieces + 1] = piece end
    assert(#pieces == #params, "selector " .. selector .. " has " .. #pieces .. " parts for " .. #params .. " parameters")
    local out = {sign .. " " .. result}
    for i, param in ipairs(params) do
        out[#out + 1] = pieces[i] .. "(" .. declare(param.type, "", param.nullability) .. ")" .. param.name
    end
    return table.concat(out, " ") .. suffix .. ";"
end

-- The member declarations of one owner: the required ones, then an @optional section when some are optional.
local function members_text(list)
    local required, optional = {}, {}
    for _, row in ipairs(list or {}) do
        local target = is_optional(row) and optional or required
        target[#target + 1] = "  " .. member_text(row)
    end
    local lines = required
    if #optional > 0 then
        lines[#lines + 1] = "@optional"
        for _, text in ipairs(optional) do lines[#lines + 1] = text end
    end
    return lines
end

-- The attribute text after a declarator (a space and it, or nothing).
local function suffix_of(attributes)
    return attributes ~= "" and (" " .. attributes) or ""
end

-- A file's names: a definition it needs wins over a forward declaration.
-- Each name keeps both facts a use can give: that its definition is needed (def), and the forward declaration its class or protocol
-- use needs (forward). A use may come before the definition in the same header, so a definition does not replace a forward.
local function note(deps, name, use)
    if name == nil or KEYWORDS[name] then return end
    local entry = deps[name] or {}
    if use == "def" then
        entry.def = true
    elseif use == "class" or use == "protocol" then
        -- a name can be a class and a protocol both (NSObject): each keeps its forward declaration
        entry.forwards = entry.forwards or {}
        entry.forwards[use] = true
    elseif entry.forward == nil or string.sub(use, 1, 8) == "generic:" then
        -- a generic use's arity wins over a plain forward: @class NSArray; then NSArray<T> * would not be the same class
        entry.forward = use
    end
    deps[name] = entry
end

local function note_type(deps, defs, text)
    for name, use in pairs(type_names(text, {}, defs)) do note(deps, name, use) end
end

-- The names a method or a property uses: its result or type, and its parameters' types.
local function note_member(deps, defs, row)
    note_type(deps, defs, row[COL.type])
    if row[COL.kind] == "method" and row[COL.params] ~= "-" then
        for _, p in ipairs(parameters_of(row[COL.params], "-")) do note_type(deps, defs, p.type) end
    end
end

-- The type parameters of a generic class or a category, from the IR's typeparams cell (name:bound entries, in order, separated by " | ").
-- Each is written as the declaration writes it: "Name : Bound", or the bare name when the bound is id (an unbounded parameter). The
-- bound's names are noted in deps, as a type is.
local function type_parameters_of(cell, deps, defs)
    local out = {}
    assert(cell, "an IR row with no typeparams cell: the full IR has 21 cells, an older one must be rebuilt")
    if cell == "-" then return out end
    for _, entry in ipairs(split(cell, " | ")) do
        local name, bound = string.match(entry, "^([^:]+):(.*)$")
        assert(name, "a type parameter with no bound: " .. entry)
        if bound == "id" then
            out[#out + 1] = name
        else
            note_type(deps, defs, bound)
            out[#out + 1] = name .. " : " .. bound
        end
    end
    return out
end

function render(framework, rows, defs, has_map, has_sdk_headers, usr_dirs)
    local counts = {declarations = {}, skipped = {}}
    local function count(kind, n)
        counts.declarations[kind] = (counts.declarations[kind] or 0) + (n or 1)
    end
    local function skip(reason)
        counts.skipped[reason] = (counts.skipped[reason] or 0) + 1
    end

    -- the getters' nullability (the result part of an accessor's column 10, by its USR): a property the IR gives unspecified whose getter
    -- is nonnull is null_resettable (its getter nonnull, its setter nullable), which no column of the property records
    -- The same goes for optional: an optional property of a protocol is in its accessors' attrs (optional), not in the property's own.
    local getters, optional_getters = {}, {}
    for _, row in ipairs(rows) do
        if row[COL.kind] == "accessor" then
            getters[row[COL.usr]] = string.match(row[COL.nullability], "^([^|]*)")
            if string.find(row[COL.attrs], "optional", 1, true) then optional_getters[row[COL.usr]] = true end
        end
    end

    -- the C functions a framework declares under one name more than once are overloads (Sparse's SparseConvertFromCoordinate: one per
    -- element type, each with its own USR). C spells an overload overloadable, and every declaration of it carries the attribute; the
    -- IR records no overloadable attribute, so the names with two USRs are the overloads.
    local usrs_of_name, overloads = {}, {}
    for _, row in ipairs(rows) do
        if row[COL.kind] == "function" then
            usrs_of_name[row[COL.name]] = usrs_of_name[row[COL.name]] or {}
            usrs_of_name[row[COL.name]][row[COL.usr]] = true
        end
    end
    for name, usrs in pairs(usrs_of_name) do
        local count = 0
        for _ in pairs(usrs) do count = count + 1 end
        if count > 1 then overloads[name] = true end
    end

    -- sort the rows: the ones a top-level declaration owns, and the ones its block takes
    local enumconsts, anonymous_consts, fields, supers, conforms, members, cat_members, tops = {}, {}, {}, {}, {}, {}, {}, {}
    local category_conforms = {}  -- class@category -> the protocols the category lists
    -- the anonymous tags a field names (its anon cell, by USR), and the anonymous tags of each class that no field names (its ivars)
    local referenced, class_tags = {}, {}
    for _, row in ipairs(rows) do
        if row[COL.kind] == "field" and row[COL.anon] ~= "-" then referenced[row[COL.anon]] = true end
    end
    -- The members of a struct or union, one per line at the indent: a field's declaration, or, for a field whose type is an anonymous
    -- struct or union (its anon cell names the tag), that tag written in place, with the field's name after it.
    local function member_lines(list, indent, block)
        local out = {}
        for _, f in ipairs(list) do
            local attr = availability(f[COL.avail])
            local tail = attr ~= "" and (" " .. attr) or ""
            if f[COL.kind] == "struct" or f[COL.kind] == "union" then
                -- an unnamed member: its tag written in place, with no name after it
                out[#out + 1] = indent .. f[COL.kind] .. " {"
                for _, line in ipairs(member_lines(fields["tag:" .. f[COL.usr]] or {}, indent .. "  ", block)) do out[#out + 1] = line end
                out[#out + 1] = indent .. "}" .. tail .. ";"
            elseif f[COL.anon] ~= "-" then
                local kind = string.match(f[COL.type], "^(%a+) %(unnamed")
                assert(kind == "struct" or kind == "union", "an anonymous member with no tag kind: " .. f[COL.type])
                out[#out + 1] = indent .. kind .. " {"
                for _, line in ipairs(member_lines(fields["tag:" .. f[COL.anon]] or {}, indent .. "  ", block)) do out[#out + 1] = line end
                out[#out + 1] = indent .. "} " .. f[COL.name] .. tail .. ";"
            else
                out[#out + 1] = indent .. declare(f[COL.type], f[COL.name], f[COL.nullability]) .. tail .. ";"
                note_type(block.deps, defs, f[COL.type])
            end
        end
        return out
    end
    for _, row in ipairs(rows) do
        local kind = row[COL.kind]
        if kind == "property" then
            local getter = getter_of(row)
            local resettable = row[COL.nullability] == "u" and getters[getter] == "n"
            local optional = optional_getters[getter] and not is_optional(row)
            if resettable or optional then
                row = {table.unpack(row, 1, 16)}
                if resettable then row[COL.nullability] = "r" end
                if optional then row[COL.attrs] = row[COL.attrs] == "-" and "optional" or (row[COL.attrs] .. ",optional") end
            end
        end
        if BOOKKEEPING[kind] then
            if kind ~= "meta" then skip(kind) end
        elseif kind == "accessor" then
            skip("accessor (synthesised by clang)")
        elseif kind == "enumconst" then
            -- a constant of an anonymous enum has no container: its USR is its enum's USR and its own name (c:@Ea@FIRST@NAME)
            local by, key = enumconsts, row[COL.container]
            if key == "-" then by, key = anonymous_consts, string.match(row[COL.usr], "^(.*)@[^@]+$") end
            local list = by[key] or {}
            list[#list + 1] = row
            by[key] = list
        elseif kind == "field" then
            -- the members of an anonymous struct or union are keyed by their tag's USR (a field's USR is its tag's, then @FI@ and its name)
            local key = row[COL.container]
            if key == "-" then key = "tag:" .. string.match(row[COL.usr], "^(.*)@FI@[^@]*$") end
            local list = fields[key] or {}
            list[#list + 1] = row
            fields[key] = list
        elseif (kind == "struct" or kind == "union") and row[COL.name] == "-" then
            -- an anonymous tag is written where a field names it (member_lines), or, when no field names it and its USR is a class's, as
            -- that class's ivars; an unnamed member of a struct or union (C11: no field names it, its USR is its parent's @Ua or
            -- @S@file@offset) is written in its parent, in IR order; any other is not written
            local class = string.match(row[COL.usr], "^c:objc%(cs%)([^@]+)@")
            local parent = string.match(row[COL.usr], "^(.*)@[SU]a$") or string.match(row[COL.usr], "^(.*)@[SU]@[^@]+@%d+$")
            if class and not referenced[row[COL.usr]] then
                local list = class_tags[class] or {}
                list[#list + 1] = row
                class_tags[class] = list
            elseif parent and not referenced[row[COL.usr]] and not string.find(parent, "^c:objc") then
                local named = string.match(parent, "^c:@[SU]@([^@]+)$")
                local key = named or ("tag:" .. parent)
                local list = fields[key] or {}
                list[#list + 1] = row
                fields[key] = list
            else
                skip("anonymous " .. kind)
            end
        elseif kind == "super" then
            supers[row[COL.container]] = supers[row[COL.container]] or row[COL.name]
        elseif kind == "conforms" then
            -- a category's protocols are its own (the IR's category cell), not the class's. Otherwise the owner is its USR's cs: or pl:
            -- key, so a class and a protocol of one name keep their own lists
            local by, key = conforms, conformance_owner(row[COL.usr])
            if row[COL.category] ~= "-" then by, key = category_conforms, row[COL.container] .. "@" .. row[COL.category] end
            assert(key, "a conformance with no class or protocol USR: " .. row[COL.usr])
            local list = by[key] or {}
            list[#list + 1] = row[COL.name]
            by[key] = list
        elseif kind == "method" or kind == "property" then
            if row[COL.container] == "-" then
                local owner = owner_of(row[COL.usr])
                if owner == nil then
                    skip("member without an owner")
                else
                    local list = members[owner] or {}
                    list[#list + 1] = row
                    members[owner] = list
                end
            else
                local key = (class_of(row[COL.usr]) or "?") .. "@" .. row[COL.container]
                local list = cat_members[key] or {}
                list[#list + 1] = row
                cat_members[key] = list
            end
        elseif row[COL.header] == "-" then
            skip("no header (" .. kind .. ")")
        elseif string.sub(row[COL.header], 1, 1) == "/" then
            -- an absolute path: the typedef is declared by another SDK header, and this framework's headers do not declare it
            skip("typedef from another SDK header (absolute path)")
        else
            tops[#tops + 1] = row
        end
    end

    -- the blocks of each header, in IR order: text, the names it needs, and the names it defines. The value types (typedef, enum,
    -- struct, union) come first in a header (early), so a declaration that uses one of them after it in the IR still sees it
    local blocks, header_order = {}, {}
    local VALUE_KINDS = {typedef = true, enum = true, struct = true, union = true}
    local function block_of(header)
        if blocks[header] == nil then
            blocks[header] = {text = {}, early = {}, deps = {}, defined = {}}
            header_order[#header_order + 1] = header
        end
        return blocks[header]
    end

    -- the tags this framework defines (enum, struct, union), with the header of each; a typedef of one waits for it (see typedef). And
    -- the anonymous enums, structs and unions a typedef names (typedef struct { ... } NAME; has USR c:@SA@NAME, an enum c:@EA@NAME):
    -- they are written with that typedef, so the typedef row (type struct NAME) is left out
    local tags, emitted_tags, pending, anonymous_named = {}, {}, {}, {}
    local ANONYMOUS_USR = {enum = "@EA@", struct = "@SA@", union = "@UA@"}
    for _, row in ipairs(tops) do
        local kind = row[COL.kind]
        local anonymous = ANONYMOUS_USR[kind] ~= nil and row[COL.name] ~= "-" and string.find(row[COL.usr], ANONYMOUS_USR[kind], 1, true)
        if anonymous then
            anonymous_named[row[COL.name]] = true
        elseif kind == "enum" and row[COL.name] ~= "-" then
            tags[row[COL.name]] = row[COL.header]
        end
    end

    for _, row in ipairs(tops) do
        local kind = row[COL.kind]
        local block = block_of(row[COL.header])
        local name = row[COL.name]
        local avail = availability(row[COL.avail])
        local prefix = avail ~= "" and (avail .. "\n") or ""
        local text
        -- an enum the IR gives no constants is only declared here (its fixed type is all a use needs): not a definition
        local declared_only = false
        if kind == "enum" then
            -- a named enum takes its constants by name, an anonymous one by its USR (c:@Ea@FIRST, its constants c:@Ea@FIRST@NAME)
            local consts = name == "-" and (anonymous_consts[row[COL.usr]] or {}) or (enumconsts[name] or {})
            if name == "-" and #consts == 0 then
                skip("anonymous enum without constants")
            elseif #consts == 0 and row[COL.type] == "-" then
                skip("enum without constants or fixed type")
            elseif #consts == 0 then
                -- enum X : NSInteger; (the forward declaration with its fixed type; empty braces would define an enum with none)
                declared_only = true
                note_type(block.deps, defs, row[COL.type])
                text = prefix .. "enum " .. name .. " : " .. row[COL.type] .. ";"
                count("enum forward", 1)
            else
                local base = row[COL.type]
                local anonymous = anonymous_named[name]
                local head = name == "-" and "enum" or (anonymous and "typedef enum" or ("enum " .. name))
                local lines = {prefix .. head .. (base ~= "-" and (" : " .. base) or "") .. " {"}
                if base ~= "-" then note_type(block.deps, defs, base) end
                for _, c in ipairs(consts) do
                    local attr = availability(c[COL.avail])
                    local value = c[COL.value] ~= "-" and (" = " .. c[COL.value]) or ""
                    lines[#lines + 1] = "  " .. c[COL.name] .. (attr ~= "" and (" " .. attr) or "") .. value .. ","
                end
                lines[#lines + 1] = anonymous and ("} " .. name .. ";") or "};"
                text = table.concat(lines, "\n")
                count("enumconst", #consts)
            end
        elseif kind == "typedef" then
            if anonymous_named[name] and (row[COL.type] == "struct " .. name or row[COL.type] == "union " .. name
                    or row[COL.type] == "enum " .. name) then
                skip("typedef written with its anonymous tag")
            elseif string.find(row[COL.type], "unnamed", 1, true) then
                skip("typedef of an anonymous tag")
            else
                text = "typedef " .. declare(row[COL.type], name, row[COL.nullability]) .. suffix_of(avail) .. ";"
                note_type(block.deps, defs, row[COL.type])
                -- a typedef of a tag the same header defines comes after the tag's definition (clang reads a typedef of an enum
                -- before its definition as a fixed-type enum otherwise), so it waits for the definition
                local tag = string.match(row[COL.type], "^%a+ (%S+)$")
                if tag and tags[tag] == row[COL.header] and not emitted_tags[tag] then
                    pending[tag] = text
                    text = nil
                end
            end
        elseif kind == "struct" or kind == "union" then
            if name == "-" then
                skip("anonymous " .. kind)
            else
                local anonymous = anonymous_named[name]
                -- a named tag's availability follows its keyword: in front of the keyword it is not the tag's, and a field of the tag
                -- that uses an unavailable type is then reported (Security's SecKeychainAttribute)
                local head = anonymous and (prefix .. "typedef " .. kind .. " {") or (kind .. " " .. (avail ~= "" and (avail .. " ") or "") .. name .. " {")
                local lines = {head}
                for _, line in ipairs(member_lines(fields[name] or {}, "  ", block)) do lines[#lines + 1] = line end
                lines[#lines + 1] = anonymous and ("} " .. name .. ";") or "};"
                text = table.concat(lines, "\n")
                count("field", #(fields[name] or {}))
            end
        elseif kind == "function" then
            local result, suffix = split_suffix(row[COL.type])
            local result_nullability = string.match(row[COL.nullability], "^([^|]*)") or "-"
            local args = parameters_of(row[COL.params], string.match(row[COL.nullability], "|(.*)$") or "-")
            local decls = {}
            for i, a in ipairs(args) do
                decls[i] = declare(a.type, a.name, a.nullability)
                note_type(block.deps, defs, a.type)
            end
            if string.find(row[COL.attrs], "variadic", 1, true) then decls[#decls + 1] = "..." end
            note_type(block.deps, defs, result)
            local overloadable = overloads[name] and " __attribute__((overloadable))" or ""
            text = "extern " .. declare(result, "", result_nullability) .. " " .. name
                .. "(" .. (#decls > 0 and table.concat(decls, ", ") or "void") .. ")" .. overloadable .. suffix_of(avail) .. ";"
        elseif kind == "var" then
            text = "extern " .. declare(row[COL.type], name, row[COL.nullability]) .. suffix_of(avail) .. ";"
            note_type(block.deps, defs, row[COL.type])
        elseif kind == "interface" then
            local super = supers[name]
            local protocols, seen = {}, {}
            for _, p in ipairs(conforms["cs:" .. name] or {}) do
                if not seen[p] then
                    seen[p] = true
                    protocols[#protocols + 1] = p
                    note(block.deps, p, "protocol")
                end
            end
            local head = prefix
            if super == nil then head = head .. "__attribute__((objc_root_class))\n" end
            head = head .. swift_attribute(usr_dirs, framework, "interface", name)
            local parameters = type_parameters_of(row[COL.typeparams], block.deps, defs)
            head = head .. "@interface " .. name .. (#parameters > 0 and ("<" .. table.concat(parameters, ", ") .. ">") or "")
                .. (super and (" : " .. super) or "")
            if #protocols > 0 then head = head .. " <" .. table.concat(protocols, ", ") .. ">" end
            if super then note(block.deps, super, "def") end
            -- the class's own anonymous unions and structs are its instance variables (an ivar block, before the members)
            local lines = {head}
            local ivars = class_tags[name] or {}
            if #ivars > 0 then
                lines[1] = head .. " {"
                for _, tag in ipairs(ivars) do
                    lines[#lines + 1] = "  " .. tag[COL.kind] .. " {"
                    for _, line in ipairs(member_lines(fields["tag:" .. tag[COL.usr]] or {}, "    ", block)) do lines[#lines + 1] = line end
                    lines[#lines + 1] = "  };"
                    count("field", #(fields["tag:" .. tag[COL.usr]] or {}))
                end
                lines[#lines + 1] = "}"
            end
            for _, line in ipairs(members_text(members["cs:" .. name])) do lines[#lines + 1] = line end
            for _, m in ipairs(members["cs:" .. name] or {}) do note_member(block.deps, defs, m) end
            count("member", #(members["cs:" .. name] or {}))
            lines[#lines + 1] = "@end"
            text = table.concat(lines, "\n")
        elseif kind == "protocol" then
            local protocols = {}
            for _, p in ipairs(conforms["pl:" .. name] or {}) do
                protocols[#protocols + 1] = p
                note(block.deps, p, "protocol")
            end
            local head = prefix .. swift_attribute(usr_dirs, framework, "protocol", name) .. "@protocol " .. name
            if #protocols > 0 then head = head .. " <" .. table.concat(protocols, ", ") .. ">" end
            local lines = {head}
            for _, line in ipairs(members_text(members["pl:" .. name])) do lines[#lines + 1] = line end
            for _, m in ipairs(members["pl:" .. name] or {}) do note_member(block.deps, defs, m) end
            count("member", #(members["pl:" .. name] or {}))
            lines[#lines + 1] = "@end"
            text = table.concat(lines, "\n")
        elseif kind == "category" and name == "-" then
            -- a class extension (c:objc(ext)Class): an empty @interface Class () here, which decls reads as the extension. Its members are
            -- rows of the class's own (cs) owner, so the class block takes them
            local class = string.match(row[COL.usr], "%(ext%)(.+)$")
            assert(class, "extension USR without a class: " .. row[COL.usr])
            note(block.deps, class, "def")
            text = prefix .. "@interface " .. class .. " ()\n@end"
        elseif kind == "category" then
            local class = string.match(row[COL.usr], "%(cy%)([^@]+)@")
            assert(class, "category USR without a class: " .. row[COL.usr])
            note(block.deps, class, "def")
            local key = class .. "@" .. name
            -- a category declares its own type parameters, by its own names (the SDK's NSDictionary category is <K, V>); a category that
            -- declares none writes none, and its members use the class's names
            local parameters = type_parameters_of(row[COL.typeparams], block.deps, defs)
            local protocols = {}
            for _, p in ipairs(category_conforms[key] or {}) do
                protocols[#protocols + 1] = p
                note(block.deps, p, "protocol")
            end
            local head = prefix .. "@interface " .. class .. (#parameters > 0 and ("<" .. table.concat(parameters, ", ") .. ">") or "")
                .. " (" .. name .. ")"
            if #protocols > 0 then head = head .. " <" .. table.concat(protocols, ", ") .. ">" end
            local lines = {head}
            for _, line in ipairs(members_text(cat_members[key])) do lines[#lines + 1] = line end
            for _, m in ipairs(cat_members[key] or {}) do note_member(block.deps, defs, m) end
            count("member", #(cat_members[key] or {}))
            lines[#lines + 1] = "@end"
            text = table.concat(lines, "\n")
        else
            skip("unknown kind " .. kind)
        end
        if text then
            local list = VALUE_KINDS[kind] and block.early or block.text
            list[#list + 1] = text
            count(kind)
            -- a typedef of its own tag (typedef enum X X;) defines the typedef, not the tag: the tag's header is imported for it
            local own_tag = kind == "typedef" and string.match(row[COL.type], "^%a+ (%S+)$") == name
            if (DEFINING[kind] and not declared_only and not own_tag) or kind == "function" or kind == "var" then
                block.defined[name] = true
            end
            if kind == "enum" and name ~= "-" then
                emitted_tags[name] = true
                if pending[name] then
                    block.early[#block.early + 1] = pending[name]
                    pending[name] = nil
                    count("typedef")
                end
            end
        end
    end

    for tag in pairs(pending) do
        error("typedef of " .. tag .. " waits for a definition that was never emitted")
    end

    -- the files: each header's imports (a definition from another header, or from another framework) and forward declarations,
    -- then its blocks
    -- a header whose typedefs the IR gives file-local USRs (c:Header.h@T@Name) is not a system header in the SDK: it gets no pragma
    -- (the pragma makes clang give its typedefs the global USR c:@T@Name, which would not match)
    local file_local = {}
    for _, row in ipairs(tops) do
        if row[COL.kind] == "typedef" and string.match(row[COL.usr], "^c:([^@]+)@T@") == row[COL.header] then
            file_local[row[COL.header]] = true
        end
    end
    local files = {}
    local headers = {}
    for _, header in ipairs(header_order) do headers[#headers + 1] = header end
    table.sort(headers)
    local base = module_name(framework)
    -- the same-framework headers each header imports for its names (a superset: a name another header gives counts too), and whether
    -- a header reaches another through them
    local edges = {}
    for _, header in ipairs(headers) do
        edges[header] = {}
        for name in pairs(blocks[header].deps) do
            for _, def in ipairs(defs[name] or {}) do
                if def.framework == framework and def.header ~= header then edges[header][def.header] = true end
            end
        end
    end
    local function reaches(from, to)
        local seen, stack = {}, {from}
        while #stack > 0 do
            local h = table.remove(stack)
            if h == to then return true end
            if not seen[h] then
                seen[h] = true
                for nxt in pairs(edges[h] or {}) do stack[#stack + 1] = nxt end
            end
        end
        return false
    end
    -- a pointer typedef to a tag of an include cycle (CGPDFDictionary.h and CGPDFArray.h each use the other's) is not imported: the
    -- import would be a cycle, and the using header reads the name before its typedef. The typedef's own line is written in the using
    -- header too, which C accepts (an identical typedef may repeat)
    local inlined = {}
    for _, header in ipairs(headers) do
        local block = blocks[header]
        -- a generic class's forward declaration repeats its bounds (clang rejects a forward with another bound), so the classes those
        -- bounds name are forward-declared here too: noted before the names are listed
        local generic_uses = {}
        for name, entry in pairs(block.deps) do
            if entry.forward and string.sub(entry.forward, 1, 8) == "generic:" then generic_uses[#generic_uses + 1] = name end
        end
        for _, name in ipairs(generic_uses) do
            local def = generic_definition(defs, name, framework)
            if def then type_parameters_of(def.typeparams, block.deps, defs) end
        end
        local names = {}
        for name in pairs(block.deps) do names[#names + 1] = name end
        table.sort(names)
        local imports, forwards, generic_forwards = {}, {}, {}
        for _, name in ipairs(names) do
            local entry = block.deps[name]
            -- a name the IR defines as a typedef, enum, struct or union is a value name, whatever its use ("Byte *" is a pointer to a
            -- typedef, not a class): it is imported, never forward-declared
            local value_name = false
            for _, def in ipairs(defs[name] or {}) do
                if def.kind ~= "interface" and def.kind ~= "protocol" then value_name = true end
            end
            if (entry.def or value_name) and not block.defined[name] then
                local def = pick_other(defs[name], framework, header)
                local tag_pointer = def and def.kind == "typedef" and string.match(def.row[COL.type], "^struct [^%s]+ %*$")
                if tag_pointer and def.framework == framework and reaches(def.header, header) then
                    if not inlined[header .. "|" .. name] then
                        inlined[header .. "|" .. name] = true
                        local avail_of = availability(def.row[COL.avail])
                        -- first of the early lines: a typedef of this header may use it (a callback's parameter)
                        table.insert(block.early, 1, "typedef " .. declare(def.row[COL.type], name, def.row[COL.nullability])
                            .. suffix_of(avail_of) .. ";")
                    end
                else
                    local line = def and import_of(def, framework, header, usr_dirs)
                    if line then imports[#imports + 1] = line end
                end
            end
            -- a class or protocol is forward-declared even when this header defines it, since a use may come before the definition
            -- a protocol and a typedef share a name (typedef id<NSFileProviderItem> NSFileProviderItem): both are declared. A class and
            -- a protocol of one name (NSObject) are both declared too, unless a generic use declares the class with its arity
            local generic_use = entry.forward and string.sub(entry.forward, 1, 8) == "generic:"
            local forwarded = entry.forwards or {}
            if forwarded.class and not value_name and not generic_use then
                forwards[#forwards + 1] = "@class " .. name .. ";"
            end
            if forwarded.protocol and (not value_name or defined_as(defs, name, "protocol")) and not generic_use then
                forwards[#forwards + 1] = "@protocol " .. name .. ";"
            end
            if generic_use and not value_name then
                -- after the plain forwards: its bounds name classes forward-declared above
                -- a use of a generic class the IR does not define is an error: its parameter names and bounds are not known
                local def = generic_definition(defs, name, framework)
                assert(def and def.typeparams ~= "-", "a generic use of " .. name .. " with no generic definition in the IR")
                local params = type_parameters_of(def.typeparams, {}, defs)
                generic_forwards[#generic_forwards + 1] = "@class " .. name .. "<" .. table.concat(params, ", ") .. ">;"
            end
        end
        local head, seen = {}, {}
        for _, line in ipairs(imports) do
            if not seen[line] then
                seen[line] = true
                head[#head + 1] = line
            end
        end
        if #head > 0 and #forwards + #generic_forwards > 0 then head[#head + 1] = "" end
        for _, line in ipairs(forwards) do head[#head + 1] = line end
        for _, line in ipairs(generic_forwards) do head[#head + 1] = line end
        local parts = {}
        if #head > 0 then parts[#parts + 1] = table.concat(head, "\n") end
        local bodies = {}
        for _, text in ipairs(block.early) do bodies[#bodies + 1] = text end
        for _, text in ipairs(block.text) do bodies[#bodies + 1] = text end
        parts[#parts + 1] = table.concat(bodies, "\n\n")
        local lead = file_local[header] and "" or (SYSTEM_HEADER .. "\n")
        files["Headers/" .. header] = lead .. table.concat(parts, "\n\n") .. "\n"
    end

    if not has_map and #headers == 0 and has_sdk_headers then
        -- a framework with no module map and no declaration of its own: its SDK folder holds headers that decls reads when the
        -- fallback list names the framework, so the folder keeps one empty header (no declaration in it)
        files["Headers/" .. base .. ".h"] = SYSTEM_HEADER .. "\n"
        counts.placeholder = true
    end
    if not has_map and files["Headers/" .. base .. ".h"] == nil then
        -- decls reads a framework with no module map from the top of its Headers/ folder, the umbrella first: a header in a subfolder
        -- (vecLib's BNNS/bnns.h) is read only through an umbrella that includes it. The SDK's umbrella declares nothing, so it has no
        -- rows and is not in the IR: this one includes the IR's subfolder headers
        local nested = {}
        for _, header in ipairs(headers) do
            if string.find(header, "/", 1, true) then nested[#nested + 1] = '#import "' .. header .. '"' end
        end
        if #nested > 0 then
            files["Headers/" .. base .. ".h"] = SYSTEM_HEADER .. "\n" .. table.concat(nested, "\n") .. "\n"
            counts.generated_umbrella = true
        end
    end
    if has_map then
        -- the umbrella: the IR's own <base>.h when it has one, else a header that imports the others
        local umbrella = base .. ".h"
        if files["Headers/" .. umbrella] == nil then
            local lines = {}
            for _, header in ipairs(headers) do lines[#lines + 1] = '#import "' .. header .. '"' end
            files["Headers/" .. umbrella] = SYSTEM_HEADER .. "\n" .. table.concat(lines, "\n") .. "\n"
            counts.generated_umbrella = true
        end
        local map = {"framework module " .. base .. " {", '  umbrella header "' .. umbrella .. '"', "  export *"}
        for _, header in ipairs(headers) do
            if header ~= umbrella then map[#map + 1] = '  header "' .. header .. '"' end
        end
        map[#map + 1] = "}"
        files["Modules/module.modulemap"] = table.concat(map, "\n") .. "\n"
    end
    counts.files = 0
    for path_name, text in pairs(files) do
        counts.files = counts.files + 1
        local _, newlines = string.gsub(text, "\n", "\n")
        counts.lines = (counts.lines or 0) + newlines
    end
    return {files = files, counts = counts}
end

-- The key of a row: kind, usr, container, name and side (columns 2 to 6).
-- The USR with the offsets of its anonymous tags taken out. clang writes the offset of an anonymous struct or union into its USR
-- (c:@S@P@U@Header.h@322 is a union at offset 322 of Header.h), so a header written at other offsets gives the same declaration other
-- USRs. The compare matches on this form, on both sides, and recomputes the declaration hash over it (declaration_hash).
local function location_free(usr)
    return (string.gsub(usr, "(@[US]@[^@]+)@%d+", "%1@*"))
end

local function key_of(row)
    return table.concat({row[COL.kind], location_free(row[COL.usr]), row[COL.container], row[COL.name], row[COL.side]}, "\t")
end

-- The declaration hash the extractor computes (decls.cc declaration_hash): the cells the hash covers, each followed by the unit
-- separator, and the first 16 hex digits of their SHA-256. The USR is the location-free form (see location_free).
local HASHED = {COL.kind, COL.usr, COL.container, COL.name, COL.side, COL.type, COL.params, COL.nullability, COL.attrs, COL.value}
function declaration_hash(row)
    local parts = {}
    for _, c in ipairs(HASHED) do
        parts[#parts + 1] = (c == COL.usr and location_free(row[c]) or row[c]) .. "\31"
    end
    return string.sub(sha256.hex(table.concat(parts)), 1, 16)
end

-- The first column (of those the hash covers) where two rows with one key differ, for the cause of a declhash difference.
local COMPARED = {{COL.avail, "availability"}, {COL.nullability, "nullability"}, {COL.type, "type"}, {COL.params, "params"},
                  {COL.attrs, "attrs"}, {COL.value, "value"}}
local function differing_column(a, b)
    for _, c in ipairs(COMPARED) do
        if a[c[1]] ~= b[c[1]] then return c[2] end
    end
    return "no column"
end

-- The comparison of the IR's rows of one framework with decls' rows for it. Census and the other bookkeeping rows are not compared.
-- The result: ir and decls (the row counts), equal (rows with the key and the declhash), located (the equal rows whose USR has an
-- offset, which the comparison takes out on both sides), and causes: label -> count.
function compare(ir_rows, decl_rows)
    local expected = {}
    local report = {ir = 0, decls = 0, equal = 0, located = 0, causes = {}}
    local function cause(label)
        report.causes[label] = (report.causes[label] or 0) + 1
    end
    for _, row in ipairs(ir_rows) do
        if not BOOKKEEPING[row[COL.kind]] then
            report.ir = report.ir + 1
            local key = key_of(row)
            expected[key] = expected[key] or {}
            table.insert(expected[key], row)
        end
    end
    for _, row in ipairs(decl_rows) do
        if not BOOKKEEPING[row[COL.kind]] then
            report.decls = report.decls + 1
            local list = expected[key_of(row)]
            if list and #list > 0 then
                local ir = table.remove(list, 1)
                if declaration_hash(ir) == declaration_hash(row) then
                    report.equal = report.equal + 1
                    if location_free(row[COL.usr]) ~= row[COL.usr] then report.located = report.located + 1 end
                else
                    cause("declhash differs, " .. row[COL.kind] .. ": " .. differing_column(ir, row))
                end
            else
                cause("extra from decls, " .. row[COL.kind])
            end
        end
    end
    for _, list in pairs(expected) do
        for _, ir in ipairs(list) do cause("missing from decls, " .. ir[COL.kind]) end
    end
    return report
end

-- The rows of a text (the decls output or the IR), each the first 16 cells and the facts 19 to 21, which are the last three: they are
-- read from the end of the line, so the declaration (17) and the message (18) between them are not split out, and never read.
function rows_of(text)
    local rows = {}
    for line in string.gmatch(text, "[^\n]+") do
        local row = split_cells(line, 16)
        row[COL.typeparams], row[COL.anon], row[COL.category] = string.match(line, "\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
        rows[#rows + 1] = row
    end
    return rows
end
