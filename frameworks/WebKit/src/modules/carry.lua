local member = path.join(os.scriptdir(), "..", "..")

function manifest()
    return path.join(member, "tests", "data", "carry-manifest.txt")
end

local function directives(file)
    local found = {}
    for line in io.readfile(file):gmatch("[^\n]+") do
        local kind, target, detail = line:match("^(%S+)%s+(%S+)%s*(.-)%s*$")
        if not kind then
            kind = line:match("^(%S+)%s*$")
        end
        if kind and not kind:startswith("#") then
            table.insert(found, {kind = kind, target = target or "", detail = detail or ""})
        end
    end
    return found
end

local function contains(file, text)
    if not os.isfile(file) then
        return false
    end
    for line in io.readfile(file):gmatch("[^\n]*") do
        if line:find(text, 1, true) then
            return true
        end
    end
    return false
end

local function preference_block(file, key)
    if not os.isfile(file) then
        return {}
    end
    local block, inside = {}, false
    for line in (io.readfile(file) .. "\n"):gmatch("([^\n]*)\n") do
        if inside then
            if line == "" then
                break
            end
            table.insert(block, line)
        elseif line == key then
            inside = true
        end
    end
    return block
end

function files_containing(folder, text)
    local listing = os.iorunv("sh", {"-c", "grep -rlIF -e \"$1\" \"$2\"; status=$?; if [ \"$status\" -gt 1 ]; then exit \"$status\"; fi",
                                     "sh", text, folder})
    local found = {}
    for line in listing:gmatch("[^\n]+") do
        table.insert(found, line)
    end
    return found
end

local checks = {}

function checks.file(tree, target)
    if os.isfile(path.join(tree, target)) then
        return true, target
    end
    return false, "missing: " .. target
end

function checks.grep(tree, target, detail)
    if contains(path.join(tree, target), detail) then
        return true, target .. " contains " .. detail
    end
    return false, target .. " no longer contains: " .. detail
end

function checks.pref(tree, target, detail)
    local key, text = detail:match("^(%S+)%s+(.+)$")
    key = key or detail
    text = text or detail
    for _, line in ipairs(preference_block(path.join(tree, target), key .. ":")) do
        if line:find(text, 1, true) then
            return true, target .. " " .. key .. " keeps " .. text
        end
    end
    return false, target .. " " .. key .. " lost: " .. text
end

function checks.set(_, target, detail)
    if contains(path.join(member, target), detail) then
        return true, target .. " keeps " .. detail
    end
    return false, target .. " lost: " .. detail
end

function checks.guard(tree, target, detail)
    local floor = tonumber(detail)
    if not floor or math.floor(floor) ~= floor then
        return false, "the guard floor for " .. target .. " is not a whole number: " .. detail
    end
    local folder = path.join(tree, target)
    local count = os.isdir(folder) and #files_containing(folder, "WEBKIT_IOS6") or 0
    if count >= floor then
        return true, string.format("%s carries the guard in %d files (floor %d)", target, count, floor)
    end
    return false, string.format("%s carries the guard in only %d files, floor is %d", target, count, floor)
end

function paths(file)
    local found = {}
    for _, directive in ipairs(directives(file or manifest())) do
        if checks[directive.kind] and directive.kind ~= "set" and directive.target ~= "" then
            found[directive.target] = true
        end
    end
    return table.orderkeys(found)
end

function check(tree, file, opt)
    opt = opt or {}
    local intact, checked, lines = true, 0, {}
    for _, directive in ipairs(directives(file or manifest())) do
        local run = checks[directive.kind]
        local passed, message
        if run then
            passed, message = run(tree, directive.target, directive.detail)
        else
            passed, message = false, "unknown directive: " .. directive.kind
        end
        table.insert(lines, string.format("%-6s %s", passed and "ok" or "FAIL", message))
        checked = checked + 1
        intact = intact and passed
    end
    if checked == 0 then
        table.insert(lines, (file or manifest()) .. " names nothing to check")
        intact = false
    end
    if opt.print then
        for _, line in ipairs(lines) do
            print(line)
        end
    end
    return intact, lines
end

function verify(tree)
    local intact, lines = check(tree)
    if not intact then
        local failed = {}
        for _, line in ipairs(lines) do
            if line:startswith("FAIL") then
                table.insert(failed, line)
            end
        end
        raise("the patched WebKit no longer holds what this port depends on (carry-manifest.txt):\n  %s", table.concat(failed, "\n  "))
    end
end
