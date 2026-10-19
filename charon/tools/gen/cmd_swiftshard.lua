local swift_shard = import("swift_shard", {anonymous = true})

function run(args)
    assert(args.sdk, "--sdk (the SDK folder) is required")
    assert(args.coordination, "--coordination (the corpus folder) is required")
    local heavy, names, triple = swift_shard.plan(args.coordination, args.sdk, args.framework)
    local written, missing = 0, 0
    for _, result in ipairs(swift_shard.write_shards(args.tree, heavy, args.sdk, triple, names)) do
        if result.rows then
            written = written + 1
            print(string.format("swiftshard: %s %d rows", result.name, result.rows))
        else
            missing = missing + 1
            print(string.format("swiftshard: %s no shard: %s", result.name, result.reason))
        end
    end
    print(string.format("swiftshard: %d shards, %d modules without one", written, missing))
    return 0
end
