-- The availability of a declaration, in the IR's form, the rule that merges the declarations of one key that disagree, and the render
-- of the spec's availability text from those fields (ruling D7: the generator renders; no regex over declaration text).
--
-- The IR's form (the avail column): flags first, then one entry per platform clang names, sorted by platform name:
--   *unavailable, *deprecated    the flag holds for every platform (no platform names it)
--   platform=introduced/deprecated/obsoleted/unavailable
--                                each version as written ("16.0"), "-" for none, the unavailable flag as 1 or 0
--   "-"                          no availability at all
-- The message column holds the texts: "deprecated: TEXT" (the API_DEPRECATED message) and "unavailable: TEXT" (an unavailable
-- attribute's message), the second after " | " (split_message reads it; a deprecation text may contain " | " itself).
--
-- The rule for a key whose declarations disagree (merge): per platform, a declaration that names the platform votes; the declarations
-- that name the platform as unavailable do not introduce it. A declaration that names no platform at all carries no availability
-- fact and does not vote: the annotated declarations decide (ruling of 2026-10-10).
--   introduced   the earliest introduction of the available votes (an unrestricted vote makes it unrestricted)
--   deprecated   the latest deprecation, and only when every available vote deprecates the platform
--   obsoleted    the latest obsoletion, and only when every available vote obsoletes the platform
--   unavailable  only when every vote is unavailable (available if any declaration is available)
-- The message is the deprecation text of the declaration that gives the latest deprecation, and the unavailable text of the first
-- declaration that makes a platform unavailable.

-- A version as major * 10000 + minor * 100 + subminor; "-" is none, and none is 0.
local byteorder = import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})

function version_number(text)
    if text == "-" then return 0 end
    local major, minor, sub = text:match("^(%d+)%.?(%d*)%.?(%d*)$")
    return tonumber(major) * 10000 + (tonumber(minor) or 0) * 100 + (tonumber(sub) or 0)
end

-- The parsed availability of one declaration: its flags and its platforms (intro, dep, obs as text; unavailable as a boolean).
function parse_availability(text)
    local out = {always_unavailable = false, always_deprecated = false, entries = {}}
    local body = text
    while body:sub(1, 1) == "*" do
        local flag, after = body:match("^(%*%a+)%s*(.*)$")
        if flag == "*unavailable" then out.always_unavailable = true end
        if flag == "*deprecated" then out.always_deprecated = true end
        body = after
    end
    if body == "" or body == "-" then return out end
    for entry in body:gmatch("[^,]+") do
        local platform, intro, dep, obs, unavailable = entry:match("^([^=]+)=([^/]+)/([^/]+)/([^/]+)/([01])$")
        out.entries[platform] = {intro = intro, dep = dep, obs = obs, unavailable = unavailable == "1"}
    end
    return out
end

-- The IR's text of a set of platform entries and flags (the order and the spelling availability() writes).
function format_availability(flags, entries)
    local head = {}
    if flags.always_unavailable then table.insert(head, "*unavailable") end
    if flags.always_deprecated then table.insert(head, "*deprecated") end
    local names = {}
    for platform in pairs(entries) do table.insert(names, platform) end
    byteorder.sort(names)
    local list = {}
    for _, platform in ipairs(names) do
        local e = entries[platform]
        table.insert(list, platform .. "=" .. e.intro .. "/" .. e.dep .. "/" .. e.obs .. "/" .. (e.unavailable and "1" or "0"))
    end
    local out = table.concat(head, " ")
    if #list > 0 then out = (out == "" and "" or out .. " ") .. table.concat(list, ",") end
    return out == "" and "-" or out
end

-- The deprecation and the unavailability texts of a message cell: "deprecated: TEXT", "unavailable: TEXT", or both as
-- "deprecated: TEXT | unavailable: TEXT". The unavailability text is the part after the last " | unavailable: ", so a deprecation text
-- may contain " | " (a replacement list does).
function split_message(message)
    local rest, unavailable = message, nil
    local head, tail = message:match("^(.*) | unavailable: (.*)$")
    if head then
        rest, unavailable = head, tail
    elseif message:sub(1, 13) == "unavailable: " then
        rest, unavailable = "", message:sub(14)
    end
    return rest:match("^deprecated: (.*)$"), unavailable
end

-- The version of the votes for one field: the latest, when every vote has one; none otherwise.
local function latest(votes, field)
    local best, best_text = nil, "-"
    for _, vote in ipairs(votes) do
        if vote[field] == "-" then return "-" end
        local n = version_number(vote[field])
        if best == nil or n > best then best, best_text = n, vote[field] end
    end
    return best_text
end

