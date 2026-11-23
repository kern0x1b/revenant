import("async.runjobs")
import("core.base.json")

local ast = import("ast", {rootdir = os.scriptdir(), anonymous = true})
local sdkfiles = import("sdk", {rootdir = os.scriptdir(), anonymous = true})

local CLANG = sdkfiles.clang()

local SWIFT_KINDS = {Func = true, Constructor = true, Accessor = true, Var = true, Struct = true, Class = true, Enum = true,
                     Protocol = true, TypeAlias = true, EnumElement = true, Subscript = true, AssociatedType = true}
local SWIFT_TYPES = {Struct = true, Class = true, Enum = true, Protocol = true}

local function lines_of(text)
    return {lines = function ()
        return string.gmatch(text, "[^\n]+")
    end}
end

local function has_word(text, word)
    return string.find(" " .. (text or "") .. " ", " " .. word .. " ", 1, true) ~= nil
end

local function add(state, row)
    local key = row.kind .. "\0" .. row.container .. "\0" .. row.name .. "\0" .. row.symbol
    local index = state.seen[key]
    if index == nil then
        table.insert(state.rows, row)
        state.seen[key] = #state.rows
        return
    end
    local kept = state.rows[index]
    if kept.intro == nil then
        kept.intro = row.intro
    end
    if has_word(row.flags, "unavailable") and not has_word(kept.flags, "unavailable") then
        local words = kept.flags or ""
        kept.flags = words == "" and "unavailable" or words .. " unavailable"
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
        local words = {}
        if #ast.children_of(top, "ObjCNonRuntimeProtocolAttr") > 0 then
            table.insert(words, "nonruntime")
        end
        if ast.has_unavailable(top) then
            table.insert(words, "unavailable")
        end
        add(state, {kind = "protocol", container = "", name = top.name, symbol = "_OBJC_PROTOCOL_$_" .. top.name,
            signature = "", intro = intro, flags = table.concat(words, " ")})
    elseif top.kind == "FunctionDecl" and top.name and not top.flags.static and not top.flags.inline and not top.implicit
        and not string.find(top.name, "^__builtin") then
        assert(string.find(top.name, "^[%a_][%w_]*$"), "a C function whose name is not an identifier, '" .. top.name .. "', in: " .. top.body)
        add(state, {kind = "C function", container = "", name = top.name, symbol = top.name, signature = top.type or "", intro = intro,
            flags = ast.has_unavailable(top) and "unavailable" or ""})
    elseif top.kind == "VarDecl" and top.name and top.flags.extern then
        assert(string.find(top.name, "^[%a_][%w_]*$"), "a global whose name is not an identifier, '" .. top.name .. "', in: " .. top.body)
        add(state, {kind = "global variable", container = "", name = top.name, symbol = top.name, signature = top.type or "", intro = intro,
            flags = ast.has_unavailable(top) and "unavailable" or ""})
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

local function target_of(version)
    return "arm64-apple-ios" .. version
end

