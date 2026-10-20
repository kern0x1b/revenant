local revenant = path.absolute(path.join(os.scriptdir(), "..", "..", ".."))
local workspace = import("workspace", {rootdir = path.join(revenant, "modules"), anonymous = true})
local mutator = import("mutate", {rootdir = path.join(os.scriptdir(), "..", "host", "common"), anonymous = true})

local COPIED = {"RevenantAXSettings.h", "RevenantAXSettingsCommon.h", "RevenantAXSettings17.m", "RevenantAXSettings18.m",
                "RevenantAXSettings26.m", "RevenantHearing15.m"}

local CRASHED = "the settings check died of a signal before it could finish"

MUTATIONS = {
    {"M1-value-yes", "RevenantAXSettingsCommon.h", 1,
     "    return NO;\n}",
     "    return YES;\n}"},
    {"M2-posts-a-change", "RevenantAXSettings17.m", 1,
     "BOOL AXAnimatedImagesEnabled(void)\n{\n    return RevenantAXSettingIsOffOnThisRelease();\n}",
     "BOOL AXAnimatedImagesEnabled(void)\n{\n    [[NSNotificationCenter defaultCenter]\n"
     .. "        postNotificationName:AXAnimatedImagesEnabledDidChangeNotification object:nil];\n"
     .. "    return RevenantAXSettingIsOffOnThisRelease();\n}"},
    {"M3-completion-never-called", "RevenantAXSettings18.m", 1,
     "    if (!completionHandler) {\n        return;\n    }",
     "    if (completionHandler || !completionHandler) {\n        return;\n    }"},
    {"M4-completion-called-twice", "RevenantAXSettings18.m", 1,
     "    completionHandler([NSError errorWithDomain:RevenantAXSettingsErrorDomain code:feature userInfo:@{\n"
     .. "        NSLocalizedDescriptionKey: reason,\n        @\"AXSettingsFeature\": @(feature),\n    }]);",
     "    NSError *first = [NSError errorWithDomain:RevenantAXSettingsErrorDomain code:feature userInfo:@{\n"
     .. "        NSLocalizedDescriptionKey: reason,\n        @\"AXSettingsFeature\": @(feature),\n    }];\n"
     .. "    completionHandler(first);\n    completionHandler(first);"},
    {"M5-completion-called-later", "RevenantAXSettings18.m", 1,
     "    completionHandler([NSError errorWithDomain:RevenantAXSettingsErrorDomain code:feature userInfo:@{",
     "    NSError *deferred = [NSError errorWithDomain:RevenantAXSettingsErrorDomain code:feature userInfo:@{\n"
     .. "        NSLocalizedDescriptionKey: reason,\n        @\"AXSettingsFeature\": @(feature),\n    }];\n"
     .. "    dispatch_async(dispatch_get_main_queue(), ^{\n        completionHandler(deferred);\n    });\n"
     .. "    if (0) completionHandler([NSError errorWithDomain:RevenantAXSettingsErrorDomain code:feature userInfo:@{"},
    {"M6-system-domain", "RevenantAXSettings18.m", 1,
     "NSErrorDomain const RevenantAXSettingsErrorDomain = @\"org.revenant.Accessibility.Settings\";",
     "NSErrorDomain const RevenantAXSettingsErrorDomain = @\"com.apple.Accessibility.Settings\";"},
    {"M7-wrong-code", "RevenantAXSettings18.m", 1,
     "    completionHandler([NSError errorWithDomain:RevenantAXSettingsErrorDomain code:feature userInfo:@{",
     "    completionHandler([NSError errorWithDomain:RevenantAXSettingsErrorDomain code:0 userInfo:@{"},
    {"M8-constant-renamed", "RevenantAXSettings26.m", 1,
     "    @\"AXShowBordersEnabledStatusDidChangeNotification\";",
     "    @\"AXShowBordersEnabledStatusDidChange\";"},
    {"M9-hearing-ear-not-defined", "RevenantHearing15.m", 1,
     "AXHearingDeviceEar AXMFiHearingDeviceStreamingEar(void)",
     "static AXHearingDeviceEar revenant_port_unused(void)"},
    {"M10-null-completion-crashes", "RevenantAXSettings18.m", 1,
     "    if (!completionHandler) {\n        return;\n    }",
     "    if (!completionHandler) {\n        completionHandler(nil);\n        return;\n    }", true},
    {"M11-control-path-only", "RevenantAXSettings17.m", 1,
     "    return RevenantAXSettingIsOffOnThisRelease();",
     "    return RevenantAXSettingIsOffOnThisRelease();"}
}

