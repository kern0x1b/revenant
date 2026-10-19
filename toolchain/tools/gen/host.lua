local emit = import("emit", {anonymous = true})
local stream = import("stream", {anonymous = true})
local strings = import("strings", {anonymous = true})
local json = import("core.base.json")

local PROJECT = path.absolute(path.join(os.scriptdir(), "host"))
local HOST = "/System/Library/Frameworks"

local builddir_cache = nil
local product_cache = {}

local function plain(text)
    return (string.gsub(text or "", "\27%[[%d;]*m", ""))
end

function tail(text, n)
    local stripped = string.gsub(string.gsub(text or "", "^%s+", ""), "%s+$", "")
    return string.sub(stripped, -n)
end

local function head(text)
    return string.sub(string.gsub(text or "", "%s+$", ""), 1, 200)
end

local function object_end(text, start)
    local depth, in_string, i = 0, false, start
    while i <= #text do
        local c = string.sub(text, i, i)
        if in_string then
            if c == "\\" then
                i = i + 1
            elseif c == "\"" then
                in_string = false
            end
        elseif c == "\"" then
            in_string = true
        elseif c == "{" then
            depth = depth + 1
        elseif c == "}" then
            depth = depth - 1
            if depth == 0 then
                return i
            end
        end
        i = i + 1
    end
    return nil
end

function json_of(text, what)
    local start = nil
    if string.sub(text, 1, 1) == "{" then
        start = 1
    else
        local at = string.find(text, "\n{", 1, true)
        start = at and at + 1 or nil
    end
    assert(start, what .. ": xmake printed no JSON object; its output begins: " .. head(text))
    local finish = object_end(text, start) or #text
    local body = string.sub(text, start, finish)
    local notes = string.gsub(string.gsub(string.sub(text, finish + 1), "^%s+", ""), "%s+$", "")
    local value = nil
    try {
        function()
            value = json.decode(body)
        end,
        catch {
            function(e)
                raise(what .. ": the JSON object does not decode (" .. tostring(e) .. "); its output begins: " .. head(text))
            end
        }
    }
    return value, notes
end

function run(program, argv)
    local out = {}
    local status, err = stream.run(program, argv or {}, function(line)
        table.insert(out, line)
    end)
    local text = #out > 0 and (table.concat(out, "\n") .. "\n") or ""
    return status == 0, text, err, status
end

local function xmake_at(cwd, project, argv)
    local here = os.curdir()
    local ok, out, err = true, "", ""
    local command = table.join({argv[1]}, {"-P", project}, table.slice(argv, 2))
    try {
        function()
            os.cd(cwd)
            ok, out, err = run(os.programfile(), command)
        end,
        catch {
            function(e)
                ok, out, err = false, "", tostring(e)
            end
        }
    }
    os.cd(here)
    return ok, plain(out), plain(err)
end

local function xmake(argv)
    return xmake_at(PROJECT, PROJECT, argv)
end

function target_product(cwd, project, name)
    local ok, out, err = xmake_at(cwd, project, {"show", "-t", name, "--format=json"})
    assert(ok, "xmake show failed for " .. name .. " of " .. project .. ": " .. tail(err, 300))
    local shown, notes = json_of(out, "xmake show -t " .. name .. " of " .. project)
    local file = shown.targetfile
    if not path.is_absolute(file) then
        file = path.join(project, file)
    end
    return path.normalize(path.absolute(file)), notes
end

function configure(framework, sources)
    local ok, _, err = xmake({"f", "-y", "-q", "--framework=" .. framework, "--sources=" .. sources})
    assert(ok, "xmake configure failed: " .. tail(err, 300))
end

function builddir()
    if builddir_cache == nil then
        local ok, out, err = xmake({"show", "--format=json"})
        assert(ok, "xmake show failed: " .. tail(err, 300))
        local dir = json_of(out, "xmake show").project.builddir
        if not path.is_absolute(dir) then
            dir = path.join(PROJECT, dir)
        end
        builddir_cache = path.absolute(dir)
    end
    return builddir_cache
end

function product(name)
    if product_cache[name] == nil then
        product_cache[name] = target_product(PROJECT, PROJECT, name)
    end
    return product_cache[name]
end

function build(name, force)
    local argv = {"build", "-y"}
    if force then
        table.insert(argv, "-r")
    end
    table.insert(argv, name)
    local ok, out, err = xmake(argv)
    io.stderr:write(out)
    if not ok then
        local kept = {}
        for _, line in ipairs(strings.lines(err ~= "" and err or out)) do
            if not string.find(line, "^%s*>%s+in%s") then
                table.insert(kept, line)
            end
        end
        return false, table.concat(kept, "\n")
    end
    io.stderr:write(err)
    return true, ""
end

function write_generated(name, text)
    local filepath = path.join(builddir(), "gen", name)
    local changed = emit.file(filepath, text)
    return filepath, changed
end

function framework_binary(framework)
    return path.join(HOST, framework .. ".framework", framework), os.isdir(path.join(HOST, framework .. ".framework"))
end
