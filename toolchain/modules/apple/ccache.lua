local DEFAULT_GIGABYTES = 4
local SLOPPINESS = "include_file_ctime,include_file_mtime"
local KINDS = {"cc", "cxx", "mm", "mxx"}
local CONFIG = "# Written by toolchain/modules/apple/ccache.lua. Every setting comes from the environment of the shim next to it,\n"
               .. "# so this file only keeps the user's own ccache.conf from being read.\n"

local function cache()
    return import("@addon.revenant.cache", {anonymous = true})
end

function folder()
    return path.join(cache().store(), "ccache")
end

function gigabytes()
    local text = os.getenv("REVENANT_CCACHE_GB")
    if not text or text == "" then
        return DEFAULT_GIGABYTES
    end
    local number = tonumber(text)
    if not number or number <= 0 then
        raise("REVENANT_CCACHE_GB is %q, which is not a positive number of gigabytes", text)
    end
    return number
end

function program()
    if os.getenv("REVENANT_CCACHE") == "off" then
        return nil
    end
    for _, directory in ipairs((os.getenv("PATH") or ""):split(":", {plain = true})) do
        local candidate = path.join(directory, "ccache")
        if directory ~= "" and os.isexec(candidate) then
            return candidate
        end
    end
end

local function quoted(text)
    return "'" .. (text:gsub("'", "'\\''")) .. "'"
end

local function script(ccache, real, settings)
    return table.concat({
        "#!/bin/sh",
        "# Written by toolchain/modules/apple/ccache.lua: " .. real:gsub("[\r\n]", " ") .. " through ccache, with its own settings and cache folder.",
        "export CCACHE_CONFIGPATH=" .. quoted(settings.config),
        "export CCACHE_DIR=" .. quoted(settings.directory),
        "export CCACHE_BASEDIR=" .. quoted(settings.basedir),
        "export CCACHE_MAXSIZE=" .. quoted(settings.size),
        "export CCACHE_NOHASHDIR=1",
        "export CCACHE_COMPILERCHECK=content",
        "export CCACHE_SLOPPINESS=" .. quoted(SLOPPINESS),
        "exec " .. quoted(ccache) .. " " .. quoted(real) .. " \"$@\"",
        ""
    }, "\n")
end

local function write_executable(file, text)
    os.mkdir(path.directory(file))
    local temporary = file .. "." .. hash.uuid():sub(1, 8) .. ".tmp"
    io.writefile(temporary, text)
    os.vrunv("chmod", {"+x", temporary})
    os.mv(temporary, file)
end

function shim(real, opt)
    opt = opt or {}
    local ccache = opt.program or program()
    if not ccache then
        return nil
    end
    local root = opt.folder or folder()
    local settings = {
        config = path.join(root, "ccache.conf"),
        directory = path.join(root, "cache"),
        basedir = opt.basedir or path.directory(cache().checkout()),
        size = string.format("%gG", opt.gigabytes or gigabytes())
    }
    local text = script(ccache, real, settings)
    local file = path.join(root, "shim", hash.strhash128(text), path.filename(real))
    if not os.isfile(file) or io.readfile(file) ~= text then
        write_executable(file, text)
    end
    if not os.isfile(settings.config) then
        os.mkdir(root)
        io.writefile(settings.config, CONFIG)
    end
    return file
end

function enter(target, opt)
    if not (opt and opt.program) and not program() then
        return false
    end
    local shims = {}
    for _, kind in ipairs(KINDS) do
        local real
        for _, toolchain in ipairs(target:toolchains()) do
            real = real or toolchain:tool(kind)
        end
        if real then
            shims[kind] = shim(real, opt)
        end
    end
    local entered = false
    for _, kind in ipairs(KINDS) do
        if shims[kind] then
            target:set("toolset", kind, shims[kind])
            entered = true
        end
    end
    if entered then
        target:set("policy", "build.ccache", false)
    end
    return entered
end
