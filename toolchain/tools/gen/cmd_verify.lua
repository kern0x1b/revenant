function run(args)
    local status, detail = import("verify", {anonymous = true}).run(args)
    print("verify: " .. tostring(detail))
    return status
end
