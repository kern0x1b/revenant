import("fixtures")

local LISTING = [[
import("core.project.config")
import("core.project.project")

function main()
    config.load()
    local names = {}
    for name, _ in pairs(project.targets()) do
        table.insert(names, name)
    end
    table.sort(names)
    print("TARGETS " .. #names)
end
]]

local function load(root, folder, curdir, envs)
    local listing = path.join(folder, "listing.lua")
    local log = path.join(folder, "load.log")
    io.writefile(listing, LISTING)
    local status = os.execv(os.programfile(), {"l", "-P", root, listing},
        {try = true, stdout = log, stderr = log, curdir = curdir, envs = envs})
    local text = io.readfile(log) or ""
    if status ~= 0 then
        return "the project must load all of its targets on a host with no iPhoneOS SDK, but xmake l exited with " .. tostring(status) .. ": " .. text
    elseif not text:find("TARGETS %d+") then
        return "the listing printed no target count, so the project did not load its targets: " .. text
    end
end

function failures(opt)
    local found = {}
    local repository = path.absolute(path.join(os.scriptdir(), "../../.."))
    local root = fixtures.scratch()

    local own = path.join(root, "own")
    os.mkdir(own)
    local problem = load(repository, own, own, {XMAKE_CONFIGDIR = path.join(own, "config")})
    if problem then
        table.insert(found, problem)
    end

    local foreign = path.join(root, "foreign")
    local project = path.join(foreign, "project")
    os.mkdir(project)
    io.writefile(path.join(project, "xmake.lua"), 'set_project("foreign")\nset_xmakever("3.1.2")\n')
    local configured = os.execv(os.programfile(), {"f", "-P", project, "-p", "iphoneos", "-a", "armv7", "-y", "--require=n"},
        {try = true, stdout = path.join(foreign, "configure.log"), stderr = path.join(foreign, "configure.log"), curdir = project})
    if configured ~= 0 then
        table.insert(found, "a foreign iPhoneOS configuration must be made for the check, but xmake f exited with " .. tostring(configured) .. ": " .. (io.readfile(path.join(foreign, "configure.log")) or ""))
    end

    local isolated = path.join(foreign, "isolated")
    os.mkdir(isolated)
    problem = load(repository, isolated, project, {XMAKE_CONFIGDIR = path.join(isolated, "config")})
    if problem then
        table.insert(found, "with a foreign iPhoneOS configuration beside the checkout: " .. problem)
    end

    local shared = path.join(foreign, "shared")
    os.mkdir(shared)
    io.writefile(path.join(shared, "listing.lua"), LISTING)
    local sharedlog = path.join(shared, "load.log")
    local status = os.execv(os.programfile(), {"l", "-P", repository, path.join(shared, "listing.lua")},
        {try = true, stdout = sharedlog, stderr = sharedlog, curdir = project})
    if status == 0 then
        table.insert(found, "a foreign iPhoneOS configuration must break the load of the project that uses it, or the check of the isolated load proves nothing: " .. (io.readfile(sharedlog) or ""))
    end

    os.tryrm(root)
    return found
end
