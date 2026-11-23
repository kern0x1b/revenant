local memo = import("memo", {rootdir = os.scriptdir(), anonymous = true})
local real = {
    readfile = io.readfile,
    open = io.open,
    execv = os.execv,
    iorunv = os.iorunv,
    vrunv = os.vrunv,
    runv = os.runv,
}

local function allowed(root, value, reads)
    if not value:find("/") and not value:find("\\") then
        return true
    end
    local full = path.normalize(path.absolute(value))
    if not full:startswith(root .. "/") then
        return true
    end
    local relative = full:sub(#root + 2)
    if relative:startswith(".cache/") or relative:startswith("build/") then
        return true
    end
    return memo.matches(relative, reads)
end

local function from_suite(root)
    for level = 3, 12 do
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

function start(root, reads)
    root = path.normalize(path.absolute(root))
    local function wrap(name, original)
        return function (...)
            local arguments = table.pack(...)
            local value = arguments[1]
            if type(value) == "string" and from_suite(root) and not allowed(root, value, reads) then
                raise("light suite reads %s, which its declaration does not list; add it to toolchain/tests/suite_reads.lua so the memo key covers it", value)
            end
            return original(table.unpack(arguments, 1, arguments.n))
        end
    end
    io.readfile = wrap("readfile", real.readfile)
    io.open = wrap("open", real.open)
    os.execv = wrap("execv", real.execv)
    os.iorunv = wrap("iorunv", real.iorunv)
    os.vrunv = wrap("vrunv", real.vrunv)
    os.runv = wrap("runv", real.runv)
end
