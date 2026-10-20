local USAGE = [[usage: ./xmakew l frameworks/WebKit/tests/device/run.lua [HOST] [--port N]
  loads every device test page in Safari on the phone and prints each verdict.
  HOST is the address the phone reaches this Mac on, this Mac's en0 by default;
  the port is --port, else TEST_PORT, else 8899.]]

local pages = {"text-and-emoji", "gradients-and-blends", "image-draw-cost", "svg-image-filters", "web-platform", "websocket"}

local function escaped(text)
    return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

local function final_pattern(page)
    return "^" .. escaped("GET /verdicts?page=" .. page .. "&results=") .. "[^&]+.*final=1"
end

local function reported_pattern(page)
    return escaped("GET /verdicts?page=" .. page)
end

local function warm_pattern(token)
    return escaped("GET /warm-up-state?bridge=yes&token=" .. token)
end

local function ensure_bridge(harness, phone, server, base, state)
    for attempt = 1, 3 do
        state.token = state.token + 1
        phone:open_url(base .. "/warmup.html?token=" .. state.token)
        if server:wait_for(warm_pattern(state.token), 8, 2) then
            return true
        end
        io.stderr:print("the tweak is not in this Safari; restarting it (attempt %d)", attempt)
        phone:restart_safari(12)
    end
    io.stderr:print("giving up on the tweak; the bridges it installs will read as missing")
    return false
end

function main(...)
    local harness = import("harness", {rootdir = os.scriptdir(), anonymous = true})
    local verdicts = import("verdicts", {rootdir = os.scriptdir(), anonymous = true})
    local tree = import("tree", {rootdir = path.join(os.scriptdir(), "..", "..", "tools", "lib"), anonymous = true})
    local given, rest = tree.arguments({...}, {port = "value", help = "switch"})
    if given.help then
        print(USAGE)
        return
    end
    local host = rest[1] or harness.host_address()
    local port = tonumber(given.port) or harness.port(8899)
    local base = "http://" .. host .. ":" .. port
    local phone = harness.phone()
    local problems, passed = {}, false
    harness.with_server(port, {}, function (server)
        os.sleep(1000)
        phone:restart_safari(12)
        local state = {token = 0}
        for _, page in ipairs(pages) do
            ensure_bridge(harness, phone, server, base, state)
            phone:open_url(base .. "/" .. page .. ".html?run=" .. harness.run_token())
            server:wait_for(final_pattern(page), 22, 2)
        end
        for _, page in ipairs(pages) do
            if not server:seen(reported_pattern(page)) then
                table.insert(problems, "MISSING " .. page .. " reported nothing")
            elseif not server:seen(final_pattern(page)) then
                table.insert(problems, "PARTIAL " .. page .. " stopped before its end - the verdicts below are what it reached")
            end
        end
        for _, line in ipairs(problems) do
            print(line)
        end
        local feed = {}
        for _, target in ipairs(server:matching("/verdicts?")) do
            table.insert(feed, "GET " .. target)
        end
        passed = verdicts.count(feed)
    end)
    if #problems > 0 or not passed then
        raise("the device gate failed")
    end
end
