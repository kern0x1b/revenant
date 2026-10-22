local generate = import("generate", {rootdir = os.scriptdir(), anonymous = true})
local skeleton = import("skeleton", {rootdir = os.scriptdir(), anonymous = true})
local sources = import("implemented", {rootdir = os.scriptdir(), anonymous = true})
local libraries = import("libraries", {rootdir = os.scriptdir(), anonymous = true})
local publics = import("public", {rootdir = os.scriptdir(), anonymous = true})
local sdkfiles = import("sdk", {rootdir = os.scriptdir(), anonymous = true})

local KINDS = {"class", "C function", "global variable", "instance method", "class method", "objc symbol", "swift symbol"}

local function symbol_kind(name, letter)
    if name:find("^_OBJC_METACLASS_%$_") then
        return nil
    elseif name:find("^_OBJC_CLASS_%$_") then
        return "class"
    elseif name:find("^_OBJC_") then
        return "objc symbol"
    elseif name:find("^_%$s") then
        return "swift symbol"
    elseif letter == "T" or letter == "t" or letter == "W" or letter == "w" then
        return "C function"
    end
    return "global variable"
end

local function owner_of(kind, container, name)
    if kind == "class" then
        return "_OBJC_CLASS_$_" .. name, "symbol"
    elseif kind == "C function" or kind == "global variable" or kind == "swift symbol" then
        return "_" .. name, "symbol"
    end
    return kind .. "|" .. container .. "|" .. name, "method"
end

local function sorted(list)
    table.sort(list)
    return list
end

local function exported_owners(libs)
    local symbol_owners, symbol_kinds, method_owners = {}, {}, {}
    for _, library in ipairs(libs) do
        for name, letter in pairs(library.symbols) do
            local kind = symbol_kind(name, letter)
            if kind then
                symbol_owners[name] = symbol_owners[name] or {}
                table.insert(symbol_owners[name], library.name)
                symbol_kinds[name] = kind
            end
        end
        for key in pairs(library.methods) do
            method_owners[key] = method_owners[key] or {}
            table.insert(method_owners[key], library.name)
        end
    end
    return symbol_owners, symbol_kinds, method_owners
end

local function normalised(keys, symbol_owners)
    local function proxied(container)
        if container:startswith("Revenant") and symbol_owners["_OBJC_CLASS_$_" .. container:sub(9)] then
            return container:sub(9)
        end
        return container
    end
    local normal = {}
    for framework, set in pairs(keys) do
        normal[framework] = {}
        for key in pairs(set) do
            local kind, container, name = key:match("^(.-)|(.-)|(.*)$")
            if kind == "instance method" or kind == "class method" then
                key = kind .. "|" .. proxied(container) .. "|" .. name
            end
            normal[framework][key] = true
        end
    end
    return normal
end

