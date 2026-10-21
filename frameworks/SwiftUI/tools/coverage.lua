import("core.base.json")
local text = import("lib.text", {rootdir = os.scriptdir(), anonymous = true})
local sets = import("lib.sets", {rootdir = os.scriptdir(), anonymous = true})
local tree = import("lib.tree", {rootdir = os.scriptdir(), anonymous = true})

local function format_named(template, values)
    return (string.gsub(template, "{([%w_]+)}", function(key)
        return tostring(values[key])
    end))
end

local function take(s, count)
    local length = utf8.len(s) or #s
    if length <= count then
        return s
    end
    return string.sub(s, 1, utf8.offset(s, count + 1) - 1)
end

local function line_at(content, pos)
    local count = 0
    for _ in string.gmatch(string.sub(content, 1, pos - 1), "\n") do
        count = count + 1
    end
    return count + 1
end

local function sources()
    local dir = tree.sources()
    if #os.dirs(path.join(dir, "*")) > 0 then
        raise("coverage: " .. dir .. " has subdirectories, and the walk over them is not written")
    end
    local names = {}
    for _, file in ipairs(os.files(path.join(dir, "*.swift"))) do
        names[#names + 1] = path.filename(file)
    end
    table.sort(names)
    local out = {}
    for _, name in ipairs(names) do
        out[#out + 1] = {name = name, text = io.readfile(path.join(dir, name))}
    end
    return out
end

local function apple_surface()
    local types, type_names = {}, {}
    for _, line in ipairs(text.lines(io.readfile(tree.api("apple-types.txt")))) do
        local parts = text.split(line, "\t")
        if #parts ~= 2 then
            raise("coverage: apple-types.txt line has " .. #parts .. " columns: " .. line)
        end
        if types[parts[1]] == nil then
            type_names[#type_names + 1] = parts[1]
        end
        types[parts[1]] = parts[2]
    end
    local mods = {}
    for _, line in ipairs(text.lines(io.readfile(tree.api("apple-view-modifiers.txt")))) do
        if text.strip(line) ~= "" then
            mods[#mods + 1] = text.strip(line)
        end
    end
    return types, type_names, mods
end

local function ios_names(file)
    local set = {}
    for _, line in ipairs(text.lines(io.readfile(tree.api(file)))) do
        if text.strip(line) ~= "" then
            set[text.strip(line)] = true
        end
    end
    return set
end

local function first_call(line)
    local from = 1
    while true do
        local a = string.find(line, "unimplemented(", from, true)
        local b = string.find(line, "ignored(", from, true)
        local at, word
        if a and (not b or a <= b) then
            at, word = a, "unimplemented"
        elseif b then
            at, word = b, "ignored"
        else
            return nil
        end
        local boundary = at == 1 or not string.match(string.sub(line, at - 1, at - 1), "[%w_]")
        local after_func = at > 5 and string.sub(line, at - 5, at - 1) == "func "
        if boundary and not after_func then
            return at, word
        end
        from = at + 1
    end
end

local function stub_calls()
    local counted, partial, unreadable = {}, {}, {}
    for _, source in ipairs(sources()) do
        for number, line in ipairs(text.lines(source.text)) do
            local at, word = first_call(line)
            if at then
                local rest = string.sub(line, at + #word + 1)
                local where = source.name .. ":" .. number
                local literal = string.match(rest, '^[^,"]+,%s*"([^"]*)"')
                local call = take(text.strip(string.sub(line, at)), 80)
                if not literal or not string.match(literal, "^[%w_]*$") then
                    unreadable[#unreadable + 1] = {where, call}
                elseif literal ~= "" then
                    counted[#counted + 1] = {word, literal}
                end
            end
        end
        local content = source.text
        local pos = 1
        while true do
            local found = string.find(content, "_Unsupported.", pos, true)
            if not found then
                break
            end
            local after = found + #"_Unsupported."
            local kind, opening
            local a, b = string.find(content, '^pendingNote%("', after)
            if a then
                kind, opening = "pendingNote", b + 1
            else
                a, b = string.find(content, '^note%("', after)
                if a then
                    kind, opening = "note", b + 1
                end
            end
            local close = kind and string.find(content, '"', opening, true)
            if close then
                local arg = string.sub(content, opening, close - 1)
                local head = nil
                local base = string.match(arg, "^[%w_%.]+")
                if base then
                    head = base .. (string.match(arg, "^[%w_%.]+(%([^%)\\]*%))") or "")
                end
                partial[#partial + 1] = {kind, head or arg, source.name .. ":" .. line_at(content, found)}
                pos = close + 1
            else
                pos = after
            end
        end
    end
    return counted, partial, unreadable
end

local function ours()
    local types, mods, ignored, pending = {}, {}, {}, {}
    for _, source in ipairs(sources()) do
        local content = source.text
        local pos = 1
        while true do
            local found, after_public = string.find(content, "public ", pos, true)
            if not found then
                break
            end
            local p = after_public + 1
            while true do
                local _, attribute_end = string.find(content, "^@[%w_]+%s+", p)
                if not attribute_end then
                    break
                end
                p = attribute_end + 1
            end
            local kind, name = string.match(content, "^(%a+)%s+([A-Za-z_][%w_]*)", p)
            if kind == "struct" or kind == "class" or kind == "enum" or kind == "protocol" then
                types[name] = true
                local _, name_end = string.find(content, "^%a+%s+[A-Za-z_][%w_]*", p)
                pos = name_end + 1
            else
                pos = found + 1
            end
        end
        for _, keyword in ipairs({"typealias", "associatedtype"}) do
            pos = 1
            while true do
                local found, keyword_end = string.find(content, keyword, pos, true)
                if not found then
                    break
                end
                local name = string.match(content, "^%s+([A-Za-z_][%w_]*)", keyword_end + 1)
                if name then
                    types[name] = true
                end
                pos = keyword_end + 1
            end
        end
        pos = 1
        while true do
            local found, opening_end = string.find(content, 'ignored(self, "', pos, true)
            if not found then
                break
            end
            local name, reason = string.match(content, '^([%w_]+)", "([^"]*)"%)', opening_end + 1)
            if name then
                ignored[name] = reason
            end
            pos = opening_end + 1
        end
        pos = 1
        while true do
            local found, opening_end = string.find(content, 'unimplemented(self, "', pos, true)
            if not found then
                break
            end
            local name = string.match(content, '^([%w_]+)"%)', opening_end + 1)
            if name then
                pending[name] = true
            end
            pos = opening_end + 1
        end
        local in_view = false
        for _, line in ipairs(text.split(content, "\n")) do
            local extended = string.match(line, "^extension ([%w_%.]+)")
            if extended then
                in_view = extended == "View"
            end
            local declares = false
            for _, prefix in ipairs({"public ", "final ", ""}) do
                if not declares and text.startswith(line, prefix) then
                    local rest = string.sub(line, #prefix + 1)
                    for _, kind in ipairs({"struct", "class", "enum", "protocol"}) do
                        if text.startswith(rest, kind .. " ") then
                            declares = true
                        end
                    end
                end
            end
            if declares then
                in_view = false
            end
            local modifier = string.match(line, "^    public func ([%w_]+)")
            if modifier and in_view then
                mods[modifier] = true
            end
        end
    end
    local pending_only = {}
    for name in pairs(pending) do
        if ignored[name] == nil then
            pending_only[name] = true
        end
    end
    return types, mods, ignored, pending_only
end

local INVENTED_GENERATOR = "tools/api_surface.lua"

local function invented_file()
    return path.join(tree.run("api"), "invented.txt")
end

local function invented_count()
    if not os.isfile(invented_file()) then
        return nil
    end
    local n = 0
    for _, line in ipairs(text.lines(io.readfile(invented_file()))) do
        if text.strip(line) ~= "" then
            n = n + 1
        end
    end
    return n
end

local SCORE = "%*%*(%d+) types%*%* and %*%*(%d+) modifiers%*%*, of which %*%*(%d+) work%*%*, (%d+) stubs %(they write to the log%), (%d+) declared"
local IOS_SCORE = "Of what Apple declares available on iOS: %*%*(%d+) of (%d+) types%*%* and %*%*(%d+) of (%d+) modifiers%*%*, of which %*%*(%d+) work%*%*, (%d+) stubs, (%d+) ignored"
local SCORE_TEXT = "**{types} types** and **{mods} modifiers**, of which **{working} work**, {pending} stubs (they write to the log), {ignored} declared"
local IOS_SCORE_TEXT = "Of what Apple declares available on iOS: **{ios_types} of {ios_apple_types} types** and **{ios_mods} of {ios_apple_mods} modifiers**, of which **{ios_working} work**, {ios_pending} stubs, {ios_ignored} ignored"
local INVENTED_SCORE = "(The count is the same in both places — )(%d+):"
local INVENTED_SCORE_ONE = "The count is the same in both places — (%d+):"

local NUMBER_KEYS = {"apple_types", "types", "apple_mods", "mods", "working", "pending", "ignored",
    "ios_apple_types", "ios_types", "ios_apple_mods", "ios_mods", "ios_working", "ios_pending", "ios_ignored"}

local function counts()
    local apple_types, apple_type_names, apple_mods = apple_surface()
    local our_types, our_mods, ignored, pending = ours()
    local ios_types, ios_mods = ios_names("apple-types-ios.txt"), ios_names("apple-view-modifiers-ios.txt")

    local covered_types = 0
    for _, name in ipairs(apple_type_names) do
        if our_types[name] then
            covered_types = covered_types + 1
        end
    end
    local covered_mods, working, stubs = {}, {}, {}
    for _, name in ipairs(apple_mods) do
        if our_mods[name] then
            covered_mods[#covered_mods + 1] = name
        end
    end
    table.sort(covered_mods)
    for _, name in ipairs(covered_mods) do
        if ignored[name] == nil and not pending[name] then
            working[#working + 1] = name
        end
        if pending[name] then
            stubs[#stubs + 1] = name
        end
    end
    local n = {
        apple_types = #apple_type_names,
        types = covered_types,
        apple_mods = #apple_mods,
        mods = #covered_mods,
        working = #working,
        pending = #stubs,
        ignored = #covered_mods - #working - #stubs,
    }
    local ios_mod_list, ios_work, ios_pend = {}, {}, {}
    for _, name in ipairs(covered_mods) do
        if ios_mods[name] then
            ios_mod_list[#ios_mod_list + 1] = name
        end
    end
    for _, name in ipairs(working) do
        if ios_mods[name] then
            ios_work[#ios_work + 1] = name
        end
    end
    for _, name in ipairs(stubs) do
        if ios_mods[name] then
            ios_pend[#ios_pend + 1] = name
        end
    end
    local ios_type_hits = 0
    for name in pairs(ios_types) do
        if our_types[name] then
            ios_type_hits = ios_type_hits + 1
        end
    end
    n.ios_apple_types = sets.count_of(ios_types)
    n.ios_types = ios_type_hits
    n.ios_apple_mods = sets.count_of(ios_mods)
    n.ios_mods = #ios_mod_list
    n.ios_working = #ios_work
    n.ios_pending = #ios_pend
    n.ios_ignored = #ios_mod_list - #ios_work - #ios_pend
    return n, {
        apple_types = apple_types, apple_type_names = apple_type_names, apple_mods = apple_mods,
        our_types = our_types, our_mods = our_mods, ignored = ignored, stubs = stubs,
    }
end

local function baseline_json(n)
    local rows = {}
    for _, key in ipairs(NUMBER_KEYS) do
        rows[#rows + 1] = '  "' .. key .. '": ' .. tostring(n[key])
    end
    return "{\n" .. text.join(",\n", rows) .. "\n}"
end

local function dict_repr(n)
    local rows = {}
    for _, key in ipairs(NUMBER_KEYS) do
        rows[#rows + 1] = "'" .. key .. "': " .. tostring(n[key])
    end
    return "{" .. text.join(", ", rows) .. "}"
end

local ARGS = {}

local function has_arg(flag)
    for _, a in ipairs(ARGS) do
        if a == flag then
            return true
        end
    end
    return false
end

function main(...)
    ARGS = {...}
    local n, parts = counts()
    local baseline_path = tree.api("coverage-baseline.json")
    local readme_path = tree.revenant("docs", "reference", "swiftui", "ledger.md")

    if has_arg("--update") then
        io.writefile(baseline_path, baseline_json(n))
        local readme = io.readfile(readme_path)
        readme = string.gsub(readme, SCORE, function(...)
            return format_named(SCORE_TEXT, n)
        end)
        readme = string.gsub(readme, IOS_SCORE, function(...)
            return format_named(IOS_SCORE_TEXT, n)
        end)
        local actual = invented_count()
        if actual == nil then
            print(invented_file() .. " is missing: the invented-name count was not written to docs/reference/swiftui/ledger.md; " .. INVENTED_GENERATOR .. " writes it")
        else
            readme = string.gsub(readme, INVENTED_SCORE, function(head)
                return head .. actual .. ":"
            end)
        end
        io.writefile(readme_path, readme)
        print("written: " .. dict_repr(n))
        return 0
    end

    if has_arg("--check") then
        local problems = {}
        if os.isfile(baseline_path) then
            local baseline = json.decode(io.readfile(baseline_path))
            for _, key in ipairs({"types", "mods", "working"}) do
                if n[key] < baseline[key] then
                    problems[#problems + 1] = key .. ": was " .. string.format("%d", baseline[key]) .. ", now " .. n[key]
                        .. " — coverage fell"
                end
            end
        end
        local readme = io.readfile(readme_path)
        local ios = {string.match(readme, IOS_SCORE)}
        if #ios == 0 then
            problems[#problems + 1] = "docs/reference/swiftui/ledger.md has no line with the iOS count"
        else
            local actual = {}
            for i, key in ipairs({"ios_types", "ios_apple_types", "ios_mods", "ios_apple_mods", "ios_working", "ios_pending", "ios_ignored"}) do
                actual[i] = n[key]
            end
            local same = true
            for i = 1, 7 do
                if tonumber(ios[i]) ~= actual[i] then
                    same = false
                end
            end
            if not same then
                problems[#problems + 1] = "docs/reference/swiftui/ledger.md says for iOS (" .. text.join(", ", ios) .. "), in fact ("
                    .. text.join(", ", actual) .. ") — update docs/reference/swiftui/ledger.md (./xmakew l frameworks/SwiftUI/tools/coverage.lua --update)"
            end
        end
        local stated = {string.match(readme, SCORE)}
        if #stated == 0 then
            problems[#problems + 1] = "docs/reference/swiftui/ledger.md has no line with the count"
        else
            local actual = {n.types, n.mods, n.working, n.pending, n.ignored}
            local same = true
            for i = 1, 5 do
                if tonumber(stated[i]) ~= actual[i] then
                    same = false
                end
            end
            if not same then
                problems[#problems + 1] = "docs/reference/swiftui/ledger.md says (" .. text.join(", ", stated) .. "), in fact ("
                    .. text.join(", ", actual) .. ") — update docs/reference/swiftui/ledger.md (./xmakew l frameworks/SwiftUI/tools/coverage.lua --update)"
            end
        end
        for _, name in ipairs(sets.sorted_keys(parts.ignored)) do
            if not string.find(readme, "`" .. name .. "`", 1, true) then
                problems[#problems + 1] = "ignored API " .. name .. " is not described in docs/reference/swiftui/ledger.md"
            end
        end
        local said = string.match(readme, INVENTED_SCORE_ONE)
        said = said and tonumber(said)
        local actual = invented_count()
        if has_arg("--before-build") then
        elseif actual == nil then
            problems[#problems + 1] = invented_file() .. " is missing, and without it the invented-name count cannot be checked: "
                .. INVENTED_GENERATOR .. " writes it; run it and update docs/reference/swiftui/ledger.md (./xmakew l frameworks/SwiftUI/tools/coverage.lua --update)"
        elseif said == nil then
            problems[#problems + 1] = "docs/reference/swiftui/ledger.md does not name the invented-name count (" .. invented_file() .. ")"
        elseif said ~= actual then
            problems[#problems + 1] = "docs/reference/swiftui/ledger.md says " .. said .. " invented names, " .. invented_file() .. " holds "
                .. actual .. " — update docs/reference/swiftui/ledger.md (./xmakew l frameworks/SwiftUI/tools/coverage.lua --update)"
        end
        local counted, partial, unreadable = stub_calls()
        for _, call in ipairs(unreadable) do
            problems[#problems + 1] = call[1] .. ": " .. call[2] .. " — the counter cannot read the name (it needs a string of one identifier)"
        end
        for _, entry in ipairs(partial) do
            local kind, name, where = entry[1], entry[2], entry[3]
            if not string.find(readme, "`" .. name, 1, true) then
                local word = kind == "pendingNote" and "unimplemented" or "ignored"
                problems[#problems + 1] = where .. ": partial " .. word .. " \"" .. name .. "\" is not named in docs/reference/swiftui/ledger.md"
            end
        end
        if #problems > 0 then
            print("coverage: the check failed")
            for _, problem in ipairs(problems) do
                print(" - " .. problem)
            end
            os.exit(1)
        end
        print("coverage: types " .. n.types .. "/" .. n.apple_types .. ", modifiers " .. n.mods .. "/" .. n.apple_mods
            .. " (working " .. n.working .. ", stubs " .. n.pending .. ", ignored " .. n.ignored .. ") — docs/reference/swiftui/ledger.md agrees")
        return 0
    end

    print("types:        " .. n.types .. " of " .. n.apple_types)
    print("modifiers:    " .. n.mods .. " of " .. n.apple_mods .. " (working " .. n.working .. ", stubs " .. n.pending
        .. ", declared and ignored " .. n.ignored .. ")")
    if has_arg("--pending") then
        print("  " .. text.join(", ", parts.stubs))
    end
    if has_arg("--ignored") then
        for _, name in ipairs(sets.sorted_keys(parts.ignored)) do
            print("  " .. name .. ": " .. parts.ignored[name])
        end
    end
    if has_arg("--missing") then
        local missing_types = {}
        for _, name in ipairs(parts.apple_type_names) do
            if not parts.our_types[name] then
                missing_types[#missing_types + 1] = name
            end
        end
        local missing_mods = {}
        for _, name in ipairs(parts.apple_mods) do
            if not parts.our_mods[name] then
                missing_mods[#missing_mods + 1] = name
            end
        end
        print("\nnot covered (types):")
        print("  " .. text.join(", ", missing_types))
        print("\nnot covered (modifiers):")
        print("  " .. text.join(", ", missing_mods))
    end
    return 0
end
