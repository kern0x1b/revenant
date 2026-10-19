-- mutate.lua FILE FROM TO - the one-token change the control in run.sh makes (Lua port of the former mutate.py).
-- Refused unless FROM occurs exactly once, so a control that cannot be planted says so instead of reporting a mutant
-- that was never applied (2026-10-03: a planted run over an unplanted file reported a mutant as applied four times).
function main(path, old, new)
    local handle = assert(io.open(path, "r"), "cannot read " .. path)
    local text = handle:read("*a")
    handle:close()
    local count, start = 0, 1
    local first
    while true do
        local found = text:find(old, start, true)
        if not found then break end
        count = count + 1
        first = first or found
        start = found + #old
    end
    if count ~= 1 then
        io.stderr:write(string.format("%s: %q occurs %d times, not once\n", path, old, count))
        os.exit(1)
    end
    local result = text:sub(1, first - 1) .. new .. text:sub(first + #old)
    handle = assert(io.open(path, "w"), "cannot write " .. path)
    handle:write(result)
    handle:close()
    print(string.format("planted: %s -> %s", old, new))
    return 0
end
