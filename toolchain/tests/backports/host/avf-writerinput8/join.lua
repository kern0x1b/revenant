local ALLOWANCES = {
    ["switch-on unattached: canPerformMultiplePasses unattached after setting the switch"] =
        "the switch is stored and reads back; the writer cannot re-read its source on the release this port "
        .. "runs on, so canPerformMultiplePasses is NO. Measured: Apple's own class answers YES from the switch "
        .. "alone, before anything is attached",
    ["switch-on before startWriting: canPerformMultiplePasses attached before startWriting"] =
        "follows the switch: NO here, for the reason on the row above",
    ["switch-on: canPerformMultiplePasses after startWriting"] = "follows the switch",
    ["switch-on: canPerformMultiplePasses after setting the switch post-start"] = "follows the switch",
    ["switch-on: canPerformMultiplePasses after markCurrentPassAsFinished"] = "follows the switch",
    ["switch-on: currentPassDescription after markCurrentPassAsFinished"] =
        "Apple nominates a SECOND pass here - the description is still live and the block ran once, not twice. "
        .. "This port has no analysis pass to hand out, and AVAssetWriterInput.h:512 says that with "
        .. "canPerformMultiplePasses NO the description becomes nil at once",
    ["switch-on: block calls after markCurrentPassAsFinished"] =
        "follows the row above: two invocations here, one where Apple starts a second pass",
    ["switch-on: block on the given queue after markCurrentPassAsFinished"] =
        "follows the row above; both halves deliver every invocation on the queue the client gave",
    ["switch-on: block calls after a second markCurrentPassAsFinished"] =
        "Apple is between passes there and refuses a second -markCurrentPassAsFinished because a pass is "
        .. "pending, so its one invocation stands; this port has no pending pass",
    ["switch-on: block saw"] =
        "follows the second-pass rows: the port's block sees the first pass and then nil, which is the whole "
        .. "of what a single-pass writer has to offer",
    ["switch-on: markCurrentPassAsFinished a second time"] =
        "the HOST's own answer here is not reproducible: six runs of the oracle gave RAISED five times and "
        .. "ACCEPTED once, because with the switch on Apple's analysis pass may already have finished by the time "
        .. "the second call arrives. The port refuses in both configurations, which is what the host did in five "
        .. "of six runs and in every switch-off run",
    ["switch-off: block calls on registration"] =
        "the host delivers the first invocation from its own setup, after the call has returned; this port "
        .. "queues it, so it is delivered before the queue drains",
    ["switch-off: block on the given queue on registration"] = "follows the row above",
    ["switch-on: block calls on registration"] = "follows the registration rows above",
    ["switch-on: block on the given queue on registration"] = "follows the registration rows above",
    ["switch-off before startWriting: markAsFinished before startWriting"] =
        "the release's -markAsFinished refuses before -startWriting (measured: NSInternalInconsistencyException, "
        .. "'Cannot call method when status is 0'); the stand-in records it instead. Nothing in this family calls "
        .. "it in that state - the port raises from -markCurrentPassAsFinished first",
    ["switch-on before startWriting: markAsFinished before startWriting"] = "follows the row above",
    ["switch-off: finishWriting"] =
        "the real writer refuses to finish a file nothing was appended to (measured NO); the stand-in has no "
        .. "encoder and answers YES. The harness appends nothing in either half",
    ["switch-on: finishWriting"] = "follows the row above",
}

local BUILD_ROWS = {
    ["CONTROL: CLASS AVAssetWriterInputPassDescription"] =
        "the stand-in declares the class and does not implement it; the port brings it",
    ["CONFIGURATION: h264 16x16, no bitrate"] = "each half asks its own writer what it can encode",
}

local function file_lines(text)
    local out, at = {}, 1
    while at <= #text do
        local stop = text:find("\n", at, true)
        if stop then
            table.insert(out, text:sub(at, stop - 1))
            at = stop + 1
        else
            table.insert(out, text:sub(at))
            break
        end
    end
    return out
end

