local SDK = os.getenv("IR_SDK")
if not SDK then raise("IR_SDK must name the iPhoneOS SDK (for example .../iPhoneOS<version>.sdk)") end
SDK = path.absolute(SDK)
local MODE = os.getenv("IR_MODE") or "write"
local FOUND = path.absolute(os.scriptdir())
local TOOLS = path.directory(FOUND)
local REPO = path.directory(TOOLS)
local SPEC = os.getenv("IR_SPEC") or path.join(REPO, "packages", "frameworks", "apple-backports", "spec")
local FULL = os.getenv("IR_FULL")
local TIMEOUT = os.getenv("IR_TIMEOUT") or "300"
local CONFLICTS = os.getenv("IR_CONFLICTS") or path.join(FOUND, "conflicts.tsv")
local UNPARSED = os.getenv("IR_UNPARSED") or path.join(FOUND, "unparsed.tsv")
local NO_SHARD = os.getenv("IR_NO_SHARD") or path.join(FOUND, "no-shard.tsv")
local stream = import("gen.stream", {rootdir = TOOLS, anonymous = true})
local host = import("gen.host", {rootdir = TOOLS, anonymous = true})
local byteorder = import("byteorder", {rootdir = path.join(REPO, "modules"), anonymous = true})
local function build_decls()
    os.execv("xmake", {"f", "-P", FOUND, "-y", "-q"}, {curdir = REPO})
    os.execv("xmake", {"build", "-P", FOUND, "-y", "decls"}, {curdir = REPO})
end
local DECLS = os.getenv("IR_DECLS")
if not DECLS then
    build_decls()
    DECLS = host.target_product(REPO, FOUND, "decls")
end
local function decls_run(args)
    local lines = {}
    local status, errors = stream.run("/usr/bin/env", table.join({"IR_SDK=" .. SDK, DECLS}, args), function (line)
        table.insert(lines, line)
    end)
    return lines, status, (errors:gsub("%s+$", ""))
end
local function decls(args)
    local lines, status, errors = decls_run(args)
    if status ~= 0 then
        raise(string.format("decls %s exited %d: %s", table.concat(args, " "), status, errors))
    end
    return lines
end
local TRIPLE = (decls({"--target"})[1]:gsub("%s+$", ""))
local COLUMNS = 21
local SHARD_NAMES = "kind,usr,container,name,side,type,params,attrs,availability,message,declhash,value"
local shard = import("shard", {rootdir = FOUND})
local avail = import("avail", {rootdir = FOUND})
local atomic = import("atomic", {rootdir = TOOLS, anonymous = true})
local SDK_NAME

SDK = path.absolute(SDK)
SPEC = path.absolute(SPEC)
if MODE ~= "write" and MODE ~= "check" and MODE ~= "conflicts" and MODE ~= "gaps" and MODE ~= "docs" then
    raise("IR_MODE must be write, check, conflicts, gaps or docs, not " .. MODE)
end

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function cells_of(line)
    local out = {}
    for cell in (line .. "\t"):gmatch("([^\t]*)\t") do table.insert(out, cell) end
    return out
end

local function redact(s)
    return (s:gsub(SDK:gsub("%p", "%%%0"), "<sdk>"))
end

local function parse(f)
    local lines, status, errors = decls_run({"--timeout", TIMEOUT, f.name})
    if status ~= 0 then
        raise(string.format("%s: decls did not finish (status %d)%s", f.name, status, errors ~= "" and (": " .. redact(errors)) or ""))
    end
    if #lines == 0 then raise(f.name .. ": decls printed no rows") end
    for _, line in ipairs(lines) do
        if #cells_of(line) ~= COLUMNS then raise(f.name .. ": a row has " .. #cells_of(line) .. " columns, not " .. COLUMNS) end
    end
    return table.concat(lines, "\n") .. "\n"
end

local function is_unparsed(out)
    return cells_of(out:match("^[^\n]*"))[2] == "unparsed"
end

