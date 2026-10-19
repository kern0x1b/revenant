-- The .tbd stubs of an iPhoneOS SDK, read and rewritten as text, for what the linker is told through the
-- markers in them: `$ld$hide$os6.1$_sym` says the library has no _sym when it targets 6.1, `$ld$add$`,
-- `$ld$previous$`, `$ld$weak$` and `$ld$install_name$` say where else it lived. A marker's version is one
-- release, not a range, so a symbol a library lacks below 7.0 carries one marker for each release of the
-- SDK's own list below 7.0.
--
-- Two formats are read: tbd-version 4 (`targets: [ armv7-ios ]`, one file may hold many documents) and
-- the 3 that SDK 26 ships (`archs: [ armv7 ]`, one document per file).

import("byteorder", {rootdir = path.join(os.scriptdir(), "..")})

local FAMILY_UMBRELLA = "/usr/lib/libSystem.B.dylib"
local FAMILY_FOLDER = "/usr/lib/system/"
local LISTS = {"symbols", "weak-symbols", "thread-local-symbols"}

-- The document texts of one .tbd, each with its own `--- !tapi-tbd` line.
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

-- The install name a document declares, without reading the rest of it.
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

-- One document: {install, format = "v3"|"v4", archs, exports = {{archs, lists = {symbols = {...}, ...}}, ...}}.
-- Only the `exports:` and the symbol-level `reexports:` sections count: undefined symbols and the libraries re-exported
-- as a whole are not what a library has.
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

-- The libraries that make up libSystem: the umbrella and what it re-exports, where Apple keeps the
-- per-release markers of the C library, the unwinder and the compiler's runtime.
function in_libsystem(install)
    return install == FAMILY_UMBRELLA or (install or ""):startswith(FAMILY_FOLDER)
end

-- Every marker of a document: {token = "$ld$hide$os6.1$_sym", kind = "hide", version = "6.1", archs = {...}}.
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

-- The plain symbols a document exports, {symbol = {armv7 = true, ...}}.
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

-- A release as (major, minor): a marker names a release the way the linker matches a deployment target,
-- which is 6.1 for 6.1.3 too.
local function release(version)
    local major, minor = tostring(version):match("^(%d+)%.?(%d*)")
    return tonumber(major) * 1000 + (tonumber(minor) or 0)
end

function older(version, other)
    return release(version) < release(other)
end

-- What a stub of `doc` lists, so that adding a marker does not repeat one already there.
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

-- One export entry of `doc`'s format naming `archs` and listing `tokens` under `list`.
local function entry_text(doc, archs, list, tokens)
    local key, suffix = doc.format == "v3" and "archs" or "targets", doc.format == "v3" and "" or "-ios"
    local listed = {}
    for _, arch in ipairs(archs) do
        table.insert(listed, arch .. suffix)
    end
    local head = "    " .. list .. ": [ "
    return string.format("  - %s: [ %s ]\n%s%s ]\n", key, table.concat(listed, ", "), head, wrapped(tokens, #head))
end

-- The document text with `entries` at the top of its exports.
local function put_entries(text, entries)
    if #entries == 0 then
        return text
    end
    local at = text:find("\nexports:[ \t]*\n")
    if at then
        local after = text:find("\n", at + 1, true)
        return text:sub(1, after) .. table.concat(entries) .. text:sub(after + 1)
    end
    -- a document that only re-exports whole libraries has no exports yet: they go where the section belongs, before the end of the document
    local ending = text:find("\n%.%.%.[ \t]*\n?$")
    local head = ending and text:sub(1, ending) or text .. (text:find("\n$") and "" or "\n")
    return head .. "exports:\n" .. table.concat(entries) .. (ending and text:sub(ending + 1) or "")
end

-- The architectures of `wanted` (a group's) that the document has.
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

-- `wanted` is {{archs = {"armv7", ...}, tokens = {...}}, ...}. The document text with each token that
-- its architectures name and it does not already list, put as entries at the top of its exports.
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

-- `wanted` is {{archs = {...}, list = "symbols", tokens = {...}}, ...}, as dropped() gives it: plain symbols, each listed by
-- an entry of its own architectures and its own list, for the architectures the document has.
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

-- Markers as add_markers takes them: {{archs, tokens}, ...}, one group for each architecture list, in the order first met.
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

-- The hide markers that tell a release older than `first` (a version, or nil for none of the held releases) that
-- `symbol` is not there: one for each of `versions` before it.
function hides(symbol, first, versions)
    local tokens = {}
    for _, version in ipairs(versions) do
        if not first or older(version, first) then
            table.insert(tokens, string.format("$ld$hide$os%s$%s", version, symbol))
        end
    end
    return tokens
end

-- The releases a document's hide markers name, sorted, each once.
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

-- The first release each symbol is exported from, as tools/sdk-markers.lua writes it: `symbol<TAB>release`
-- per line, `-` for a symbol none of the held releases exports; lines starting with # are comments.
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

-- The hide markers for the symbols of `doc` that `first` names (releases()), for the releases a device on
-- armv7 or armv7s can run: as add_markers takes them.
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

-- What a stub of a newer SDK no longer lists at all for a 32-bit slice it still names: the symbols `older` (the same
-- library's document in an older SDK) lists for armv7 or armv7s and `doc` lists under none of its architectures - not
-- only not for armv7/armv7s, but not for arm64/arm64e either - as add_symbols takes them. `iphoneos-sdk` calls this for
-- libSystem's own documents, where what the 32-bit slice exports and the 64-bit one never had (`__Unwind_SjLj_Register`,
-- `___udivdi3`) is gone from a newer SDK's stub while the release the slice runs on still has it. A symbol `doc` still
-- lists under any architecture (arm64 typically, sometimes armv7 itself grouped under a different entry) is never
-- "dropped": that is 26.2's own reorganised layout, not Apple removing a 32-bit-only primitive, and restoring it as a
-- plain export would assert something no measurement backs. Not specific to libSystem: any two documents of the same
-- library, from the two SDKs, work here.
function dropped(older, doc)
    local have = {}
    for _, entry in ipairs(doc.exports) do
        for _, list in ipairs(LISTS) do
            for _, symbol in ipairs(entry.lists[list]) do
                have[symbol] = true
            end
        end
    end
    -- for each list, the architectures each missing symbol is missing for, then the symbols that share them
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
