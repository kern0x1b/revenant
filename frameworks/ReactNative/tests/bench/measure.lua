local USAGE = [[usage: ./xmakew l -P . frameworks/ReactNative/tests/bench/measure.lua run ENGINE RUN BUNDLE [WAIT]
       ./xmakew l -P . frameworks/ReactNative/tests/bench/measure.lua summarize RUNFOLDER...
  run relaunches the React Native bench on the claimed phone with ENGINE (hermes or jsc) and BUNDLE (a path on the phone), makes
  five taps on the counter and one swipe on the list, and writes the screenshot, the host log and the answers of the touch
  injector to .cache/scratch/rn-bench/runs/ENGINE-RUN. WAIT is the seconds the bench gets to mount (default 40, use 60 for jsc).
  summarize prints the startup, the tap-to-commit latency, the fps and the RSS of each run folder.]]

local BUNDLE_ID = "org.revenant.rnhost.hermes"
local SHOT = "/usr/libexec/revenant-shot"
local COUNTER = {120, 110}
local SWIPE = {160, 420, 160, 150, 600}

local function injected(command)
    return "rm -f /var/tmp/rnhost.cmd.out; touch /var/tmp/rnhost.cmd; chmod 666 /var/tmp/rnhost.cmd; echo '" .. command .. "' > /var/tmp/rnhost.cmd"
end

local function sent(device, settings, command, answers)
    device.run(settings, injected(command))
    os.sleep(1000)
    local answer = os.tmpfile()
    if device.fetch(settings, "/var/tmp/rnhost.cmd.out", answer) then
        table.insert(answers, (io.readfile(answer):trim()))
        os.tryrm(answer)
    else
        table.insert(answers, "no answer to " .. command)
    end
    os.sleep(1000)
end

local function measure(engine, number, bundle, wait)
    local device = import("@addon.revenant.device", {anonymous = true})
    local settings = device.bind(os.curdir())
    local folder = path.join(os.curdir(), ".cache", "scratch", "rn-bench", "runs", engine .. "-" .. number)
    os.mkdir(folder)
    device.run(settings, string.format("printf 'engine=%s\\nbundle=%s\\nmodule=bench\\n' > /var/tmp/rnhost.conf; killall RNHost 2>/dev/null; sleep 3; rm -f /var/tmp/rnhost.log; /usr/libexec/revenant-sblaunch %s; sleep %d", engine, bundle, BUNDLE_ID, wait))
    local answers = {}
    for _ = 1, 5 do
        sent(device, settings, string.format("tap %d %d", COUNTER[1], COUNTER[2]), answers)
        os.sleep(1000)
    end
    sent(device, settings, string.format("swipe %d %d %d %d %d", SWIPE[1], SWIPE[2], SWIPE[3], SWIPE[4], SWIPE[5]), answers)
    os.sleep(6000)
    device.run(settings, SHOT .. " /tmp/screenshot.png")
    device.fetch(settings, "/tmp/screenshot.png", path.join(folder, "screen.png"))
    device.fetch(settings, "/var/tmp/rnhost.log", path.join(folder, "host.log"))
    io.writefile(path.join(folder, "touch.txt"), table.concat(answers, "\n") .. "\n")
    print(folder)
end

local function clock(line)
    local hours, minutes, seconds = line:match(" (%d%d):(%d%d):([%d%.]+) RNHost")
    if not hours then
        return nil
    end
    return tonumber(hours) * 3600 + tonumber(minutes) * 60 + tonumber(seconds)
end

local function first(lines, text)
    for _, line in ipairs(lines) do
        if line:find(text, 1, true) then
            return line
        end
    end
end

local function median(values)
    table.sort(values)
    local count = #values
    if count == 0 then
        return nil
    end
    if count % 2 == 1 then
        return values[(count + 1) / 2]
    end
    return (values[count / 2] + values[count / 2 + 1]) / 2
end

local function summarize(folder)
    local lines = io.readfile(path.join(folder, "host.log")):split("\n")
    local start = clock(first(lines, "react start module") or "")
    local mounted = clock(first(lines, "bench mounted") or "")
    local startup = start and mounted and string.format("%.2f", mounted - start) or "n/a"
    local touches, latencies, fps, rss = {}, {}, {}, {}
    for _, line in ipairs(lines) do
        local began = line:match("touch began (%d+)")
        if began then
            touches[#touches + 1] = tonumber(began)
        end
        local _, commit = line:match("bench commit (%d+) (%d+)")
        if commit then
            local last = touches[#touches]
            if last then
                table.insert(latencies, tonumber(commit) - last)
            end
        end
        local frames = line:match("bench fps (%d+)")
        if frames then
            table.insert(fps, tonumber(frames))
        end
        local megabytes = line:match("heartbeat rss ([%d%.]+) MB")
        if megabytes then
            table.insert(rss, tonumber(megabytes))
        end
    end
    local total, lowest = 0, nil
    for _, frames in ipairs(fps) do
        total = total + frames
        lowest = lowest and math.min(lowest, frames) or frames
    end
    local highest = nil
    for _, megabytes in ipairs(rss) do
        highest = highest and math.max(highest, megabytes) or megabytes
    end
    print(string.format("%s startup_s=%s latency_ms=[%s] median_ms=%s fps_mean_min=%s %s rss_max_mb=%s",
        path.filename(folder), startup, table.concat(latencies, " "), tostring(median(latencies) or "n/a"),
        #fps > 0 and string.format("%.1f", total / #fps) or "n/a", tostring(lowest or "n/a"), tostring(highest or "n/a")))
end

function main(...)
    local arguments = {...}
    if arguments[1] == "run" and #arguments >= 4 then
        measure(arguments[2], arguments[3], arguments[4], tonumber(arguments[5] or "40"))
    elseif arguments[1] == "summarize" and #arguments >= 2 then
        for index = 2, #arguments do
            summarize(arguments[index])
        end
    else
        print(USAGE)
    end
end
