local tbd = import("tbd", {anonymous = true})

local RANK = {available = 4, unavailable = 3, undeclared = 2, other = 1, deprecated = 0}

function statement_of(kind, api)
    if kind == "constant" or kind == "function" then
        return "(void)(" .. (string.gsub(api, "%(%)$", "")) .. ");"
    elseif kind == "enum" or kind == "struct" or kind == "typealias" then
        return "(void)(" .. api .. " *)0;"
    elseif kind == "protocol" then
        return "(void)@protocol(" .. api .. ");"
    elseif kind == "class" then
        return "(void)[" .. api .. " class];"
    end
    return nil
end

function probe_of(import_name, headers, statements)
    local lines = {}
    for _, header in ipairs(headers) do
        table.insert(lines, "#import <" .. import_name .. "/" .. header .. ">")
    end
    table.insert(lines, "void revenant_probe(void) {")
    local line_of = {}
    for i, statement in ipairs(statements) do
        table.insert(lines, statement)
        line_of[#lines] = i
    end
    table.insert(lines, "}")
    return table.concat(lines, "\n") .. "\n", line_of
end

local function classify(message)
    local version = string.match(message, "is only available on iOS ([%d%.]+) or newer")
    if version then
        return "available", version
    end
    if string.find(message, "is unavailable", 1, true) then
        return "unavailable", nil
    end
    if string.find(message, "is deprecated", 1, true) then
        return "deprecated", nil
    end
    if string.find(message, "undeclared identifier", 1, true) or string.find(message, "unknown type name", 1, true) then
        return "undeclared", nil
    end
    return "other", nil
end

function diagnostics_of(text, source)
    local out = {}
    local prefix = source .. ":"
    for line in string.gmatch(text, "[^\n]+") do
        if string.sub(line, 1, #prefix) == prefix then
            local at, message = string.match(string.sub(line, #prefix + 1), "^(%d+):%d+: %a+: (.*)$")
            if at and not string.find(line, ": note: ", 1, true) then
                local class, version = classify(message)
                local line_no = tonumber(at)
                local kept = out[line_no] and RANK[out[line_no].class] or -1
                if RANK[class] > 0 and RANK[class] > kept then
                    out[line_no] = {class = class, version = version, message = message}
                end
            end
        end
    end
    return out
end

function answer_of(diagnostic, release)
    if diagnostic == nil then
        return {status = "header-ok", needs = "lift", reason = "declared in the lifted headers and available at iOS " .. release,
                introduced = nil}
    end
    if diagnostic.class == "available" then
        return {status = "missing", needs = "code", introduced = diagnostic.version,
                reason = "declared in the lifted headers with an iOS introduction of " .. diagnostic.version .. ", after " .. release}
    elseif diagnostic.class == "unavailable" then
        return {status = "missing", needs = "code", introduced = nil,
                reason = "unavailable in the lifted headers (NS_UNAVAILABLE or an unavailable mark) at iOS " .. release}
    elseif diagnostic.class == "undeclared" then
        return {status = "undecided", needs = "lift", introduced = nil,
                reason = "not declared in the lifted headers of the framework"}
    end
    return {status = "undecided", needs = "lift", introduced = nil,
            reason = "the lifted headers do not compile this name: " .. diagnostic.message}
end

function decide(opts, unit, rows)
    local dir = tbd.framework_dir(opts.sdk, unit)
    local out = {}
    if not os.isdir(dir) then
        return out
    end
    assert(os.isfile(opts.clang), "the compiler " .. opts.clang .. " is not a file: the lifted-header pass needs clang (--clang)")
    local headers = {}
    for _, header in ipairs(os.files(path.join(dir, "Headers", "*.h"))) do
        table.insert(headers, path.filename(header))
    end
    table.sort(headers)
    local names = string.split(unit, "/")
    local statements, keys = {}, {}
    for _, row in ipairs(rows) do
        local statement = statement_of(row.kind, row.api)
        if statement then
            table.insert(statements, statement)
            table.insert(keys, row.key)
        end
    end
    if #statements == 0 then
        return out
    end
    local source_text, line_of = probe_of(names[#names], headers, statements)
    local stem = string.gsub(unit, "/", "_")
    local source = path.join(opts.out, stem .. ".m")
    local log = path.join(opts.out, stem .. ".log")
    os.mkdir(opts.out)
    io.writefile(source, source_text)
    local argv = {"-fsyntax-only", "-x", "objective-c", "-target", "armv7-apple-ios" .. opts.release, "-isysroot", opts.sdk,
                  "-ivfsoverlay", opts.vfs, "-F", path.directory(dir), "-ferror-limit=0", "-fno-color-diagnostics",
                  "-Wno-incompatible-sysroot", "-Wunguarded-availability-new", "-Wunguarded-availability", source}
    local failed = false
    try {function() os.runv(opts.clang, argv, {stdout = log, stderr = log}) end, catch {function() failed = true end}}
    local diagnostics = diagnostics_of(io.readfile(log) or "", source)
    if failed and #table.keys(diagnostics) == 0 then
        raise("clang did not compile the probe of " .. unit .. " and gave no diagnostic on its statements: see " .. log)
    end
    for line, index in pairs(line_of) do
        out[keys[index]] = answer_of(diagnostics[line], opts.release)
    end
    return out
end
