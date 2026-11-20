import("cache")

local FILE = "light-suites.verdict"
local STEP = "light suites"

local function split(value)
    local nonce, file = (value or ""):match("^(%x+)@(.+)$")
    return nonce, file
end

local function fields(file)
    local found = {}
    for line in io.readfile(file):gmatch("[^\n]+") do
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
    return try { function () return os.iorunv("sh", {"-c", "cd \"$1\" && pwd -P", "sh", folder}):trim() end }
end

local function started(pid)
    local text = try { function () return os.iorunv("ps", {"-o", "lstart=", "-p", tostring(pid)}) end } or ""
    return (text:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
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

function issue(folder, key, tree, line)
    local nonce = (hash.uuid4():gsub("-", ""))
    local pid = os.getpid()
    local began = started(pid)
    if began == "" then
        return nil
    end
    local file = path.join(folder, FILE)
    written(file, table.concat({nonce, key, real(tree) or tree, tostring(pid), began, line}, "\n") .. "\n")
    return nonce .. "@" .. file
end

function read(value, tree, memo)
    local nonce, file = split(value)
    if not nonce or not tree or not os.isfile(file) then
        return nil
    end
    local record = fields(file)
    local key, folder, pid, began, line = record[2], record[3], record[4], record[5], record[6]
    if record[1] ~= nonce or not key or not folder or not pid or not began or not line then
        return nil
    end
    if real(tree) ~= folder then
        return nil
    end
    if started(pid) ~= began then
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
