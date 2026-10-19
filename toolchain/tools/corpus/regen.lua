local workspace = import("workspace", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})

local SIX_MONTHS = 182 * 86400

local function stamp(file)
    local mtime = os.mtime(file)
    local now = os.time()
    local day = tostring(tonumber(os.date("%d", mtime)))
    if mtime + SIX_MONTHS > now and mtime < now + SIX_MONTHS then
        return os.date("%b ", mtime) .. day .. os.date(" %H:%M", mtime)
    end
    return os.date("%b ", mtime) .. day .. os.date(" %Y", mtime)
end

local function line_count(file)
    local count = 0
    for _ in io.readfile(file):gmatch("\n") do
        count = count + 1
    end
    return count
end

function main(label)
    local tools = os.scriptdir()
    local corpus = workspace.corpus()
    local export = os.getenv("CHARON_REGISTRY_TSV") or path.join(workspace.run("registry-export"), "carried-registry.tsv")
    if not os.isfile(export) then
        raise("regen.lua: no registry export at %s; write it with export-registry.lua or set CHARON_REGISTRY_TSV", export)
    end
    print(string.format("registry export: %s  rows: %8d", stamp(export), line_count(export)))
    os.cp(path.join(corpus, "crash-demand-top.tsv"), path.join(corpus, "crash-demand-prev.tsv"))
    local ranked, complaints = os.iorunv(os.programfile(), {"l", path.join(tools, "crash-demand.lua")})
    if complaints and complaints ~= "" then
        io.stderr:write(complaints)
    end
    local shown = 0
    if ranked ~= "" and ranked:sub(-1) ~= "\n" then
        ranked = ranked .. "\n"
    end
    for line in ranked:gmatch("([^\n]*)\n") do
        if shown == 3 then
            break
        end
        print(line)
        shown = shown + 1
    end
    os.execv(os.programfile(), {"l", path.join(tools, "hint-track.lua"), label or os.date("%Y-%m-%d")})
    os.cp(export, path.join(corpus, "registry-last.tsv"))
end
