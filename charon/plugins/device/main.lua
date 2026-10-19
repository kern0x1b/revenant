import("core.base.option")
import("@self.device")
import("@self.packaging")

function main()
    local action = option.get("action")
    if action == "list" then
        for _, found in ipairs(device.attached()) do
            print("%s  %s  iOS %s  tunnel %s  %s", found.udid, found.product, found.release, found.port or "none",
                  found.lease and string.format("held by %s until %s", found.lease.holder, os.date("%H:%M:%S", found.lease.expires)) or "free")
        end
        return
    end
    local settings = device.bind(os.projectdir(), option.get("device"))
    local arguments = table.concat(option.get("arguments") or {}, " ")
    if action == "claim" then
        local holder = device.holder_name(option.get("holder"))
        local expires = device.claim(settings, holder, tonumber(option.get("minutes")))
        cprint("${bright green}claimed${clear} %s for %s until %s", settings.udid, holder, os.date("%H:%M:%S", expires))
    elseif action == "release" then
        device.release(settings, device.holder_name(option.get("holder")))
        cprint("${bright green}released${clear} %s", settings.udid)
    elseif action == "where" then
        print(device.where(settings))
    elseif action == "run" then
        if arguments == "" then
            raise("xmake device run needs a command")
        end
        device.run(settings, arguments)
    elseif action == "log" then
        device.log(settings, tonumber(option.get("seconds")), arguments)
    elseif action == "install" then
        local refreshed = false
        local written_packages = packaging.write()
        local conflicts = {}
        for _, written in ipairs(written_packages) do
            if written.stage then
                table.join2(conflicts, device.identity_conflicts(settings, written.stage))
            end
        end
        if #conflicts > 0 then
            raise(table.concat(conflicts, "; "))
        end
        for _, written in ipairs(written_packages) do
            local remote = "/tmp/" .. path.filename(written.deb)
            device.copy(settings, written.deb, remote)
            device.run(settings, string.format("dpkg -i %s && rm -f %s", remote, remote))
            cprint("${bright green}installed${clear} %s on %s", path.filename(written.deb), device.where(settings))
            refreshed = refreshed or (written.stage and os.isdir(path.join(written.stage, "Applications")))
        end
        if refreshed then
            device.run(settings, "su mobile -c uicache")
        end
    elseif action == "uninstall" then
        if arguments == "" then
            raise("xmake device uninstall needs the packages to remove")
        end
        device.run(settings, device.uninstall_command(option.get("arguments"), {keep = option.get("keep")}))
    else
        raise("xmake device takes install, uninstall, log, run, where, list, claim or release")
    end
end
