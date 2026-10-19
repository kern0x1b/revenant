-- `members`: reads the member rows of a framework from its declaration shard (spec.member_rows, the rows gen builds in memory), and reports
-- the pinned members whose declaration hash differs from their pin: gen refuses those unless it re-records them. Writes nothing; the
-- members listing is derived under .gen and is not compared here.

local snapshot = import("spec", {anonymous = true})

-- Returns the exit status.
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
