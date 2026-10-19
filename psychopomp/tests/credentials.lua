-- Helpers for tests/run.sh's Claude login, replacing three inline python3 snippets:
--   xmake l tests/credentials.lua store FILE      keychain JSON on stdin -> FILE holds only claudeAiOauth
--   xmake l tests/credentials.lua left FILE       whole seconds until the access token expires (truncated toward 0)
--   xmake l tests/credentials.lua leaked FILE DIR  each file under DIR that holds the access or refresh token of FILE
-- Differences from the Python: the time is taken in whole seconds (os.time), not with fractions, so "left" can be one
-- second off at the boundary; and the file list comes from find, which takes the same paths os.walk did, but in sorted
-- order. The JSON text is re-encoded by xmake, so its spacing and key order are not those of json.dump.
import("core.base.json")

local function fail(message)
    io.stderr:write("credentials: " .. message .. "\n")
    os.exit(1)
end

local function read_binary(file)
    local handle = io.open(file, "rb")
    if not handle then
        return nil
    end
    local data = handle:read("a")
    handle:close()
    return data
end

local function claude_login(file)
    local data = read_binary(file)
    if not data then
        fail("cannot read " .. file)
    end
    local doc = json.decode(data)
    if type(doc) ~= "table" or type(doc.claudeAiOauth) ~= "table" then
        fail("no claudeAiOauth object in " .. file)
    end
    return doc.claudeAiOauth
end

local function store(file)
    local doc = json.decode(io.stdin:read("a"))
    if type(doc) ~= "table" or type(doc.claudeAiOauth) ~= "table" then
        fail("no claudeAiOauth object on stdin")
    end
    io.writefile(file, json.encode({claudeAiOauth = doc.claudeAiOauth}))
end

local function left(file)
    local seconds = claude_login(file).expiresAt / 1000 - os.time()
    local whole = seconds >= 0 and math.floor(seconds) or math.ceil(seconds)
    print(string.format("%d", whole))
end

local function leaked(file, dir)
    local login = claude_login(file)
    local secrets = {}
    for _, key in ipairs({"accessToken", "refreshToken"}) do
        if type(login[key]) == "string" and login[key] ~= "" then
            secrets[#secrets + 1] = login[key]
        end
    end
    local body = os.iorunv("/bin/sh", {"-c", 'find "$0" \\( -type f -o -type l \\) -print 2>/dev/null; true', dir})
    local paths = {}
    for path in string.gmatch(body, "[^\n]+") do
        paths[#paths + 1] = path
    end
    table.sort(paths)
    for _, path in ipairs(paths) do
        local data = read_binary(path)
        if data then
            for _, secret in ipairs(secrets) do
                if string.find(data, secret, 1, true) then
                    print(path)
                    break
                end
            end
        end
    end
end

function main(command, ...)
    local args = {...}
    if command == "store" and #args == 1 then
        store(args[1])
    elseif command == "left" and #args == 1 then
        left(args[1])
    elseif command == "leaked" and #args == 2 then
        leaked(args[1], args[2])
    else
        fail("usage: credentials.lua store FILE | left FILE | leaked FILE DIR")
    end
end
