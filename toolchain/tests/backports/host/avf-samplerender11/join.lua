local json = import("core.base.json")

local ALLOWANCES = {
    ["renderer: status after the first enqueue"] = {"2",
        "there is no audio device on this machine (CoreAudio answers 'who?' for kAudioHardwarePropertyDevices), so "
        .. "the queue the port made has no device clock and -AudioQueueGetCurrentTime answers -66678 with no valid "
        .. "time in it; a renderer that cannot place a buffer at its timestamp answers Failed with an "
        .. "AVFoundationErrorDomain error, where Apple's own renderer keeps answering Rendering for media it has "
        .. "accepted and can never play. Measured in packages/frameworks/apple-backports/facts/AVFoundation/SampleBufferRender11.md"},
    ["renderer: error after the first enqueue is nil"] = {"NO",
        "follows the row above, and the port names the queue's own OSStatus in the description"},
    ["renderer: status after nine enqueues"] = {"2", "follows the first-enqueue row"},
    ["renderer: error after nine enqueues is nil"] = {"NO", "follows the first-enqueue row"},
    ["renderer: status after a buffer with no frames"] = {"2", "follows the first-enqueue row"},
    ["absent: the renderer answers respondsToSelector: for allowedAudioSpatializationFormats"] = {"NO",
        "the property is 15.0 and the row answers absent; clang synthesises an ivar and both accessors from the "
        .. "SDK's @interface unless @dynamic says not to, and @dynamic is what makes respondsToSelector: answer NO, "
        .. "which is the truth. Measured on the object at -target armv7-apple-ios6.0 and armv7-apple-ios4.3."},
    ["absent: the renderer answers respondsToSelector: for audioOutputDeviceUniqueID"] = {"NO",
        "the header declares it API_UNAVAILABLE(ios), so there is no iOS row and the port carries nothing; "
        .. "@dynamic stops clang synthesising the accessors the @interface would otherwise get it. Apple's own "
        .. "class answers YES."},
    ["absent: the renderer answers respondsToSelector: for hasSufficientMediaDataForReliablePlaybackStart"] = {"NO",
        "the protocol property at 14.5 needs no @dynamic: a property a protocol declares is not auto-synthesised "
        .. "(measured: no accessor of that name in any of the four objects, and "
        .. "-Wobjc-protocol-property-synthesis says so at compile time). Apple's own class answers YES."},
    ["absent: the synchronizer answers respondsToSelector: for delaysRateChangeUntilHasSufficientMediaData"] = {"NO",
        "the property is 14.5 and the row answers absent, because the preroll level it asks about is not "
        .. "measurable on this machine; @dynamic is what makes respondsToSelector: answer NO. Apple's own class "
        .. "answers YES."},
    ["attached: the renderer's clock reads the synchronizer's clock as its master"] = {"YES",
        "the port slaves the renderer's own CMTimebase to the synchronizer's, which is what the header's \"Adds a "
        .. "renderer to begin operating with the synchronizer's timebase\" asks for; this Mac's own renderer "
        .. "answers nil from CMTimebaseGetMasterTimebase for both clocks and keeps them in step by propagating the "
        .. "rate instead, which is what its private -_updateRateFromTimebase is for (measured over both classes' "
        .. "method lists). The two clocks read the same time either way, which is the row beside it"},
}

local BUILD_ROWS = {
    ["CONTROL: AVSampleBufferRenderSynchronizer exists"] = "each half answers for its own build",
    ["CONTROL: AVSampleBufferAudioRenderer exists"] = "each half answers for its own build",
    ["CONTROL: the AVQueuedSampleBufferRendering protocol exists"] =
        "the host carries Apple's own protocol object; the port's comes from the source "
        .. "modules/apple/backports.lua writes for an implemented protocol row",
    ["CONTROL: the renderer answers the protocol's own -timebase"] = "each half answers for its own build",
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
            local first, last = line:find(" | ", 1, true)
            if first == nil then
                if report then
                    print("MALFORMED         the host or the port printed a line with no ' | ' in it: " .. line:trim())
                else
                    rows[line:trim()] = ""
                end
            else
                rows[line:sub(1, first - 1):trim()] = line:sub(last + 1):trim()
            end
        end
    end
    return rows
end

local function sorted_union(a, b)
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
    local required = {}
    for key, pair in pairs(ALLOWANCES) do
        required[key] = pair[1]
    end
    for key, value in pairs(host) do
        if required[key] == nil then
            required[key] = value
        end
    end
    io.writefile(path.join(build, "required.json"), json.encode(required), {encoding = "binary"})
    local less, more, unexplained = 0, 0, 0
    local differing = {}
    for _, key in ipairs(sorted_union(host, port)) do
        if BUILD_ROWS[key] ~= nil then
            print(string.format("BUILD             %-74s %s", key, BUILD_ROWS[key]))
        elseif port[key] == nil then
            print("ANSWERS LESS      " .. key)
            less = less + 1
        elseif host[key] == nil then
            print("HOST LACKS IT     " .. key)
            more = more + 1
        else
            local want = required[key]
            if want ~= nil and port[key] ~= want then
                if ALLOWANCES[key] ~= nil then
                    print(string.format("WRONG ALLOWED     %-74s the port was required to answer [%s] and answers [%s] (the host answers [%s])",
                        key, want, port[key], host[key]))
                else
                    print(string.format("UNEXPLAINED       %-74s host=[%s] port=[%s]", key, host[key], port[key]))
                end
                unexplained = unexplained + 1
            elseif host[key] ~= port[key] then
                print(string.format("ALLOWED           %-74s host=[%s] port=[%s]", key, host[key], port[key]))
                table.insert(differing, key)
            end
        end
    end
    print(string.format("SUMMARY rows: host=%d port=%d  allowed-differences=%d answers-less=%d host-lacks=%d unexplained=%d",
        #sorted_union(host, {}), #sorted_union(port, {}), #differing, less, more, unexplained))
    if less > 0 or more > 0 or unexplained > 0 then
        os.exit(1)
    end
end

local function direction(build, oracle_dir)
    local base = load(path.join(oracle_dir, "port.baseline"), false, false)
    local port = load(path.join(build, "port.table"), false, false)
    local host = load(path.join(build, "host.table"), false, false)
    local required = json.decode(io.readfile(path.join(build, "required.json"), {encoding = "binary"}))
    local changed, broke_required, closer = {}, {}, {}
    for _, key in ipairs(sorted_union(base, port)) do
        if base[key] ~= port[key] then
            table.insert(changed, key)
            if required[key] ~= nil and base[key] == required[key] and port[key] ~= required[key] then
                table.insert(broke_required, key)
            elseif host[key] ~= nil and base[key] ~= host[key] and port[key] == host[key] then
                table.insert(closer, key)
            end
        end
    end
    for _, key in ipairs(broke_required) do
        print("BROKE A REQUIRED ONE  " .. key)
    end
    for _, key in ipairs(closer) do
        print("MOVED TOWARD HOST     " .. key)
    end
    for _, key in ipairs(changed) do
        print(string.format("CHANGED           %-74s before=[%s] after=[%s]", key, show(base[key]), show(port[key])))
    end
    print(string.format("DIRECTIONALITY changed=%d broke-a-required-answer=%d moved-toward-host=%d",
        #changed, #broke_required, #closer))
    if not (#changed > 0 and #broke_required > 0) then
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
