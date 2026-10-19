import("core.base.option")
import("@self.emulator")

function main()
    local command = option.get("command")
    if not command or #command == 0 then
        raise("xmake queue runs a command in a build slot: xmake queue -- xmake build")
    end
    local program, arguments = command[1], table.slice(command, 2)
    -- A build that the queue already started passes its slot down, so a nested
    -- build runs inside it instead of waiting for one its parent holds.
    if emulator.holds_build_slot() then
        local held = os.execv(program, arguments, {try = true})
        if held ~= 0 then
            os.exit(held)
        end
        return
    end
    local count = tonumber(option.get("count")) or emulator.build_capacity()
    local slot = emulator.acquire({folder = path.join(emulator.root(), "build-slots"), count = count, patience = 0})
    local jobs = emulator.build_jobs(os.cpuinfo("ncpu"), count)
    local code = os.execv(program, emulator.queued_arguments(program, arguments, jobs),
                          {try = true, envs = {[emulator.build_slot_name()] = tostring(slot.index)}})
    emulator.release(slot)
    if code ~= 0 then
        os.exit(code)
    end
end
