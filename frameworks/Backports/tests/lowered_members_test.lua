local lowered = import("@addon.revenant.apple.lowered", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})
local facts = import("facts", {rootdir = path.join(os.scriptdir(), "..", "tools"), anonymous = true})

local GUARDED = {
    CASpringAnimation = {file = "UIKit/CASpringAnimation.m", guard = "revenant_spring_install", selectors = {"initialVelocity", "settlingDuration"}},
}

local function shadow_check(src, parsed)
    local shadows = lowered.shadowed_classes(src, parsed, lowered.read_device_members())
    local committed = io.readfile(lowered.shadowed_file())
    assert(committed == lowered.shadowed_text(shadows), "frameworks/Backports/tools/shadowed-classes.txt no longer matches the sources: run "
           .. "./xmakew l -P . frameworks/Backports/tools/shadowed_classes.lua and commit the result")
    assert(lowered.shadowed_text(lowered.parse_shadowed(committed)) == committed, "the shadowed class list does not survive a parse and serialize")
    local names = {}
    for _, shadow in ipairs(shadows) do
        table.insert(names, shadow.class)
    end
    print("shadowed classes: " .. table.concat(names, ", "))
    for _, name in ipairs(names) do
        local guard = GUARDED[name]
        assert(guard, name .. " forwards to the system class on iOS 6, where the system class has none of the members its proxy implements: "
               .. "a forwarding answer needs a completeness check, registered in GUARDED in this test")
        local text = io.readfile(path.join(src, guard.file))
        local start = text:find(" " .. guard.guard .. "(", 1, true)
        local finish = start and text:find("\n}", start, true)
        local body = start and finish and text:sub(start, finish) or ""
        assert(body:find("objc_getClass(\"" .. name .. "\")", 1, true), guard.file .. ": " .. guard.guard .. " must look the system class up by name")
        for _, selector in ipairs(guard.selectors) do
            assert(body:find("@selector(" .. selector .. ")", 1, true), guard.file .. ": " .. guard.guard .. " must check for " .. selector)
        end
    end
end

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
    shadow_check(src, parsed)
end