local function unparsed_row(name, reason)
    local row = {name, "unparsed", "-", "-", redact(reason)}
    for _ = #row + 1, COLUMNS do table.insert(row, "-") end
    return table.concat(row, "\t") .. "\n"
end

local function shard_header(libclang)
    return "#libclang=" .. libclang .. "\tsdk=" .. SDK_NAME .. "\tcolumns=" .. SHARD_NAMES .. "\n"
end

local function shard_path(label)
    return path.join(SPEC, label, "declarations.tsv")
end

local function listed_conflicts()
    local listed = {}
    if not os.isfile(CONFLICTS) then return listed end
    for line in io.lines(CONFLICTS) do
        if line:find("^[^#]") and not line:find("^framework\t") then
            local c = cells_of(line)
            listed[table.concat(c, "\t", 1, 7)] = c
        end
    end
    return listed
end

local started = os.mclock()
os.setenv("IR_SDK", SDK)
local libclang = (decls({"--version"})[1]:gsub("%s+$", ""))
SDK_NAME = (path.basename(SDK):gsub("%.sdk$", ""))

local frameworks = {}
local USR_INCLUDE = path.join(SDK, "usr", "include")
for _, line in ipairs(decls({"--list"})) do
    local name, root = line:match("^([^\t]+)\t(.+)$")
    table.insert(frameworks, {name = name, root = root, usr = root == USR_INCLUDE})
end
local function doc_rows(f)
    local out
    try {
        function () out = table.concat(decls({"--doc", "--timeout", TIMEOUT, f.name}), "\n") .. "\n" end,
        catch {
            function () out = nil end
        }
    }
    return out
end

if MODE == "docs" then
    local started = os.mclock()
    local seen, parsed, rows, bytes = 0, 0, 0, 0
    for _, f in ipairs(frameworks) do
        local out = doc_rows(f)
        seen = seen + 1
        if out then
            parsed = parsed + 1
            bytes = bytes + #out
            for _ in out:gmatch("\n") do rows = rows + 1 end
            io.write(out)
        end
    end
    print(string.format("# doc frameworks %d, parsed %d, rows %d, bytes %d, %.1f s", seen, parsed, rows, bytes,
        (os.mclock() - started) / 1000))
    return
end

local parsed, rows = 0, 0
local full = {table.concat({"-", "meta", "-", "-", "-", "-", "-", "-", "-", "-", "libclang=" .. libclang, "triple=" .. TRIPLE,
    "sdk=" .. SDK_NAME, "-", "-", "-", "-", "-", "-", "-", "-"}, "\t") .. "\n"}
