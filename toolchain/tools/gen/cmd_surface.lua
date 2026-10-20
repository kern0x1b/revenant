local emit = import("emit", {anonymous = true})
local surface_model = import("surface_model", {anonymous = true})
local sdk_info = import("sdk", {anonymous = true})

function run(args)
    assert(args.out, "surface needs --out: the folder sdk-surface-model.tsv is written to")
    assert(args.sdk, "surface needs --sdk: the iPhoneOS SDK whose release the shards are checked against")
    local list, repeats, totals, cross = surface_model.rows(args.tree, args.corpus, sdk_info.discover(args.sdk).version)
    print(string.format("surface: swift rows against the interface text: exact %d, qualified %d, relabelled %d; digester only %d "
                        .. "(of which ambiguous %d); interface only %d (added)", totals.exact or 0, totals.qualified or 0,
                        totals.relabelled or 0, totals.digester_only or 0, totals.ambiguous or 0, totals.interface_only or 0))
    print(string.format("surface: usrs in more than one framework %d: rows of the other frameworks dropped %d; the model cannot tell "
                        .. "%d usrs (%d rows), kept", cross.usrs, cross.dropped, cross.undecided_usrs, cross.undecided_rows))
    local counts, names = {}, {}
    for _, record in ipairs(list) do
        local key = record.framework .. "\t" .. record.kind
        if counts[key] == nil then
            counts[key] = 0
            table.insert(names, key)
        end
        counts[key] = counts[key] + 1
    end
    for _, key in ipairs(names) do
        print(string.format("surface: %s %d", string.gsub(key, "\t", " "), counts[key]))
    end
    emit.file(path.join(args.out, "sdk-surface-model.tsv"), surface_model.table_text(list))
    print(string.format("surface: %d rows -> sdk-surface-model.tsv (%d exact repeats of a usr dropped)", #list, repeats))
    return 0
end
