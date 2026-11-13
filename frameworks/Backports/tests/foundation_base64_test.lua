local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))

local function lines_of(text)
    local lines = {}
    for line in text:gmatch("[^\n]+") do
        table.insert(lines, line)
    end
    return lines
end

function main()
    local out = workspace.run("backports-tests", "FoundationBase64")
    local fixture = path.join(backports, "tests", "foundation_base64", "main.m")
    local category = path.join(backports, "src", "Foundation", "NSData+Base64.m")
    local flags = {"clang", "-fobjc-arc", "-Wall", "-Werror", "-framework", "Foundation"}
    local oracle = path.join(out, "oracle")
    local candidate = path.join(out, "candidate")
    os.vrunv("xcrun", table.join(flags, {"-o", oracle, fixture}))
    os.vrunv("xcrun", table.join(flags, {"-o", candidate, fixture, category}))
    local expected = lines_of(os.iorunv(oracle))
    local actual = lines_of(os.iorunv(candidate))
    assert(expected[1] == "OUTSIDE_THE_SYSTEM 0", "the macOS NSData must answer the four base64 selectors itself: " .. expected[1])
    assert(actual[1] == "OUTSIDE_THE_SYSTEM 4", "the four base64 selectors must come from the category, and not from the system: " .. actual[1])
    assert(expected[#expected] == "done" and actual[#actual] == "done", "the base64 fixture did not finish")
    assert(#expected == #actual, string.format("the oracle printed %d lines and the category %d", #expected, #actual))
    local different = 0
    for index = 2, #expected do
        if expected[index] ~= actual[index] then
            different = different + 1
            if different <= 10 then
                print(string.format("oracle:   %s\ncategory: %s", expected[index], actual[index]))
            end
        end
    end
    assert(different == 0, string.format("%d of %d answers of the category differ from macOS", different, #expected - 2))
    print(string.format("base64 category: %d answers equal to macOS", #expected - 2))
end
