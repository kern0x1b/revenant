-- coverage.lua: сколько публичной поверхности SwiftUI покрыто нашей реализацией.
--
-- Эталон — интерфейс SwiftUI из SDK (списки в ../bridge/apple-types.txt и apple-view-modifiers.txt),
-- наша сторона — исходники Sources/SwiftUI.
--
--   xmake l coverage.lua             счёт
--   xmake l coverage.lua --missing   чего нет
--   xmake l coverage.lua --ignored   что объявлено и игнорируется
--   xmake l coverage.lua --pending   заглушки: объявлены, пишут в журнал, ждут реализации
--   xmake l coverage.lua --check     проверка для сборки: счёт не упал, README сходится, у каждого
--                                    игнорируемого API есть строка причины в README
--   xmake l coverage.lua --update    записать текущий счёт в coverage-baseline.json и в README
--
-- The Python version of this file (coverage.py) read the same inputs with regular expressions. Each pattern is
-- written here as a Lua pattern or as a plain search; the comment above each one gives the regular expression it
-- stands for. The messages are the ones the Python printed.

import("core.base.json")
local text = import("lib.text", {rootdir = path.join(os.scriptdir(), ".."), anonymous = true})

local here = os.scriptdir()

-- the lines of a file, as Python's `for line in open(...)` gives them: without the newline, and no empty line after
-- the last newline
local function lines_of(content)
    local lines = text.split(content, "\n")
    if lines[#lines] == "" then
        lines[#lines] = nil
    end
    return lines
end

local function read(file)
    return io.readfile(file)
end

local function count_of(set)
    local n = 0
    for _ in pairs(set) do
        n = n + 1
    end
    return n
end

local function sorted_keys(set)
    local keys = {}
    for k in pairs(set) do
        keys[#keys + 1] = k
    end
    table.sort(keys)
    return keys
end

-- Python's str.format with named fields: {name} is replaced by the value of that key
local function format_named(template, values)
    return (string.gsub(template, "{([%w_]+)}", function(key)
        return tostring(values[key])
    end))
end

-- the first `count` characters of a string, counted in code points
local function take(s, count)
    local length = utf8.len(s) or #s
    if length <= count then
        return s
    end
    return string.sub(s, 1, utf8.offset(s, count + 1) - 1)
end

-- the line a position falls on: text.count(chr(10), 0, m.start()) + 1, with the position 1-based here
local function line_at(content, pos)
    local count = 0
    for _ in string.gmatch(string.sub(content, 1, pos - 1), "\n") do
        count = count + 1
    end
    return count + 1
end

-- the Swift sources of the module, in the order os.walk gave them (the directory has no subdirectories, so its
-- files, sorted, are the walk)
local function sources()
    local dir = path.join(here, "Sources", "SwiftUI")
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
        out[#out + 1] = {name = name, text = read(path.join(dir, name))}
    end
    return out
end

-- the public surface of Apple's SwiftUI for iOS 6, as the bridge files list it
local function apple_surface()
    local types, type_names = {}, {}
    for _, line in ipairs(lines_of(read(path.join(here, "..", "bridge", "apple-types.txt")))) do
        local parts = text.split(line, "\t")
        -- name, kind = line.rstrip('\n').split('\t')
        if #parts ~= 2 then
            raise("coverage: apple-types.txt line has " .. #parts .. " columns: " .. line)
        end
        if types[parts[1]] == nil then
            type_names[#type_names + 1] = parts[1]
        end
        types[parts[1]] = parts[2]
    end
    local mods = {}
    for _, line in ipairs(lines_of(read(path.join(here, "..", "bridge", "apple-view-modifiers.txt")))) do
        if text.strip(line) ~= "" then
            mods[#mods + 1] = text.strip(line)
        end
    end
    return types, type_names, mods
end

-- the names in one of the iOS lists: a set of the stripped, non-empty lines
local function ios_names(file)
    local set = {}
    for _, line in ipairs(lines_of(read(path.join(here, "..", "bridge", file)))) do
        if text.strip(line) ~= "" then
            set[text.strip(line)] = true
        end
    end
    return set
end

-- Every call that writes to the journal, with what coverage makes of it: a counted modifier name, a partial note
-- that the README must name, or a call the counter cannot read at all.
--
-- The Python searched every line for the first `unimplemented(` or `ignored(` at a word boundary and not after
-- `func `: r'(?<!func )\b(unimplemented|ignored)\((.*)'. Its `.*` runs to the end of the line, so a line has at most
-- one such call, and that is what is searched here.
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
        for number, line in ipairs(lines_of(source.text)) do
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
        -- r'_Unsupported\.(pendingNote|note)\("([^"]*)"': the note's text may run over lines, so the whole file is read
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
                -- r'[\w.]+(\([^)\\]*\))?' matched at the start of the note's text
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

-- The names the module declares: its types, its modifiers of View, the names it ignores with the reason, and the
-- ones it only logs (pending).
local function ours()
    local types, mods, ignored, pending = {}, {}, {}, {}
    for _, source in ipairs(sources()) do
        local content = source.text
        -- r'public (?:@\w+\s+)*(struct|class|enum|protocol)\s+([A-Za-z_]\w*)'
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
        -- r'(?:public )?typealias\s+([A-Za-z_]\w*)' and r'associatedtype\s+([A-Za-z_]\w*)'
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
        -- r'ignored\(self, "(\w+)", "([^"]*)"\)': a later declaration of the same name replaces the reason
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
        -- r'unimplemented\(self, "(\w+)"\)'
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
        -- the modifiers of View: the lines of the file, read one by one with an `extension` line opening a section
        local in_view = false
        for _, line in ipairs(text.split(content, "\n")) do
            local extended = string.match(line, "^extension ([%w_%.]+)")
            if extended then
                in_view = extended == "View"
            end
            -- r'(public |final |)(struct|class|enum|protocol) '
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
            -- r'    public func (\w+)'
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

-- the number of public names no 26.2 interface declares, or nil when that file is not there
local INVENTED_PATH = path.join(here, "..", "bridge", "api", "invented.txt")
local INVENTED_PATH_NAME = "bridge/api/invented.txt"
local INVENTED_GENERATOR = "bridge/api-surface.sh"

local function invented_count()
    if not os.isfile(INVENTED_PATH) then
        return nil
    end
    local n = 0
    for _, line in ipairs(lines_of(read(INVENTED_PATH))) do
        if text.strip(line) ~= "" then
            n = n + 1
        end
    end
    return n
end

-- The score lines of the README: the Python regular expressions, as Lua patterns with their captures
local SCORE = "%*%*(%d+) типов%*%* и %*%*(%d+) модификаторов%*%*, из них %*%*(%d+) действуют%*%*, (%d+) заглушки %(пишут в журнал%), (%d+) объявлены"
local IOS_SCORE = "Из того, что Apple объявляет доступным на iOS: %*%*(%d+) из (%d+) типов%*%* и %*%*(%d+) из (%d+) модификаторов%*%*, из них %*%*(%d+) действуют%*%*, (%d+) заглушки, (%d+) игнорируются"
local SCORE_TEXT = "**{types} типов** и **{mods} модификаторов**, из них **{working} действуют**, {pending} заглушки (пишут в журнал), {ignored} объявлены"
local IOS_SCORE_TEXT = "Из того, что Apple объявляет доступным на iOS: **{ios_types} из {ios_apple_types} типов** и **{ios_mods} из {ios_apple_mods} модификаторов**, из них **{ios_working} действуют**, {ios_pending} заглушки, {ios_ignored} игнорируются"
local INVENTED_SCORE = "(Счёт в обеих строках один и тот же — )(%d+):"
local INVENTED_SCORE_ONE = "Счёт в обеих строках один и тот же — (%d+):"

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
    -- apple_mods is a list: a modifier named twice in the file counts twice, as it did before
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
    -- ios_counts
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
    n.ios_apple_types = count_of(ios_types)
    n.ios_types = ios_type_hits
    n.ios_apple_mods = count_of(ios_mods)
    n.ios_mods = #ios_mod_list
    n.ios_working = #ios_work
    n.ios_pending = #ios_pend
    n.ios_ignored = #ios_mod_list - #ios_work - #ios_pend
    return n, {
        apple_types = apple_types, apple_type_names = apple_type_names, apple_mods = apple_mods,
        our_types = our_types, our_mods = our_mods, ignored = ignored, stubs = stubs,
    }
end

-- Python's json.dump(numbers, f, indent=2): no newline at the end
local function baseline_json(n)
    local rows = {}
    for _, key in ipairs(NUMBER_KEYS) do
        rows[#rows + 1] = '  "' .. key .. '": ' .. tostring(n[key])
    end
    return "{\n" .. text.join(",\n", rows) .. "\n}"
end

-- Python's repr of the dict numbers
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
    local baseline_path = path.join(here, "coverage-baseline.json")
    local readme_path = path.join(here, "README.md")

    if has_arg("--update") then
        io.writefile(baseline_path, baseline_json(n))
        local readme = read(readme_path)
        readme = string.gsub(readme, SCORE, function(...)
            return format_named(SCORE_TEXT, n)
        end)
        readme = string.gsub(readme, IOS_SCORE, function(...)
            return format_named(IOS_SCORE_TEXT, n)
        end)
        local actual = invented_count()
        if actual == nil then
            print(INVENTED_PATH_NAME .. " нет: счёт выдуманных имён в README не записан, его пишет " .. INVENTED_GENERATOR)
        else
            readme = string.gsub(readme, INVENTED_SCORE, function(head)
                return head .. actual .. ":"
            end)
        end
        io.writefile(readme_path, readme)
        print("записано: " .. dict_repr(n))
        return 0
    end

    if has_arg("--check") then
        local problems = {}
        if os.isfile(baseline_path) then
            local baseline = json.decode(read(baseline_path))
            for _, key in ipairs({"types", "mods", "working"}) do
                if n[key] < baseline[key] then
                    -- json reads every number as a float; Python printed the integer it was written as
                    problems[#problems + 1] = key .. ": было " .. string.format("%d", baseline[key]) .. ", стало " .. n[key]
                        .. " — покрытие упало"
                end
            end
        end
        local readme = read(readme_path)
        local ios = {string.match(readme, IOS_SCORE)}
        if #ios == 0 then
            problems[#problems + 1] = "README не содержит строки со счётом для iOS"
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
                problems[#problems + 1] = "README для iOS говорит (" .. text.join(", ", ios) .. "), на деле ("
                    .. text.join(", ", actual) .. ") — обновите README (xmake l coverage.lua --update)"
            end
        end
        local stated = {string.match(readme, SCORE)}
        if #stated == 0 then
            problems[#problems + 1] = "README не содержит строки со счётом"
        else
            local actual = {n.types, n.mods, n.working, n.pending, n.ignored}
            local same = true
            for i = 1, 5 do
                if tonumber(stated[i]) ~= actual[i] then
                    same = false
                end
            end
            if not same then
                problems[#problems + 1] = "README говорит (" .. text.join(", ", stated) .. "), на деле ("
                    .. text.join(", ", actual) .. ") — обновите README (xmake l coverage.lua --update)"
            end
        end
        for _, name in ipairs(sorted_keys(parts.ignored)) do
            if not string.find(readme, "`" .. name .. "`", 1, true) then
                problems[#problems + 1] = "игнорируемый API " .. name .. " не описан в README"
            end
        end
        local said = string.match(readme, INVENTED_SCORE_ONE)
        said = said and tonumber(said)
        local actual = invented_count()
        if has_arg("--before-build") then
            -- build.sh runs this first, and the file below is made from the module build.sh builds: on a fresh tree no
            -- build can start if it must already be there. The full --check (without the flag) compares it afterwards.
        elseif actual == nil then
            -- the oracle is generated, not tracked, so a fresh tree has none: a check that skipped a missing oracle would
            -- pass any number at all, so the absence is the failure and it names what writes the file
            problems[#problems + 1] = INVENTED_PATH_NAME .. " нет, и без него счёт выдуманных имён не проверить: его пишет "
                .. INVENTED_GENERATOR .. ", запустите его и обновите README (xmake l coverage.lua --update)"
        elseif said == nil then
            problems[#problems + 1] = "README не называет счёт выдуманных имён (bridge/api/invented.txt)"
        elseif said ~= actual then
            problems[#problems + 1] = "README говорит " .. said .. " выдуманных имён, " .. INVENTED_PATH_NAME .. " содержит "
                .. actual .. " — обновите README (xmake l coverage.lua --update)"
        end
        local counted, partial, unreadable = stub_calls()
        for _, call in ipairs(unreadable) do
            problems[#problems + 1] = call[1] .. ": " .. call[2] .. " — счётчик не может прочесть имя (нужна строка из одного идентификатора)"
        end
        for _, entry in ipairs(partial) do
            local kind, name, where = entry[1], entry[2], entry[3]
            if not string.find(readme, "`" .. name, 1, true) then
                local word = kind == "pendingNote" and "unimplemented" or "ignored"
                problems[#problems + 1] = where .. ": частичный " .. word .. " «" .. name .. "» не назван в README"
            end
        end
        if #problems > 0 then
            print("coverage: проверка не прошла")
            for _, problem in ipairs(problems) do
                print(" - " .. problem)
            end
            os.exit(1)
        end
        print("coverage: типы " .. n.types .. "/" .. n.apple_types .. ", модификаторы " .. n.mods .. "/" .. n.apple_mods
            .. " (действуют " .. n.working .. ", заглушки " .. n.pending .. ", игнорируются " .. n.ignored .. ") — README сходится")
        return 0
    end

    print("типы:         " .. n.types .. " из " .. n.apple_types)
    print("модификаторы: " .. n.mods .. " из " .. n.apple_mods .. " (действуют " .. n.working .. ", заглушки " .. n.pending
        .. ", объявлены и игнорируются " .. n.ignored .. ")")
    if has_arg("--pending") then
        print("  " .. text.join(", ", parts.stubs))
    end
    if has_arg("--ignored") then
        for _, name in ipairs(sorted_keys(parts.ignored)) do
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
        print("\nне покрыто (типы):")
        print("  " .. text.join(", ", missing_types))
        print("\nне покрыто (модификаторы):")
        print("  " .. text.join(", ", missing_mods))
    end
    return 0
end