local shards, unparsed, conflicts = {}, {}, {}
local census_of = {}
for _, f in ipairs(frameworks) do
    local out = parse(f)
    if not is_unparsed(out) then
        parsed = parsed + 1
        local lines = {shard_header(libclang):sub(1, -2)}
        local order, group, marks = {}, {}, {}
        for line in out:gmatch("[^\n]+") do
            local c = cells_of(line)
            if c[2] == "census" then
                census_of[f.name] = {own = tonumber(c[5]:match("own=(%d+)")), foreign = tonumber(c[11]:match("foreign=(%d+)")), files = {}}
                table.insert(full, line .. "\n")
            elseif c[2] == "census-file" then
                census_of[f.name].files[c[5]] = tonumber(c[11]:match("count=(%d+)"))
            elseif c[2] == "conflict" then
                table.insert(marks, {key = table.concat({c[1], c[7], c[3], c[4], c[5], c[6], c[9]}, "\t"), resolution = c[9],
                    variants = c[11], entity = table.concat({c[7], c[3], c[4], c[5], c[6]}, "\t")})
            else
                local key = table.concat(c, "\t", 2, 6)
                if not group[key] then
                    group[key] = {}
                    table.insert(order, key)
                end
                table.insert(group[key], c)
            end
        end
        local resolution_of = {}
        for _, mark in ipairs(marks) do resolution_of[mark.entity] = mark.resolution end
        local written, result_of = {}, {}
        for _, key in ipairs(order) do
            local variants = group[key]
            local row = variants[1]
            if #variants > 1 then
                if resolution_of[key] ~= "merged" then raise(f.name .. ": " .. key .. " has several rows and no merged conflict") end
                local input = {}
                for _, v in ipairs(variants) do table.insert(input, {avail = v[9], message = v[18]}) end
                local m = avail.merge(input)
                row = {}
                for i = 1, COLUMNS do row[i] = variants[1][i] end
                row[9], row[18] = m.avail, m.message
                row[16] = (decls({"--digest", m.avail})[1]:gsub("%s+$", ""))
            end
            result_of[key] = row[9]
            table.insert(written, row)
        end
        for _, mark in ipairs(marks) do
            if not result_of[mark.entity] then raise(f.name .. ": a conflict marks a key with no row: " .. mark.entity) end
            table.insert(conflicts, {key = mark.key, variants = mark.variants, result = result_of[mark.entity]})
        end
        for _, row in ipairs(written) do
            rows = rows + 1
            local kind, usr, name, side = row[2], row[3], row[5], row[6]
            local stored_name, stored_side = shard.encode(kind, usr, name, side)
            local back_name, back_side = shard.decode(kind, usr, stored_name, stored_side)
            if back_name ~= name or back_side ~= side then
                raise(f.name .. ": the name or side of a " .. kind .. " row does not round trip: " .. usr)
            end
            if kind ~= "enumconst" and row[14] ~= "-" then
                raise(f.name .. ": a " .. kind .. " row has a value; only an enum constant has one: " .. usr)
            end
            local value = kind == "enumconst" and row[14] or "-"
            if kind ~= "accessor" then
                table.insert(lines, table.concat({kind, usr, row[4], stored_name, stored_side, row[11], row[12], row[13], row[9],
                    row[18], row[15], value}, "\t"))
            end
            table.insert(full, table.concat(row, "\t") .. "\n")
        end
        if #lines > 1 then shards[f.name] = table.concat(lines, "\n") .. "\n" end
    else
        local reason = cells_of(out:match("^[^\n]*"))[5]
        table.insert(unparsed, {f.name, reason, f = f})
        table.insert(full, unparsed_row(f.name, reason))
    end
end

local function strip_comments(text)
    text = text:gsub("/%*.-%*/", " ")
    return (text:gsub("//[^\n]*", ""))
end

