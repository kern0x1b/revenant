local function unquote(text)
    return (text:gsub("+", " "):gsub("%%(%x%x)", function (hex) return string.char(tonumber(hex, 16)) end))
end

local function query_of(line)
    local query = {}
    local text = line:match("%?(.*)$")
    if not text then
        return nil
    end
    for pair in text:gmatch("[^&]+") do
        local key, value = pair:match("^([^=]*)=?(.*)$")
        key = unquote(key)
        if query[key] == nil then
            query[key] = unquote(value)
        end
    end
    return query
end

function count(lines)
    local passed, failed = 0, 0
    local seen = {}
    for _, line in ipairs(lines) do
        local query = query_of(line)
        if query then
            local page = query.page or "?"
            for _, result in ipairs((query.results or ""):split("~~", {plain = true})) do
                if result ~= "" then
                    local verdict, rest = result:match("^([^|]*)|?(.*)$")
                    local check, detail = rest:match("^([^|]*)|?(.*)$")
                    local key = page .. "\0" .. check
                    if not seen[key] then
                        seen[key] = true
                        print(string.format("%-7s %-22s %-34s %s", verdict, page, check, detail))
                        if verdict == "PASS" then
                            passed = passed + 1
                        else
                            failed = failed + 1
                        end
                    end
                end
            end
        end
    end
    print("----")
    print(string.format("%d passed, %d failed", passed, failed))
    if passed == 0 and failed == 0 then
        print("no verdicts could be read from the log")
        return false
    end
    return failed == 0
end

function main(file)
    if not file then
        print("usage: ./xmakew l frameworks/WebKit/tests/device/verdicts.lua LOG")
        print("  prints the verdicts a test page reported, from a request log with one GET line each")
        return
    end
    local lines = {}
    for line in io.readfile(file):gmatch("[^\n]+") do
        table.insert(lines, line)
    end
    if not count(lines) then
        raise("the pages reported failures or nothing")
    end
end
