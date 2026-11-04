local USAGE = [[usage: ./xmakew l -P . frameworks/ReactNative/tools/touch.lua --bundle-id ID [--before FILE] [--after FILE] [--wait SECONDS] VERB ARGUMENT...
  sends one command to the touch injector of the React Native host with bundle id ID on the claimed phone and prints its answer.
  VERB is tap X Y | swipe X1 Y1 X2 Y2 [MS] | text STRING | key delete | scroll X Y DY | taptext LABEL | methods CLASS.
  The command is appended to rnhost.cmd in the host's application folder, and the answer is read from rnhost.cmd.out in its run folder.
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

local SHOT = "/usr/libexec/revenant-shot"

function application_name(bundle_id)
    return bundle_id:match("([^%.]+)$")
end

function command_file(holder, bundle_id)
    local name = application_name(bundle_id)
    return "/var/stash/" .. holder .. "/" .. name .. "/" .. name .. ".app/rnhost.cmd"
end

function answer_file(bundle_id)
    return "/var/tmp/" .. application_name(bundle_id) .. "/rnhost.cmd.out"
end

function send(line, holder, bundle_id)
    return "rm -f " .. answer_file(bundle_id) .. " && printf '%s\\n' '" .. line .. "' >> " .. command_file(holder, bundle_id)
end

local function shot(device, settings, file)
    device.run(settings, SHOT .. " /tmp/screenshot.png")
    if not device.fetch(settings, "/tmp/screenshot.png", file) then
        raise("the screenshot could not be fetched to %s", file)
    end
end

function main(...)
    local shared = import("@addon.revenant.member", {anonymous = true})
    local given, words = shared.arguments({...}, {["bundle-id"] = "value", before = "value", after = "value", wait = "value", help = "switch"})
    if given.help or #words == 0 then
        print(USAGE)
        return
    end
    if not given["bundle-id"] then
        raise("touch needs --bundle-id: %s", USAGE)
    end
    local line = command(words)
    local device = import("@addon.revenant.device", {anonymous = true})
    local holder = device.holder_name()
    if not holder then
        raise("export REVENANT_DEVICE_HOLDER, the name the phone is claimed under")
    end
    local settings = device.bind(os.curdir())
    if given.before then
        shot(device, settings, path.absolute(given.before))
    end
    device.run(settings, send(line, holder, given["bundle-id"]))
    os.sleep(tonumber(given.wait or "4") * 1000)
    if given.after then
        shot(device, settings, path.absolute(given.after))
    end
    local answer = os.tmpfile()
    if device.fetch(settings, answer_file(given["bundle-id"]), answer) then
        io.write(io.readfile(answer))
        os.tryrm(answer)
    else
        print("the injector wrote no answer")
    end
end
