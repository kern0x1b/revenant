function grid_rows()
    return 17 * 17 * 17
end

function sample_rows(path)
    local count = 0
    for line in io.lines(path) do
        if line:sub(1, 1) ~= "#" then
            local _, tabs = line:gsub("\t", "")
            if tabs == 4 then
                count = count + 1
            end
        end
    end
    return count
end

function refuse_small_sample(path)
    local rows = sample_rows(path)
    if rows < grid_rows() then
        print(string.format("refused: this sample has %d rows and the grid alone is %d, so nothing below is a "
            .. "measurement", rows, grid_rows()))
        return false
    end
    return true
end
