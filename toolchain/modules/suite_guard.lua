local memo = import("memo", {rootdir = path.absolute(path.directory(debug.getinfo(1, "S").short_src:gsub("^@", ""))), anonymous = true})
local real = {
    readfile = io.readfile,
    open = io.open,
    execv = os.execv,
    iorunv = os.iorunv,
    vrunv = os.vrunv,
    runv = os.runv,
    getenv = os.getenv,
}

local function normalized(value)
    local full = path.absolute(value)
    local parts = {}
    for part in full:gmatch("[^/]+") do
        if part == ".." then
            table.remove(parts)
        elseif part ~= "." then
            table.insert(parts, part)
        end
    end
    return "/" .. table.concat(parts, "/")
end

local function allowed(root, value, reads)
    local full = normalized(value)
    if not full:startswith(root .. "/") then
        return true
    end
    local relative = full:sub(#root + 2)
    if relative == "build" or relative:startswith("build/") or relative:startswith(".cache/") or relative:startswith(".xmake/") then
        return true
    end
    return memo.matches(relative, reads)
end

local function from_suite(root)
    for level = 3, 14 do
        local info = debug.getinfo(level, "S")
        if not info then
            break
        end
        local source = info.short_src or ""
        if source:startswith("@") then
            source = source:sub(2)
        end
        if source ~= "[C]" and not source:endswith("suite_guard.lua") and path.absolute(source):startswith(root) then
            return true
        end
    end
    return false
end

local function refusal(value)
    raise("light suite reads %s, which its declaration does not list; add it to toolchain/tests/suite_reads.lua so the memo key covers it", value)
end

local function check_value(root, value, reads)
    if type(value) ~= "string" then
        return
    end
    if not os.isfile(value) and not os.isdir(value) and not value:startswith(root) then
        return
    end
    if not allowed(root, value, reads) then
        refusal(value)
    end
end

local function env_allowed(name, names)
    if name:startswith("REVENANT_") or name:startswith("XMAKE") or name == "PATH" or name == "HOME" or name == "TMPDIR" or name:startswith("LC_") then
        return true
    end
    for _, declared in ipairs(names or {}) do
        if name == declared then
            return true
        end
    end
    return false
end

function start(root, reads, names)
    root = path.normalize(path.absolute(root))
    local function wrap(original)
        return function (...)
            local arguments = table.pack(...)
            if from_suite(root) then
                for index = 1, arguments.n do
                    check_value(root, arguments[index], reads)
                end
            end
            return original(table.unpack(arguments, 1, arguments.n))
        end
    end
    local function wrap_command(original)
        return function (program, arguments, options)
            local values = arguments or {}
            if from_suite(root) then
                check_value(root, program, reads)
                for _, value in ipairs(values) do
                    check_value(root, value, reads)
                end
                if type(program) == "string" and program:endswith("sh") and values[1] == "-c" then
                    for token in tostring(values[2]):gmatch("%S+") do
                        check_value(root, (token:gsub("^[\"']", ""):gsub("[\"']$", "")), reads)
                    end
                end
            end
            return original(program, arguments, options)
        end
    end
    io.readfile = wrap(real.readfile)
    io.open = wrap(real.open)
    os.execv = wrap_command(real.execv)
    os.iorunv = wrap_command(real.iorunv)
    os.vrunv = wrap_command(real.vrunv)
    os.runv = wrap_command(real.runv)
    os.getenv = function (name)
        if from_suite(root) and not env_allowed(name, names) then
            raise("light suite reads the environment variable %s, which it does not declare; add it to the suite's env list so the memo key covers it", name)
        end
        return real.getenv(name)
    end
end
