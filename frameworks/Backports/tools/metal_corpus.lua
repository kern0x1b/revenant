local toolchain = import("metal_toolchain", {rootdir = os.scriptdir()})

TARGET = "air64-apple-ios12.0"

function compile(metal, source, air)
    local failure
    try {
        function () os.vrunv(metal, {"-c", "-target", TARGET, "-ffast-math", source, "-o", air}) end,
        catch {
            function (errors)
                failure = errors or "compile failed"
            end
        }
    }
    return failure
end

function metallib(tool, airs, output)
    local arguments = {}
    for _, air in ipairs(airs) do
        table.insert(arguments, air)
    end
    table.insert(arguments, "-o")
    table.insert(arguments, output)
    os.vrunv(tool, arguments)
end

function groups(root)
    local byDirectory, order = {}, {}
    for _, pattern in ipairs({"submodules/**.metal", "build-system/**.metal"}) do
        for _, file in ipairs(os.files(path.join(root, pattern))) do
            if not file:find("/ffmpeg/", 1, true) and not file:find("/rules_apple/test/", 1, true) then
                local directory = path.directory(file)
                if not byDirectory[directory] then
                    byDirectory[directory] = {}
                    table.insert(order, directory)
                end
                table.insert(byDirectory[directory], file)
            end
        end
    end
    table.sort(order)
    return order, byDirectory
end

function verdicts(translation, stages, library)
    local rows = {}
    for line in translation:gmatch("[^\n]+") do
        local name, stage = line:match("^[^:]+: OK (%S+) (%S+)$")
        if name then
            table.insert(rows, {library = library, name = name, stage = stage, verdict = "OK", reason = ""})
        else
            local refused, reason = line:match("^[^:]+: REFUSED (%S+): (.*)$")
            if refused then
                table.insert(rows, {library = library, name = refused, stage = stages[refused] or "", verdict = "REFUSED", reason = reason})
            end
        end
    end
    return rows
end

function main(dmg, air2es, root, output, mountpoint)
    local bin = toolchain.mount(dmg, mountpoint)
    local metal = path.join(bin, "metal")
    local linker = path.join(bin, "metallib")
    local work = path.join(os.tmpdir(), "revenant-metal-corpus")
    os.rm(work)
    os.mkdir(work)
    local order, byDirectory = groups(root)
    local rows, failures = {}, {}
    for _, directory in ipairs(order) do
        local library = directory:sub(#root + 2):gsub("/", "_")
        local airs = {}
        for _, file in ipairs(byDirectory[directory]) do
            local air = path.join(work, library .. "_" .. path.basename(file) .. ".air")
            local failure = compile(metal, file, air)
            if failure then
                table.insert(failures, path.relative(file, root) .. ": " .. tostring(failure):sub(1, 200))
            else
                table.insert(airs, air)
            end
        end
        if #airs > 0 then
            local lib = path.join(work, library .. ".metallib")
            metallib(linker, airs, lib)
            local listing = os.iorunv(air2es, {"--list", lib})
            local stages = {}
            for name, stage in listing:gmatch("%d+ (%S+) (%S+) offset=") do
                stages[name] = stage
            end
            local command = string.format("'%s' '%s' '%s' 2>&1; exit 0", air2es, lib, path.join(work, library .. ".es2"))
            local translation = os.iorunv("/bin/sh", {"-c", command})
            for _, row in ipairs(verdicts(translation, stages, library)) do
                table.insert(rows, row)
            end
        end
    end
    local lines = {"library\tname\tstage\tverdict\treason"}
    for _, row in ipairs(rows) do
        table.insert(lines, table.concat({row.library, row.name, row.stage, row.verdict, row.reason}, "\t"))
    end
    io.writefile(output, table.concat(lines, "\n") .. "\n")
    local counts = {}
    for _, row in ipairs(rows) do
        counts[row.verdict] = (counts[row.verdict] or 0) + 1
    end
    print(string.format("metal-corpus: %d entry points, %d OK, %d REFUSED, %d source files did not compile; verdicts in %s",
                        #rows, counts.OK or 0, counts.REFUSED or 0, #failures, output))
    for _, failure in ipairs(failures) do
        print("metal-corpus: did not compile: " .. failure)
    end
end
