local FILE = "light-suites.verdict"

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

function parse(output)
    local plain = (output or ""):gsub("\27%[[%d;]*m", "")
    local line = plain:match("recalled light suites memo [^\n]*")
    local key = plain:match("\nkey (%x+)") or plain:match("^key (%x+)")
    if line and key then
        return line, key
    end
end

function issue(folder, key, root, line)
    local nonce = (hash.uuid4():gsub("-", ""))
    local file = path.join(folder, FILE)
    written(file, table.concat({nonce, key, root, line}, "\n") .. "\n")
    os.tryrm(file .. ".verified")
    return nonce .. "@" .. file
end

function current_key(root)
    local output = os.iorunv(os.programfile(), {"l", "-P", root, path.join(root, "tools", "prepush.lua"), "--recall", "light suites"})
    local _, key = parse(output)
    return key
end

function read(value, current)
    local nonce, file = split(value)
    if not nonce or not os.isfile(file) then
        return nil
    end
    local record = fields(file)
    if record[1] ~= nonce or not record[2] or not record[3] or not record[4] then
        return nil
    end
    local marker = file .. ".verified"
    local stamp = nonce .. "\n" .. record[2]
    if os.isfile(marker) and io.readfile(marker) == stamp then
        return record[4]
    end
    local key = try { function () return (current or current_key)(record[3]) end }
    if key ~= record[2] then
        return nil
    end
    written(marker, stamp)
    return record[4]
end

function clear(value)
    local nonce, file = split(value)
    if nonce and os.isfile(file) and fields(file)[1] == nonce then
        os.tryrm(file)
        os.tryrm(file .. ".verified")
    end
end
