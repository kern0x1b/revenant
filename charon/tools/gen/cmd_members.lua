local snapshot = import("spec", {anonymous = true})

function run(args)
    snapshot.forget()
    local fw = args.framework
    local rows = snapshot.member_rows(args.tree, fw)
    local refused = snapshot.refused(args.tree, fw)
    print(string.format("members %s: %d member rows from the shard, %d pinned member(s) with a changed declaration", fw, #rows, #refused))
    for _, change in ipairs(refused) do
        print(string.format("  refused: %s %s: pinned %s, the shard has %s", change.key, change.api, change.old, change.new))
    end
    return 0
end
