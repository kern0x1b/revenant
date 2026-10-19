local render = import("render_headers", {anonymous = true})
local emit = import("emit", {anonymous = true})
local target = import("target_availability", {anonymous = true})
local port_enums = import("port_enums", {anonymous = true})
local project = import("project", {anonymous = true})
local json = import("core.base.json")

local function read_text(filepath)
    local handle = assert(io.open(filepath, "rb"), "cannot open " .. filepath)
    local text = handle:read("a")
    handle:close()
    return text
end

local function group_by_framework(rows)
    local by_framework = {}
    for _, row in ipairs(rows) do
        local list = by_framework[row[1]] or {}
        list[#list + 1] = row
        by_framework[row[1]] = list
    end
    return by_framework
end

local function read_ir(filepath)
    local rows = {}
    for _, row in ipairs(render.rows_of(read_text(filepath))) do
        if row[2] ~= "meta" then
            rows[#rows + 1] = row
        end
    end
    return rows, group_by_framework(rows)
end

local function location_of(sdk, framework)
    local top = string.match(framework, "^([^/]+)")
    for _, folder in ipairs({"Frameworks", "SubFrameworks"}) do
        local dir = path.join(sdk, "System", "Library", folder, top .. ".framework")
        if os.isdir(dir) then return folder, dir end
    end
    return nil
end

local function sdk_folder(dir, framework)
    local base = dir
    for segment in string.gmatch(framework, "/([^/]+)") do
        base = path.join(base, "Frameworks", segment .. ".framework")
    end
    return base
end

local function swift_names_of(sdk)
    local swift = {}
    local files = {}
    for _, dir in ipairs(os.dirs(path.join(sdk, "System", "Library", "Frameworks", "*.framework"))) do
        for _, file in ipairs(os.files(path.join(dir, "Headers", "*.apinotes"))) do table.insert(files, file) end
    end
    for _, file in ipairs(os.files(path.join(sdk, "usr", "include", "*.apinotes"))) do table.insert(files, file) end
    table.sort(files)
    local kinds = {Classes = "interface", Protocols = "protocol"}
    for _, file in ipairs(files) do
        local framework, kind, name = nil, nil, nil
        for line in io.lines(file) do
            local top_name = string.match(line, "^Name:%s*(%S+)")
            local section = string.match(line, "^(%a+):%s*$")
            local entry = string.match(line, "^%- Name:%s*(%S+)")
            local swift_name = string.match(line, "^  SwiftName:%s*(%S+)")
            if top_name then
                framework = top_name
            elseif section then
                kind, name = kinds[section], nil
            elseif entry then
                name = entry
            elseif swift_name and kind and name and framework then
                swift[framework] = swift[framework] or {}
                swift[framework][kind] = swift[framework][kind] or {}
                swift[framework][kind][name] = swift_name
                name = nil
            end
        end
    end
    return swift
end

local function usr_dirs_of(sdk)
    local dirs, umbrellas, bare, modules, paths, any, own_folder = {}, {}, {}, {}, {}, {}, {}
    for _, file in ipairs(os.files(path.join(sdk, "usr", "include", "*.modulemap"))) do
        local module = nil
        for line in io.lines(file) do
            local name = string.match(line, "^module%s+([%w_]+)")
            if name then
                module = name
                modules[name] = true
            end
            local umbrella = string.match(line, '^%s*umbrella%s+"([^"]+)"')
            if module and umbrella and dirs[module] == nil then dirs[module] = umbrella end
            local folder, base = string.match(line, '^%s*header%s+"([^"/]+)/([^"/]+)"')
            if folder and base == folder .. ".h" then umbrellas[folder] = folder .. "/" .. base end
            if module and string.match(line, '^%s*header%s+"[^"/]+"') then bare[module] = true end
            local rel = string.match(line, '^%s*header%s+"([^"]+)"')
            if module and rel then
                local base = string.match(rel, "([^/]+)$")
                local folder = string.match(rel, "^(.*)/[^/]+$")
                paths[module] = paths[module] or {}
                paths[module][base] = paths[module][base] or rel
                if folder and own_folder[module] == nil then own_folder[module] = folder end
                any[base] = any[base] or {}
                if not table.contains(any[base], rel) then table.insert(any[base], rel) end
            end
        end
    end
    local folders, folder_umbrellas = {}, {}
    for _, dir in ipairs(os.dirs(path.join(sdk, "usr", "include", "*"))) do
        local folder = path.filename(dir)
        for _, file in ipairs(os.files(path.join(dir, "*.h"))) do
            local base = path.filename(file)
            if folders[base] == nil then folders[base] = folder else folders[base] = false end
        end
        if os.isfile(path.join(dir, folder .. ".h")) then folder_umbrellas[folder] = folder .. "/" .. folder .. ".h" end
    end
    local reexport = {}
    local frameworks = os.dirs(path.join(sdk, "System", "Library", "Frameworks", "*.framework"))
    table.sort(frameworks)
    for _, dir in ipairs(frameworks) do
        local name = string.match(path.filename(dir), "^(.-)%.framework$")
        local umbrella = path.join(dir, "Headers", name .. ".h")
        if name and string.sub(name, 1, 1) ~= "_" and os.isfile(umbrella) then
            for line in io.lines(umbrella) do
                local top = string.match(line, "^%s*#%s*%a+%s*[<\"]_([^/>\"]+)/")
                if top and reexport["_" .. top] == nil then reexport["_" .. top] = name end
            end
        end
    end
    local function exists(rel) return os.isfile(path.join(sdk, "usr", "include", rel)) end
    local function target(rel)
        local umbrella = umbrellas[path.directory(rel)] or folder_umbrellas[path.directory(rel)]
        if umbrella and string.find(io.readfile(path.join(sdk, "usr", "include", rel)) or "", "instead of this file directly", 1, true) then
            return umbrella
        end
        return rel
    end
    return {prefix = dirs, umbrella = umbrellas, bare = bare, folder = folders, exists = exists, target = target, modules = modules,
        paths = paths, any = any, own_folder = own_folder, reexport = reexport, swift = swift_names_of(sdk),
        sdk_framework = function (name) return location_of(sdk, name) ~= nil end}
end

local function destination_of(folder, framework)
    local out = folder .. "/" .. string.match(framework, "^([^/]+)") .. ".framework"
    for segment in string.gmatch(framework, "/([^/]+)") do
        out = out .. "/Frameworks/" .. segment .. ".framework"
    end
    return out
end

local function write_all(out, folder, framework, result)
    local dest = path.join(out, destination_of(folder, framework))
    for relative, text in pairs(result.files) do
        emit.file(path.join(dest, relative), text)
    end
end

local function write_usr_module(root, sdk, framework, result, usr_dirs, entries, totals)
    for relative, text in pairs(result.files) do
        local base = string.gsub(relative, "^Headers/", "")
        local rel = usr_dirs.paths[framework] and usr_dirs.paths[framework][base]
        local prefix = usr_dirs.prefix[framework] or usr_dirs.own_folder[framework]
        local found = usr_dirs.any[base] or {}
        for _, candidate in ipairs(found) do
            if not rel and prefix and string.match(candidate, "^(.*)/[^/]+$") == prefix then rel = candidate end
        end
        if not rel and #found == 1 then rel = found[1] end
        rel = rel or path.join(prefix or usr_dirs.folder[base] or "", base)
        local folder = string.match(rel, "^(.*)/[^/]+$") or ""
        local dest = path.join(root, "usr", "include", rel)
        emit.file(dest, text)
        if entries then
            local replaced = path.join(sdk, "usr", "include", folder)
            entries[replaced] = entries[replaced] or {}
            table.insert(entries[replaced], {name = base, external = path.absolute(dest)})
        end
    end
    totals.frameworks = totals.frameworks + 1
    totals.files = totals.files + result.counts.files
    totals.lines = totals.lines + (result.counts.lines or 0)
    for kind, n in pairs(result.counts.declarations) do
        totals.declarations[kind] = (totals.declarations[kind] or 0) + n
    end
    for reason, n in pairs(result.counts.skipped) do
        totals.skipped[reason] = (totals.skipped[reason] or 0) + n
    end
end

local function print_causes(report)
    local labels = {}
    for label in pairs(report.causes) do labels[#labels + 1] = label end
    table.sort(labels)
    for _, label in ipairs(labels) do
        print(string.format("  %6d  %s", report.causes[label], label))
    end
end

local function compare_mode(args, by_framework)
    local framework = args.framework
    local ir_rows = by_framework[framework] or {}
    local decl_rows = render.rows_of(read_text(args.compare))
    local report = render.compare(ir_rows, decl_rows)
    print(string.format("%s: IR rows %d, decls rows %d, equal %d", framework, report.ir, report.decls, report.equal))
    local differences = 0
    for _, n in pairs(report.causes) do differences = differences + n end
    print(string.format("%s: differences %d", framework, differences))
    print_causes(report)
    return 0, differences, report.causes
end

local function write_frameworks(root, sdk, rows, by_framework, names, usr_dirs, entries)
    local defs = render.defs_of(rows)
    local totals = {frameworks = 0, not_in_sdk = 0, files = 0, lines = 0, declarations = {}, skipped = {}}
    for _, framework in ipairs(names) do
        local folder, dir = location_of(sdk, framework)
        if folder == nil and usr_dirs.modules[framework] then
            local result = render.render(framework, by_framework[framework] or {}, defs, false, false, usr_dirs)
            write_usr_module(root, sdk, framework, result, usr_dirs, entries, totals)
        elseif folder == nil then
            totals.not_in_sdk = totals.not_in_sdk + 1
        else
            local has_map = os.isfile(path.join(sdk_folder(dir, framework), "Modules", "module.modulemap"))
            local has_sdk_headers = #os.files(path.join(dir, "Headers", "*.h")) > 0
            local result = render.render(framework, by_framework[framework] or {}, defs, has_map, has_sdk_headers, usr_dirs)
            write_all(root, folder, framework, result)
            if entries then
                local dest = path.join(root, destination_of(folder, framework))
                for relative in pairs(result.files) do
                    local replaced = path.join(sdk_folder(dir, framework), path.directory(relative))
                    entries[replaced] = entries[replaced] or {}
                    table.insert(entries[replaced], {name = path.filename(relative), external = path.absolute(path.join(dest, relative))})
                end
            end
            totals.frameworks = totals.frameworks + 1
            totals.files = totals.files + result.counts.files
            totals.lines = totals.lines + (result.counts.lines or 0)
            for kind, n in pairs(result.counts.declarations) do
                totals.declarations[kind] = (totals.declarations[kind] or 0) + n
            end
            for reason, n in pairs(result.counts.skipped) do
                totals.skipped[reason] = (totals.skipped[reason] or 0) + n
            end
        end
    end
    return totals
end

function overlay_text(entries)
    local roots = {}
    for folder, files in pairs(entries) do
        table.sort(files, function (a, b) return a.name < b.name end)
        local contents = {}
        for _, file in ipairs(files) do
            table.insert(contents, {type = "file", name = file.name, ["external-contents"] = file.external})
        end
        table.insert(roots, {type = "directory", name = path.absolute(folder), contents = json.mark_as_array(contents)})
    end
    table.sort(roots, function (a, b) return a.name < b.name end)
    return json.encode({["case-sensitive"] = "false", version = 0, roots = json.mark_as_array(roots)})
end

local function print_totals(label, totals, seconds)
    local kinds = {}
    for kind in pairs(totals.declarations) do kinds[#kinds + 1] = kind end
    table.sort(kinds)
    print(string.format("%s: %d frameworks written, %d not in the SDK's frameworks (usr/include), %d files, %d lines, %d s",
        label, totals.frameworks, totals.not_in_sdk, totals.files, totals.lines, seconds))
    for _, kind in ipairs(kinds) do
        print(string.format("  declarations %-10s %d", kind, totals.declarations[kind]))
    end
    local reasons = {}
    for reason in pairs(totals.skipped) do reasons[#reasons + 1] = reason end
    table.sort(reasons)
    for _, reason in ipairs(reasons) do
        print(string.format("  skipped %-30s %d", reason, totals.skipped[reason]))
    end
end

local function write_mode(args, rows, by_framework)
    local out = args.out
    local sdk = args.sdk
    if out == nil or sdk == nil then
        print("headers: writing needs --out and --sdk")
        return 2
    end
    if args.port_values == nil then
        print("headers: writing needs --port-values (the port's enumerator values, written by tools/found/port_values.lua)")
        return 2
    end
    local names = {}
    if args.framework then
        names = {args.framework}
    else
        for name in pairs(by_framework) do names[#names + 1] = name end
        table.sort(names)
    end
    local usr_dirs = usr_dirs_of(sdk)
    local started = os.time()
    local faithful = write_frameworks(out, sdk, rows, by_framework, names, usr_dirs)
    print_totals("headers", faithful, os.time() - started)
    local release = project.port_release(args)
    local listed = target.read_registry(path.join(args.tree, "packages", "a", "apple-backports"))
    local port_rows, lowered = target.lowered_copy(rows, listed, release)
    local run = port_enums.read(args.port_values)
    local widened, absent, unparsed, types = port_enums.apply(port_rows, run)
    local port = path.join(out, "port", release)
    local entries = {}
    local ported = write_frameworks(port, sdk, port_rows, group_by_framework(port_rows), names, usr_dirs, entries)
    local overlay = path.join(port, "vfs.yaml")
    io.writefile(overlay, overlay_text(entries))
    print(string.format("headers: %d availability marks lowered to the port's release %s, written under %s, overlay %s",
        lowered, release, port, overlay))
    print(string.format("headers: %d enumerator values and %d enum types taken from the port's triple's run, %d enumerators the run "
        .. "does not declare (%d of them in a module it does not parse, kept as the IR has them)", widened, types, absent, unparsed))
    print_totals("headers port", ported, os.time() - started)
    return 0, string.format("%d frameworks, %d files, %d lines", faithful.frameworks, faithful.files, faithful.lines)
end

function run(args)
    if args.ir == nil then
        print("headers: needs --ir (the full 21-column IR)")
        return 2
    end
    local rows, by_framework = read_ir(args.ir)
    if args.compare then
        if args.framework == nil then
            print("headers: --compare needs --framework")
            return 2
        end
        return compare_mode(args, by_framework)
    end
    return write_mode(args, rows, by_framework)
end