function checked_dump(command, umbrella, text, errors)
    if text == nil or #text == 0 then
        local stderr = errors ~= nil and errors:trim() or ""
        raise("clang exited with status 0 but its AST dump of %s is %s%s\ncommand: %s", umbrella, text == nil and "unreadable" or "empty",
              #stderr > 0 and ("; stderr: " .. stderr) or "", command)
    end
    return text
end

function ast_dump(sdk, version, umbrella)
    local arguments = {"-target", target_of(version), "-isysroot", sdk, "-fobjc-arc", "-w", "-fsyntax-only",
        "-Xclang", "-ast-dump", "-x", "objective-c", "/dev/null", "-include", umbrella}
    local command = CLANG .. " " .. os.args(arguments)
    local text, errors, failure
    try {
        function ()
            text, errors = os.iorunv(CLANG, arguments)
        end,
        catch {
            function (raised)
                failure = tostring(type(raised) == "table" and raised.errors or raised)
            end
        }
    }
    if failure ~= nil then
        raise("clang failed to dump the declarations of %s: %s\ncommand: %s", umbrella, failure, command)
    end
    return checked_dump(command, umbrella, text, errors)
end

function objc_facts(sdk, name, version)
    local umbrella = sdkfiles.umbrella_header(sdk, name)
    local state = {rows = {}, seen = {}}
    if umbrella == nil then
        return state.rows
    end
    local prefix = sdkfiles.framework_root(sdk, name)
    local function inside(file)
        return file ~= nil and string.sub(file, 1, #prefix) == prefix
    end
    local text = ast_dump(sdk, version, umbrella)
    ast.scan(lines_of(text), function (top)
        if inside(top.file) then
            objc_top(state, top)
        end
    end, inside)
    return state.rows
end

function extract(sdk, version, cache, logs, name)
    local rows = objc_facts(sdk, name, version)
    if sdkfiles.has_swift_module(sdk, name) then
        for _, row in ipairs(swift_facts(sdk, name, version, logs)) do
            table.insert(rows, row)
        end
    end
    sdkfiles.write_rows(path.join(cache, name .. ".tsv"), name, rows)
end

local CONSTANT_SHARDS = 4

local function constant_summary(sdk, names, indexes)
    local summary = {}
    local function note(index, name, intro, kind)
        if name and string.find(name, "^[%a_][%w_]*$") then
            local seen = summary[name]
            if seen == nil then
                seen = {}
                summary[name] = seen
            end
            if intro ~= nil and seen.first == nil then
                seen.first = {index, intro, kind}
            end
            seen.last = {index, kind}
        end
    end
    for _, index in ipairs(indexes) do
        local umbrella = sdkfiles.umbrella_header(sdk, names[index])
        if umbrella ~= nil then
            local text = ast_dump(sdk, sdkfiles.sdk_version(sdk), umbrella)
            ast.scan(lines_of(text), function (top)
                if top.kind == "VarDecl" and top.name and top.flags.extern then
                    note(index, top.name, ast.ios_intro(top), "extern")
                elseif top.kind == "EnumDecl" then
                    for _, child in ipairs(ast.children_of(top, "EnumConstantDecl")) do
                        note(index, child.name, ast.ios_intro(child) or ast.ios_intro(top), "enum")
                    end
                end
            end)
        end
    end
    return summary
end

local function write_summary(file, summary)
    local lines = {}
    for name, seen in pairs(summary) do
        local first = seen.first or {"", "", ""}
        table.insert(lines, table.concat({name, tostring(first[1]), tostring(first[2]), first[3], tostring(seen.last[1]), seen.last[2]}, "\t"))
    end
    table.sort(lines)
    local temp = file .. ".part"
    io.writefile(temp, table.concat(lines, "\n") .. (#lines > 0 and "\n" or ""))
    os.mv(temp, file)
end

local function read_summary(file)
    local summary = {}
    for line in io.lines(file) do
        local name, first_index, first_intro, first_kind, last_index, last_kind = string.match(line, "^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
        assert(name, "a malformed constant intro summary row in " .. file .. ": " .. line)
        summary[name] = {first = first_index ~= "" and {tonumber(first_index), tonumber(first_intro), first_kind} or nil, last = {tonumber(last_index), last_kind}}
    end
    return summary
end

local function merge_summaries(summaries)
    local intros = {}
    local firsts, lasts = {}, {}
    for _, summary in ipairs(summaries) do
        for name, seen in pairs(summary) do
            if seen.first ~= nil and (firsts[name] == nil or seen.first[1] < firsts[name][1]) then
                firsts[name] = seen.first
            end
            if lasts[name] == nil or seen.last[1] > lasts[name][1] then
                lasts[name] = seen.last
            end
        end
    end
    for name, last in pairs(lasts) do
        local first = firsts[name]
        intros[name] = first and {intro = first[2], kind = first[3]} or {intro = nil, kind = last[2]}
    end
    return intros
end

local function shard_failure(folder, errors)
    local reports = {}
    for _, file in ipairs(os.files(path.join(folder, "*.failed"))) do
        table.insert(reports, io.readfile(file))
    end
    table.sort(reports)
    if #reports == 0 then
        reports = {tostring(errors)}
    end
    return table.concat(reports, "\n")
end

local function sharded_summaries(sdk, names, shards, pids)
    local folder = sdkfiles.workspace().fresh("constant-intros")
    local summaries, failure = {}, nil
    try {
        function ()
            runjobs("backports/constant-intros", function (shard)
                local argv = {"l", "-P", sdkfiles.root(), path.join(os.scriptdir(), "facts.lua"), "constant-intros", sdk, path.join(folder, shard .. ".tsv")}
                for _, index in ipairs(shards[shard]) do
                    table.insert(argv, tostring(index))
                end
                os.execv(os.programfile(), argv, {stdout = path.join(folder, shard .. ".out"), stderr = path.join(folder, shard .. ".err")})
            end, {total = #shards, comax = #shards})
            for shard = 1, #shards do
                table.insert(summaries, read_summary(path.join(folder, shard .. ".tsv")))
                table.insert(pids, tonumber(io.readfile(path.join(folder, shard .. ".tsv.pid"))))
            end
        end,
        catch {
            function (errors)
                failure = shard_failure(folder, errors)
            end
        },
        finally {
            function ()
                os.tryrm(folder)
            end
        }
    }
    if failure ~= nil then
        raise("%s", failure)
    end
    return summaries
end

function main(command, sdk, output, ...)
    assert(command == "constant-intros", "usage: facts.lua constant-intros <sdk> <summary file> <framework index>...")
    local indexes = {}
    for _, index in ipairs({...}) do
        table.insert(indexes, tonumber(index))
    end
    local failure
    try {
        function ()
            io.writefile(output .. ".pid", tostring(os.getpid()))
            write_summary(output, constant_summary(sdk, sdkfiles.framework_names(sdk), indexes))
        end,
        catch {
            function (errors)
                failure = tostring(errors)
            end
        }
    }
    if failure ~= nil then
        io.writefile(output .. ".failed", failure)
        raise("%s", failure)
    end
end

function constant_intros(sdk, opt)
    local pids = {}
    if opt and opt.report then
        opt.report.pids = pids
    end
    local file = path.join(sdkfiles.cache_folder(sdk), "constant_intros.tsv")
    if os.isfile(file) then
        local cached = {}
        for line in io.lines(file) do
            local name, intro, kind = string.match(line, "^([^\t]*)\t([^\t]*)\t([^\t]*)$")
            assert(name, "a malformed constant intro row in " .. file .. ": " .. line)
            cached[name] = {intro = tonumber(intro), kind = kind}
        end
        return cached
    end
    local names = sdkfiles.framework_names(sdk)
    local shards = {}
    for index = 1, math.max(1, math.min((opt and opt.shards) or CONSTANT_SHARDS, #names)) do
        shards[index] = {}
    end
    for index = 1, #names do
        table.insert(shards[(index - 1) % #shards + 1], index)
    end
    local summaries
    if #shards > 1 then
        summaries = sharded_summaries(sdk, names, shards, pids)
    else
        summaries = {constant_summary(sdk, names, shards[1])}
    end
    local intros = merge_summaries(summaries)
    local rows = {}
    for name, found in pairs(intros) do
        table.insert(rows, string.format("%s\t%s\t%s", name, found.intro and tostring(found.intro) or "", found.kind))
    end
    table.sort(rows)
    os.mkdir(path.directory(file))
    local temp = file .. "." .. hash.strhash128(tostring({}) .. file) .. ".part"
    io.writefile(temp, table.concat(rows, "\n") .. (#rows > 0 and "\n" or ""))
    os.mv(temp, file)
    return intros
end

function swift_facts(sdk, name, version, scratch)
    local output = path.join(scratch, name .. "." .. tostring(os.getpid()) .. "." .. hash.strhash128(tostring({}) .. name .. tostring(os.mclock())) .. ".json")
    os.execv(sdkfiles.digester(), {"-dump-sdk", "-module", name, "-sdk", sdk, "-target", target_of(version), "-avoid-location",
        "-avoid-tool-args", "-swift-only", "-module-cache-path", sdkfiles.model_cache(sdk), "-o", output})
    local document = json.loadfile(output)
    os.tryrm(output)
    assert(document, "the digester wrote no JSON for " .. name)
    local state = {rows = {}, seen = {}}
    swift_walk(state, document.ABIRoot or document, "", nil)
    return state.rows
end

