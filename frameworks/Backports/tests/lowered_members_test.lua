local lowered = import("@addon.revenant.apple.lowered", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})
local facts = import("facts", {rootdir = path.join(os.scriptdir(), "..", "tools"), anonymous = true})

local GUARDED = {
    CASpringAnimation = {file = "UIKit/CASpringAnimation.m", guard = "revenant_spring_install", selectors = {"initialVelocity", "settlingDuration"}},
}

local function has_members(members)
    for _ in pairs(members or {}) do
        return true
    end
    return false
end

local function shadow_check(src, parsed)
    local aliased = {}
    for _, file in ipairs(os.files(path.join(src, "**.m"))) do
        local text = io.readfile(file)
        for name in text:gmatch("REVENANT_ALIAS%(%s*([%a_][%w_]*)%s*%)") do
            aliased[name] = true
        end
        for name in text:gmatch("%.set _OBJC_CLASS_%$_([%a_][%w_]*),") do
            aliased[name] = true
        end
    end
    local device = lowered.read_device_members().classes
    local names = {}
    for name in pairs(aliased) do
        if device[name] then
            table.insert(names, name)
        end
    end
    table.sort(names)
    local shadows = {}
    for _, name in ipairs(names) do
        local proxy = parsed.classes["Revenant" .. name]
        local own = parsed.classes[name]
        if has_members(proxy) and not has_members(own) then
            table.insert(shadows, name)
        end
    end
    print("alias classes that the device also has: " .. table.concat(names, ", "))
    print("alias classes whose system class has no lowered member: " .. table.concat(shadows, ", "))
    for _, name in ipairs(shadows) do
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