local function lines_of(text)
    local lines = text:split("\n", {strict = true})
    if lines[#lines] == "" then
        table.remove(lines)
    end
    return lines
end

local function first_line(text, wanted)
    for _, line in ipairs(lines_of(text)) do
        if line:find(wanted, 1, true) then
            return line
        end
    end
end

local function last_lines(text, count)
    local lines = lines_of(text)
    return table.concat(lines, "\n", math.max(1, #lines - count + 1))
end

local function run_check(dir)
    local output = path.join(dir, "out.txt")
    local file = io.open(output, "w")
    local status = os.execv(os.programfile(), {"l", path.join(os.scriptdir(), "run.lua")},
                            {envs = {ACCESSIBILITY_SRC = dir, BUILD = path.join(dir, "build")}, stdout = file, stderr = file, try = true})
    file:close()
    return status, io.readfile(output) or ""
end

function run(opt)
    opt = opt or {}
    local package = path.join(revenant, "packages", "frameworks", "apple-backports")
    local sources = opt.sources or path.join(package, "Accessibility")
    local work = opt.build or workspace.run("revenant-accessibility-settings-mutants")
    os.tryrm(work)
    os.mkdir(work)
    local counts = {ran = 0, killed = 0, run_failed = 0, survived = 0, control_green = 0}
    for _, mutation in ipairs(opt.mutations or MUTATIONS) do
        local name, file, nth, old, new, crash_is_kill = table.unpack(mutation, 1, 6)
        local dir = path.join(work, name)
        os.mkdir(dir)
        if os.isfile(path.join(sources, "Accessibility.m")) then
            os.cp(path.join(sources, "Accessibility.m"), dir)
        end
        for _, each in ipairs(COPIED) do
            os.cp(path.join(sources, each), path.join(dir, each))
        end
        if os.isfile(path.join(package, "RevenantSayOnce.h")) then
            os.cp(path.join(package, "RevenantSayOnce.h"), dir)
        end
        local applied, refusal = mutator.mutate(path.join(dir, file), old, new, nth)
        io.writefile(path.join(dir, "mutate.log"), applied and "" or (refusal .. "\n"))
        if not applied then
            print(string.format("MUTANT DID NOT APPLY: %s: %s", name, refusal))
            counts.run_failed = counts.run_failed + 1
        else
            counts.ran = counts.ran + 1
            local status, output = run_check(dir)
            if status == 0 then
                if old == new then
                    counts.control_green = counts.control_green + 1
                    print("control stayed green through the same path: " .. name)
                else
                    print("MUTANT SURVIVED: " .. name)
                    counts.survived = counts.survived + 1
                end
            elseif output:find("FAILED", 1, true) then
                counts.killed = counts.killed + 1
                print(string.format("killed: %s: %s", name, first_line(output, "FAILED")))
            elseif crash_is_kill and output:find(CRASHED, 1, true) then
                counts.killed = counts.killed + 1
                print(string.format("killed: %s: the program died on a null completion, which is the behaviour being broken", name))
            elseif output:find("did not build", 1, true) or output:find("error:", 1, true) then
                counts.run_failed = counts.run_failed + 1
                print(string.format("RUN FAILED (not counted as noticed): %s: %s", name, first_line(output, "error:") or ""))
            else
                counts.run_failed = counts.run_failed + 1
                print("MUTANT DIED FOR THE WRONG REASON: " .. name)
                print(last_lines(output, 4))
            end
        end
    end
    print(string.format("mutants run: %d, killed: %d, controls stayed green: %d, run failed: %d, survived: %d",
                        counts.ran, counts.killed, counts.control_green, counts.run_failed, counts.survived))
    counts.passed = counts.survived == 0 and counts.run_failed == 0 and counts.control_green == 1
                    and counts.killed + counts.control_green == counts.ran
    return counts
end

function main()
    local source = os.getenv("ACCESSIBILITY_SRC")
    local build = os.getenv("BUILD")
    local counts = run({sources = source ~= "" and source or nil, build = build ~= "" and build or nil})
    if not counts.passed then
        os.exit(1)
    end
end
