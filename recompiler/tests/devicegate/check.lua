local function refusal(action)
    local message
    try {
        function ()
            action()
        end,
        catch {
            function (raised)
                message = tostring(raised)
            end
        }
    }
    return message
end

function main(out)
    local scripts = path.join(os.scriptdir(), "..", "..", "tools")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local module = import("@addon.revenant.device", {anonymous = true})
    local problems = {}

    local forms = {
        {{}, false, false},
        {{"--host-only"}, true, false},
        {{{host_only = true}}, true, false},
        {{"--device-only"}, false, true},
        {{{device_only = true}}, false, true},
        {{"--host-only", {device_only = true}}, true, true},
    }
    for _, form in ipairs(forms) do
        local given = corpus.options(table.unpack(form[1]))
        if given.host_only ~= form[2] or given.device_only ~= form[3] then
            table.insert(problems, string.format("corpus.options reads %d argument(s) as host_only=%s device_only=%s, expected %s and %s", #form[1],
                                                 tostring(given.host_only), tostring(given.device_only), tostring(form[2]), tostring(form[3])))
        end
    end

    local folder = path.join(os.tmpdir(), "revenant-devicegate")
    os.tryrm(folder)
    os.mkdir(folder)
    local saved = {}
    local names = {"REVENANT_DEVICE_LEASES", "REVENANT_DEVICE_HOLDER", "DEVICE_HOST", "DEVICE_UDID"}
    for _, name in ipairs(names) do
        saved[name] = os.getenv(name) or false
    end
    os.setenv("REVENANT_DEVICE_LEASES", path.join(folder, "leases"))
    os.setenv("DEVICE_HOST", "10.0.0.7")
    os.setenv("DEVICE_UDID", "devicegate-test")
    local settings = module.bind(os.projectdir(), nil)
    os.setenv("REVENANT_DEVICE_HOLDER", "gate-a")
    local text = refusal(function () corpus.device() end)
    if not text or not text:find("does not hold it", 1, true) then
        table.insert(problems, "a check reached the phone nobody claimed: " .. tostring(text))
    end
    module.claim(settings, "gate-b", 5)
    text = refusal(function () corpus.device() end)
    if not text or not text:find("does not hold it", 1, true) then
        table.insert(problems, "a check reached the phone another holder claimed: " .. tostring(text))
    end
    module.release(settings, "gate-b")
    module.claim(settings, "gate-a", 5)
    text = refusal(function () corpus.device() end)
    if text then
        table.insert(problems, "the holder of the claim was refused: " .. text)
    end
    os.setenv("REVENANT_DEVICE_HOLDER", "")
    text = refusal(function () corpus.device() end)
    if not text or not text:find("does not hold it", 1, true) then
        table.insert(problems, "a check reached the phone with no holder named: " .. tostring(text))
    end
    module.release(settings, "gate-a")
    for _, name in ipairs(names) do
        os.setenv(name, saved[name] or nil)
    end
    os.tryrm(folder)
    if #problems > 0 then
        raise("%s", table.concat(problems, "\n"))
    end
    print("ok: the check scripts read host-only and device-only as a string or as a table, and a check does not reach the phone unless its holder claimed it")
end
