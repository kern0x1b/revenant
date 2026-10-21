import("byteorder", {rootdir = path.join(os.scriptdir(), "..")})

local FAMILY_UMBRELLA = "/usr/lib/libSystem.B.dylib"
local FAMILY_FOLDER = "/usr/lib/system/"
local LISTS = {"symbols", "weak-symbols", "thread-local-symbols"}

function documents(text)
    local found, current = {}, nil
    for line in text:gmatch("[^\n]*\n") do
        if line:find("^%-%-%- ") then
            current = {}
            table.insert(found, current)
        end
        if current then
            table.insert(current, line)
        end
    end
    for index, lines in ipairs(found) do
        found[index] = table.concat(lines)
    end
    return found
end

function install(text)
    return text:match("\ninstall%-name:%s*'([^']+)'") or text:match("\ninstall%-name:%s*(%S+)")
end

local function names(list)
    local found = {}
    for item in list:gmatch("[^,%[%]]+") do
        local name = item:gsub("^%s+", ""):gsub("%s+$", ""):gsub("^'", ""):gsub("'$", "")
        if #name > 0 then
            table.insert(found, name)
        end
    end
    return found
end

local function architectures(list)
    local found = {}
    for _, name in ipairs(names(list)) do
        table.insert(found, (name:gsub("%-ios$", "")))
    end
    return found
end

function read(text)
    local doc = {install = install(text), exports = {}}
    doc.format = text:find("^%-%-%- !tapi%-tbd%-v3") and "v3" or "v4"
    local key = doc.format == "v3" and "archs" or "targets"
    doc.archs = architectures(text:match("\n" .. key .. ":%s*%[(.-)%]") or "")
    local section, entry = nil, nil
    for line in text:gmatch("[^\n]*\n") do
        local top = line:match("^([%w%-]+):")
        if top then
            section, entry = top, nil
        end
        local listed = line:match("^  %- " .. key .. ":%s*%[(.-)%]")
        local held = section == "exports" or section == "reexports"
        if held and listed then
            entry = {archs = architectures(listed), text = line}
            table.insert(doc.exports, entry)
        elseif entry and held then
            entry.text = entry.text .. line
        end
    end
    for _, entry in ipairs(doc.exports) do
        entry.lists = {}
        for _, list in ipairs(LISTS) do
            local content = entry.text:match("\n    " .. list:gsub("%-", "%%-") .. ":%s*%[(.-)%]")
            entry.lists[list] = content and names(content) or {}
        end
        entry.text = nil
    end
    return doc
end

function in_libsystem(install)
    return install == FAMILY_UMBRELLA or (install or ""):startswith(FAMILY_FOLDER)
end

function markers(doc)
    local found = {}
    for _, entry in ipairs(doc.exports) do
        for _, list in ipairs(LISTS) do
            for _, symbol in ipairs(entry.lists[list]) do
                if symbol:startswith("$ld$") then
                    local kind, version = symbol:match("^%$ld%$(%a+)%$os([%d%.]+)%$")
                    table.insert(found, {token = symbol, kind = kind, version = version, archs = entry.archs})
                end
            end
        end
    end
    return found
end

function exported(doc)
    local found = {}
    for _, entry in ipairs(doc.exports) do
        for _, list in ipairs(LISTS) do
            for _, symbol in ipairs(entry.lists[list]) do
                if not symbol:startswith("$ld$") then
                    found[symbol] = found[symbol] or {}
                    for _, arch in ipairs(entry.archs) do
                        found[symbol][arch] = true
                    end
                end
            end
        end
    end
    return found
end

local function release(version)
    local major, minor = tostring(version):match("^(%d+)%.?(%d*)")
    return tonumber(major) * 1000 + (tonumber(minor) or 0)
end

function older(version, other)
    return release(version) < release(other)
end

local function present(doc)
    local found = {}
    for _, marker in ipairs(markers(doc)) do
        found[marker.token] = true
    end
    return found
