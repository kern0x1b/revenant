local PROBE_TEXT = {"libplist", "-fuse-ld", "generic.swift:", "libfoo.a", "AR-NOTFOUND"}

function clean(line)
    local text = line:gsub("\27%[[%d;?]*%a", ""):gsub("\r", "")
    text = text:gsub("^%d+%-%d+%-%d+T%d+:%d+:%d+%.%d+Z ", "")
    return (text:gsub("^%d%d:%d%d:%d%d ", ""))
end

function probe(line)
    if line:find("build/.gens/", 1, true) and line:find("/probes/", 1, true) then
        return true
    end
    for _, text in ipairs(PROBE_TEXT) do
        if line:find(text, 1, true) then
            return true
        end
    end
    return line:find("^curl: %(%d+%) .*error: 404") ~= nil
end

function primary(line)
    if line:find("|", 1, true) or line:find("swiftc failed for", 1, true) then
        return nil
    end
    if line:find("^error: ") or line:find(" error: ", 1, true) then
        return line
    end
    return nil
end

function marker(line)
    return line:match("swiftc failed for (%S+) with: (.*)$")
end

local function add(list, seen, value)
    if not seen[value] then
        seen[value] = true
        table.insert(list, value)
    end
end

function report(text)
    local result = {failed = {}, errors = {}, modules = {}}
    local seen = {failed = {}, errors = {}}
    local pending = {}
    local attributed = {}
    local previous = false
    for line in text:gmatch("[^\n]+") do
        line = clean(line)
        local module, argv = marker(line)
        local probing = probe(line)
        local failed = line:match("^%[%s*%d+%%%]: (%S+) .* failed %d")
        if module then
            local diagnostics = {}
            for i = 1, math.min(3, #pending) do
                diagnostics[i] = pending[i]
                attributed[pending[i]] = true
            end
            table.insert(result.modules, {module = module, argv = argv, diagnostics = diagnostics})
            pending = {}
        elseif failed then
            add(result.failed, seen.failed, failed)
        elseif line:find("^errors: ") then
            add(result.errors, seen.errors, line)
        elseif not probing and not (previous and line:find("linker command failed", 1, true)) then
            local message = primary(line)
            if message then
                add(result.errors, seen.errors, message)
                if message:match("^%S+:%d+:%d+: error: ") then
                    table.insert(pending, message)
                end
            end
        end
        previous = probing
    end
    local errors = {}
    for _, message in ipairs(result.errors) do
        if not attributed[message] then
            table.insert(errors, message)
        end
    end
    result.errors = errors
    return result
end
