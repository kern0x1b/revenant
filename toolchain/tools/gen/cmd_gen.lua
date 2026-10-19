local layout = import("layout", {anonymous = true})
local snapshot = import("spec", {anonymous = true})
local render = import("render", {anonymous = true})
local emit = import("emit", {anonymous = true})
local digest = import("digest", {anonymous = true})
local files = import("files", {anonymous = true})
local tsv = import("tsv", {anonymous = true})
local order = import("order", {anonymous = true})
local sdk = import("sdk", {anonymous = true})

local MEMBERS_NAME = "members.tsv"
local MANIFEST_NAME = "manifest.tsv"

function frameworks(tree)
    return snapshot.frameworks(tree)
end

function stale_constants(base, fw, emitted)
    local out = {}
    for _, found in ipairs(files.glob(path.join(base, path.filename(fw) .. "Constants*.m"))) do
        local name = path.filename(found)
        if emitted[name] == nil then
            table.insert(out, name)
        end
    end
    table.sort(out, order.less)
    return out
end

local function members_text(rows)
    local out = {}
    for _, r in ipairs(rows) do
        if r.kind == "method" or r.kind == "property" or r.kind == "constant" then
            table.insert(out, {r.api, r.hash})
        end
    end
    return tsv.table_text({"api", "hash"}, out)
end

local function spec_name(sdk_release)
    return "spec." .. sdk.names(sdk_release).sdk_id .. ".tsv"
end

function derived(tree, fw, corpus, sdk_release)
    local emitted = render.render(tree, fw, corpus, sdk_release)
    local spec = snapshot.load(tree, fw)
    emitted[spec_name(sdk_release)] = snapshot.table_text(spec)
    emitted[MEMBERS_NAME] = members_text(spec)
    return emitted
end

local function manifest_text(emitted, sdk_release)
    local manifest = {}
    for _, name in ipairs(order.keys(emitted)) do
        if name ~= spec_name(sdk_release) and name ~= MEMBERS_NAME then
            table.insert(manifest, {name, digest.digest_of(emitted[name])})
        end
    end
    return tsv.table_text({"file", "sha256"}, manifest)
end

local function rerecord(tree, fw, refused)
    local pinned_changes = {}
    for _, change in ipairs(refused) do
        pinned_changes[change.key] = change
    end
    local list = snapshot.pins(tree, fw)
    for _, p in ipairs(list) do
        local change = pinned_changes[p.key]
        if change ~= nil then
            p.pinned = change.new
            p["pinned-by"] = "repin"
        end
    end
    emit.file(layout.pins_path(tree, fw), snapshot.pins_text(list))
end

local function write_framework(args, fw, sdk_release)
    local emitted = derived(args.tree, fw, args.coordination, sdk_release)
    emitted[MANIFEST_NAME] = manifest_text(emitted, sdk_release)
    local base = layout.gen_dir(args.tree, fw)
    for _, name in ipairs(stale_constants(base, fw, emitted)) do
        os.rm(path.join(base, name))
    end
    local before = emit.count()
    local names = order.keys(emitted)
    for _, name in ipairs(names) do
        emit.file(path.join(base, name), emitted[name])
    end
    print(string.format("gen %s: %d files in %s (%d written)", fw, #names, layout.constants().OUT_ROOT .. "/" .. fw, emit.count() - before))
end

function refusal(tree, fw, change)
    return string.format("REFUSED %s %s: pinned declaration hash %s, the shard has %s. Review the override, then re-record it: "
        .. "xmake l tools/gen.lua gen --tree %s --framework %s --record", change.key, change.api, change.old, change.new, tree, fw)
end

function run(args)
    assert(args.sdk, "gen needs --sdk: the iPhoneOS SDK whose release names the corpus and the spec file")
    local sdk_release = sdk.discover(args.sdk).version
    snapshot.forget()
    local targets = args.all and frameworks(args.tree) or {args.framework}
    local refused_frameworks = {}
    for _, fw in ipairs(targets) do
        local refused = snapshot.refused(args.tree, fw)
        if #refused > 0 and not args.record then
            for _, change in ipairs(refused) do
                print(refusal(args.tree, fw, change))
            end
            print(string.format("gen %s: refused, %d pin(s) changed since they were recorded; nothing written for it", fw, #refused))
            table.insert(refused_frameworks, fw)
        else
            if #refused > 0 then
                rerecord(args.tree, fw, refused)
                print(string.format("gen %s: re-recorded %d pin(s) as repin", fw, #refused))
            end
            write_framework(args, fw, sdk_release)
        end
    end
    if #refused_frameworks > 0 then
        print(string.format("gen: refused %d framework(s), nothing written for them: %s", #refused_frameworks, table.concat(refused_frameworks, ", ")))
        return 1
    end
    return 0
end