-- The rows of one key, each {avail = IR text, message = IR text}: the merged availability and message (the rule of the header).
function merge(rows)
    local parsed, names, named = {}, {}, {}
    -- each flag is ANDed only over the rows that vote on it: a row that names a platform, or carries that flag. A row that names no
    -- platform and carries no flag is unannotated and votes on nothing (the rule of the header; review F7).
    local all_unavailable, all_deprecated = true, true
    local voting_unavailable, voting_deprecated = 0, 0
    for _, r in ipairs(rows) do
        local p = parse_availability(r.avail)
        p.message = r.message or ""
        table.insert(parsed, p)
        local names_platform = false
        for _ in pairs(p.entries) do names_platform = true end
        for platform in pairs(p.entries) do
            if not named[platform] then
                named[platform] = true
                table.insert(names, platform)
            end
        end
        if names_platform or p.always_unavailable then
            voting_unavailable = voting_unavailable + 1
            all_unavailable = all_unavailable and p.always_unavailable
        end
        if names_platform or p.always_deprecated then
            voting_deprecated = voting_deprecated + 1
            all_deprecated = all_deprecated and p.always_deprecated
        end
    end
    byteorder.sort(names)
    local entries = {}
    for _, platform in ipairs(names) do
        local votes, unavailable = {}, false
        for _, p in ipairs(parsed) do
            local e = p.entries[platform]
            if p.always_unavailable or (e and e.unavailable) then
                unavailable = true
            elseif e then
                table.insert(votes, {intro = e.intro, dep = e.dep, obs = e.obs})
            end
        end
        if #votes == 0 then
            entries[platform] = {intro = "-", dep = "-", obs = "-", unavailable = true}
        else
            -- an unrestricted vote (no introduction) makes the introduction none
            local earliest, unrestricted = nil, false
            for _, v in ipairs(votes) do
                if v.intro == "-" then
                    unrestricted = true
                elseif earliest == nil or version_number(v.intro) < version_number(earliest) then
                    earliest = v.intro
                end
            end
            local intro = (unrestricted or earliest == nil) and "-" or earliest
            local entry = {intro = intro, dep = latest(votes, "dep"), obs = latest(votes, "obs"), unavailable = false}
            if intro ~= "-" or entry.dep ~= "-" or entry.obs ~= "-" then entries[platform] = entry end
        end
    end
    local flags = {always_unavailable = all_unavailable and voting_unavailable > 0,
        always_deprecated = all_deprecated and voting_deprecated > 0}
    local avail = format_availability(flags, entries)
    -- the messages: the deprecation of the row with the latest deprecation, the unavailable text of the first row that has one
    local deprecated_row, latest_dep = nil, -1
    local any_unavailable = false
    for _, e in pairs(entries) do
        if e.unavailable then any_unavailable = true end
    end
    local unavailable_text = nil
    for _, p in ipairs(parsed) do
        for _, e in pairs(p.entries) do
            if e.dep ~= "-" and version_number(e.dep) > latest_dep then
                latest_dep, deprecated_row = version_number(e.dep), p
            end
        end
        local _, unavailable = split_message(p.message)
        if unavailable_text == nil then unavailable_text = unavailable end
    end
    local pieces = {}
    local deprecated = split_message(deprecated_row and deprecated_row.message or "")
    local any_deprecated = false
    for _, e in pairs(entries) do
        if e.dep ~= "-" then any_deprecated = true end
    end
    if any_deprecated and deprecated then table.insert(pieces, "deprecated: " .. deprecated) end
    if any_unavailable and unavailable_text then table.insert(pieces, "unavailable: " .. unavailable_text) end
    return {avail = avail, message = table.concat(pieces, " | ")}
end

-- The spec's availability text, rendered from the IR fields (the contract of design-foundation.md section 5.8): the macros in the
-- order API_AVAILABLE, API_DEPRECATED, API_OBSOLETED, API_UNAVAILABLE, each listing its platforms in name order, separated by spaces.
local function quoted(text)
    return '"' .. text:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

function render(avail_text, message)
    local parsed = parse_availability(avail_text)
    local names = {}
    for platform in pairs(parsed.entries) do table.insert(names, platform) end
    byteorder.sort(names)
    local available, deprecated, obsoleted, unavailable = {}, {}, {}, {}
    for _, platform in ipairs(names) do
        local e = parsed.entries[platform]
        if e.unavailable then
            table.insert(unavailable, platform)
        elseif e.obs ~= "-" then
            table.insert(obsoleted, platform .. "(" .. e.intro .. ", " .. e.obs .. ")")
        elseif e.dep ~= "-" then
            table.insert(deprecated, platform .. "(" .. e.intro .. ", " .. e.dep .. ")")
        elseif e.intro ~= "-" then
            table.insert(available, platform .. "(" .. e.intro .. ")")
        end
    end
    local text = split_message(message or "") or ""
    local out = {}
    if #available > 0 then table.insert(out, "API_AVAILABLE(" .. table.concat(available, ", ") .. ")") end
    if parsed.always_deprecated then
        table.insert(out, "API_DEPRECATED(" .. quoted(text) .. ")")
    elseif #deprecated > 0 then
        table.insert(out, "API_DEPRECATED(" .. quoted(text) .. ", " .. table.concat(deprecated, ", ") .. ")")
    end
    if #obsoleted > 0 then table.insert(out, "API_OBSOLETED(" .. table.concat(obsoleted, ", ") .. ")") end
    if #unavailable > 0 then
        table.insert(out, "API_UNAVAILABLE(" .. table.concat(unavailable, ", ") .. ")")
    elseif parsed.always_unavailable then
        table.insert(out, "API_UNAVAILABLE")
    end
    return table.concat(out, " ")
end
