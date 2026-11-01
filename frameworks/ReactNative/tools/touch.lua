local USAGE = [[usage: ./xmakew l frameworks/ReactNative/tools/touch.lua [--before FILE] [--after FILE] [--wait SECONDS] VERB ARGUMENT...
  sends one command to the touch injector of a running React Native host on the claimed phone and prints its result.
  VERB is tap X Y | swipe X1 Y1 X2 Y2 [MS] | text STRING | key delete | scroll X Y DY | taptext LABEL | methods CLASS.
  --before and --after take a screenshot of the phone to FILE before the command and after the wait (default 4 seconds).]]

local SPECS = {
    tap = {count = 2, numbers = true},
    swipe = {count = {4, 5}, numbers = true},
    scroll = {count = 3, numbers = true},
    key = {count = 1, words = {delete = true}},
    methods = {count = 1},
}

function command(words)
    local verb = words[1]
    if verb == "text" or verb == "taptext" then
        if #words < 2 then
            raise("%s needs the text: %s", verb, USAGE)
        end
        local rest = table.concat(words, " ", 2)
        if rest:find("[\r\n']") then
            raise("%s takes a single line without a quote", verb)
        end
        return verb .. " " .. rest
    end
    local spec = SPECS[verb]
    if not spec then
        raise("unknown verb %s: %s", tostring(verb), USAGE)
    end
    local given = #words - 1
    local counts = type(spec.count) == "table" and spec.count or {spec.count}
    if not table.contains(counts, given) then
        raise("%s takes %s arguments, not %d", verb, table.concat(counts, " or "), given)
    end
    for index = 2, #words do
        if spec.numbers and not words[index]:match("^%-?%d+%.?%d*$") then
            raise("%s takes numbers, not %s", verb, words[index])
        end
        if spec.words and not spec.words[words[index]] then
            raise("%s does not take %s", verb, words[index])
        end
    end
    return table.concat(words, " ")
end

function script(line)
    return table.concat({
        "rm -f /var/tmp/rnhost.cmd.out",
        "touch /var/tmp/rnhost.cmd",
        "chmod 666 /var/tmp/rnhost.cmd",
        "echo '" .. line .. "' > /var/tmp/rnhost.cmd"}, "; ")
end

local SHOT = "/usr/libexec/revenant-shot"

local function shot(device, settings, file)
    device.run(settings, SHOT .. " /tmp/screenshot.png")
    if not device.fetch(settings, "/tmp/screenshot.png", file) then
        raise("the screenshot could not be fetched to %s", file)
    end
end

function main(...)
    local shared = import("@addon.revenant.member", {anonymous = true})
    local given, words = shared.arguments({...}, {before = "value", after = "value", wait = "value", help = "switch"})
    if given.help or #words == 0 then
        print(USAGE)
        return
    end
    local line = command(words)
    local device = import("@addon.revenant.device", {anonymous = true})
    local settings = device.bind(os.curdir())
    if given.before then
        shot(device, settings, path.absolute(given.before))
    end
    device.run(settings, script(line))
    os.sleep(tonumber(given.wait or "4") * 1000)
    if given.after then
        shot(device, settings, path.absolute(given.after))
    end
    local answer = os.tmpfile()
    if device.fetch(settings, "/var/tmp/rnhost.cmd.out", answer) then
        io.write(io.readfile(answer))
        os.tryrm(answer)
    else
        print("the injector wrote no answer")
    end
end
