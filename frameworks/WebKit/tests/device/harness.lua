import("core.base.bytes")
import("core.base.scheduler")
import("core.base.socket")

local tests = path.normalize(path.absolute(os.scriptdir()))
local member = path.normalize(path.join(tests, "..", ".."))
local revenant = path.normalize(path.join(member, "..", ".."))

local types = {html = "text/html; charset=utf-8", js = "application/javascript", css = "text/css", jpg = "image/jpeg",
               jpeg = "image/jpeg", png = "image/png", svg = "image/svg+xml", json = "application/json", txt = "text/plain"}

function folder()
    return tests
end

function shots()
    return import("workspace", {rootdir = path.join(revenant, "toolchain", "modules"), anonymous = true}).run("webkit-shots")
end

function run_token()
    return math.random(0, 32767)
end

function host_address()
    local found = try { function () return os.iorunv("ipconfig", {"getifaddr", "en0"}) end }
    if found and found:trim() ~= "" then
        return found:trim()
    end
    return "127.0.0.1"
end

local function unquote(text)
    return (text:gsub("+", " "):gsub("%%(%x%x)", function (hex) return string.char(tonumber(hex, 16)) end))
end

local function object(methods, fields)
    for name, method in pairs(methods) do
        fields[name] = method
    end
    return fields
end

local server_methods = {}

