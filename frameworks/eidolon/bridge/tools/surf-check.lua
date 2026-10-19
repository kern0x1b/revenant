local text = import("lib.text", {rootdir = path.join(os.scriptdir(), "..", ".."), anonymous = true})

local NESTED = {
    {"ResizingMode", 2},
    {"Orientation", 10},
    {"Interpolation", 3},
    {"TemplateRenderingMode", 1},
    {"Representation", 2},
}
local MAX_IMAGE_OWN = 15

function main(...)
    local args = {...}
    local file = args[1] or os.getenv("SURFACE_TSV")
    if file == nil then
        io.stderr:write("usage: surf-check.lua [SURFACE-TSV], or SURFACE_TSV set\n")
        os.exit(2)
    end
    local counts = {}
    for _, line in ipairs(text.split(io.readfile(file), "\n")) do
        if text.strip(line) ~= "" then
            local parts = text.split(line, "\t")
            if #parts ~= 3 then
                io.stderr:write(string.format("%s: a row has %d columns, want 3 (owner, kind, name)\n", file, #parts))
                os.exit(1)
            end
            counts[parts[1]] = (counts[parts[1]] or 0) + 1
        end
    end
    io.stderr:write(string.format("# judging %s\n", file))

    local failures = {}
    local owned = counts["Image"] or 0
    print(string.format("%s Image owns no more than the %d rows the interfaces give it: %d",
        owned <= MAX_IMAGE_OWN and "ok  " or "FAIL", MAX_IMAGE_OWN, owned))
    for _, pair in ipairs(NESTED) do
        local got = counts["Image." .. pair[1]] or 0
        print(string.format("%s Image.%s owns its own members (%d rows, the interface has about %d)",
            got > 0 and "ok  " or "FAIL", pair[1], got, pair[2]))
        if got == 0 then
            failures[#failures + 1] = string.format("Image.%s owns nothing; its members are filed elsewhere", pair[1])
        end
    end
    io.stderr:write(string.format("# Image owns %d rows of its own\n", owned))
    if owned > MAX_IMAGE_OWN then
        failures[#failures + 1] = string.format("Image owns %d rows, more than the %d its interfaces declare",
            owned, MAX_IMAGE_OWN)
    end
    for _, line in ipairs(failures) do
        io.stderr:write("# " .. line .. "\n")
    end
    os.exit(#failures > 0 and 1 or 0)
end
