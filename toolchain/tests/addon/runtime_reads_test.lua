local function copy_without(set, class, key)
    local copy = {}
    for name, value in pairs(set) do
        copy[name] = value
    end
    copy.classes = {}
    for name, members in pairs(set.classes) do
        copy.classes[name] = members
    end
    local members = {}
    for name, value in pairs(set.classes[class]) do
        if name ~= key then
            members[name] = value
        end
    end
    copy.classes[class] = members
    return copy
end

local function witness(lowered, set, files)
    for _, file in ipairs(files) do
        local text = io.readfile(file)
        if text:find("@interface", 1, true) then
            local seen = {}
            for class in text:gmatch("@interface%s+([%a_][%w_]*)") do
                local members = set.classes[class]
                if members and not seen[class] then
                    seen[class] = true
                    local before = lowered.lower_header(text, set)
                    local tries = 0
                    for key in pairs(members) do
                        tries = tries + 1
                        if tries > 12 then
                            break
                        end
                        if before ~= text and lowered.lower_header(text, copy_without(set, class, key)) ~= before then
                            return {file = file, class = class, key = key}
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function raises(action)
    local message
    try {
        action,
        catch {
            function (raised)
                message = tostring(raised)
            end
        }
    }
    return message
end

function failures(opt)
    local found = {}
    local function check(condition, message)
        if not condition then
            table.insert(found, message)
        end
    end
    local lowered = import("@addon.revenant.apple.lowered", {anonymous = true})
    local reads = import("@addon.revenant.apple.runtime_reads", {anonymous = true})
    local workspace = import("@addon.revenant.workspace", {anonymous = true})
    local byteorder = import("byteorder", {rootdir = opt.modules, anonymous = true})
    local sdk = workspace.sdk()
    local set = lowered.read_all_members()
    local listed = reads.headers()

    check(#listed > 0, "toolchain/src/swift-runtime/reads/lowered-reads.txt lists no header")
    local previous = ""
    for _, relative in ipairs(listed) do
        check(byteorder.less(previous, relative), "lowered-reads.txt is not in byte order and unique at " .. relative)
        check(relative:endswith(".h"), "lowered-reads.txt lists a file that is not a header: " .. relative)
        check(os.isfile(path.join(sdk, relative)), "lowered-reads.txt lists " .. relative .. ", which the SDK does not have")
        previous = relative
    end

    local allowed = reads.allowed_headers()
    local inside, outside = {}, {}
    for _, relative in ipairs(listed) do
        if relative:startswith("System/Library/Frameworks/") then
            table.insert(inside, path.join(sdk, relative))
        end
    end
    for _, file in ipairs(os.files(path.join(sdk, "System", "Library", "Frameworks", "*.framework", "Headers", "*.h"))) do
        if not allowed[path.relative(file, sdk)] then
            table.insert(outside, file)
        end
    end
    table.sort(outside)
    local listed_witness = witness(lowered, set, inside)
    local unlisted_witness = witness(lowered, set, outside)
    check(listed_witness ~= nil, "no listed header has a member whose removal changes its lowering: the digest cannot be tested")
    check(unlisted_witness ~= nil, "no unlisted framework header has a member whose removal changes its lowering: the digest cannot be tested")
    if listed_witness and unlisted_witness then
        local relative = path.relative(listed_witness.file, sdk)
        local own = {relative}
        local base = reads.lowered_rows(sdk, set, own)
        check(reads.lowered_rows(sdk, set, own) == base, "the digest of the lowered text is not stable")
        check(reads.lowered_rows(sdk, copy_without(set, listed_witness.class, listed_witness.key), own) ~= base,
              "a member removed from " .. listed_witness.class .. " lowers " .. relative .. " differently and leaves the digest")
        check(reads.lowered_rows(sdk, copy_without(set, unlisted_witness.class, unlisted_witness.key), own) == base,
              "a member removed from " .. unlisted_witness.class .. ", declared in the unlisted " .. path.relative(unlisted_witness.file, sdk) .. ", moves the digest")

        local only = {[listed_witness.file] = true, [unlisted_witness.file] = true}
        local changed = lowered.lowered_texts(sdk, set, {}, only)
        local kept = changed[listed_witness.file]
        lowered.closed_to(sdk, changed, {[relative] = true})
        check(changed[listed_witness.file] == kept and not kept:startswith("#error"), "the overlay replaces the listed header " .. relative)
        local stub = changed[unlisted_witness.file]
        check(stub ~= nil and stub:startswith("#error") and stub:find(path.relative(unlisted_witness.file, sdk), 1, true),
              "an unlisted lowered header is not replaced by an error naming it: " .. tostring(stub))
    end

    local root = workspace.fresh("runtime-reads-test")
    local folder = path.join(root, "stdlib", "public", "Darwin", "Fixture")
    os.mkdir(folder)
    io.writefile(path.join(folder, "Fixture.swift"), "@available(macOS 10.10, iOS 8.0, *)\npublic func fixtureCall() {}\n")
    local seen = {}
    lowered.lower_swift_overlay_folder(root, "Fixture", {classes = {}}, function (key)
        seen[key] = true
    end)
    check(seen["name fixtureCall"] == true, "the Swift lowering did not report the lookup of fixtureCall")
    local message = raises(function ()
        lowered.lower_swift_overlay_folder(root, "Fixture", {classes = {}}, reads.lookup_check({"name otherCall"}).note)
    end)
    check(message ~= nil and message:find("name fixtureCall", 1, true), "a lookup that the list does not hold does not fail the build: " .. tostring(message))
    check(raises(function ()
        lowered.lower_swift_overlay_folder(root, "Fixture", {classes = {}}, reads.lookup_check({"name fixtureCall"}).note)
    end) == nil, "a listed lookup fails the build")
    local keys = {"name fixtureCall"}
    local without = reads.swift_digest({classes = {}}, keys)
    check(reads.swift_digest({classes = {NSFixture = {["-fixtureCall"] = true}}}, keys) ~= without, "a member the lowering looked up does not move the Swift digest")
    check(reads.swift_digest({classes = {NSFixture = {["-otherCall"] = true}}}, keys) == without, "a member the lowering never looked up moves the Swift digest")

    local pair = {"name firstCall", "name secondCall"}
    local partial = reads.lookup_check(pair)
    partial.note("name firstCall")
    local stale = raises(function ()
        partial.finish(true)
    end)
    check(stale ~= nil and stale:find("name secondCall", 1, true) and stale:find("never made", 1, true),
          "a listed lookup that a complete build never made is not reported: " .. tostring(stale))
    check(raises(function ()
        partial.finish(false)
    end) == nil, "an incomplete build (arm64 skips AVFoundation) reports a listed lookup it never made")
    local whole = reads.lookup_check(pair)
    whole.note("name firstCall")
    whole.note("name secondCall")
    check(raises(function ()
        whole.finish(true)
    end) == nil, "a complete build that made every listed lookup is reported")

    local variable = reads.record_variable()
    local before = {record = os.getenv(variable), out = os.getenv("REVENANT_PREBUILT_OUT")}
    local recorded = path.join(root, "recorded")
    local release = path.join(root, "release")
    os.setenv(variable, recorded)
    os.setenv("REVENANT_PREBUILT_OUT", release)
    local recorder = reads.lookup_check(pair)
    recorder.note("name secondCall")
    recorder.note("name unlistedCall")
    check(raises(function ()
        recorder.finish(true)
    end) == nil, "a recording run reports a listed lookup it never made")
    local written = path.join(recorded, "swift-overlay-reads.txt")
    check(os.isfile(written) and io.readfile(written) == "name secondCall\nname unlistedCall\n", "the recording does not hold the sorted lookups the run made")
    local prebuilt = import("prebuilt", {rootdir = opt.modules, anonymous = true})
    local refused = raises(function ()
        prebuilt.pack({name = function () return "swift-runtime" end})
    end)
    check(refused ~= nil and refused:find(variable, 1, true) and refused:find("must not be packed", 1, true),
          "a build that records the lookups can pack a prebuilt archive: " .. tostring(refused))
    check(not os.isdir(release), "the refused pack created the release folder")
    os.setenv(variable, before.record or "")
    os.setenv("REVENANT_PREBUILT_OUT", before.out or "")

    local sdks = {a = path.join(root, "sdk-a"), b = path.join(root, "sdk-b"), c = path.join(root, "sdk-c")}
    for name, folder in pairs(sdks) do
        os.mkdir(path.join(folder, "usr", "include"))
        io.writefile(path.join(folder, "usr", "include", "a.h"), name == "c" and "int b;\n" or "int a;\n")
    end
    check(reads.lowered_key(sdks.a) == reads.lowered_key(sdks.b), "the same SDK content under two paths gets two lowered-digest cache keys")
    check(reads.lowered_key(sdks.a) ~= reads.lowered_key(sdks.c), "an SDK header that differs does not move the lowered-digest cache key")
    os.tryrm(root)
    return found
end