local function lines_of(text)
    local out = {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do table.insert(out, line) end
    return out
end

local header_facts_of = {}
local function header_facts(file)
    if header_facts_of[file] then return header_facts_of[file] end
    local info = {code = false, metal = false, define = false, includes = {}}
    local guard
    for _, line in ipairs(lines_of((strip_comments(io.readfile(file)):gsub("\\\n", " ")))) do
        if line:match("^%s*#") then
            local ifndef = line:match("^%s*#%s*ifndef%s+([%w_]+)")
            local defined = line:match("^%s*#%s*define%s+([%w_]+)")
            if ifndef then guard = ifndef end
            if line:match("^%s*#%s*define%s") and defined ~= guard then info.define = true end
            if line:match("^%s*#%s*if") or line:match("^%s*#%s*elif") then
                if line:find("__METAL_VERSION__", 1, true) or line:find("__HAVE_BFLOAT__", 1, true) then info.metal = true end
            end
            local next_name = line:match("^%s*#%s*include_next%s*[<\"]([^>\"]+)[>\"]")
            local name = line:match("^%s*#%s*include%s*[<\"]([^>\"]+)[>\"]") or line:match("^%s*#%s*import%s*[<\"]([^>\"]+)[>\"]")
            if next_name then
                table.insert(info.includes, {name = next_name, next = true})
            elseif name then
                table.insert(info.includes, {name = name, next = false})
            end
        elseif line:find("%S") then
            info.code = true
        end
    end
    header_facts_of[file] = info
    return info
end

local function usr_module_headers(name, nested)
    local include = path.join(SDK, "usr", "include")
    local maps = os.files(path.join(include, "*.modulemap"))
    for _, dir in ipairs(os.dirs(path.join(include, "*"))) do
        if os.isfile(path.join(dir, "module.modulemap")) then table.insert(maps, path.join(dir, "module.modulemap")) end
    end
    local out = {}
    for _, map in ipairs(maps) do
        local lines = lines_of(io.readfile(map))
        local start
        for i, line in ipairs(lines) do
            if line:match("^%s*explicit%s+module%s+" .. name .. "[%s{%[]") or line:match("^%s*module%s+" .. name .. "[%s{%[]") then
                start = i
                break
            end
        end
        if start then
            local depth = 0
            for i = start, #lines do
                local line = lines[i]
                if depth == 1 or (nested and depth > 1) then
                    local rel = line:match("header%s+\"([^\"]+)\"") or line:match("umbrella%s+\"([^\"]+)\"")
                    if rel then
                        local full = path.join(path.directory(map), rel)
                        if os.isdir(full) then
                            for _, file in ipairs(os.files(path.join(full, "**.h"))) do table.insert(out, file) end
                        elseif os.isfile(full) then
                            table.insert(out, full)
                        end
                    end
                end
                for _ in line:gmatch("{") do depth = depth + 1 end
                for _ in line:gmatch("}") do depth = depth - 1 end
                if depth == 0 and i > start then break end
            end
            break
        end
    end
    byteorder.sort(out)
    return out
end

local sweep_by_name, owner_dir, usr_owner, usr_nested_owner, base_owner, alias_of = {}, {}, {}, {}, {}, {}
local by_root = {}
for _, f in ipairs(frameworks) do
    sweep_by_name[f.name] = f
    if not f.usr then by_root[f.root] = f.name end
end
for _, f in ipairs(frameworks) do
    if f.usr then
        for _, file in ipairs(usr_module_headers(f.name)) do usr_owner[file] = usr_owner[file] or f.name end
        for _, file in ipairs(usr_module_headers(f.name, true)) do usr_nested_owner[file] = usr_nested_owner[file] or f.name end
    else
        if os.islink(f.root) then
            alias_of[f.name] = by_root[path.normalize(path.join(path.directory(f.root), os.readlink(f.root)))]
        else
            owner_dir[path.join(f.root, "Headers")] = f.name
        end
        if not f.name:find("/", 1, true) then base_owner[f.name] = f.name end
    end
end
for _, f in ipairs(frameworks) do
    local base = f.name:match("([^/]+)$")
    if not f.usr and base_owner[base] == nil then base_owner[base] = f.name end
end

local function owner_of(file)
    local dir = path.directory(file)
    while dir ~= "" and dir ~= "/" do
        if owner_dir[dir] then return owner_dir[dir] end
        local up = path.directory(dir)
        if up == dir then break end
        dir = up
    end
    return usr_owner[file]
end

local function declaration_owner(file)
    return owner_of(file) or usr_nested_owner[file]
end

local function file_of_include(from, include)
    local near = path.normalize(path.join(path.directory(from), include.name))
    if not include.next and os.isfile(near) then return near end
    local root = path.join(SDK, "usr", "include", include.name)
    if os.isfile(root) then return root end
    local first, rest = include.name:match("^([^/]+)/(.+)$")
    local owner = first and base_owner[first]
    if owner then
        local file = path.join(sweep_by_name[owner].root, "Headers", rest)
        if os.isfile(file) then return file end
    end
    return nil
end

local reached_of_file = {}
local function reached(file)
    if reached_of_file[file] == nil then
        local out = {}
        for _, include in ipairs(header_facts(file).includes) do
            local target = file_of_include(file, include)
            if target then table.insert(out, target) end
        end
        reached_of_file[file] = out
    end
    return reached_of_file[file]
end

local own_files_of = {}
local function own_files(f)
    if own_files_of[f.name] == nil then
        local files = f.usr and usr_module_headers(f.name) or os.files(path.join(f.root, "Headers", "**.h"))
        byteorder.sort(files)
        own_files_of[f.name] = files
    end
    return own_files_of[f.name]
end

local function census_owners(census)
    local counts, unowned, unowned_count = {}, {}, 0
    for file, count in pairs(census.files) do
        local owner = declaration_owner(path.join(SDK, file))
        if owner then
            counts[owner] = (counts[owner] or 0) + count
        else
            table.insert(unowned, file)
            unowned_count = unowned_count + count
        end
    end
    if #unowned > 0 then
        byteorder.sort(unowned)
        return "unresolved", {}, unowned_count .. " declarations are written in headers that no framework or module map holds: " .. table.concat(unowned, ", ")
    end
    local names = {}
    for name in pairs(counts) do table.insert(names, name) end
    byteorder.sort(names)
    if #names == 0 then return "unresolved", {}, "declarations reach the unit, but the census names no header for them" end
    for _, name in ipairs(names) do
        if not shards[name] then
            return "unresolved", {}, counts[name] .. " declarations are written in " .. name .. "'s headers, and " .. name .. " has no shard"
        end
    end
    if #names == 1 and names[1] == "Foundation" then return "placeholder", {}, "its headers include Foundation and declare nothing of their own" end
    local parts = {}
    for _, name in ipairs(names) do table.insert(parts, name .. " (" .. counts[name] .. ")") end
    if #names == 1 then return "alias", names, "its headers declare nothing; its declarations belong to " .. parts[1] end
    return "umbrella", names, "its headers declare nothing; its declarations belong to " .. table.concat(parts, ", ")
end

local function scan_no_shard(f, census)
    if alias_of[f.name] then
        return "alias", {alias_of[f.name]}, "its folder is a symbolic link to " .. alias_of[f.name] .. "'s"
    end
    local code, metal, define, includes = false, false, false, false
    for _, file in ipairs(own_files(f)) do
        local info = header_facts(file)
        if info.code and info.metal then metal = true end
        if info.code and not info.metal then code = true end
        if info.define then define = true end
        if #info.includes > 0 then includes = true end
    end
    local targets, visited, queue = {}, {}, {}
    for _, file in ipairs(own_files(f)) do
        for _, target in ipairs(reached(file)) do table.insert(queue, target) end
    end
    while #queue > 0 do
        local file = table.remove(queue)
        if not visited[file] then
            visited[file] = true
            local owner = owner_of(file)
            if owner and shards[owner] then
                targets[owner] = true
            else
                for _, target in ipairs(reached(file)) do table.insert(queue, target) end
            end
        end
    end
    local names = {}
    for name in pairs(targets) do table.insert(names, name) end
    byteorder.sort(names)
    if census.foreign == 0 then
        if code then return "unexplained", {}, "its headers hold code outside the Metal guards, and the census reaches no declaration" end
        if metal then return "metal", {}, "its code is under Metal guards (__METAL_VERSION__ or __HAVE_BFLOAT__); no declaration reaches the unit" end
        if define then return "macros", {}, "its headers hold macros and no code; no declaration reaches the unit" end
        if includes then return "placeholder", {}, "its headers include headers that reach no declaration" end
        return "empty", {}, "its headers hold no code, no macro and no include"
    end
    if code then return "unexplained", {}, "its headers hold code outside the Metal guards; declarations of other headers reach the unit too" end
    local class, owners, reason = census_owners(census)
    if class ~= "unresolved" then return class, owners, reason end
    local confirmed = {}
    for file in pairs(census.files) do
        local owner = declaration_owner(path.join(SDK, file))
        if owner then confirmed[owner] = true end
    end
    local kept = {}
    for _, name in ipairs(names) do
        if confirmed[name] then table.insert(kept, name) end
    end
    names = kept
    if #names == 0 then return class, owners, reason end
    if #names == 1 and names[1] == "Foundation" then return "placeholder", {}, "its headers include Foundation and declare nothing of their own" end
    if #names == 1 then return "alias", names, "its headers declare nothing; the declarations are " .. names[1] .. "'s" end
    return "umbrella", names, "its headers declare nothing; the declarations are those of " .. table.concat(names, ", ")
end

local swift_interface_of_memo
local function swift_interface_of(module)
    if swift_interface_of_memo == nil then
        swift_interface_of_memo = {}
        for _, file in ipairs(os.files(path.join(SDK, "**", "*.swiftinterface"))) do
            local name = file:match("([^/]+)%.swiftmodule/[^/]+%.swiftinterface$")
            if name and not swift_interface_of_memo[name] then swift_interface_of_memo[name] = file end
        end
    end
    return swift_interface_of_memo[module]
end

local function source_of(f, reason)
    if string.find(reason, "Swift", 1, true) then
        local interface = swift_interface_of(f.name:match("([^/]+)$"))
        if interface == nil then return nil end
        return "parsed (Swift interface)", redact(reason) .. "; its Swift interface " .. redact(interface) .. " is read by the swift shard step"
    end
    if f.usr then
        if #usr_module_headers(f.name) == 0 then
            return "no declarations", redact(reason) .. "; the module map entry names no header"
        end
        return nil
    end
    if reason == "no public header in Headers/ and no module map header" and #os.files(path.join(f.root, "Headers", "**.h")) == 0 then
        local entries = {}
        for _, file in ipairs(os.files(path.join(f.root, "**"))) do
            table.insert(entries, string.sub(file, #f.root + 2))
        end
        byteorder.sort(entries)
        return "no declarations", redact(reason) .. "; the folder holds no header: " .. table.concat(entries, ", ")
    end
    return nil
end

local sources = {}
do
    local still_unparsed = {}
    for _, u in ipairs(unparsed) do
        local class, evidence = source_of(u.f, u[2])
        if class then
            table.insert(sources, {u[1], class, evidence})
        else
            table.insert(still_unparsed, u)
        end
    end
    unparsed = still_unparsed
    table.sort(sources, function (a, b) return byteorder.less(a[1], b[1]) end)
end

local no_shard_text
if MODE == "write" or MODE == "check" then
    local classified = {}
    for _, u in ipairs(unparsed) do classified[u[1]] = "unparsed" end
    for _, s in ipairs(sources) do classified[s[1]] = s[2] end
    local unclassified, computed = {}, {}
    for _, f in ipairs(frameworks) do
        if not shards[f.name] and not classified[f.name] then
            local census = census_of[f.name]
            if census and census.own == 0 then
                local class, names, reason = scan_no_shard(f, census)
                table.insert(computed, {name = f.name, class = class, targets = names, reason = reason})
            else
                table.insert(unclassified, f.name)
            end
        end
    end
    byteorder.sort(unclassified)
    if #unclassified > 0 then
        raise("a framework with no shard is neither unparsed nor declares nothing of its own by the census: " .. table.concat(unclassified, " "))
    end
    table.sort(computed, function (a, b) return byteorder.less(a.name, b.name) end)
    local rows = {"# the frameworks of the sweep with no shard that declare nothing of their own: name, class, targets, reason (TAB separated)."
        .. " Computed by the sweep from the frameworks' own headers and the census of their declarations (ir.lua scan_no_shard), never listed by name."}
    for _, c in ipairs(computed) do
        local targets = #c.targets > 0 and table.concat(c.targets, ",") or "-"
        table.insert(rows, c.name .. "\t" .. c.class .. "\t" .. targets .. "\t" .. c.reason)
    end
    no_shard_text = table.concat(rows, "\n") .. "\n"
end

if MODE == "gaps" then
    local snapshot = os.getenv("IR_SNAPSHOT") or raise("IR_SNAPSHOT must name the snapshot folder whose frameworks are classified")
    local skipped, sdk_framework = {}, {}
    for _, u in ipairs(unparsed) do skipped[u[1]] = u[2] end
    for _, s in ipairs(sources) do skipped[s[1]] = s[3] end
    for _, f in ipairs(frameworks) do sdk_framework[f.name] = f end
    local names = {}
    for _, dir in ipairs(os.dirs(path.join(snapshot, "*"))) do
        local name = path.filename(dir)
        if not os.isfile(shard_path(name)) then table.insert(names, name) end
    end
    byteorder.sort(names)
    local tally = {}
    for _, name in ipairs(names) do
        local f = sdk_framework[name]
        local category, count, detail
        if not f then
            local usr_headers = #os.files(path.join(SDK, "usr", "include", name, "**.h"))
            local swift_stdlib = os.isdir(path.join(SDK, "usr", "lib", "swift", name .. ".swiftmodule"))
            category = "not-an-sdk-framework"
            count = usr_headers
            detail = "usr/include headers " .. usr_headers .. ", Swift stdlib module " .. (swift_stdlib and "yes" or "no")
        else
            local reason = skipped[name]
            local no_header = reason ~= nil and (reason:find("Swift interface only", 1, true) ~= nil
                or reason:find("no public header", 1, true) ~= nil or reason:find("no module map header", 1, true) ~= nil)
            count = census_of[name] and census_of[name].own or 0
            if no_header then
                category = reason:find("Swift interface only", 1, true) and "swift-only" or "no-public-header"
                detail = reason
            elseif skipped[name] then
                category = "skipped-by-extractor"
                detail = skipped[name]
            elseif census_of[name] and census_of[name].own == 0 then
                category, _, detail = scan_no_shard(f, census_of[name])
            else
                category = "unexplained"
                detail = "the extractor parsed it, and its census disagrees with its shard status"
            end
        end
        tally[category] = (tally[category] or 0) + 1
        print(string.format("%s\t%s\t%d\t%s", name, category, count, detail))
    end
    for category, n in pairs(tally) do print(string.format("summary\t%s\t%d", category, n)) end
    return
end

local listed = listed_conflicts()
if MODE == "conflicts" then
    for _, c in ipairs(conflicts) do print(c.key .. "\t" .. c.variants .. "\t" .. c.result) end
    print(string.format("%d conflicts", #conflicts))
    return
end
local found = {}
local unlisted, wrong = {}, {}
for _, c in ipairs(conflicts) do
    found[c.key] = true
    local line = listed[c.key]
    if not line then
        table.insert(unlisted, c.key .. "\t" .. c.variants .. "\t" .. c.result)
    elseif line[9] ~= c.result then
        table.insert(wrong, c.key .. ": the list says [" .. line[9] .. "], the rule gives [" .. c.result .. "]")
    end
end
local stale = {}
for key in pairs(listed) do
    if not found[key] then table.insert(stale, key) end
end
if #unlisted > 0 or #stale > 0 or #wrong > 0 then
    raise(string.format("%d conflicts are not listed in %s, %d listed conflicts are gone, %d listed results differ from the rule:\n%s%s%s",
        #unlisted, CONFLICTS, #stale, #wrong, table.concat(unlisted, "\n"), #stale > 0 and ("\nstale: " .. table.concat(stale, "\nstale: ")) or "",
        #wrong > 0 and ("\n" .. table.concat(wrong, "\n")) or ""))
end

local listed_names = {}
for _, f in ipairs(frameworks) do listed_names[f.name] = true end
local existing = {}
if os.isdir(SPEC) then
    for _, file in ipairs(os.files(path.join(SPEC, "**", "declarations.tsv"))) do
        existing[file] = true
    end
end
local stale_shards, without_shard = {}, {}
for file in pairs(existing) do
    local label = file:sub(#SPEC + 2, #file - #"/declarations.tsv")
    if not listed_names[label] then
        table.insert(stale_shards, file)
    elseif not shards[label] then
        table.insert(without_shard, label)
    end
end
byteorder.sort(stale_shards)
byteorder.sort(without_shard)
if #without_shard > 0 then
    raise(string.format("decls gives no shard for %s, but a committed shard is there: a framework decls still lists keeps its committed "
        .. "shard, so its removal is a reviewed change (delete the shard by hand)", table.concat(without_shard, ", ")))
end

local changed, largest, largest_name, total_bytes = {}, 0, "", 0
for label, text in pairs(shards) do
    total_bytes = total_bytes + #text
    if #text > largest then
        largest, largest_name = #text, label
    end
    local file = shard_path(label)
    local old = os.isfile(file) and io.readfile(file) or nil
    if old ~= text then table.insert(changed, label) end
end
byteorder.sort(changed)

local unparsed_rows = {}
for _, s in ipairs(sources) do table.insert(unparsed_rows, {s[1], s[2], s[3]}) end
for _, u in ipairs(unparsed) do table.insert(unparsed_rows, {u[1], "unparsed", redact(u[2])}) end
table.sort(unparsed_rows, function (a, b) return byteorder.less(a[1], b[1]) end)
local unparsed_text = {"# the frameworks of the SDK the extractor does not parse as C or Objective-C: name, the class of its source, and the evidence"
    .. " (tab-separated, one line each). parsed (Swift interface): read by the swift shard step; no declarations: no header of its own."}
for _, r in ipairs(unparsed_rows) do table.insert(unparsed_text, r[1] .. "\t" .. r[2] .. "\t" .. r[3]) end
unparsed_text = table.concat(unparsed_text, "\n") .. "\n"

if MODE == "check" or MODE == "write" then
    local differs = {}
    for file in pairs(existing) do
        local recorded = io.readfile(file):match("libclang=([^\t\n]*)")
        if recorded and recorded ~= libclang then
            table.insert(differs, file:sub(#SPEC + 2, #file - #"/declarations.tsv"))
        end
    end
    byteorder.sort(differs)
    if #differs > 0 and (MODE == "check" or not os.getenv("IR_REPIN")) then
        raise(string.format("libclang identity differs in %d shards (%s): this machine has [%s]%s", #differs,
            table.concat(differs, ", "), libclang, MODE == "check" and "" or "; re-record with IR_REPIN=1 as a reviewed re-pin"))
    end
end

if MODE == "check" then
    if #changed > 0 or #stale_shards > 0 then
        raise(string.format("%d shards differ from the regenerated ones (%s), %d shards are stale (%s)", #changed,
            table.concat(changed, ", "), #stale_shards, table.concat(stale_shards, ", ")))
    end
    local old_unparsed = os.isfile(UNPARSED) and io.readfile(UNPARSED) or nil
    if old_unparsed ~= unparsed_text then raise(UNPARSED .. " differs from the regenerated list") end
    local old_no_shard = os.isfile(NO_SHARD) and io.readfile(NO_SHARD) or nil
    if old_no_shard ~= no_shard_text then raise(NO_SHARD .. " differs from the regenerated table") end
    print("check ok: " .. SPEC)
else
    for _, label in ipairs(changed) do
        atomic.write(shard_path(label), shards[label])
    end
    for _, file in ipairs(stale_shards) do os.rm(file) end
    atomic.write(UNPARSED, unparsed_text)
    atomic.write(NO_SHARD, no_shard_text)
    print(string.format("wrote %d shards, removed %d stale shards", #changed, #stale_shards))
end

if FULL then
    atomic.write(FULL, table.concat(full))
end

local swift_sources, no_declarations = 0, 0
for _, s in ipairs(sources) do
    if s[2] == "parsed (Swift interface)" then swift_sources = swift_sources + 1 else no_declarations = no_declarations + 1 end
end
print(string.format("frameworks %d, parsed (C/ObjC) %d, parsed (Swift interface) %d, no declarations %d, unparsed %d, rows %d (shard rows), conflicts %d, %.1f s",
    #frameworks, parsed, swift_sources, no_declarations, #unparsed, rows, #conflicts, (os.mclock() - started) / 1000))
local shard_count = 0
for _ in pairs(shards) do shard_count = shard_count + 1 end
print(string.format("shards %d, bytes %d in all, largest %d (%s)", shard_count, total_bytes, largest, largest_name))
