import("core.base.json")
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})
local aggregate = import("aggregate", {rootdir = os.scriptdir(), anonymous = true})

local APPS = {"ish", "ppsspp", "pojav", "provenance", "delta", "utm", "aidoku", "yattee", "session", "telegram"}
local SKIP_EXTENSIONS = {png = true, plist = true, nib = true, car = true, json = true, strings = true, storyboardc = true}
local FUI = {Foundation = true, UIKit = true, UIFoundation = true, CoreFoundation = true}

local function cache_dir()
    return path.join(aggregate.corpus_dir(), "selcache")
end

local function output_of(program, argv)
    local out = ""
    try {
        function ()
            out = os.iorunv(program, argv)
        end,
        catch {
            function ()
                out = ""
            end
        }
    }
    return out
end

local function trim(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function bundle_selectors(appdir)
    local sels = {}
    for _, file in ipairs(os.files(path.join(appdir, "**"))) do
        local extension = file:match("%.([^./]+)$")
        if not (extension and SKIP_EXTENSIONS[extension]) and output_of("file", {file}):find("Mach-O", 1, true) then
            local out = output_of("otool", {"-v", "-s", "__TEXT", "__objc_methname", file})
            for line in out:gmatch("[^\n]+") do
                local name = line:match("^%x%x%x%x%x%x%x%x+%s+(%S.*)$")
                if name then
                    sels[trim(name)] = true
                end
            end
        end
    end
    return sels
end

local function extract()
    os.mkdir(cache_dir())
    for _, app in ipairs(APPS) do
        local base = path.join(aggregate.corpus_dir(), app, "extracted", "Payload")
        local bundles = os.isdir(base) and os.dirs(path.join(base, "*.app")) or {}
        byteorder.sort(bundles)
        if bundles[1] then
            local sels = {}
            for name in pairs(bundle_selectors(bundles[1])) do
                table.insert(sels, name)
            end
            byteorder.sort(sels)
            json.mark_as_array(sels)
            local file = assert(io.open(path.join(cache_dir(), app .. ".json"), "w"))
            file:write(json.encode(sels) .. "\n")
            file:close()
            print(string.format("%s: %d selectors cached", app, #sels))
        end
    end
    print("EXTRACT-DONE")
end

local function registry_selectors()
    local index = {}
    local file = aggregate.registry_export()
    if not os.isfile(file) then
        return index
    end
    local first = true
    for line in io.lines(file) do
        if first then
            first = false
        else
            local p = {}
            for field in (line .. "\t"):gmatch("([^\t]*)\t") do
                table.insert(p, field)
            end
            if #p >= 3 then
                local class, selector = p[2]:match("^[-+]%[(%S+)%s+(.+)%]$")
                if class then
                    index[selector] = index[selector] or {}
                    table.insert(index[selector], {framework = p[1], class = class, status = p[3]})
                end
            end
        end
    end
    return index
end

local function tags(list)
    local parts = {}
    for _, m in ipairs(list) do
        table.insert(parts, m.framework .. ":" .. m.class .. ":" .. m.status)
    end
    return table.concat(parts, ";")
end

local function report()
    local universe = aggregate.selector_universe()
    local regsel = registry_selectors()
    local app_sel, app_count = {}, 0
    for _, app in ipairs(APPS) do
        local file = path.join(cache_dir(), app .. ".json")
        if os.isfile(file) then
            local held = json.decode(io.readfile(file))
            if held == nil then
                raise("selector-demand.lua: %s is not readable JSON", file)
            end
            local set = {}
            for _, name in ipairs(held) do
                set[name] = true
            end
            app_sel[app] = set
            app_count = app_count + 1
        end
    end
    local freq, names = {}, {}
    for _, app in ipairs(APPS) do
        for name in pairs(app_sel[app] or {}) do
            if not universe[name] then
                if freq[name] == nil then
                    freq[name] = {}
                    table.insert(names, name)
                end
                freq[name][app] = true
            end
        end
    end
    local rows = {}
    for _, name in ipairs(names) do
        local apps = {}
        for app in pairs(freq[name]) do
            table.insert(apps, app)
        end
        byteorder.sort(apps)
        table.insert(rows, {selector = name, apps = apps})
    end
    rows = aggregate.ranked(rows, function (row) return #row.apps end, function (row) return row.selector end)

    local out = path.join(aggregate.corpus_dir(), "selector-demand-7-10.tsv")
    local file = assert(io.open(out, "w"))
    file:write("apps\tselector\tregistry_matches(framework:class:status)\tapplist\n")
    for _, row in ipairs(rows) do
        file:write(string.format("%d\t%s\t%s\t%s\n", #row.apps, row.selector, tags(regsel[row.selector] or {}), table.concat(row.apps, ",")))
    end
    file:close()

    local fui_rows = {}
    for _, row in ipairs(rows) do
        local matched = {}
        for _, m in ipairs(regsel[row.selector] or {}) do
            if FUI[m.framework] then
                table.insert(matched, m)
            end
        end
        if #matched > 0 then
            table.insert(fui_rows, {n = #row.apps, selector = row.selector, matches = matched, apps = row.apps})
        end
    end
    local function is_impl(matches)
        for _, m in ipairs(matches) do
            local c = m.class
            if not (c:sub(-8) == "Delegate" or c:sub(-10) == "DataSource" or c:sub(-8) == "Observer") then
                return false
            end
        end
        return true
    end
    local outf = path.join(aggregate.corpus_dir(), "selector-demand-FUIKit.tsv")
    local sent = aggregate.ranked(fui_rows, function (row) return row.n end, function (row) return row.selector end)
    local keyed = {}
    for index, row in ipairs(sent) do
        local group = is_impl(row.matches) and "1" or "0"
        keyed[group .. "\1" .. string.format("%07d", 1000000 - row.n) .. "\1" .. row.selector .. "\1" .. string.format("%07d", index)] = row
    end
    local file_f = assert(io.open(outf, "w"))
    file_f:write("apps\tkind\tselector\tframework:class:status\tapplist\n")
    for _, key in ipairs(byteorder.keys(keyed)) do
        local row = keyed[key]
        file_f:write(string.format("%d\t%s\t%s\t%s\t%s\n", row.n, is_impl(row.matches) and "impl?" or "send?", row.selector,
                                   tags(row.matches), table.concat(row.apps, ",")))
    end
    file_f:close()

    print(string.format("# %d apps; %d new selectors (not in 6.0). Full: %s", app_count, #rows, out))
    print(string.format("# F+UIKit-registry-matched: %d selectors -> %s", #fui_rows, outf))
    print("# TOP 'send?' (app calls on a system class; not a delegate it implements):")
    local shown = 0
    for _, key in ipairs(byteorder.keys(keyed)) do
        local row = keyed[key]
        if not is_impl(row.matches) and shown < 30 then
            shown = shown + 1
            print(string.format("  %2d  %-44s %s", row.n, row.selector, tags(row.matches)))
        end
    end
    print("# TOP F+UIKit-registry-matched new selectors by app-count (framework:class:status):")
    for index = 1, math.min(60, #fui_rows) do
        local row = fui_rows[index]
        print(string.format("  %2d  %-52s %s", row.n, row.selector, tags(row.matches)))
    end
end

function main(command)
    if command == "extract" then
        extract()
    elseif command == nil or command == "report" then
        report()
    else
        raise("usage: selector-demand.lua [extract|report]")
    end
end