local function load(file, lenient, report)
    local rows = {}
    if not os.isfile(file) then
        if lenient then
            return rows
        end
        raise(string.format("join.lua: %s is not there", file))
    end
    for _, line in ipairs(file_lines(io.readfile(file, {encoding = "binary"}))) do
        if line:trim() ~= "" then
            local stripped = line:gsub("\n$", "")
            local first, last = stripped:find(" | ", 1, true)
            if first == nil then
                if report then
                    print("MALFORMED         the host or the port printed a line with no ' | ' in it: " .. line:trim())
                else
                    rows[stripped:trim()] = ""
                end
            else
                rows[stripped:sub(1, first - 1):trim()] = stripped:sub(last + 1):trim()
            end
        end
    end
    return rows
end

local function sorted_keys(a, b)
    local seen, out = {}, {}
    for key in pairs(a) do
        seen[key] = true
    end
    for key in pairs(b) do
        seen[key] = true
    end
    for key in pairs(seen) do
        table.insert(out, key)
    end
    table.sort(out)
    return out
end

local function show(value)
    if value == nil then
        return "None"
    end
    return value
end

local function join(build, oracle_dir)
    local host = load(path.join(build, "host.table"), true, true)
    local port = load(path.join(build, "port.table"), true, true)
    local base = load(path.join(oracle_dir, "port.baseline"), true, true)
    local less, more, differs = 0, 0, 0
    local unexplained = {}
    for _, key in ipairs(sorted_keys(host, port)) do
        if BUILD_ROWS[key] ~= nil then
            print(string.format("BUILD             %-74s %s", key, BUILD_ROWS[key]))
        elseif port[key] == nil then
            print("ANSWERS LESS      " .. key)
            less = less + 1
        elseif host[key] == nil then
            print("HOST LACKS IT     " .. key)
            more = more + 1
        elseif host[key] ~= port[key] then
            differs = differs + 1
            if ALLOWANCES[key] ~= nil then
                print(string.format("ALLOWED           %-74s host=[%s] port=[%s]", key, host[key], port[key]))
            else
                print(string.format("UNEXPLAINED       %-74s host=[%s] port=[%s]", key, host[key], port[key]))
                table.insert(unexplained, key)
            end
        end
    end
    print(string.format("SUMMARY rows: host=%d port=%d  must-match-unequal=%d answers-less=%d host-lacks=%d unexplained=%d",
        #sorted_keys(host, {}), #sorted_keys(port, {}), differs, less, more, #unexplained))
    if less > 0 or more > 0 or #unexplained > 0 then
        os.exit(1)
    end
end

local function direction(build, oracle_dir)
    local base = load(path.join(oracle_dir, "port.baseline"), false, false)
    local port = load(path.join(build, "port.table"), false, false)
    local host = load(path.join(build, "host.table"), false, false)
    local changed, right_then_wrong, closer = {}, {}, {}
    for _, key in ipairs(sorted_keys(base, port)) do
        if base[key] ~= port[key] then
            table.insert(changed, key)
            if host[key] ~= nil and base[key] == host[key] and port[key] ~= host[key] then
                table.insert(right_then_wrong, key)
            elseif host[key] ~= nil and base[key] ~= host[key] and port[key] == host[key] then
                table.insert(closer, key)
            end
        end
    end
    for _, key in ipairs(right_then_wrong) do
        print("BROKE A RIGHT ONE  " .. key)
    end
    for _, key in ipairs(closer) do
        print("MOVED TOWARD HOST  " .. key)
    end
    for _, key in ipairs(changed) do
        print(string.format("CHANGED           %-74s before=[%s] after=[%s]", key, show(base[key]), show(port[key])))
    end
    print(string.format("DIRECTIONALITY changed=%d right-then-wrong=%d moved-toward-host=%d",
        #changed, #right_then_wrong, #closer))
    if not (#changed > 0 and #right_then_wrong > 0) then
        os.exit(1)
    end
end

function main(command, build, oracle_dir)
    if command == "join" then
        join(build, oracle_dir)
    elseif command == "direction" then
        direction(build, oracle_dir)
    else
        raise("join.lua: join or direction, not " .. tostring(command))
    end
end
