function main(transcript, floor, what)
    local compared, mismatches
    for line in io.lines(transcript) do
        local c, m = line:match("^compared (%d+) mismatches (%d+)$")
        if c then
            compared, mismatches = tonumber(c), tonumber(m)
        end
    end
    if not compared then
        print("FAIL: the case printed no verdict line")
        os.exit(1)
    end
    if mismatches ~= 0 then
        print(string.format("FAIL: %d mismatches over %d compared", mismatches, compared))
        os.exit(1)
    end
    if compared < tonumber(floor) then
        print(string.format("FAIL: only %d elements compared, which cannot be %s", compared, what))
        os.exit(1)
    end
    print(string.format("PASS: %d elements compared, %d mismatches", compared, mismatches))
end
