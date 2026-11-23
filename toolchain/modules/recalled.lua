import("cache")

local STEP = "light suites"
local OWNER = "ci_local.lua"
local reals = {}

local function split(value)
    local nonce, file = (value or ""):match("^(%x+)@(.+)$")
    return nonce, file
end

local function fields(file)
    local found = {}
    for line in (io.readfile(file) or ""):gmatch("[^\n]+") do
        table.insert(found, line)
    end
    return found
end

local function written(file, text)
    local partial = file .. "." .. hash.uuid4()
    io.writefile(partial, text)
    os.mv(partial, file)
end

local function real(folder)
    if reals[folder] == nil then
        reals[folder] = try { function () return os.iorunv("sh", {"-c", "cd \"$1\" && pwd -P", "sh", folder}):trim() end } or false
    end
    return reals[folder] or nil
end

local function process(pid)
    local text = try { function () return os.iorunv("ps", {"-ww", "-o", "lstart=,command=", "-p", tostring(pid)}) end } or ""
    local began, command = text:match("^%s*(%a+%s+%a+%s+%d+%s+%d+:%d+:%d+%s+%d+)%s+(.-)%s*$")
    if not began then
        return "", ""
    end
    return (began:gsub("%s+", " ")), command
end

local function alive(pid)
    return os.execv("/bin/kill", {"-0", tostring(pid)}, {try = true}) == 0
end

local function named(pid, nonce)
    return string.format("light-suites-%s-%s.verdict", pid, nonce)
end

function parse(output)
    local plain = (output or ""):gsub("\27%[[%d;]*m", "")
    local line = plain:match("recalled light suites memo [^\n]*")
    local key = plain:match("\nkey (%x+)") or plain:match("^key (%x+)")
    if line and key then
        return line, key
    end
end

function holds(memo, name, key)
    local file = path.join(memo, (name:gsub("%s+", "-")), key)
    if not os.isfile(file) then
        return false
    end
    for line in io.readfile(file):gmatch("[^\n]+") do
        if line == "verdict ok" then
            return true
        end
    end
    return false
end

function issue(folder, key, tree, line, owner)
    local nonce = (hash.uuid4():gsub("-", ""))
    local pid = owner or os.getpid()
    local began, command = process(pid)
    if began == "" then
        if os.getenv("REVENANT_SUITE_SANDBOX") == "1" and alive(pid) then
            began = tostring(os.time())
            command = OWNER .. " (sandboxed)"
        else
            return nil
        end
    end
    if not (" " .. command):find("[%s/]" .. OWNER:gsub("%p", "%%%0")) then
        return nil
    end
    local where = path.normalize(path.absolute(folder))
    local file = path.join(where, named(pid, nonce))
    written(file, table.concat({nonce, key, real(tree) or tree, tostring(pid), began, where, line, OWNER}, "\n") .. "\n")
    return nonce .. "@" .. file
end

function read(value, tree, memo)
    local nonce, file = split(value)
    if not nonce or not tree or not os.isfile(file) then
        return nil
    end
    local record = fields(file)
    local key, folder, pid, began, where, line, owner = record[2], record[3], record[4], record[5], record[6], record[7], record[8]
    if record[1] ~= nonce or not key or not folder or not pid or not began or not where or not line or owner ~= OWNER or not alive(pid) then
        return nil
    end
    if path.filename(file) ~= named(pid, nonce) or path.normalize(path.directory(file)) ~= where then
        return nil
    end
    if real(tree) ~= folder then
        return nil
    end
    if not holds(memo or path.join(cache.store(), "memo"), STEP, key) then
        return nil
    end
    return line
end

function clear(value)
    local nonce, file = split(value)
    if nonce and os.isfile(file) and fields(file)[1] == nonce then
        os.tryrm(file)
    end
end