function analyse(keys, libs, public)
    local symbol_owners, symbol_kinds, method_owners = exported_owners(libs)
    keys = normalised(keys, symbol_owners)

    local duplicated = {}
    for _, kind in ipairs(KINDS) do
        duplicated[kind] = {}
    end
    local lines = {}
    local function duplicate(kind, name, owners)
        table.insert(duplicated[kind], name)
        table.insert(lines, string.format("duplicated\t%s\t%s\t%s", kind, name, table.concat(sorted(owners), ",")))
    end
    for name, owners in pairs(symbol_owners) do
        if #owners > 1 then
            duplicate(symbol_kinds[name], name, owners)
        end
    end
    for key, owners in pairs(method_owners) do
        if #owners > 1 then
            duplicate(key:match("^(.-)|"), key, owners)
        end
    end

    local counts, missing_lines, internal_lines = {}, {}, {}
    for _, kind in ipairs(KINDS) do
        counts[kind] = {implemented = 0, once = 0, missing = 0, internal = 0}
    end
    for framework, set in pairs(keys) do
        for key in pairs(set) do
            local kind, container, name = key:match("^(.-)|(.-)|(.*)$")
            local id, lookup = owner_of(kind, container, name)
            local owners = (lookup == "symbol" and symbol_owners[id]) or (lookup == "method" and method_owners[id]) or {}
            local is_public
            if kind == "class" then
                is_public = public.classes[name]
            elseif lookup == "symbol" then
                is_public = public.symbols[name]
            else
                is_public = public.methods[id]
            end
            local count = counts[kind]
            count.implemented = count.implemented + 1
            if #owners == 1 then
                count.once = count.once + 1
            elseif #owners == 0 and is_public then
                count.missing = count.missing + 1
                table.insert(missing_lines, string.format("missing\t%s\t%s", framework, key))
            elseif #owners == 0 then
                count.internal = count.internal + 1
                if kind == "class" then
                    table.insert(internal_lines, string.format("not public\t%s\t%s\t%s", framework, kind, name))
                end
            end
        end
    end

    local summary = {}
    local total_missing, total_duplicated = 0, 0
    for _, kind in ipairs(KINDS) do
        local count = counts[kind]
        total_missing = total_missing + count.missing
        total_duplicated = total_duplicated + #duplicated[kind]
        table.insert(summary, string.format("%-18s implemented %d, exported once %d, missing %d, duplicated %d, not public %d",
            kind, count.implemented, count.once, count.missing, #duplicated[kind], count.internal))
    end
    table.insert(summary, string.format("total: missing %d, duplicated %d", total_missing, total_duplicated))

    table.sort(missing_lines)
    table.sort(internal_lines)
    table.join2(lines, missing_lines)
    table.join2(lines, internal_lines)
    return {keys = keys, summary = summary, lines = lines, missing = total_missing, duplicated = total_duplicated}
end

local function reachable(row, symbol_owners, method_owners)
    if row.kind == "class" then
        return symbol_owners["_OBJC_CLASS_$_" .. row.name] ~= nil
    elseif row.kind == "C function" or row.kind == "global variable" then
        return symbol_owners["_" .. row.name] ~= nil
    elseif row.kind == "Swift declaration" then
        local kind, symbol = skeleton.swift_stub(row)
        return kind ~= nil and symbol_owners["_" .. symbol] ~= nil
    elseif generate.inherited_init(row) then
        return true
    end
    return method_owners[generate.method_key(row)] ~= nil
end

local function implemented_row(row, framework, keys, defined)
    if row.kind == "protocol" then
        return defined[row.name] == true
    end
    return generate.is_implemented(keys, framework, row)
end

local function status_of(state, keys, symbol_owners, method_owners, defined)
    local status = {}
    local total_implemented, total_members, total_reachable, total_linkable = 0, 0, 0, 0
    for _, framework in ipairs(state.frameworks) do
        local implemented, members, linkable, found = 0, 0, 0, 0
        for _, row in ipairs(generate.in_scope_rows(state, framework)) do
            if row.kind ~= "enum constant" then
                members = members + 1
                if implemented_row(row, framework, keys, defined) then
                    implemented = implemented + 1
                end
                if row.kind ~= "protocol" then
                    linkable = linkable + 1
                    if reachable(row, symbol_owners, method_owners) then
                        found = found + 1
                    end
                end
            end
        end
        total_implemented = total_implemented + implemented
        total_members = total_members + members
        total_reachable = total_reachable + found
        total_linkable = total_linkable + linkable
        table.insert(status, string.format("%-28s implemented %d of %d, reachable %d of %d", framework.name, implemented, members, found, linkable))
    end
    table.insert(status, string.format("%-28s implemented %d of %d, reachable %d of %d", "total", total_implemented, total_members, total_reachable, total_linkable))
    return status
end

function main(libdir, report)
    libdir = libdir or path.join(sdkfiles.root(), "build", "iphoneos", "armv7", "release")
    report = report or path.join(sdkfiles.build_root(), "exports.txt")
    local started = os.mclock()
    local function phase(label)
        print(string.format("phase %s %.1f s", label, (os.mclock() - started) / 1000))
        started = os.mclock()
    end
    local state = generate.prepare()
    phase("facts")
    local keys = sources.from_objects()
    phase("objects")
    local libs = libraries.read(libdir)
    phase("libraries")
    local public, found, read = publics.build(state.frameworks, state.sdk)
    phase("sdk")
    local result = analyse(keys, libs, public)
    phase("analyse")

    local summary = table.join({string.format("libraries %d, declared classes and symbols the SDK's %d .tbd files export %d", #libs, read, found)}, result.summary)
    io.writefile(report, table.concat(summary, "\n") .. "\n" .. table.concat(result.lines, "\n") .. (#result.lines > 0 and "\n" or ""))
    print(table.concat(summary, "\n"))
    print("report " .. report)

    local symbol_owners, _, method_owners = exported_owners(libs)
    local status = status_of(state, result.keys, symbol_owners, method_owners, sources.defined_protocols())
    local status_report = path.join(path.directory(report), "status.txt")
    io.writefile(status_report, table.concat(status, "\n") .. "\n")
    print("status " .. status_report)

    if result.missing > 0 or result.duplicated > 0 then
        raise("the export check failed: %d public symbol%s missing, %d duplicated", result.missing,
              result.missing == 1 and "" or "s", result.duplicated)
    end
end