end

local function wrapped(tokens, indent)
    local lines, line = {}, ""
    for _, token in ipairs(tokens) do
        if #line > 0 and #line + #token > 100 then
            table.insert(lines, line)
            line = ""
        end
        line = line .. (#line > 0 and " " or "") .. "'" .. token .. "',"
    end
    table.insert(lines, line)
    return (table.concat(lines, "\n" .. string.rep(" ", indent)):gsub(",$", ""))
end

local function entry_text(doc, archs, list, tokens)
    local key, suffix = doc.format == "v3" and "archs" or "targets", doc.format == "v3" and "" or "-ios"
    local listed = {}
    for _, arch in ipairs(archs) do
        table.insert(listed, arch .. suffix)
    end
    local head = "    " .. list .. ": [ "
    return string.format("  - %s: [ %s ]\n%s%s ]\n", key, table.concat(listed, ", "), head, wrapped(tokens, #head))
end

local function put_entries(text, entries)
    if #entries == 0 then
        return text
    end
    local at = text:find("\nexports:[ \t]*\n")
    if at then
        local after = text:find("\n", at + 1, true)
        return text:sub(1, after) .. table.concat(entries) .. text:sub(after + 1)
    end
    local ending = text:find("\n%.%.%.[ \t]*\n?$")
    local head = ending and text:sub(1, ending) or text .. (text:find("\n$") and "" or "\n")
    return head .. "exports:\n" .. table.concat(entries) .. (ending and text:sub(ending + 1) or "")
end

local function supported_archs(doc, wanted)
    local supported, archs = {}, {}
    for _, arch in ipairs(doc.archs) do
        supported[arch] = true
    end
    for _, arch in ipairs(wanted) do
        if supported[arch] then
            table.insert(archs, arch)
        end
    end
    return archs
end

function add_markers(text, wanted)
    local doc = read(text)
    local have = present(doc)
    local entries = {}
    for _, group in ipairs(wanted) do
        local archs, tokens = supported_archs(doc, group.archs), {}
        for _, token in ipairs(group.tokens) do
            if not have[token] then
                have[token] = true
                table.insert(tokens, token)
            end
        end
        if #archs > 0 and #tokens > 0 then
            table.insert(entries, entry_text(doc, archs, "symbols", tokens))
        end
    end
    return put_entries(text, entries)
end

function add_symbols(text, wanted)
    local doc = read(text)
    local have = exported(doc)
    local entries = {}
    for _, group in ipairs(wanted) do
        local archs = supported_archs(doc, group.archs)
        local tokens = {}
        for _, token in ipairs(group.tokens) do
            local already = true
            for _, arch in ipairs(archs) do
                already = already and have[token] and have[token][arch]
            end
            if not already then
                table.insert(tokens, token)
            end
        end
        if #archs > 0 and #tokens > 0 then
            table.insert(entries, entry_text(doc, archs, group.list, tokens))
        end
    end
    return put_entries(text, entries)
end

function add_archs(text, wanted)
    local doc = read(text)
    local missing = {}
    for _, arch in ipairs(wanted) do
        if not table.contains(doc.archs, arch) then
            table.insert(missing, arch)
        end
    end
    if #missing == 0 then
        return text
    end
    local key, suffix = doc.format == "v3" and "archs" or "targets", doc.format == "v3" and "" or "-ios"
    local names = {}
    for _, arch in ipairs(missing) do
        table.insert(names, arch .. suffix)
    end
    local at, close = text:find("\n" .. key .. ":[ \t]*%[[^%]]*%]")
    local listed = text:sub(at, close):gsub("%s*%]$", "")
    return text:sub(1, at - 1) .. listed .. ", " .. table.concat(names, ", ") .. " ]" .. text:sub(close + 1)
end

function slice(doc, wanted)
    local groups, order = {}, {}
    for _, entry in ipairs(doc.exports) do
        local archs = {}
        for _, arch in ipairs(wanted) do
            if table.contains(entry.archs, arch) then
                table.insert(archs, arch)
            end
        end
        if #archs > 0 then
            for _, list in ipairs(LISTS) do
                local key = list .. "\t" .. table.concat(archs, ",")
                if not groups[key] then
                    groups[key] = {archs = archs, list = list, tokens = {}, seen = {}}
                    table.insert(order, key)
                end
                for _, symbol in ipairs(entry.lists[list]) do
                    if not symbol:startswith("$ld$") and not groups[key].seen[symbol] then
                        groups[key].seen[symbol] = true
                        table.insert(groups[key].tokens, symbol)
                    end
                end
            end
        end
    end
    local out = {}
    for _, key in ipairs(order) do
        table.insert(out, {archs = groups[key].archs, list = groups[key].list, tokens = groups[key].tokens})
    end
    return out
end

local function section(text, key)
    local at = text:find("\n" .. key .. ":[ \t]*\n")
    if not at then
        return nil
    end
    return at, text:find("\n%S", at + 1) or #text
end

local function armv7_lines(older, key)
    local oat, oafter = section(older, key)
    if not oat then
        return {}
    end
    local body = older:sub(oat, oafter):match("^\n[^\n]*\n(.*)$") or ""
    local kept, keep = {}, false
    for line in body:gmatch("[^\n]*\n") do
        if line:match("^  %- ") then
            keep = line:find("armv7", 1, true) ~= nil
        end
        if keep then
            table.insert(kept, line)
        end
    end
    return kept
end

function add_section(text, older_parts, key)
    local at, after = section(text, key)
    if at and text:sub(at, after):find("armv7", 1, true) then
        return text
    end
    local kept = {}
    for _, older in ipairs(older_parts) do
        kept = armv7_lines(older, key)
        if #kept > 0 then
            break
        end
    end
    if #kept == 0 then
        return text
    end
    local extra = table.concat(kept)
    if at then
        return text:sub(1, after) .. extra .. text:sub(after + 1)
    end
    if text:sub(-1) ~= "\n" then
        text = text .. "\n"
    end
    return text .. key .. ":\n" .. extra
end

function restore_armv7(text, held, older_parts)
    local slices = {}
    for _, arch in ipairs({"armv7", "armv7s"}) do
        if table.contains(held.archs, arch) then
            table.insert(slices, arch)
        end
    end
    text = add_archs(text, slices)
    text = add_clients(text)
    text = add_section(text, older_parts, "parent-umbrella")
    return add_symbols(text, slice(held, slices))
end

function add_clients(text)
    local at = text:find("\nallowable%-clients:[ \t]*\n")
    if not at then
        return text
    end
    local after = text:find("\n%S", at + 1) or #text
    local section = text:sub(at, after)
    if section:find("armv7", 1, true) then
        return text
    end
    local body = section:match("^\n[^\n]*\n(.*)$") or ""
    local extra = (body:gsub("targets:(%s*)%[[^%]]*%]", "targets:%1[ armv7-ios, armv7s-ios ]"))
    if extra == "" then
        return text
    end
    return text:sub(1, after) .. extra .. text:sub(after + 1)
end

function add_reexports(text, capable)
    local at = text:find("\nreexported%-libraries:[ \t]*\n")
    if not at then
        return text
    end
    local after = text:find("\n%S", at + 1) or #text
    local section = text:sub(at, after)
    if section:find("armv7", 1, true) then
        return text
    end
    local names, seen = {}, {}
    for name in section:gmatch("'(/[^']+)'") do
        if capable[name] and not seen[name] then
            seen[name] = true
            table.insert(names, "'" .. name .. "'")
        end
    end
    if #names == 0 then
        return text
    end
    local entry = string.format("  - targets:         [ armv7-ios, armv7s-ios ]\n    libraries:       [ %s ]\n", table.concat(names, ", "))
    return text:sub(1, after) .. entry .. text:sub(after + 1)
end

function group(found)
    local groups, order = {}, {}
    for _, marker in ipairs(found) do
        local key = table.concat(marker.archs, ",")
        if not groups[key] then
            groups[key] = {archs = marker.archs, tokens = {}}
            table.insert(order, key)
        end
        table.insert(groups[key].tokens, marker.token)
    end
    local wanted = {}
    for _, key in ipairs(order) do
        table.insert(wanted, groups[key])
    end
    return wanted
end

function hides(symbol, first, versions)
    local tokens = {}
    for _, version in ipairs(versions) do
        if not first or older(version, first) then
            table.insert(tokens, string.format("$ld$hide$os%s$%s", version, symbol))
        end
    end
    return tokens
end

function hidden_releases(doc)
    local seen, found = {}, {}
    for _, marker in ipairs(markers(doc)) do
        if marker.kind == "hide" and not seen[marker.version] then
            seen[marker.version] = true
            table.insert(found, marker.version)
        end
    end
    table.sort(found, function (a, b) return release(a) < release(b) end)
    return found
end

function releases(text)
    local found = {}
    for line in text:gmatch("[^\n]+") do
        local symbol, first = line:match("^([^#\t][^\t]*)\t(%S+)$")
        if symbol then
            found[symbol] = first ~= "-" and first or false
        end
    end
    return found
end

function derived(doc, first, versions)
    local groups, order = {}, {}
    for _, entry in ipairs(doc.exports) do
        local archs = {}
        for _, arch in ipairs(entry.archs) do
            if arch == "armv7" or arch == "armv7s" then
                table.insert(archs, arch)
            end
        end
        local key = table.concat(archs, ",")
        for _, list in ipairs(LISTS) do
            for _, symbol in ipairs(entry.lists[list]) do
                if #archs > 0 and first[symbol] ~= nil then
                    if not groups[key] then
                        groups[key] = {archs = archs, tokens = {}}
                        table.insert(order, key)
                    end
                    for _, token in ipairs(hides(symbol, first[symbol] or nil, versions)) do
                        table.insert(groups[key].tokens, token)
                    end
                end
            end
        end
    end
    local wanted = {}
    for _, key in ipairs(order) do
        table.insert(wanted, groups[key])
    end
    return wanted
end

function dropped(older, doc)
    local have = {}
    for _, entry in ipairs(doc.exports) do
        for _, list in ipairs(LISTS) do
            for _, symbol in ipairs(entry.lists[list]) do
                have[symbol] = true
            end
        end
    end
    local missing = {}
    for _, entry in ipairs(older.exports) do
        for _, list in ipairs(LISTS) do
            for _, symbol in ipairs(entry.lists[list]) do
                if not symbol:startswith("$ld$") and not have[symbol] then
                    for _, arch in ipairs(entry.archs) do
                        if arch == "armv7" or arch == "armv7s" then
                            missing[list] = missing[list] or {}
                            missing[list][symbol] = missing[list][symbol] or {}
                            missing[list][symbol][arch] = true
                        end
                    end
                end
            end
        end
    end
    local groups, order = {}, {}
    for _, list in ipairs(LISTS) do
        local symbols = table.keys(missing[list] or {})
        byteorder.sort(symbols)
        for _, symbol in ipairs(symbols) do
            local archs = {}
            for _, arch in ipairs({"armv7", "armv7s"}) do
                if missing[list][symbol][arch] then
                    table.insert(archs, arch)
                end
            end
            local key = list .. "\t" .. table.concat(archs, ",")
            if not groups[key] then
                groups[key] = {archs = archs, list = list, tokens = {}}
                table.insert(order, key)
            end
            table.insert(groups[key].tokens, symbol)
        end
    end
    local wanted = {}
    for _, key in ipairs(order) do
        table.insert(wanted, groups[key])
    end
    return wanted
end
