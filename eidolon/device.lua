-- xmake l device.lua copy LOCAL REMOTE | run "COMMAND" | fetch REMOTE LOCAL
function main(action, a, b)
    local modules = assert(os.getenv("CHARON_MODULES"), "CHARON_MODULES must name the modules directory of a Charon checkout")
    local device = import("device", {rootdir = modules, anonymous = true})
    local settings = {host = os.getenv("DEVICE_HOST"), port = os.getenv("DEVICE_PORT"), password = os.getenv("DEVICE_PASSWORD"), udid = os.getenv("DEVICE_UDID")}
    if action == "copy" then
        device.copy(settings, a, b)
        print("copied")
    elseif action == "fetch" then
        device.fetch(settings, a, b)
        print("fetched")
    elseif action == "log" then
        device.log(settings, tonumber(a) or 20)
    else
        local out = device.run(settings, a, {seconds = tonumber(b) or 60})
        if out then io.write(out) end
    end
end
