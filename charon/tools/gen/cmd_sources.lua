local sources = import("sources", {anonymous = true})
local sdk = import("sdk", {anonymous = true})

local function print_table(rows, columns)
    local width = {}
    for column = 1, columns do
        width[column] = 0
        for _, row in ipairs(rows) do
            width[column] = math.max(width[column], #row[column])
        end
    end
    for _, row in ipairs(rows) do
        local cells = {}
        for column = 1, columns do
            cells[column] = row[column] .. string.rep(" ", width[column] - #row[column])
        end
        print(table.concat(cells, " | "))
    end
end

function run(args)
    assert(args.sdk, "sources needs --sdk: the iPhoneOS SDK whose release names the rows")
    local rows = {{"source", "kind", "licence", "loader", "status", "adds"}}
    for _, row in ipairs(sources.sources(sdk.discover(args.sdk).version)) do
        table.insert(rows, row)
    end
    print_table(rows, 6)
    print("")
    local leads = {{"lead", "library", "licence", "use", "status"}}
    for _, row in ipairs(sources.oss_leads()) do
        table.insert(leads, row)
    end
    print_table(leads, 5)
    return 0
end
