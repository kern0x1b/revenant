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

function failures(opt)
    local found = {}
    local repository = path.absolute(path.join(os.scriptdir(), "../../.."))
    local root = fixtures.scratch()
    local listing = path.join(root, "listing.lua")
    io.writefile(listing, LISTING)
    local log = path.join(root, "load.log")
    local status = os.execv(os.programfile(), {"l", "-P", repository, listing}, {try = true, stdout = log, stderr = log, curdir = repository})
    local text = io.readfile(log)
    if status ~= 0 then
        table.insert(found, "the project must load all of its targets on a host with no iPhoneOS SDK, but xmake l exited with " .. tostring(status) .. ": " .. text)
    elseif not text:find("TARGETS %d+") then
        table.insert(found, "the listing printed no target count, so the project did not load its targets: " .. text)
    end
    os.tryrm(root)
    return found
end
