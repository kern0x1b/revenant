local lowered = import("@addon.revenant.apple.lowered", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})
local facts = import("facts", {rootdir = path.join(os.scriptdir(), "..", "tools"), anonymous = true})

function main()
    local src = path.absolute(path.join(os.scriptdir(), "..", "src"))
    local committed = io.readfile(lowered.members_file())
    local sdk = workspace.sdk()
    local expected = lowered.members_text(src, sdk, facts.constant_intros(sdk))
    assert(committed == expected, "frameworks/Backports/lowered-members.txt no longer matches frameworks/Backports/src: run "
           .. "./xmakew l -P . frameworks/Backports/tools/lowered_members.lua and commit the result")
    local parsed = lowered.parse(committed)
    assert(lowered.serialize(parsed) == committed, "the lowered member list does not survive a parse and serialize")
    local unlowered = {}
    for _, pattern in ipairs({"**.m", "**.mm", "**.c"}) do
        for _, file in ipairs(os.files(path.join(src, pattern))) do
            for name in io.readfile(file):gmatch("BACKPORT_IMPL%(%s*([%a_][%w_]*)%s*%)") do
                if not parsed.functions[name] and not parsed.globals[name] then
                    unlowered[name] = path.relative(file, src)
                end
            end
        end
    end
    for _, name in ipairs(table.orderkeys(unlowered)) do
        raise("%s is implemented in src/%s as BACKPORT_IMPL(%s) but is not in the lowered member list, so the SDK's declaration keeps its availability and a Swift or C use of it at the deployment target fails to compile", name, unlowered[name], name)
    end
end
