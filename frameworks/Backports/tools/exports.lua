local sdkfiles = import("sdk", {rootdir = os.scriptdir(), anonymous = true})
local sources = import("implemented", {rootdir = os.scriptdir(), anonymous = true})

function exported_of(library)
    local symbols = {}
    for line in os.iorunv("nm", {"-gU", library}):gmatch("[^\n]+") do
        local name = line:match("^%x+ %a (%S+)$")
        if name then
            symbols[name] = true
        end
    end
    return symbols
end

function methods_of(library)
    local methods, named, unnamed = {}, 0, 0
    for line in os.iorunv("otool", {"-ov", library}):gmatch("[^\n]+") do
        local sign, container, selector = line:match("([%+%-])%[(%S+) ([^%]]+)%]$")
        if sign and line:match("^%s+imp%s") then
            named = named + 1
            local class = container:match("^[^(]+")
            local kind = sign == "+" and "class method" or "instance method"
            methods[kind .. "|" .. class .. "|" .. selector] = true
        elseif line:match("^%s+imp%s") then
            unnamed = unnamed + 1
        end
    end
    return methods, named, unnamed
end

function keys_of()
    local keys = {}
    for framework, set in pairs(sources.from_objects()) do
        for key in pairs(set) do
            table.insert(keys, {framework = framework, key = key})
        end
    end
    table.sort(keys, function (a, b)
        return a.framework .. "\0" .. a.key < b.framework .. "\0" .. b.key
    end)
    return keys
end

function owners_of(item, libraries)
    local kind, container, name = item.key:match("^(.-)|(.-)|(.*)$")
    local owners = {}
    for _, library in ipairs(libraries) do
        local found
        if kind == "class" then
            found = library.exports["_OBJC_CLASS_$_" .. name]
        elseif kind == "C function" or kind == "global variable" then
            found = library.exports["_" .. name]
        elseif kind == "property" then
            found = library.methods["instance method|" .. container .. "|" .. name]
        else
            found = library.methods[item.key]
        end
        if found then
            table.insert(owners, library.name)
        end
    end
    return owners
end

function main(libdir, report)
    libdir = libdir or path.join(sdkfiles.root(), "build", "iphoneos", "armv7", "release")
    report = report or path.join(sdkfiles.build_root(), "exports.txt")
    local libraries = {}
    for _, file in ipairs(os.files(path.join(libdir, "lib*.dylib"))) do
        local methods, named, unnamed = methods_of(file)
        table.insert(libraries, {name = path.filename(file), exports = exported_of(file), methods = methods,
            named = named, unnamed = unnamed})
    end
    assert(#libraries > 0, "no lib*.dylib in " .. libdir)
    local unnamed = 0
    for _, library in ipairs(libraries) do
        unnamed = unnamed + library.unnamed
    end
    local lines, counts, missing, duplicated, once = {}, {}, 0, 0, 0
    for _, item in ipairs(keys_of()) do
        local kind = item.key:match("^(.-)|")
        counts[kind] = counts[kind] or {missing = 0, duplicated = 0, once = 0}
        local owners = owners_of(item, libraries)
        if #owners == 0 then
            missing = missing + 1
            counts[kind].missing = counts[kind].missing + 1
            table.insert(lines, string.format("missing\t%s\t%s", item.framework, item.key))
        elseif #owners > 1 then
            duplicated = duplicated + 1
            counts[kind].duplicated = counts[kind].duplicated + 1
            table.insert(lines, string.format("duplicated\t%s\t%s\t%s", item.framework, item.key, table.concat(owners, ",")))
        else
            once = once + 1
            counts[kind].once = counts[kind].once + 1
        end
    end
    local summary = {}
    for kind, count in pairs(counts) do
        table.insert(summary, string.format("%-18s exported once %d, missing %d, duplicated %d", kind, count.once, count.missing, count.duplicated))
    end
    table.sort(summary)
    table.insert(summary, 1, string.format("libraries %d, unnamed method implementations %d", #libraries, unnamed))
    table.insert(summary, string.format("total: exported once %d, missing %d, duplicated %d", once, missing, duplicated))
    io.writefile(report, table.concat(summary, "\n") .. "\n" .. table.concat(lines, "\n") .. (#lines > 0 and "\n" or ""))
    print(table.concat(summary, "\n"))
    print("report " .. report)
end
