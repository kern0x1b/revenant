local objc = import("objc", {anonymous = true})
local sdk = import("sdk", {anonymous = true})

function run(args)
    assert(args.coordination, "--coordination (the corpus folder) is required")
    assert(args.sdk, "objc needs --sdk: the iPhoneOS SDK whose release names the corpus folder")
    local frameworks, rows = {}, 0
    objc.each(args.coordination, sdk.discover(args.sdk).version, nil, function(fw)
        frameworks[fw] = (frameworks[fw] or 0) + 1
        rows = rows + 1
    end)
    local count = 0
    for _ in pairs(frameworks) do
        count = count + 1
    end
    print(string.format("objc: %d frameworks, %d rows (nothing written: each consumer streams the table)", count, rows))
    return 0
end
