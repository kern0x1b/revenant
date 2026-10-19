-- The enumerator values and enum types of the port's triple, for the port's headers (cmd_headers). tools/found/port_values.lua writes
-- them: the declaration extractor run over the SDK's headers with the port's triple (armv7-apple-ios6.1.3), so clang evaluates each
-- enumerator, and gives each enum without a fixed type, for the ABI the port is built for. The IR's are the SDK's own triple's (arm64):
-- NSIntegerMax is 9223372036854775807 there and 2147483647 on armv7, and an enum with no fixed type is unsigned long on arm64 but
-- unsigned long long on armv7 (DISPATCH_WALLTIME_NOW). The join is by USR. A value or type that differs takes the run's; one the run does
-- not declare keeps the IR's, and so does one of a module the run does not parse for the triple (the run names that module, with its
-- first error). The faithful headers never take these values.

local COL = {framework = 1, kind = 2, usr = 3, type = 11, value = 14}

-- The values of one run's file: usr -> value (an enumerator declared in two modules has one value in the run, else the file is refused),
-- usr -> underlying type of each enum the run gives one, and framework -> reason for each module the run does not parse. The file's lines
-- starting with # are its header.
function read(filepath)
    local text = io.readfile(filepath)
    assert(text, "port values: cannot read " .. filepath)
    local run = {values = {}, types = {}, unparsed = {}}
    for line in string.gmatch(text, "[^\n]+") do
        if string.sub(line, 1, 1) ~= "#" then
            local kind, framework, usr, value = string.match(line, "^([^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)$")
            assert(kind, "port values: a line is not four cells: " .. line)
            if kind == "unparsed" then
                run.unparsed[framework] = value
            elseif kind == "enumconst" then
                local seen = run.values[usr]
                assert(seen == nil or seen == value, "port values: " .. usr .. " has two values in the run: " .. tostring(seen) .. ", " .. value)
                run.values[usr] = value
            elseif kind == "enumtype" then
                run.types[usr] = value
            else
                error("port values: an unknown kind " .. kind)
            end
        end
    end
    return run
end

-- Writes the run's values into the rows given (the port's copies of the IR rows): an enumerator whose value the run gives differently
-- takes the run's value, and so does an enum whose underlying type the run gives differently. Returns the number of values changed, the
-- number of enumerators the run does not declare, the number of those whose module the run does not parse (a subset of the second), and
-- the number of enum types changed.
function apply(rows, run)
    local changed, absent, unparsed, types = 0, 0, 0, 0
    for _, row in ipairs(rows) do
        local fixed = run.types[row[COL.usr]]
        if row[COL.kind] == "enum" and fixed ~= nil and row[COL.type] ~= "-" and fixed ~= row[COL.type] then
            row[COL.type] = fixed
            types = types + 1
        end
        if row[COL.kind] == "enumconst" and row[COL.value] ~= "-" then
            local value = run.values[row[COL.usr]]
            if value == nil then
                absent = absent + 1
                if run.unparsed[row[COL.framework]] ~= nil then unparsed = unparsed + 1 end
            elseif value ~= row[COL.value] then
                row[COL.value] = value
                changed = changed + 1
            end
        end
    end
    return changed, absent, unparsed, types
end