local function respond(client, status, kind, body)
    local head = string.format("HTTP/1.0 %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n",
                               status, kind, #body)
    client:send(head .. body, {block = true})
end

function server_methods:_session(client)
    local buffer = bytes(8192)
    local received = ""
    while not received:find("\r\n\r\n", 1, true) and #received < 65536 do
        local count, data = client:recv(buffer, 8192)
        if count > 0 then
            received = received .. data:str()
        elseif count == 0 then
            if client:wait(socket.EV_RECV, 10000) ~= socket.EV_RECV then
                break
            end
        else
            break
        end
    end
    local method, target = received:match("^(%u+) (%S+) HTTP/")
    if method then
        table.insert(self.requests, method .. " " .. target)
        local file = target:match("^([^?#]*)")
        file = unquote(file):gsub("^/+", "")
        local resolved = path.join(self.root, file == "" and "index.html" or file)
        local inside = path.normalize(resolved):startswith(path.normalize(self.root) .. "/")
        if method == "GET" and inside and os.isfile(resolved) then
            respond(client, "200 OK", types[path.extension(resolved):sub(2):lower()] or "application/octet-stream",
                    io.readfile(resolved, {encoding = "binary"}))
        else
            respond(client, "404 Not Found", "text/plain", "not here\n")
        end
    end
    client:close()
end

function server_methods:_serve()
    while not self.stopped do
        local client = self.socket:accept({timeout = 500})
        if client then
            scheduler.co_start(function ()
                self:_session(client)
            end)
        end
    end
    self.socket:close()
end

function server_methods:stop()
    self.stopped = true
end

function server_methods:lines()
    return table.copy(self.requests)
end

function server_methods:seen(pattern)
    for _, line in ipairs(self.requests) do
        if line:find(pattern) then
            return true
        end
    end
    return false
end

function server_methods:wait_for(pattern, attempts, interval)
    for _ = 1, attempts do
        os.sleep(interval * 1000)
        if self:seen(pattern) then
            return true
        end
    end
    return false
end

function server_methods:matching(prefix)
    local found = {}
    for _, line in ipairs(self.requests) do
        local target = line:match("^%S+ (.*)$")
        if target and target:startswith(prefix) then
            table.insert(found, target)
        end
    end
    return found
end

function server_methods:reports()
    local found = {}
    for _, target in ipairs(self:matching("/report?")) do
        local query = target:sub(#"/report?" + 1)
        table.insert(found, unquote((query:split("&r=", {plain = true, limit = 2})[1]) or ""))
    end
    return found
end

function server_methods:last_report()
    local found = self:reports()
    return found[#found] or ""
end

function serve(port, opt)
    opt = opt or {}
    local listening, errors = socket.bind(opt.bind or "0.0.0.0", port)
    if not listening then
        raise("port %d is already serving something else (%s); set TEST_PORT", port, tostring(errors))
    end
    listening:listen(64)
    local instance = object(server_methods, {socket = listening, root = opt.folder or tests, requests = {}, stopped = false})
    scheduler.co_start(function ()
        instance:_serve()
    end)
    return instance
end

function with_server(port, opt, body)
    local instance = serve(port, opt)
    local ok, errors = true, nil
    local result
    scheduler.co_group_begin("webkit-device-test", function ()
        scheduler.co_start(function ()
            result = try {
                function ()
                    return body(instance)
                end,
                catch {
                    function (raised)
                        ok, errors = false, raised
                    end
                }
            }
        end)
    end)
    scheduler.co_group_wait("webkit-device-test")
    instance:stop()
    if not ok then
        raise(errors)
    end
    return result
end

local phone_methods = {}

function phone()
    local device = import("@addon.revenant.device", {anonymous = true})
    local settings = device.bind(revenant)
    return object(phone_methods, {device = device, settings = settings})
end

function phone_methods:run(command)
    return self.device.run(self.settings, command, {capture = true}) or ""
end

function phone_methods:reachable()
    local answer = try { function () return self:run("echo ok") end }
    return answer ~= nil and answer:find("ok", 1, true) ~= nil
end

function phone_methods:restart_safari(settle)
    self:run("killall MobileSafari 2>/dev/null; true")
    os.sleep(settle * 1000)
end

function phone_methods:open_url(url)
    self:run("uiopen '" .. url .. "'")
end

function phone_methods:copy(localfile, remote)
    self.device.copy(self.settings, localfile, remote)
end

function phone_methods:fetch(remote, localfile)
    return self.device.fetch(self.settings, remote, localfile)
end

function phone_methods:reverse_tunnel(port)
    return self.device.reverse_tunnel(self.settings, port)
end

function phone_methods:screenshot(name)
    local target = path.join(shots(), name)
    self:run("shot")
    self:fetch("/tmp/screenshot.png", target)
    return target
end

local page_area = {left = 0, top = 150, right = 640, bottom = 880}
local tolerance = 40

local function share(matched, total, empty)
    local percent = total > 0 and math.floor(matched * 100 / total) or 0
    return percent < 1 and empty or (percent .. "%")
end

function painted(shot, colour)
    if not os.isfile(shot) then
        return "no shot"
    end
    local converted = shot .. ".bmp"
    local ok = try { function ()
        os.runv("sips", {"-s", "format", "bmp", shot, "--out", converted})
        return true
    end }
    if not ok or not os.isfile(converted) then
        return "no shot"
    end
    local data = io.readfile(converted, {encoding = "binary"})
    os.tryrm(converted)
    local offset = string.unpack("<I4", data, 11)
    local width, height, _, depth = string.unpack("<i4i4I2I2", data, 19)
    local step = depth // 8
    if step < 3 then
        return "no shot"
    end
    local stride = ((width * step + 3) // 4) * 4
    local top_down = height < 0
    height = math.abs(height)
    local wanted
    if colour then
        local r, g, b = colour:match("^(%d+),(%d+),(%d+)$")
        wanted = {tonumber(r), tonumber(g), tonumber(b)}
    end
    local matched, total = 0, 0
    for y = page_area.top, math.min(page_area.bottom, height) - 1 do
        local row = top_down and y or (height - 1 - y)
        for x = page_area.left, math.min(page_area.right, width) - 1 do
            local at = offset + row * stride + x * step + 1
            local b, g, r = data:byte(at, at + 2)
            total = total + 1
            if wanted then
                if math.abs(r - wanted[1]) < tolerance and math.abs(g - wanted[2]) < tolerance and math.abs(b - wanted[3]) < tolerance then
                    matched = matched + 1
                end
            elseif (r * 299 + g * 587 + b * 114) // 1000 < 200 then
                matched = matched + 1
            end
        end
    end
    return share(matched, total, wanted and "absent" or "blank")
end

function port(default)
    return tonumber(os.getenv("TEST_PORT") or default)
end
