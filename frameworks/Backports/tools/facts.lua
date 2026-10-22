import("core.base.json")

local ast = import("ast", {rootdir = os.scriptdir(), anonymous = true})
local sdkfiles = import("sdk", {rootdir = os.scriptdir(), anonymous = true})

local CLANG = "/usr/bin/clang"

local SWIFT_KINDS = {Func = true, Constructor = true, Accessor = true, Var = true, Struct = true, Class = true, Enum = true,
                     Protocol = true, TypeAlias = true, EnumElement = true, Subscript = true, AssociatedType = true}
local SWIFT_TYPES = {Struct = true, Class = true, Enum = true, Protocol = true}

local function lines_of(text)
    return {lines = function ()
        return string.gmatch(text, "[^\n]+")
    end}
end

local function add(state, row)
    local key = row.kind .. "\0" .. row.container .. "\0" .. row.name .. "\0" .. row.symbol
    local index = state.seen[key]
    if index == nil then
        table.insert(state.rows, row)
        state.seen[key] = #state.rows
    elseif state.rows[index].intro == nil then
        state.rows[index].intro = row.intro
    end
end

local function defined(node)
    return #node.children > 0 or node.multiline
end

local function method_signature(node)
    local head = (node.class_method and "+" or "-") .. " (" .. (node.type or "void") .. ")"
    local labels = {}
    for label in string.gmatch(node.name, "[^:]+:") do
        table.insert(labels, label)
    end
    if #labels == 0 then
        return head .. node.name
    end
    local params = ast.children_of(node, "ParmVarDecl")
    local parts = {}
    for index, label in ipairs(labels) do
        local param = params[index]
        table.insert(parts, label .. "(" .. ((param and param.type) or "id") .. ")" .. ((param and param.name) or ("arg" .. index)))
    end
    return head .. table.concat(parts, " ")
end

local function property_flags(child)
    local flags = {}
    if child.flags["class"] then
        table.insert(flags, "class")
    end
    local getter = ast.getter_of(child)
    if getter then
        table.insert(flags, "getter:" .. getter)
    end
    if ast.has_unavailable(child) then
        table.insert(flags, "unavailable")
    end
    return table.concat(flags, " ")
end

local function members(state, container, node, intro)
    for _, child in ipairs(node.children) do
        if not child.implicit and child.name ~= nil then
            local own = ast.ios_intro(child) or intro
            if child.kind == "ObjCMethodDecl" then
                add(state, {kind = child.class_method and "class method" or "instance method", container = container,
                    name = child.name, symbol = (child.class_method and "+" or "-") .. "[" .. container .. " " .. child.name .. "]",
                    signature = method_signature(child), intro = own, flags = ast.has_unavailable(child) and "unavailable" or ""})
            elseif child.kind == "ObjCPropertyDecl" then
                add(state, {kind = "property", container = container, name = child.name, symbol = container .. "." .. child.name,
                    signature = (child.flags.readonly and "readonly " or "") .. (child.type or ""), intro = own, flags = property_flags(child)})
            end
        end
    end
end

