-- `swiftmodel`: writes the full Swift declaration model of each Swift module of the SDK (swift_model.lua) under --out, one TSV per
-- module. A build product, never committed. --sdk is the SDK, --out the folder, --framework runs one module (a measurement).
-- The digester runs through heavy.sh; --coordination names the corpus folder heavy.sh sits beside (default: the workspace's).

local swift_model = import("swift_model", {anonymous = true})

-- The path of coordination/heavy.sh: beside --coordination when it is given, else the workspace's coordination folder.
local function heavy_path(args)
    if args.coordination then
        return path.join(args.coordination, "heavy.sh")
    end
    return path.join(os.getenv("HOME"), "Git", "projects", "ios", "coordination", "heavy.sh")
end

-- Returns the exit status.
function run(args)
    assert(args.sdk, "--sdk (the SDK folder) is required")
    assert(args.out, "--out (the folder to write the model into) is required")
    local heavy = heavy_path(args)
    assert(os.isfile(heavy), "no heavy.sh: " .. heavy)
    local names = args.framework and {args.framework} or swift_model.modules(args.sdk)
    local triple = swift_model.triple_of(args.sdk)
    os.mkdir(args.out)
    -- the digester's dumps of the named modules, run as one batch first (swift_model.prefetch); each module's model is read from it
    local folder = swift_model.prefetch(args.tree, heavy, args.sdk, triple, names)
    local written, missing, total = 0, 0, 0
    for _, name in ipairs(names) do
        local rows, reason = swift_model.write_model(folder, args.out, name)
        if rows then
            written = written + 1
            total = total + rows
            print(string.format("swiftmodel: %s %d rows", name, rows))
        else
            missing = missing + 1
            print(string.format("swiftmodel: %s no model: %s", name, reason))
        end
    end
    print(string.format("swiftmodel: %d modules, %d rows, %d modules without a model", written, total, missing))
    return 0
end
