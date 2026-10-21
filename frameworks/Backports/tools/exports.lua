local generate = import("generate", {rootdir = os.scriptdir(), anonymous = true})
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
    elseif kind == "C function" or kind == "global variable" then
        return "_" .. name, "symbol"
    end
    return kind .. "|" .. container .. "|" .. name, "method"
end

local function sorted(list)
    table.sort(list)
    return list
end

function main(libdir, report)
    libdir = libdir or path.join(sdkfiles.root(), "build", "iphoneos", "armv7", "release")
    report = report or path.join(sdkfiles.build_root(), "exports.txt")
    local state = generate.prepare()
    local keys = sources.from_objects()
    local libs = libraries.read(libdir)
    local public, tbd_read, tbd_total = publics.build(state.frameworks, state.sdk)

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

    local duplicated = {}
    for _, kind in ipairs(KINDS) do
        duplicated[kind] = {}
    end
    local dup_lines = {}
    local function duplicate(kind, name, owners)
        table.insert(duplicated[kind], name)
        table.insert(dup_lines, string.format("duplicated\t%s\t%s\t%s", kind, name, table.concat(sorted(owners), ",")))
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
                table.insert(missing_lines, string.format("missing\t%s\t%s\t%s", framework, kind, name))
            elseif #owners == 0 then
                count.internal = count.internal + 1
                if kind == "class" then
                    table.insert(internal_lines, string.format("not public\t%s\t%s\t%s", framework, kind, name))
                end
            end
        end
    end

    local summary = {string.format("libraries %d, public frameworks %d of %d read from their .tbd", #libs, tbd_read, tbd_total)}
    local total_missing, total_duplicated = 0, 0
    for _, kind in ipairs(KINDS) do
        local count = counts[kind]
        total_missing = total_missing + count.missing
        total_duplicated = total_duplicated + #duplicated[kind]
        table.insert(summary, string.format("%-18s implemented %d, exported once %d, missing %d, duplicated %d, not public %d",
            kind, count.implemented, count.once, count.missing, #duplicated[kind], count.internal))
    end
    table.insert(summary, string.format("total: missing %d, duplicated %d", total_missing, total_duplicated))

    local lines = {}
    for _, line in ipairs(dup_lines) do
        table.insert(lines, line)
    end
    table.sort(missing_lines)
    for _, line in ipairs(missing_lines) do
        table.insert(lines, line)
    end
    table.sort(internal_lines)
    for _, line in ipairs(internal_lines) do
        table.insert(lines, line)
    end
    io.writefile(report, table.concat(summary, "\n") .. "\n" .. table.concat(lines, "\n") .. (#lines > 0 and "\n" or ""))
    print(table.concat(summary, "\n"))
    print("report " .. report)

    local status = {}
    local total_implemented, total_members = 0, 0
    for _, framework in ipairs(state.frameworks) do
        local implemented, members = 0, 0
        for _, row in ipairs(generate.in_scope_rows(state, framework)) do
            if row.kind ~= "enum constant" then
                members = members + 1
                if generate.is_implemented(keys, framework, row) then
                    implemented = implemented + 1
                end
            end
        end
        total_implemented = total_implemented + implemented
        total_members = total_members + members
        table.insert(status, string.format("%-28s implemented %d of %d", framework.name, implemented, members))
    end
    table.insert(status, string.format("%-28s implemented %d of %d", "total", total_implemented, total_members))
    local status_report = path.join(path.directory(report), "status.txt")
    io.writefile(status_report, table.concat(status, "\n") .. "\n")
    print("status " .. status_report)

    if total_missing > 0 or total_duplicated > 0 then
        raise("the export check failed: %d public symbol%s missing, %d duplicated", total_missing,
              total_missing == 1 and "" or "s", total_duplicated)
    end
end
