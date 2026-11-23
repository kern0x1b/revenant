import("core.base.json")

local tools = path.absolute(path.join(os.scriptdir(), "..", "tools"))
local stubs = import("stubs", {rootdir = tools, anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})

local SKELETON = [==[
static void revenant_stub_1(void)
{ revenant_backports_fail("-[Window canBecomeKeyWindow]"); }
static void revenant_stub_2(void)
{ revenant_backports_fail("+[Window sharedWindow]"); }
static const struct revenant_backports_method revenant_methods[] = {{"Window", "canBecomeKeyWindow", 0, (IMP)revenant_stub_1}, {"Window", "sharedWindow", 1, (IMP)revenant_stub_2}, {"Notification", "fireDate", 0, (IMP)revenant_stub_3}, {"Notification", "setFireDate:", 0, (IMP)revenant_stub_4}, {"Plain", "fireDate", 0, (IMP)revenant_stub_5}, {"Newer", "init", 0, (IMP)revenant_stub_6}, {"Newer", "hint", 0, (IMP)revenant_stub_7}, {"Newer", "setHint:", 0, (IMP)revenant_stub_8}, {"Newer", "isLive", 0, (IMP)revenant_stub_9}, {"Newer", "unusedByApp", 0, (IMP)revenant_stub_10}, {"Newer", "futureOnly", 0, (IMP)revenant_stub_11}};
]==]

local INVENTORY = {
    classes = {
        NSObject = {instance = {"init", "description"}, class = {"alloc", "allocWithZone:", "new"}},
        View = {superclass = "NSObject", instance = {"frame"}, class = {}},
        Window = {superclass = "View", instance = {"makeKeyWindow"}, class = {}},
        Notification = {superclass = "NSObject", instance = {"init"}, class = {"alloc", "allocWithZone:"}},
        ConcreteNotification = {superclass = "Notification", instance = {"fireDate", "setFireDate:"}, class = {}},
        Plain = {superclass = "NSObject", instance = {"init"}, class = {}},
        PlainChild = {superclass = "Plain", instance = {"fireDate"}, class = {}},
    },
}

local FACTS = {
    "Fake\tinstance method\tWindow\tcanBecomeKeyWindow\t-[Window canBecomeKeyWindow]\t- (BOOL)canBecomeKeyWindow\t2000\t",
    "Fake\tproperty\tNewer\thint\t-[Newer hint]\t@property BOOL hint\t8000\t",
    "Fake\tproperty\tNewer\tlive\t-[Newer live]\t@property (getter=isLive) BOOL live\t9000\t",
    "Fake\tinstance method\tNewer\tfutureOnly\t-[Newer futureOnly]\t- (void)futureOnly\t17000\t",
    "Fake\tclass method\tWindow\tsharedWindow\t+[Window sharedWindow]\t+ (instancetype)sharedWindow\t4000\t",
    "Fake\tproperty\tNewer\thint\t-[Newer hint]\t@property BOOL hint\t7000\t",
}

local function set_of(list)
    local set = {}
    for _, name in ipairs(list) do
        set[name] = true
    end
    return set
end

local function expect(condition, message)
    assert(condition, message)
end

local function expect_equal(actual, expected, message)
    assert(actual == expected, string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)))
end

local function keys_of(entries)
    local keys = {}
    for _, entry in ipairs(entries) do
        table.insert(keys, entry.key)
    end
    return table.concat(keys, "|")
end