local function objc_top(state, top)
    local intro = ast.ios_intro(top)
    if top.kind == "ObjCInterfaceDecl" and top.name and defined(top) then
        assert(string.find(top.name, "^[%a_][%w_]*$"), "a class whose name is not an identifier, '" .. top.name .. "', in: " .. top.body)
        local super = ast.children_of(top, "super")[1]
        add(state, {kind = "class", container = "", name = top.name, symbol = "_OBJC_CLASS_$_" .. top.name,
            signature = super and super.type or "", intro = intro, flags = ast.has_unavailable(top) and "unavailable" or ""})
        members(state, top.name, top, intro)
    elseif top.kind == "ObjCCategoryDecl" then
        local interface = ast.children_of(top, "ObjCInterface")[1]
        if interface and interface.type then
            assert(string.find(interface.type, "^[%a_][%w_]*$"), "a category whose class is not an identifier, '" .. interface.type .. "', in: " .. top.body)
            members(state, interface.type, top, intro)
        end
    elseif top.kind == "ObjCProtocolDecl" and top.name and defined(top) then
        assert(string.find(top.name, "^[%a_][%w_]*$"), "a protocol whose name is not an identifier, '" .. top.name .. "', in: " .. top.body)
        add(state, {kind = "protocol", container = "", name = top.name, symbol = "_OBJC_PROTOCOL_$_" .. top.name,
            signature = "", intro = intro, flags = #ast.children_of(top, "ObjCNonRuntimeProtocolAttr") > 0 and "nonruntime" or ""})
    elseif top.kind == "FunctionDecl" and top.name and not top.flags.static and not top.flags.inline and not top.implicit
        and not string.find(top.name, "^__builtin") then
        assert(string.find(top.name, "^[%a_][%w_]*$"), "a C function whose name is not an identifier, '" .. top.name .. "', in: " .. top.body)
        add(state, {kind = "C function", container = "", name = top.name, symbol = top.name, signature = top.type or "", intro = intro})
    elseif top.kind == "VarDecl" and top.name and top.flags.extern then
        assert(string.find(top.name, "^[%a_][%w_]*$"), "a global whose name is not an identifier, '" .. top.name .. "', in: " .. top.body)
        add(state, {kind = "global variable", container = "", name = top.name, symbol = top.name, signature = top.type or "", intro = intro})
    elseif top.kind == "EnumDecl" then
        for _, child in ipairs(ast.children_of(top, "EnumConstantDecl")) do
            if child.name then
                add(state, {kind = "enum constant", container = top.name or "", name = child.name, symbol = child.name,
                    signature = child.type or "", intro = ast.ios_intro(child) or intro})
            end
        end
    end
end

local function swift_walk(state, node, container, intro)
    local own = (node.intro_iOS and ast.version_of(node.intro_iOS)) or intro
    local name = node.printedName or node.name
    if node.declKind and SWIFT_KINDS[node.declKind] and node.mangledName and name then
        add(state, {kind = "Swift declaration", container = container, name = name, symbol = node.mangledName,
            signature = node.declKind, intro = own})
    end
    local inner = container
    if node.declKind and SWIFT_TYPES[node.declKind] and name then
        inner = container == "" and name or (container .. "." .. name)
    end
    for _, child in ipairs(node.children or {}) do
        swift_walk(state, child, inner, own)
    end
end

local function digester()
    return os.iorunv("/usr/bin/xcrun", {"--find", "swift-api-digester"}):trim()
end

local function target_of(version)
    return "arm64-apple-ios" .. version
end

function objc_facts(sdk, name, version)
    local umbrella = sdkfiles.umbrella_header(sdk, name)
    local state = {rows = {}, seen = {}}
    if umbrella == nil then
        return state.rows
    end
    local prefix = sdkfiles.framework_root(sdk, name)
    local text = os.iorunv(CLANG, {"-target", target_of(version), "-isysroot", sdk, "-fobjc-arc", "-w", "-fsyntax-only",
        "-Xclang", "-ast-dump", "-x", "objective-c", "/dev/null", "-include", umbrella})
    ast.scan(lines_of(text), function (top)
        if top.file ~= nil and string.sub(top.file, 1, #prefix) == prefix then
            objc_top(state, top)
        end
    end)
    return state.rows
end

function swift_facts(sdk, name, version, scratch)
    local output = path.join(scratch, name .. ".json")
    os.execv(digester(), {"-dump-sdk", "-module", name, "-sdk", sdk, "-target", target_of(version), "-avoid-location",
        "-avoid-tool-args", "-swift-only", "-module-cache-path", sdkfiles.model_cache(), "-o", output})
    local document = json.loadfile(output)
    os.tryrm(output)
    assert(document, "the digester wrote no JSON for " .. name)
    local state = {rows = {}, seen = {}}
    swift_walk(state, document.ABIRoot or document, "", nil)
    return state.rows
end

