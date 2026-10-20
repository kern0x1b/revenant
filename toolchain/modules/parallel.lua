local GIB = 1024 * 1024 * 1024

local function jobserver()
    local module = try { function () return import("core.base.jobserver", {anonymous = true}) end }
    return module and module.client() and module or nil
end

function width()
    local limit = tonumber(os.getenv("XMAKE_MAX_JOBS"))
    if limit and limit >= 1 then
        return math.floor(limit)
    end
    return os.default_njob()
end

function link_jobs()
    local given = tonumber(os.getenv("REVENANT_LINK_JOBS"))
    if given and given >= 1 then
        return math.floor(given)
    end
    local memory = tonumber(try { function () return os.iorunv("sysctl", {"-n", "hw.memsize"}):trim() end })
    local jobs = memory and math.floor(memory / (10 * GIB)) or 1
    return math.max(math.min(jobs, width()), 1)
end

local function ninja_reads_jobserver(program)
    if not jobserver() then
        return false
    end
    local version = try { function () return os.iorunv(program or "ninja", {"--version"}):trim() end }
    local major, minor = (version or ""):match("^(%d+)%.(%d+)")
    major, minor = tonumber(major), tonumber(minor)
    return major ~= nil and (major > 1 or (major == 1 and minor >= 13))
end

function ninja(limit, program)
    if ninja_reads_jobserver(program) then
        return {}
    end
    return {"-j", tostring(limit and math.min(limit, width()) or width())}
end

function cmake_ninja(limit)
    if ninja_reads_jobserver() then
        return {}
    end
    return {"--parallel", tostring(limit and math.min(limit, width()) or width())}
end

function hold(limit, func)
    local wanted = limit and math.min(limit, width()) or width()
    local server = jobserver()
    if server then
        return server.hold(wanted, func)
    end
    return func(wanted)
end
