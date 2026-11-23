local dyld = import("@addon.revenant.apple.dyld", {anonymous = true})
local byteorder = import("@addon.revenant.byteorder", {anonymous = true})

local ROOT = path.absolute(path.join(os.scriptdir(), "..", "..", ".."))
local BASELINE = path.join(os.scriptdir(), "data", "export-baseline.txt")
local RETIRED = path.join(os.scriptdir(), "data", "export-retired.txt")
local ARCHITECTURE = "armv7"
local USAGE = [=[usage: ./xmakew l -P . frameworks/Backports/tests/export_baseline_test.lua [test | check [FOLDER] | update [FOLDER]]

test    runs the checks of the judge on fixtures (no build needed)
check   reads the export tries of the Backports libraries in FOLDER and fails when a class the baseline lists is gone
update  adds the classes FOLDER exports to the baseline; it never removes a line
FOLDER  defaults to REVENANT_BACKPORTS_LIBRARIES, then to the gate tree's build/iphoneos/armv7/release]=]

local function public_class(symbol)
    local name = symbol:match("^_OBJC_CLASS_%$_(.+)$") or symbol:match("^_OBJC_METACLASS_%$_(.+)$")
    return name ~= nil and not name:find("^Revenant") and not name:find("^_")
end

local function lines_of(file)
    local found = {}
    for line in (io.readfile(file) or ""):gmatch("[^\n]+") do
        table.insert(found, line)
    end
    return found
end

local function read_baseline(file)
    local keys = {}
    for _, line in ipairs(lines_of(file)) do
        local library, symbol = line:match("^(%S+) (%S+)$")
        assert(library and symbol, file .. ": a line is not '<library> <symbol>': " .. line)
        keys[library .. " " .. symbol] = true
    end
    return keys
end

local function read_retired(file)
    local retired = {}
    for _, line in ipairs(lines_of(file)) do
        local library, symbol, reason = line:match("^(%S+) (%S+) (.+)$")
        retired[library and (library .. " " .. symbol) or line] = reason or ""
    end
    return retired
end

-- dyld.load reads a folder named libraries_<architecture>; a build's folder is named for its configuration, so the Backports
-- libraries are cloned (APFS, no copy) into one that is. (toolchain/modules/apple/dyld.lua is an input of the swift-runtime
-- recipe digest, so it is not changed for this.)
local function staged(folder)
    local stage = path.join(os.tmpdir(), "export-baseline-" .. hash.uuid(), "libraries_" .. ARCHITECTURE)
    os.mkdir(stage)
    local count = 0
    for _, file in ipairs(os.files(path.join(folder, "lib*Backports.dylib"))) do
        os.vrunv("cp", {"-c", file, path.join(stage, path.filename(file))})
        count = count + 1
    end
    if count == 0 then
        os.tryrm(path.directory(stage))
        raise("%s holds no lib*Backports.dylib: build the Backports libraries first", folder)
    end
    return stage
end

local function exported_classes(folder)
    local keys = {}
    local stage = staged(folder)
    local cache, failure
    try {
        function ()
            cache = dyld.load(stage)
        end,
        catch {
            function (raised)
                failure = tostring(raised)
            end
        }
    }
    os.tryrm(path.directory(stage))
    if failure then
        raise("%s", failure)
    end
    for install, library in pairs(cache.libraries) do
        local name = path.filename(install)
        if name:match("^lib[%w_]+Backports%.dylib$") then
            for symbol in pairs(library.exports) do
                if public_class(symbol) then
                    keys[name .. " " .. symbol] = true
                end
            end
        end
    end
    return keys
end

function judge(baseline, retired, exported)
    local problems = {}
    for key in pairs(baseline) do
        if not exported[key] and retired[key] == nil then
            table.insert(problems, string.format("%s is no longer exported, and an app linked against the earlier library binds to it: export it again, or list it in export-retired.txt with the reason", key))
        end
    end
    for key, reason in pairs(retired) do
        if reason == "" then
            table.insert(problems, string.format("export-retired.txt lists '%s' without a reason", key))
        elseif not baseline[key] then
            table.insert(problems, string.format("export-retired.txt lists %s, which the baseline does not list", key))
        elseif exported[key] then
            table.insert(problems, string.format("export-retired.txt lists %s, which is exported again: remove the line", key))
        end
    end
    byteorder.sort(problems)
    return problems
end

local function default_folder()
    local named = os.getenv("REVENANT_BACKPORTS_LIBRARIES")
    if named and named ~= "" then
        return named
    end
    return path.join(ROOT, "build", "backports-gate", "tree", "build", "iphoneos", ARCHITECTURE, "release")
end

local function check(folder)
    assert(os.isdir(folder), folder .. " is not built: build the Backports libraries first")
    local problems = judge(read_baseline(BASELINE), read_retired(RETIRED), exported_classes(folder))
    assert(#problems == 0, "the Backports libraries lost exports that earlier builds had:\n  " .. table.concat(problems, "\n  "))
end

local function update(folder)
    assert(os.isdir(folder), folder .. " is not built: build the Backports libraries first")
    local keys = read_baseline(BASELINE)
    local added = 0
    for key in pairs(exported_classes(folder)) do
        if not keys[key] then
            keys[key] = true
            added = added + 1
        end
    end
    local sorted = {}
    for key in pairs(keys) do
        table.insert(sorted, key)
    end
    byteorder.sort(sorted)
    io.writefile(BASELINE, table.concat(sorted, "\n") .. "\n")
    print("the baseline lists %d symbols, %d of them new", #sorted, added)
end

local function problems_of(baseline, retired, exported)
    return table.concat(judge(baseline, retired, exported), "\n")
end

local function self_test()
    local A, B = "libAVFoundationBackports.dylib _OBJC_CLASS_$_AVSampleBufferDisplayLayer", "libAVFoundationBackports.dylib _OBJC_METACLASS_$_AVSampleBufferDisplayLayer"
    local C = "libFoundationBackports.dylib _OBJC_CLASS_$_NSURLComponents"
    local baseline = {[A] = true, [B] = true, [C] = true}
    assert(problems_of(baseline, {}, {[A] = true, [B] = true, [C] = true}) == "", "a build that exports everything the baseline lists is refused")
    assert(problems_of(baseline, {}, {[A] = true, [B] = true, [C] = true, ["libX.dylib _OBJC_CLASS_$_New"] = true}) == "", "a new export is refused")
    local lost = problems_of(baseline, {}, {[C] = true})
    assert(lost:find(A, 1, true) and lost:find(B, 1, true) and not lost:find(C, 1, true), "a lost class and metaclass are not both named: " .. lost)
    local moved = problems_of(baseline, {}, {[B] = true, [C] = true, ["libOtherBackports.dylib _OBJC_CLASS_$_AVSampleBufferDisplayLayer"] = true})
    assert(moved:find(A, 1, true), "a class that moved to another library is accepted")
    assert(problems_of(baseline, {[A] = "the system exports it"}, {[B] = true, [C] = true}) == "", "a retired export with a reason is refused")
    assert(problems_of(baseline, {[A] = ""}, {[B] = true, [C] = true}):find("without a reason", 1, true), "a retired export without a reason is accepted")
    assert(problems_of(baseline, {[A] = "the system exports it"}, {[A] = true, [B] = true, [C] = true}):find("exported again", 1, true), "a retired export that is back is accepted")
    assert(problems_of(baseline, {["libNone.dylib _OBJC_CLASS_$_Never"] = "gone"}, {[A] = true, [B] = true, [C] = true}):find("does not list", 1, true), "a retired line the baseline does not list is accepted")
    assert(public_class("_OBJC_CLASS_$_UIDevice") and public_class("_OBJC_METACLASS_$_UIDevice"), "an SDK class is not public")
    assert(not public_class("_OBJC_CLASS_$_RevenantTapPump") and not public_class("_OBJC_CLASS_$__TtC3Foo3Bar") and not public_class("_OBJC_IVAR_$_UIDevice.x"), "an internal symbol is public")
    print("export baseline test: 10 checks passed")
end

function main(verb, folder)
    if verb == nil or verb == "test" then
        return self_test()
    elseif verb == "check" then
        return check(folder or default_folder())
    elseif verb == "update" then
        return update(folder or default_folder())
    end
    raise("unknown verb %s\n%s", verb, USAGE)
end