local function test_parsing(folder)
    local parsed = stubs.stubs_of(folder)
    expect_equal(#parsed, 11, "every table entry of a skeleton file is a stub")
    expect_equal(parsed[2].class_method, true, "a class method keeps its flag")
    expect_equal(parsed[1].class_method, false, "an instance method keeps its flag")
    expect_equal(parsed[3].cls .. " " .. parsed[3].selector, "Notification fireDate", "the class and the selector are read")
end

local function test_inventory(file)
    local inventory = stubs.inventory_of(file)
    expect(inventory.responds("Window", "frame", false), "a method of a superclass answers")
    expect(inventory.responds("Window", "init", false), "a method of the root class answers")
    expect(not inventory.responds("Window", "canBecomeKeyWindow", false), "a missing method does not answer")
    expect(inventory.responds("Window", "alloc", true), "a class method of the root class answers a class method")
    expect(not inventory.responds("Window", "frame", true), "an instance method does not answer a class method")
    expect(inventory.responds("Notification", "fireDate", false), "a class that replaces alloc answers for what its concrete subclass answers")
    expect(not inventory.responds("Plain", "fireDate", false), "a class that keeps alloc does not answer for its subclass")
    expect(inventory.responds("Absent", "description", false), "a class the device lacks answers what the root class answers")
    expect(not inventory.responds("Absent", "fireDate", false), "a class the device lacks does not answer anything else")
end

local function test_lowered(file)
    local lowered = stubs.lowered_of(file)
    expect(lowered["-Newer hint"], "a lowered member is read")
    expect(lowered["-Newer setHint:"], "the setter of a lowered property is implied")
    expect(lowered["-Newer setLive:"], "the setter of an is-property is named without the prefix")
    expect(lowered["+Window sharedWindow"], "a lowered class method is read")
    expect(lowered["+Window setSharedWindow:"], "a class property's setter is implied the same way")
    expect(not lowered["-Window frame"], "an unlisted member is not lowered")
end

local function test_intros(folder)
    local intros = stubs.intros_of(folder)
    expect_equal(intros["-Newer hint"], 7000, "the lowest version among duplicate declarations counts")
    expect_equal(intros["-Newer isLive"], 9000, "a property names its is-getter")
    expect_equal(intros["-Newer setHint:"], 7000, "a property names its setter")
    expect_equal(intros["+Window sharedWindow"], 4000, "a class method keeps its sign")
    expect_equal(intros["-Window canBecomeKeyWindow"], 2000, "an instance method is read")
end

local function test_snapshot(skeleton, inventory, facts)
    local parsed = stubs.stubs_of(skeleton)
    local found = stubs.inventory_of(inventory)
    local intros = stubs.intros_of(facts)
    local entries = stubs.snapshot_entries(parsed, found, {
        {classes = set_of({"Window", "Notification", "Newer"}), selectors = set_of({"canBecomeKeyWindow", "sharedWindow", "fireDate", "init", "hint", "setHint:", "isLive", "futureOnly"})},
        {classes = set_of({"Plain"}), selectors = set_of({"fireDate"})},
    }, intros)
    expect_equal(keys_of(entries), "+Window sharedWindow|-Newer futureOnly|-Newer hint|-Newer isLive|-Newer setHint:|-Plain fireDate|-Window canBecomeKeyWindow",
        "a stub is named when some binary has both its class and its selector, and the device does not answer it")
    local with_intro = {}
    for _, entry in ipairs(entries) do
        with_intro[entry.key] = entry.intro
    end
    expect_equal(with_intro["-Newer futureOnly"], 17000, "an entry keeps its introduction version")
    expect_equal(with_intro["-Plain fireDate"], nil, "an entry without a fact has an unknown version")
    local alone = stubs.snapshot_entries(parsed, found, {{classes = set_of({"Window"}), selectors = set_of({"fireDate"})}}, intros)
    expect_equal(#alone, 0, "a class from one binary and a selector from none do not name a stub")
    return entries
end

local function test_snapshot_file(entries, folder)
    local file = path.join(folder, "Fake.snapshot")
    io.writefile(file, stubs.snapshot_text("Fake", 15, entries))
    local read = stubs.snapshot_read(file)
    expect_equal(read.app, "Fake", "the app is kept")
    expect_equal(read.minimum, 15, "the minimum is kept")
    expect_equal(keys_of(read.entries), keys_of(entries), "the entries survive a round trip")
    expect_equal(read.entries[2].intro, 17000, "a version survives a round trip")
    return read
end

local function test_judge(snapshot)
    local none = {}
    local violations, stale = stubs.judge({snapshot}, {["-Newer hint"] = true}, none)
    expect_equal(#violations, 5, "an entry no source lowers and no list allows is a violation, a lowered one is not, and one newer than the minimum is not")
    expect(not table.concat(violations, "\n"):find("futureOnly", 1, true), "an API newer than the app's minimum is guarded in the app")
    expect(table.concat(violations, "\n"):find("-Plain fireDate (SDK iOS unknown)", 1, true) ~= nil, "an unknown version is enforced")
    expect_equal(#stale, 0, "nothing is stale without a list")
    local allowed = {["-Window canBecomeKeyWindow"] = "backlog", ["-Newer hint"] = "backlog", ["-Absent gone"] = "device"}
    violations, stale = stubs.judge({snapshot}, {["-Newer hint"] = true}, allowed)
    expect_equal(#violations, 4, "a listed entry is not a violation")
    expect_equal(#stale, 2, "a listed entry that is lowered, or that no snapshot names, is stale")
    expect(stale[1]:find("-Absent gone", 1, true) ~= nil and stale[2]:find("-Newer hint", 1, true) ~= nil, "the stale entries are named in order")
end

local function test_allowed(folder)
    local file = path.join(folder, "allowed.txt")
    io.writefile(file, "-Window\tcanBecomeKeyWindow\tbacklog\n+Window\tsharedWindow\tdevice\n")
    local allowed = stubs.allowed_read(file)
    expect_equal(allowed["-Window canBecomeKeyWindow"], "backlog", "a reason is read")
    expect_equal(allowed["+Window sharedWindow"], "device", "a class method is read")
    io.writefile(file, "-Window\tcanBecomeKeyWindow\tsoon\n")
    local failed = false
    try {
        function ()
            stubs.allowed_read(file)
        end,
        catch {
            function ()
                failed = true
            end
        }
    }
    expect(failed, "an unknown reason is refused")
    local count = 0
    for _ in pairs(stubs.allowed_read(path.join(folder, "missing.txt"))) do
        count = count + 1
    end
    expect_equal(count, 0, "a missing list is empty")
end

local function test_repository()
    local folder = path.join(tools, "app-stubs")
    local files = os.files(path.join(folder, "*.snapshot"))
    table.sort(files, stubs.bytes_less)
    expect(#files > 0, "a checked-in snapshot names the application's stubs")
    local snapshots, lowered, allowed = {}, stubs.lowered_of(path.join(tools, "lowered-members.txt")), stubs.allowed_read(path.join(folder, "allowed.txt"))
    for _, file in ipairs(files) do
        local snapshot = stubs.snapshot_read(file)
        table.insert(snapshots, snapshot)
        local seen, previous = {}, ""
        for _, entry in ipairs(snapshot.entries) do
            expect(not seen[entry.key], snapshot.app .. " names " .. entry.key .. " twice")
            expect(stubs.bytes_less(previous, entry.key), snapshot.app .. " is not in byte order at " .. entry.key)
            seen[entry.key] = true
            previous = entry.key
        end
    end
    local violations, stale = stubs.judge(snapshots, lowered, allowed)
    expect(#violations == 0, "dangerous stubs:\n" .. table.concat(violations, "\n"))
    expect(#stale == 0, "stale entries:\n" .. table.concat(stale, "\n"))
    local crash = "-AVAudioSession secondaryAudioShouldBeSilencedHint"
    local named = false
    for _, snapshot in ipairs(snapshots) do
        for _, entry in ipairs(snapshot.entries) do
            named = named or entry.key == crash
        end
    end
    expect(named, "the snapshot names the member that aborted Telegram13 on the 4S")
    expect(lowered[crash], "the Backports lower the member that aborted Telegram13 on the 4S")
    local without = {}
    for key in pairs(lowered) do
        without[key] = key ~= crash or nil
    end
    violations = stubs.judge(snapshots, without, allowed)
    expect_equal(#violations, 1, "without its implementation the member that aborted Telegram13 is the one violation")
    expect(violations[1]:find(crash, 1, true) == 1, "and the violation names it")
    return #snapshots
end

function main()
    local root = path.join(workspace.scratch(), "stubs-test")
    os.tryrm(root)
    local skeleton, facts = path.join(root, "skeleton"), path.join(root, "facts")
    os.mkdir(skeleton)
    os.mkdir(facts)
    io.writefile(path.join(skeleton, "Fake.m"), SKELETON)
    io.writefile(path.join(facts, "Fake.tsv"), table.concat(FACTS, "\n") .. "\n")
    io.writefile(path.join(facts, "constant_intros.tsv"), "ignored\n")
    local inventory = path.join(root, "classes.json")
    io.writefile(inventory, json.encode(INVENTORY))
    local lowered = path.join(root, "lowered.txt")
    io.writefile(lowered, "member Newer -hint\nmember Newer -isLive\nmember Window +sharedWindow\nclass Newer\n")
    test_parsing(skeleton)
    test_inventory(inventory)
    test_lowered(lowered)
    test_intros(facts)
    local entries = test_snapshot(skeleton, inventory, facts)
    local snapshot = test_snapshot_file(entries, root)
    test_judge(snapshot)
    test_allowed(root)
    local count = test_repository()
    os.tryrm(root)
    print("stubs tests passed: parsing, device inventory, lowered members, SDK versions, snapshots, judgement and %d checked-in snapshot", count)
end
