local swift_model = import("swift_model", {anonymous = true})

local function heavy_path(args)
    if args.coordination then
        return path.join(args.coordination, "heavy.sh")
    end
    return path.join(os.getenv("HOME"), "Git", "projects", "ios", "coordination", "heavy.sh")
end

function run(args)
    assert(args.sdk, "--sdk (the SDK folder) is required")
    assert(args.out, "--out (the folder to write the model into) is required")
    local heavy = heavy_path(args)
    assert(os.isfile(heavy), "no heavy.sh: " .. heavy)
    local names = args.framework and {args.framework} or swift_model.modules(args.sdk)
    local triple = swift_model.triple_of(args.sdk)
    os.mkdir(args.out)
    local folder = swift_model.prefetch(heavy,args.sdk, triple, names)
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
