function run(program, argv, opt)
    local status = 0
    try
    {
        function ()
            os.execv(program, argv, opt)
        end,
        catch
        {
            function (errors)
                status = tonumber(tostring(errors):match("failed%((%d+)%)")) or -1
            end
        }
    }
    return status
end

function lines(text)
    local out = {}
    for line in text:gmatch("[^\n]+") do
        table.insert(out, line)
    end
    return out
end

function count(text, pattern)
    local found = 0
    for _, line in ipairs(lines(text)) do
        if line:find(pattern, 1, true) then
            found = found + 1
        end
    end
    return found
end
