-- The floor a fit's sample has to clear, in one place, because two fits read the same sample.
--
-- Both fits under this directory read the same file and both have to agree about whether it is a
-- measurement or not, and a disagreement between two copies of this decision would be silent: one fit
-- would refuse a sample, print its refusal and exit 1, the other would carry on and print a verdict of
-- it, and the runner - which stops on the first failure - would never see the two disagree. So the floor
-- lives here once and both fits import it.
--
-- The floor is the grid's own row count and nothing more. The probe writes a 17x17x17 sRGB grid first,
-- so a sample smaller than that is truncated or is not a fit sample at all, and every figure either fit
-- prints is over a sample of at least this size. A larger sample is not refused, and a large but
-- degenerate one - the right number of rows and the wrong contents - is caught by the known-answer
-- check in run.sh rather than here, because that is a question about the contents and this one is about
-- the size.
--
--   grid_rows() -> 4913, sample_rows(path) -> integer, refuse_small_sample(path) -> boolean

-- The rows the grid alone writes.
function grid_rows()
    return 17 * 17 * 17
end

-- How many rows of answers the sample holds.
--
-- A row of answers is a line of five tab-separated fields - the kind, the three channels and the name -
-- and the count is of those, not of lines. Counting lines instead let a file of nothing at all clear
-- the floor and then kill both fits where they unpack a line, which is the same shape as the
-- divide-by-zero this floor replaced, reached through a different door. The probe's own header line is
-- not a row either, and neither is anything else that does not parse as one.
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

-- false, with the reason on stdout, when the sample is too small for anything below it to count.
function refuse_small_sample(path)
    local rows = sample_rows(path)
    if rows < grid_rows() then
        print(string.format("refused: this sample has %d rows and the grid alone is %d, so nothing below is a "
            .. "measurement", rows, grid_rows()))
        return false
    end
    return true
end
