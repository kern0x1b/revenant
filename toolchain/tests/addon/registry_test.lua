import("fixtures")

local function one_minimum_step(backports, root, found)
    local tool = import("registry-one-minimum", {rootdir = path.join(root, "..", "..", "..", "toolchain", "tools")})
    local work = path.join(fixtures.scratch(), "one-minimum")
    os.rm(work)
    os.mkdir(path.join(work, "registry", "RevenantThing"))
    os.mkdir(path.join(work, "RevenantThing"))
    io.writefile(path.join(work, "RevenantThing", "RevenantMixedA.m"),
        "#import <Foundation/Foundation.h>\n"
        .. "@implementation RevenantMixedOne\n@end\n"
        .. "@implementation RevenantMixedTwo\n@end\n")
    io.writefile(path.join(work, "RevenantThing", "RevenantMixedB.m"),
        "#import <Foundation/Foundation.h>\n"
        .. "@implementation RevenantMixedThree\n@end\n"
        .. "@implementation RevenantMixedFour\n@end\n")
    io.writefile(path.join(work, "RevenantThing", "RevenantClean.m"),
        "#import <Foundation/Foundation.h>\n"
        .. "@implementation RevenantCleanOne\n@end\n")
    local entries = {}
    for _, row in ipairs({{"RevenantMixedOne", ""}, {"RevenantMixedTwo", "6.0"},
                           {"RevenantMixedThree", "7.0"}, {"RevenantMixedFour", "6.0"},
                           {"RevenantCleanOne", "6.0"}}) do
        table.insert(entries, string.format('{"api": "%s", "kind": "class", "introduced": "9.0",'
            .. ' "status": "implemented", "reason": "a fixture", "effect": "a fixture",'
            .. ' "minimum": "%s"}', row[1], row[2]))
    end
    io.writefile(path.join(work, "registry", "RevenantThing", "values.json"),
        '{"framework": "RevenantThing", "entries": [' .. table.concat(entries, ",") .. "]}")
    local mixed = tool.offenders(work)
    local by_object, objects = {}, 0
    for _, one in ipairs(mixed) do
        by_object[path.filename(one.object)] = one
        objects = objects + 1
    end
    if not by_object["RevenantMixedA.m"] then
        table.insert(found, "one minimum per object: RevenantMixedA.m holds a row with no minimum beside"
            .. " one at 6.0 and must be refused, and the rule did not name it")
    else
        if #by_object["RevenantMixedA.m"].minimums ~= 2 then
            table.insert(found, "one minimum per object: RevenantMixedA.m must be named as holding none"
                .. " and 6.0, and it names " .. table.concat(by_object["RevenantMixedA.m"].minimums, " and "))
        end
    end
    if not by_object["RevenantMixedB.m"] then
        table.insert(found, "one minimum per object: RevenantMixedB.m holds 6.0 and 7.0, two values, and"
            .. " must be refused, and the rule did not name it")
    end
    if by_object["RevenantClean.m"] then
        table.insert(found, "one minimum per object: RevenantClean.m holds every row at 6.0 and must not"
            .. " be named, and the rule named it")
    end
    if objects ~= 2 then
        table.insert(found, string.format("one minimum per object: the fixture holds three objects and"
            .. " exactly two of them mix, and the rule named %d", objects))
    end
    local scoped = tool.offenders(path.join(root, "..", "..", "..", "packages", "frameworks", "apple-backports"), "Foundation")
    for _, one in ipairs(scoped) do
        if path.filename(one.object) ~= "NSURLSessionWebSocket13.m" then
            table.insert(found, "one minimum per object: Foundation holds one object that mixes and the"
                .. " rule named " .. path.filename(one.object) .. " as well")
        end
    end
end

local function range_step(backports, folder, found)
    local work = path.join(folder, "range")
    os.mkdir(path.join(work, "registry"))
    local entries = {}
    for _, row in ipairs({{"range_early", "4.3"}, {"range_late", "6.0"}, {"range_both_early", "4.3"}, {"range_both_late", "6.0"}, {"range_caller", "4.3"}, {"range_sharer", "4.3"}}) do
        table.insert(entries, string.format('{"api": "%s", "kind": "function", "introduced": "9.0", "minimum": "%s", "status": "implemented"}', row[1], row[2]))
    end
    io.writefile(path.join(work, "registry", "range.json"), '{"framework": "Range", "entries": [' .. table.concat(entries, ", ") .. ']}\n')
    local listed = backports.registry(work, work)
    local api = "__attribute__((visibility(\"default\"))) "
    local early = fixtures.object(work, "early", api .. "int range_early(void) { return 4; }\n")
    local late = fixtures.object(work, "late", "int range_shared(void);\n" .. api .. "int range_late(void) { return range_shared() + 6; }\n")
    local helper = fixtures.object(work, "helper", "int range_shared(void) { return 0; }\n")
    local installer = fixtures.object(work, "installer", "static int installed;\n__attribute__((constructor)) static void install(void) { installed = 1; }\n")
    local mixed = fixtures.object(work, "mixed", api .. "int range_both_early(void) { return 4; }\n" .. api .. "int range_both_late(void) { return 6; }\n")
    local caller = fixtures.object(work, "caller", "int range_late(void);\n" .. api .. "int range_caller(void) { return range_late(); }\n")
    local sharer = fixtures.object(work, "sharer", "int range_shared(void);\n" .. api .. "int range_sharer(void) { return range_shared() + 4; }\n")
    local upward = fixtures.object(work, "upward", "int range_late(void);\nstatic int installed;\n__attribute__((constructor)) static void install(void) { installed = range_late(); }\n")
    local objects = {early, late, helper, installer}
    local minimums, problems, unreached = backports.minimums(listed, objects, "armv7", "4.3")
    if #problems > 0 or minimums[early] or minimums[late] ~= "6.0" or minimums[helper] ~= "6.0" or minimums[installer] or table.concat(unreached, ",") ~= installer then
        table.insert(found, string.format("for iOS 4.3 the 6.0 object and the helper it calls are carried from 6.0 and the installer is unreached, not early %s late %s helper %s installer %s, unreached %s, refused %s",
                                          tostring(minimums[early]), tostring(minimums[late]), tostring(minimums[helper]), tostring(minimums[installer]), table.concat(unreached, ","), table.concat(problems, "; ")))
    end
    local kept, _, left = backports.band({}, objects, nil, {release = "4.3", minimums = minimums})
    if table.concat(kept, ",") ~= table.concat({early, installer}, ",") or table.concat(left, ",") ~= table.concat({late, helper}, ",") then
        table.insert(found, "the band for iOS 4.3 keeps the 4.3 object and the installer and leaves the 6.0 object and its helper out, not keep " .. table.concat(kept, ",") .. " and leave " .. table.concat(left, ","))
    end
    kept, _, left = backports.band({}, objects, nil, {release = "6.0", minimums = minimums})
    if #kept ~= 4 or #left ~= 0 then
        table.insert(found, string.format("the band for iOS 6.0 keeps all four objects, not %d with %d left out", #kept, #left))
    end
    _, problems = backports.minimums(listed, {mixed}, "armv7", "4.3")
    if #problems ~= 1 or not problems[1]:find("range_both_early", 1, true) or not problems[1]:find("range_both_late", 1, true) then
        table.insert(found, "an object holding entries of minimums 4.3 and 6.0 must be refused for iOS 4.3 naming both: " .. table.concat(problems, "; "))
    end
    _, problems = backports.minimums(listed, {mixed}, "armv7", "6.0")
    if #problems ~= 0 then
        table.insert(found, "for iOS 6.0 neither minimum bounds anything, so the mixed object is not refused: " .. table.concat(problems, "; "))
    end
    _, problems = backports.minimums(listed, {early, late, helper, caller}, "armv7", "4.3")
    if #problems ~= 1 or not problems[1]:find("caller.o", 1, true) or not problems[1]:find("_range_late", 1, true) then
        table.insert(found, "an object the registry carries at 4.3 that calls the 6.0 object must be refused naming both: " .. table.concat(problems, "; "))
    end
    local shared = {early, late, helper, sharer}
    minimums, problems = backports.minimums(listed, shared, "armv7", "4.3")
    if #problems > 0 or minimums[helper] or minimums[sharer] or minimums[late] ~= "6.0" then
        table.insert(found, string.format("a helper called by the 4.3 and the 6.0 object is carried with the 4.3 one, not helper %s sharer %s late %s, refused %s",
                                          tostring(minimums[helper]), tostring(minimums[sharer]), tostring(minimums[late]), table.concat(problems, "; ")))
    end
    kept, _, left = backports.band({}, shared, nil, {release = "4.3", minimums = minimums})
    if table.concat(kept, ",") ~= table.concat({early, helper, sharer}, ",") or table.concat(left, ",") ~= late then
        table.insert(found, "the band for iOS 4.3 keeps the helper the 4.3 object calls and leaves only the 6.0 object out, not keep " .. table.concat(kept, ",") .. " and leave " .. table.concat(left, ","))
    end
    local upwards = {early, late, helper, upward}
    local inherited
    minimums, problems, unreached, inherited = backports.minimums(listed, upwards, "armv7", "4.3")
    local from = inherited[upward]
    if #problems > 0 or #unreached > 0 or minimums[upward] ~= "6.0" or not from or from.from ~= late or from.symbol ~= "_range_late" then
        table.insert(found, string.format("an installer that calls the 6.0 object takes 6.0 from it by _range_late, not %s from %s by %s, unreached %s, refused %s",
                                          tostring(minimums[upward]), tostring(from and from.from), tostring(from and from.symbol), table.concat(unreached, ","), table.concat(problems, "; ")))
    end
    kept, _, left = backports.band({}, upwards, nil, {release = "4.3", minimums = minimums})
    if table.concat(kept, ",") ~= early or table.concat(left, ",") ~= table.concat({late, helper, upward}, ",") then
        table.insert(found, "the band for iOS 4.3 leaves the installer that calls the 6.0 object out with it, not keep " .. table.concat(kept, ",") .. " and leave " .. table.concat(left, ","))
    end
    kept, _, left = backports.band({}, upwards, nil, {release = "6.0", minimums = minimums})
    if #kept ~= 4 or #left ~= 0 then
        table.insert(found, string.format("the band for iOS 6.0 keeps the installer that calls the 6.0 object, not %d kept with %d left out", #kept, #left))
    end
end

local function type_rows(backports, found)
    local root = fixtures.scratch()
    os.tryrm(root)
    os.mkdir(root)
    os.mkdir(path.join(root, "Revenant"))
    os.mkdir(path.join(root, "registry"))
    io.writefile(path.join(root, "Revenant", "RevenantFixture.h"),
                 "#import <Foundation/Foundation.h>\n// key pairs\ntypedef NSUInteger FixturedType;\ntypedef NS_ENUM(NSInteger, FixturedKind) {\n    FixturedCaseOne = 1,\n    FixturedCaseTwo = 2,\n};\n")
    local function told(rows)
        io.writefile(path.join(root, "registry", "Fix.json"), string.format('{"framework": "Fix", "entries": [%s]}', table.concat(rows, ", ")))
        local message
        local passed = try {
            function () backports.check_registry(root, root, {classes = {}, members = {}, symbols = {}}, true, "6.1.3", {}, nil) return true end,
            catch {function (errors) message = tostring(errors) end}
        }
        return (passed and "the check passed, nothing was held unbuilt") or message or "raised with no message"
    end
    local function row(api, kind)
        return string.format('{"api": "%s", "kind": "%s", "introduced": "11.0", "minimum": "6.0", "status": "implemented", "facts": "f"}', api, kind)
    end
    local refused = told({row("FixturedType", "type"), row("FixturedKind", "type"), row("FixturedCaseOne", "case")})
    if refused ~= "the check passed, nothing was held unbuilt" then
        table.insert(found, "a type and an enumeration case a Revenant header declares must not be held unbuilt: " .. refused)
    end
    local sdk = path.join(root, "fake-sdk")
    os.mkdir(path.join(sdk, "usr"))
    os.mkdir(path.join(sdk, "usr", "include"))
    io.writefile(path.join(sdk, "usr", "include", "Fake.h"), "typedef int FixturedSdkType;\n")
    io.writefile(path.join(root, "registry", "Fix.json"), string.format('{"framework": "Fix", "entries": [%s]}', row("FixturedSdkType", "type")))
    local message
    local passed = try {
        function () backports.check_registry(root, root, {classes = {}, members = {}, symbols = {}}, true, "6.1.3", {}, nil, sdk) return true end,
        catch {function (errors) message = tostring(errors) end}
    }
    if (passed and "the check passed, nothing was held unbuilt") ~= "the check passed, nothing was held unbuilt" then
        table.insert(found, "a type the SDK's headers declare must not be held unbuilt, and the SDK search is not reaching that answer: " .. tostring(message))
    end

    local absent = told({row("FixturedAbsent", "type"), row("FixturedCaseAbsent", "case")})
    for _, name in ipairs({"FixturedAbsent", "FixturedCaseAbsent"}) do
        if not absent:find(name, 1, true) then
            table.insert(found, "a type no header declares is still red, and the run must name " .. name .. ": " .. absent)
        end
    end
    local rows = backports.registry(root, root)
    told({string.format('{"api": "FixturedFree()", "kind": "function", "introduced": "11.0", "minimum": "6.0", "status": "implemented", "facts": "f"}')})
    rows = backports.registry(root, root)
    if (rows["FixturedFree()"] or {}).kind ~= "function" then
        table.insert(found, "a function is not read out of the registry at all, so nothing can look it up")
    end
    told({row("FixturedType", "type"), row("FixturedKind", "type"), row("FixturedCaseOne", "case")})
    local listed = backports.registry(root, root)
    for _, name in ipairs({"FixturedType", "FixturedKind", "FixturedCaseOne"}) do
        if (listed[name] or {}).kind == nil then
            table.insert(found, "the registry does not list " .. name .. " at all")
        end
    end
    os.tryrm(root)
end



local function member_and_protocol_rows(backports, found)
    local root = fixtures.scratch()
    os.tryrm(root)
    os.mkdir(root)
    os.mkdir(path.join(root, "registry"))
    local function rows(text)
        io.writefile(path.join(root, "registry", "Fix.json"), '{"framework": "Fix", "entries": [' .. text .. ']}')
    end
    local inventory = {classes = {FixClass = {image = true, instance = {}, ["+"] = {}},
                                   FixProtocol = {image = true, instance = {}, ["+"] = {}}}}
    local function asked(members, symbols, withProtocol)
        local classes = {FixClass = withProtocol and true or true}
        if withProtocol then
            classes = {FixClass = true}
        end
        local message
        local ok = try {
            function () backports.check_registry(root, root, {classes = classes, members = members, symbols = symbols or {}},
                                                  true, "6.1.3", {}, inventory) return true end,
            catch {function (errors) message = tostring(errors) end}
        }
        return (ok and "passed" or message or "raised with no message")
    end
    local class = '{"api": "FixClass", "kind": "class", "introduced": "9.0", "minimum": "6.0", "status": "implemented", "facts": "f"}'
    local protocol = '{"api": "FixProtocol", "kind": "protocol", "introduced": "9.0", "minimum": "6.0", "status": "implemented", "facts": "f"}'
    rows(class)
    local member = {["-[FixClass extra]"] = true}
    if not asked(member):find("FixClass", 1, true) then
        table.insert(found, "a category method on a class the release carries must be red without a row of its own, and it is not: " .. asked(member))
    end
    rows(class .. ',{"api": "-[FixClass extra]", "kind": "method", "introduced": "9.0", "minimum": "6.0", "status": "implemented", "facts": "f"}')
    local said = asked(member)
    if said:find("FixClass") then
        table.insert(found, "a category method with a row of its own must pass, and it is red: " .. said)
    end
    local function named(members)
        local named_rows = {}
        local message
        local ok = try {
            function ()
                local _, _, class_only = backports.check_registry(root, root, {classes = {FixClass = true}, members = members or {}, symbols = {}},
                                                                  true, "6.1.3", {}, inventory)
                for _, name in ipairs(class_only or {}) do table.insert(named_rows, name) end
                return true
            end,
            catch {function (errors) message = tostring(errors) end}
        }
        return (ok and table.concat(named_rows, " ") or ("raised: " .. tostring(message)))
    end
    local with_member, without = named(member), named({})
    if with_member:find("-[FixClass extra]", 1, true) then
        table.insert(found, "a member row a member answers must not be named as answered by its class alone, and it is: " .. with_member)
    end
    if not without:find("-[FixClass extra]", 1, true) then
        table.insert(found, "a member row with no member behind it must be named in the class-alone list, and it is not: " .. without)
    end
    inventory.classes.FixCategory = {image = true, instance = {}, ["+"] = {}}
    rows(class .. ',{"api": "FixCategory.iOSAppOnFix", "kind": "property", "introduced": "9.0", "minimum": "6.0", "status": "implemented", "facts": "f"}')
    said = asked({["-[FixCategory isiOSAppOnFix]"] = true})
    if said:find("FixCategory", 1, true) then
        table.insert(found, "a getter=isiOSAppOnFix accessor must answer the row FixCategory.iOSAppOnFix both ways, and it is red: " .. said)
    end
    inventory.classes.FixCategory = nil
    rows(protocol)
    io.writefile(path.join(root, "RevenantFixture.h"), "#import <Foundation/Foundation.h>\n@protocol FixProtocol <NSObject>\n- (void)fixIt;\n@end\n")
    local declared = backports.declared_protocols(root, root)
    if not declared.FixProtocol then
        table.insert(found, "a protocol a header the package installs declares with a body must be implemented, and it is not")
    end
    os.tryrm(path.join(root, "RevenantFixture.h"))
    io.writefile(path.join(root, "RevenantFixture.h"), "#import <Foundation/Foundation.h>\n@protocol FixProtocol;\n")
    declared = backports.declared_protocols(root, root)
    if declared.FixProtocol then
        table.insert(found, "a forward declaration is not a declaration: @protocol FixProtocol; must not answer the row")
    end
    os.tryrm(path.join(root, "RevenantFixture.h"))
    said = asked({}, {})
    if not said:find("FixProtocol", 1, true) then
        table.insert(found, "a protocol row no header declares must be red, and it is not: " .. said)
    end
    os.tryrm(root)
end


local function two_readers(backports, found)
    local inventory = {classes = {
        FixDefined = {image = true, instance = {["-definedOne"] = true}, ["+"] = {}},
        FixCarried = {image = true, instance = {["-carriedOne"] = true}, ["+"] = {}},
        RevenantHelper = {image = false, instance = {["-helperOne"] = true}, ["+"] = {}}}}
    local function read(list)
        table.sort(list)
        return table.concat(list, " ")
    end
    local band = read(backports.added_members(inventory, {FixDefined = true, FixCarried = true}))
    if band ~= "-[RevenantHelper helperOne]" then
        table.insert(found, "the band reader must return only what the object defines, not a member a category adds to a class the release carries, and it says: " .. band)
    end
    local api = read(backports.carried_api(inventory))
    if not api:find("%-%[FixCarried carriedOne%]", 1, false) or api:find("RevenantHelper", 1, true) or not api:find("FixDefined", 1, true) then
        table.insert(found, "the API reader must return the members of every class but the port's own, and it says: " .. api)
    end
end


local function own_rows(backports, found)
    local root = fixtures.scratch()
    os.tryrm(root)
    os.mkdir(path.join(root, "registry"))
    os.mkdir(path.join(root, "registry", "Alpha"))
    os.mkdir(path.join(root, "registry", "Beta"))
    local function rows(folder, name)
        io.writefile(path.join(root, "registry", folder, "rows.json"),
                     string.format('{"framework": "%s", "entries": [{"api": "%s", "kind": "protocol", "introduced": "9.0", "status": "implemented", "facts": "f"}]}', folder, name))
    end
    rows("Alpha", "AlphaOne")
    rows("Beta", "BetaOne")
    local out = path.join(root, "out")
    os.mkdir(out)
    for _, pair in ipairs({{"Alpha", "AlphaOne"}, {"Beta", "BetaOne"}}) do
        local folder, name = pair[1], pair[2]
        local library = {name = folder .. "Backports", folder = folder}
        local written = backports.protocol_sources({root = root, sources = root}, library, out, folder)
        local text = written[1] and io.readfile(written[1]) or ""
        if not text:find("@protocol(" .. name .. ")", 1, true) then
            table.insert(found, folder .. " does not generate its own protocol row: " .. text:gsub("\n", " "):sub(1, 90))
        end
        local other = folder == "Alpha" and "BetaOne" or "AlphaOne"
        if text:find("@protocol(" .. other .. ")", 1, true) then
            table.insert(found, folder .. " generates the other library's protocol row, so every library carries every protocol")
        end
    end
    os.tryrm(root)
end


local function generated_includes(backports, found)
    local folder = "/somewhere/frameworks/Backports/src/Foundation"
    local flags = table.concat(backports.compile_arguments({includes = {folder}}, "Protocols.m"), " ")
    if not flags:find("-I" .. folder, 1, true) then
        table.insert(found, "a generated source's job must add the library's own folder to its include path, and it does not: " .. flags)
    end
    local bare = table.concat(backports.compile_arguments({}, "Protocols.m"), " ")
    if bare:find("-I/somewhere", 1, true) then
        table.insert(found, "a job that names no include root must not have one, and it does: " .. bare)
    end
end


local function protocol_headers(backports, root, found)
    local out = fixtures.scratch()
    for _, library in ipairs(backports.libraries()) do
        local written = backports.protocol_sources({root = root, sources = root, sdkdir = os.getenv("BP_SDK")}, library, out, library.folder)
        local tree = path.join(root, "..", "..", "..", "toolchain")
        local rendered = import("gen.protocol_headers", {rootdir = path.join(tree, "tools"), anonymous = true})
        if #written > 0 and rendered.header_text(tree, library.folder) == nil then
            table.insert(found, string.format("%s has %d generated protocol sources and no Revenant%sProtocols.h for them to import: "
                                              .. "spec/protocol-headers.tsv has no rows for %s",
                                              library.name, #written, library.folder, library.folder))
        end
    end
    os.tryrm(out)
end


local function protocol_declarations(backports, root, found)
    local out = fixtures.scratch()
    for _, library in ipairs(backports.libraries()) do
        local folder = path.join(root, library.folder)
        if os.isdir(folder) then
            local carried, count = {}, 0
            for _, written in ipairs(backports.protocol_sources({root = root, sources = root, sdkdir = os.getenv("BP_SDK")}, library, out, library.folder)) do
                for line in io.lines(written) do
                    local name = line:match("@protocol%(([%w_]+)%)")
                    if name then carried[name] = true; count = count + 1 end
                end
            end
            if count > 0 then
                for _, name in ipairs(os.files(path.join(folder, "*.m"), path.join(folder, "*.mm"),
                                              path.join(folder, "*.h"), path.join(folder, "*.c"))) do
                    local relative = name:sub(#folder + 2)
                    for line in io.lines(name) do
                        local declared = line:match("^%s*@protocol%s+([%w_]+)%s*[:<]")
                        if declared and carried[declared] then
                            table.insert(found, string.format(
                                "%s declares @protocol %s, which the generated protocol source defines too, so two objects define that protocol object and ld64 keeps whichever of the two comes first: %s",
                                relative, declared, relative))
                        end
                    end
                end
            end
        end
    end
    os.tryrm(out)
end


local function one_protocol_object(backports, root, found)
    local out = fixtures.scratch()
    for _, library in ipairs(backports.libraries()) do
        local opt = {root = root, sources = root, sdkdir = os.getenv("BP_SDK")}
        local folder = path.join(root, library.folder)
        if os.isdir(folder) then
            local forced = {}
            for _, written in ipairs(backports.protocol_sources(opt, library, out, library.folder)) do
                for line in io.lines(written) do
                    local name = line:match("@protocol%(([%w_]+)%)")
                    if name then forced[name] = true end
                end
            end
            local wanted = {}
            for name in pairs(forced) do wanted[name] = true end
            local carriers = {}
            backports.conforming_protocols(opt, library, wanted, carriers)
            for name in pairs(forced) do
                if carriers[name] then
                    table.insert(found, string.format(
                        "%s has an implemented protocol row for %s and %s declares a conformance to it, so two objects of this library define __OBJC_PROTOCOL_$_%s and ld64 keeps whichever comes first: the generated protocol source must not force it",
                        library.name, name, carriers[name], name))
                end
            end
        end
    end
    os.tryrm(out)
end


local function message_names(backports, found)
    local root = fixtures.scratch()
    os.tryrm(root)
    os.mkdir(root)
    os.mkdir(path.join(root, "registry"))
    local inventory = {classes = {FixMapView = {image = true, instance = {}, ["+"] = {}}}}
    local function row(api, kind)
        return string.format('{"api": "%s", "kind": "%s", "introduced": "9.0", "minimum": "6.0", "status": "implemented", "facts": "f"}', api, kind)
    end
    io.writefile(path.join(root, "registry", "Fix.json"),
                 string.format('{"framework": "Fix", "entries": [%s]}', row("FixMapView", "class")))
    local message
    local passed = try {
        function ()
            local surface = {classes = {FixMapView = true},
                             members = {["-[FixMapView alpha]"] = true, ["-[FixMapView beta:]"] = true},
                             symbols = {}, defined = {}}
            backports.check_registry(root, root,surface, true, "6.1.3", {}, inventory)
            return "passed"
        end,
        catch {function (errors) message = tostring(errors) end}
    }
    os.tryrm(root)
    if passed then
        table.insert(found, "a member of a class the release carries with no row of its own must be reported, and it is not")
        return
    end
    local listed = (message:match("built, but no entry in registry/: (.*)") or ""):gsub("%s+$", "")
    if listed == "" then
        table.insert(found, "the gap list must be in the message a machine reads: " .. message:gsub("\n", " | "):sub(1, 110))
        return
    end
    local names = {}
    for name in listed:gmatch("[^;]+") do
        table.insert(names, (name:gsub("^%s+", "")))
    end
    if #names ~= 2 or names[1] ~= "-[FixMapView alpha]" or names[2] ~= "-[FixMapView beta:]" then
        table.insert(found, "the gap list must split back into the two names it names, and it says: " .. listed)
    end
end


local function real_object(backports, modules, found)
    local built
    for _, run in ipairs(os.dirs(path.join(import("workspace", {rootdir = modules, anonymous = true}).cache(), "*", "*"))) do
        for _, folder in ipairs(os.dirs(path.join(run, "build", "objects", "*"))) do
            for _, object in ipairs(os.files(path.join(run, "build", "objects", folder, "protocols", "*.o"))) do
                built = {run = run, folder = folder, object = object}
            end
        end
    end
    if not built then
        return
    end
    local root = fixtures.scratch()
    os.tryrm(root)
    os.mkdir(root)
    os.mkdir(path.join(root, "registry"))
    local name = nil
    local symbols = os.iorunv("xcrun", {"nm", built.object}, {try = true}) or ""
    for protocol in symbols:gmatch("__OBJC_PROTOCOL_$([A-Za-z0-9_]+)") do
        name = protocol
        break
    end
    if not name then
        os.tryrm(root)
        return
    end
    io.writefile(path.join(root, "registry", "Fix.json"),
                 string.format('{"framework": "Fix", "entries": [{"api": "%s", "kind": "protocol", "introduced": "9.0", "minimum": "6.0", "status": "implemented", "facts": "f"}]}', name))
    local message
    local ok = try {
        function ()
            backports.registry_step({root = root, sources = root, builddir = built.run, deployment = "6.1.3"},
                                    {classes = {}, members = {}, symbols = {}, defined = {}}, true, {})
            return "passed"
        end,
        catch {function (errors) message = tostring(errors) end}
    }
    if not ok and message:find("nothing of that name is built: " .. name, 1, true) then
        table.insert(found, "the protocol metadata in " .. path.filename(built.object) .. " is not read, so " .. name .. " is reported unbuilt")
    end
    os.tryrm(root)
end

local function protocol_owner_step(backports, opt, found)
    local scratch = fixtures.scratch()
    local root = path.join(scratch, "case")
    local mutant_root = path.join(scratch, "mutant")
    os.tryrm(mutant_root)
    os.tryrm(scratch)
    os.mkdir(scratch)
    os.mkdir(root)
    os.mkdir(path.join(root, "registry"))
    local inventory = {classes = {}}
    local function asked(sdkdir)
        io.writefile(path.join(root, "registry", "Fix.json"),
                     '{"framework": "Fix", "entries": ['
                     .. '{"api": "-[ARKitShapedDelegate shaped]", "kind": "method", "introduced": "9.0", "minimum": "6.0", "status": "implemented", "facts": "f"},'
                     .. '{"api": "ARKitShapedDelegate", "kind": "protocol", "introduced": "9.0", "minimum": "6.0", "status": "implemented", "facts": "f"}]}')
        local message
        local ok = try {
            function ()
                backports.check_registry(root, root, {classes = {}, members = {},
                                               symbols = {}, defined = {}}, true, "6.1.3", {}, inventory, sdkdir, {})
                return "passed"
            end,
            catch {function (errors) message = tostring(errors) end}
        }
        return (ok and "passed" or message or "raised with no message")
    end
    local said = asked(nil)
    if not said:find("ARKitShapedDelegate shaped", 1, true) then
        table.insert(found, "a member of a protocol that neither a port header nor the SDK declares must be reported, and it is not: " .. said:gsub("\n", " | "):sub(1, 120))
    end
    io.writefile(path.join(root, "RevenantFixture.h"), "#import <Foundation/Foundation.h>\n@protocol ARKitShapedDelegate <NSObject>\n- (void)shaped;\n@end\n")
    local function ask(n, a, b, c, d)
        local value
        local ok = try {
            function () value = backports.protocol_declared(a, a, b, c, d) return true end,
            catch {function () return false end}
        }
        return ok and value or false
    end
    if ask(1, root, "ARKitShapedDelayed", inventory, nil) then
        table.insert(found, "a protocol no header declares yet must not be answered from one")
    end
    io.writefile(path.join(root, "RevenantDelayed.h"), "@protocol ARKitShapedDelayed <NSObject>\n@end\n")
    if not ask(2, root, "ARKitShapedDelayed", inventory, nil) then
        table.insert(found, "a protocol a header declares after the first answer is not seen: what protocol_declared memoises is keyed on the folder, not on what is in it")
    end
    os.tryrm(path.join(root, "RevenantDelayed.h"))
    os.mkdir(mutant_root)
    os.mkdir(path.join(mutant_root, "apple"))
    for _, name in ipairs(os.files(path.join(opt.modules, "apple", "*.lua"))) do
        io.writefile(path.join(mutant_root, "apple", path.filename(name)), io.readfile(name))
    end
    for _, name in ipairs(os.files(path.join(opt.modules, "*.lua"))) do
        io.writefile(path.join(mutant_root, path.filename(name)), io.readfile(name))
    end
    local backports = path.join(mutant_root, "apple", "backports.lua")
    local text = io.readfile(backports)
    local needle = "protocol_declared(root, src, owner, inventory, sdkdir))"
    local first, last = text:find(needle, 1, true)
    local second = first and text:find(needle, last + 1, true)
    if not first or second then
        table.insert(found, "the needle is not in the copy exactly once, so the mutant is not what it claims: "
                            .. tostring(first) .. "/" .. tostring(second))
    end
    local without = first and (text:sub(1, first - 1) .. "false)" .. text:sub(last + 1)) or text
    io.writefile(backports, without)
    os.mkdir(path.join(mutant_root, "registry"))
    io.writefile(path.join(mutant_root, "registry", "Fix.json"), io.readfile(path.join(root, "registry", "Fix.json")))
    io.writefile(path.join(mutant_root, "probe.lua"), [[
function main(modules)
    local backports = import("apple.backports", {rootdir = modules, anonymous = true})
    local message
    local ok = try {
        function () backports.check_registry(os.getenv("PROBE_ROOT"), os.getenv("PROBE_ROOT"),{classes = {}, members = {}, symbols = {}, declared = {}},
                                        true, "6.1.3", {}, {classes = {}}, nil, {}) return "passed" end,
        catch {function (errors) message = tostring(errors) end}
    }
    print(ok and "passed" or (message or "raised"))
end
]])
    os.mkdir(path.join(mutant_root, "packages"))
    os.mkdir(path.join(mutant_root, "packages", "a"))
    os.mkdir(path.join(mutant_root, "packages", "frameworks", "apple-backports"))
    os.mkdir(path.join(mutant_root, "packages", "frameworks", "apple-backports", "registry"))
    io.writefile(path.join(mutant_root, "packages", "frameworks", "apple-backports", "registry", "Fix.json"),
                 io.readfile(path.join(root, "registry", "Fix.json")))
    local out = path.join(root, "mutant.out")
    io.writefile(out, "")
    local err = path.join(scratch, "mutant.err")
    io.writefile(err, "")
    local rc = os.execv(os.programfile(), {"l", path.join(mutant_root, "probe.lua"), mutant_root},
                        {try = true, envs = {PROBE_ROOT = root}, stdout = out, stderr = err})
    local said = io.readfile(out) or ""
    local failed = io.readfile(err) or ""
    if rc ~= 0 then
        table.insert(found, string.format("the mutant's probe died with %s and said nothing: %s", tostring(rc),
                                          failed:gsub("\n", " | "):sub(1, 200)))
    elseif said:find("ARKitShapedDelegate shaped", 1, true) then
    elseif said:find("passed", 1, true) then
        table.insert(found, "the mutant did not report the ARKit member, so the control is not a control: " .. said)
    else
        table.insert(found, "the mutant's probe answered nothing at all, which is a failure of the control: rc="
                            .. tostring(rc) .. " answer=[" .. said:gsub("\n", " | "):sub(1, 120) .. "] stderr="
                            .. failed:gsub("\n", " | "):sub(1, 120))
    end
    said = asked(nil)
    if said:find("ARKitShapedDelegate shaped", 1, true) then
        table.insert(found, "a member of a protocol a port header declares must pass, and it is red: " .. said:gsub("\n", " | "):sub(1, 120))
    end
    os.tryrm(path.join(root, "RevenantFixture.h"))
    local cryptex = path.join(root, "Cryptexes", "OS", "test-uuid", "System", "Library", "Frameworks")
    os.mkdir(path.join(cryptex, "X.framework", "Headers"))
    io.writefile(path.join(cryptex, "X.framework", "Headers", "X.h"),
                 "@protocol ARKitShapedSymlinked <NSObject>\n- (void)symlinked;\n@end\n")
    local frameworks = path.join(root, "fake-sdk-2", "System", "Library", "Frameworks")
    os.mkdir(frameworks)
    os.execv("ln", {"-sfn", cryptex .. "/X.framework", frameworks .. "/X.framework"}, {try = true})
    if not ask(3, root, "ARKitShapedSymlinked", {}, path.join(root, "fake-sdk-2")) then
        table.insert(found, "a protocol a framework behind a symlink declares must be answered: os.files does not follow one, so the scan has to resolve the framework")
    end
    local cryptex3 = path.join(root, "Cryptexes", "OS", "test-uuid-2", "System", "Library", "Frameworks")
    os.mkdir(path.join(cryptex3, "Y.framework", "Headers"))
    io.writefile(path.join(cryptex3, "Y.framework", "Headers", "Y.h"), "@protocol ARKitShapedForward;\n")
    local frameworks3 = path.join(root, "fake-sdk-3", "System", "Library", "Frameworks")
    os.mkdir(frameworks3)
    os.execv("ln", {"-sfn", cryptex3 .. "/Y.framework", frameworks3 .. "/Y.framework"}, {try = true})
    if ask(4, root, "ARKitShapedForward", {}, path.join(root, "fake-sdk-3")) then
        table.insert(found, "a forward declaration (@protocol X;) must not answer a row: nothing is declared")
    end
    os.tryrm(root)
end



local function inline_rows_step(backports, opt, found)
    local counter = 0
    local header_path = path.join(opt.modules, "..", "..", "frameworks", "Backports", "src", "AVFoundation",
                                 "RevenantCMTag26.h")
    local header = io.readfile(header_path)
    if not header then
        table.insert(found, "the port's RevenantCMTag26.h is not in this tree, so the inline fixtures cannot be the port's own: " .. header_path)
        return
    end
    local function asked(name, text)
        counter = counter + 1
        local root = fixtures.scratch()
        os.tryrm(root)
        os.mkdir(root)
        os.mkdir(path.join(root, "registry"))
        io.writefile(path.join(root, "Store.h"), text or header)
        io.writefile(path.join(root, "registry", "Fix.json"), string.format(
            '{"framework": "Fix", "entries": [{"api": "%s()", "kind": "function", "introduced": "13.0", "minimum": "6.0", "status": "implemented", "facts": "f"}]}', name))
        local message
        local ok = try {
            function () backports.check_registry(root, root, {classes = {}, members = {}, symbols = {}, defined = {}},
                                                true, "6.1.3", {}, {classes = {}}, nil, {}) return true end,
            catch {function (e) message = tostring(e) end}
        }
        os.tryrm(root)
        return (ok and "passed" or (message or "raised"))
    end
    local defined = {}
    for name in header:gmatch("CF_INLINE%s+[%w_<>%* ]+%s+([%w_]+)%s*%b()") do
        defined[name] = true
    end
    local green = {}
    for name in pairs(defined) do
        green[#green + 1] = name
    end
    table.sort(green)
    if #green == 0 then
        table.insert(found, "the port's RevenantCMTag26.h defines no inline the fixtures can name")
    end
    for _, name in ipairs(green) do
        if asked(name):find(name, 1, true) then
            table.insert(found, "an inline the port defines with a body must answer its row, and it does not: " .. name)
        end
    end
    if asked("CMTagDeclaredOnly", "#import <Foundation/Foundation.h>\nCF_INLINE Boolean CMTagDeclaredOnly( CMTag tag ) CF_REFINED_FOR_SWIFT;\n"):find("CMTagDeclaredOnly", 1, true) == nil then
        table.insert(found, "a declaration without a body must not answer a function row, and it does")
    end
    if asked("CMTagCommentedOnly", "#import <Foundation/Foundation.h>\n/* CMTagCommentedOnly definition: static inline Boolean CMTagCommentedOnly(CMTag tag) { return 1; } */\n"):find("CMTagCommentedOnly", 1, true) == nil then
        table.insert(found, "a name that only appears in a comment must not answer a function row, and it does")
    end
    if asked("CMTagCalledFromABody", "#import <Foundation/Foundation.h>\nCF_INLINE Boolean CMTagCaller( CMTag tag ) CF_REFINED_FOR_SWIFT\n{\n\treturn CMTagCalledFromABody( tag );\n}\n"):find("CMTagCalledFromABody", 1, true) == nil then
        table.insert(found, "a name only called inside another body must not answer a function row, and it does")
    end
end

SCRATCH_RUNS = nil
function scratch_root(name)
    if not os.isdir(SCRATCH_RUNS) then
        os.mkdir(SCRATCH_RUNS)
    end
    return path.join(SCRATCH_RUNS, name .. "-" .. os.getpid())
end

function generated_index(backports, found)
    local root = scratch_root("registry_test_generated")
    os.tryrm(root)
    os.mkdir(path.join(root, "registry"))
    os.mkdir(path.join(root, ".gen", "Accounts"))
    local header = "framework\tkind\tapi\tintroduced\tminimum\tmaximum\tstatus\teffect\tfacts\tsource\towner\tdeclhash"
    local function index(api, source)
        return table.concat({"Accounts", "constant", api, "7.0", "6.0", "7.0", "implemented", "", ".gen/Accounts/README.md", source,
                             "generated", "0123456789abcdef"}, "\t")
    end
    local function write_index(rows)
        io.writefile(path.join(root, ".gen", "Accounts", "rows.tsv"), header .. "\n" .. table.concat(rows, "\n") .. "\n")
    end
    local function write_source(text)
        io.writefile(path.join(root, ".gen", "Accounts", "FixConstants70.m"), text)
    end
    local function complaints()
        local _, incomplete = backports.registry(root, root)
        return table.concat(incomplete, "; ")
    end
    write_source('NSString *const FixConstantAlpha = @"alpha";\n')
    write_index({index("FixConstantAlpha", ".gen/Accounts/FixConstants70.m")})
    if complaints() ~= "" then
        table.insert(found, "a generated row whose source defines it is refused: " .. complaints())
    end
    write_source('NSString *const FixConstantOther = @"other";\n')
    if not complaints():find("FixConstantAlpha is a generated row, but its source .gen/Accounts/FixConstants70.m does not define it", 1, true) then
        table.insert(found, "a generated row whose source does not define it must be refused by name, not '" .. complaints() .. "'")
    end
    write_index({index("FixConstantAlpha", "")})
    if not complaints():find("FixConstantAlpha is a generated row with no source", 1, true) then
        table.insert(found, "a generated row with no source must be refused, not '" .. complaints() .. "'")
    end
    write_index({index("FixConstantAlpha", ".gen/Accounts/Missing.m")})
    if not complaints():find("does not exist", 1, true) then
        table.insert(found, "a generated row whose source file is missing must be refused, not '" .. complaints() .. "'")
    end
    write_source('NSString *const FixConstantAlpha = @"alpha";\n')
    write_index({index("FixConstantAlpha", ".gen/Accounts/FixConstants70.m")})
    io.writefile(path.join(root, "registry", "Fix.json"),
                 '{"framework": "Fix", "entries": [{"api": "FixConstantAlpha", "kind": "constant", "introduced": "7.0", "status": "implemented", "facts": "x"}]}')
    if not complaints():find("FixConstantAlpha is named by both registry/Fix.json and .gen/Accounts/rows.tsv", 1, true) then
        table.insert(found, "a name in the registry and in a generated index must be refused naming both, not '" .. complaints() .. "'")
    end
    os.tryrm(root)
end

function failures(opt)
    local backports = import("apple.backports", {rootdir = opt.modules, anonymous = true})
    SCRATCH_RUNS = import("workspace", {rootdir = opt.modules, anonymous = true}).run("registry-test")
    local found = {}
    local root = path.join(opt.modules, "..", "..", "packages", "frameworks", "apple-backports")
    if not os.isdir(path.join(root, "registry")) then
        table.insert(found, root .. " holds no registry to read")
        return found
    end
    local spellings = {["SomeLateFunction()"] = {api = "SomeLateFunction()", kind = "function",
                                                 introduced = "18.2", status = "implemented"},
                       ["-[UIView tintColorDidChange]"] = {api = "-[UIView tintColorDidChange]",
                                                           kind = "method", introduced = "7.0",
                                                           status = "implemented"},
                       ["UIBlurEffect"] = {api = "UIBlurEffect", kind = "class", introduced = "8.0",
                                           status = "absent"}}
    local by_function = backports.entry_of(spellings, "SomeLateFunction")
    local by_member = backports.entry_of(spellings, "UIView.tintColorDidChange")
    if not by_function or by_function.introduced ~= "18.2" then
        table.insert(found, "the registry entry of a function must be found by the bare name the symbol table gives it, since the registry spells it with its parentheses")
    end
    if not by_member or by_member.introduced ~= "7.0" then
        table.insert(found, "the registry entry of a member must be found by the class that owns it, which is the shape check_registry is given")
    end
    if backports.entry_of(spellings, "NoSuchName") then
        table.insert(found, "a name the registry does not carry must be answered nil, not another entry")
    end
    local source = io.readfile(path.join(opt.modules, "apple", "backports.lua")) or ""
    local first = source:find("function releases_in", 1, true)
    local last = first and source:find("\nend\n", first, true)
    local body = (first and last) and source:sub(first, last) or ""
    if not body:find("entry_of(listed(opt.root, opt.sources), name)", 1, true) then
        table.insert(found, "releases_in must reach the registry through entry_of and not by a raw index that misses every function")
    end
    local listed, incomplete = backports.registry(root, root)
    for index, complaint in ipairs(incomplete or {}) do
        if index <= 8 then
            table.insert(found, "the registry says: " .. complaint)
        end
    end
    if #(incomplete or {}) > 8 then
        table.insert(found, string.format("and %d more of the same", #incomplete - 8))
    end
    local named = 0
    for _ in pairs(listed or {}) do
        named = named + 1
    end
    if named == 0 then
        table.insert(found, "the registry of the repository names no API at all, which is not what it is for")
    end
    wiring(backports, root, found)
    range_step(backports, fixtures.scratch(), found)
    one_minimum_step(backports, root, found)
    spelling(backports, found)
    unreadable(backports, found)
    status_rule(backports, found)
    named_twice(backports, found)
    generated_index(backports, found)
    type_rows(backports, found)
    inline_rows_step(backports, opt, found)
    member_and_protocol_rows(backports, found)
    two_readers(backports, found)
    own_rows(backports, found)
    generated_includes(backports, found)
    protocol_headers(backports, root, found)
    one_protocol_object(backports, root, found)
    protocol_declarations(backports, root, found)
    message_names(backports, found)
    real_object(backports, opt.modules, found)
    protocol_owner_step(backports, opt, found)
    return found
end

function status_rule(backports, found)
    local root = scratch_root("registry_test_status_rule")
    os.tryrm(root)
    os.mkdir(path.join(root, "registry"))
    local function complaints(rows)
        io.writefile(path.join(root, "registry", "Fix.json"), '{"framework": "Fix", "entries": [' .. table.concat(rows, ", ") .. ']}')
        local _, incomplete = backports.registry(root, root)
        return table.concat(incomplete, "; ")
    end
    local function row(api, status, extra)
        return string.format('{"api": "%s", "kind": "class", "introduced": "9.0", "minimum": "6.0", "status": "%s"%s}', api, status, extra or "")
    end
    local told = complaints({row("FixInert", "inert", ', "reason": "nothing draws it", "effect": "nothing"')})
    if not told:find("FixInert says inert", 1, true) then
        table.insert(found, string.format("an inert row is not refused (says '%s')", told))
    end
    told = complaints({row("FixAbsent", "absent", ', "reason": "the release has nothing", "effect": "NSClassFromString answers nil"')})
    if not told:find("FixAbsent is absent without a release window", 1, true) then
        table.insert(found, string.format("an absent row without a maximum is not refused (says '%s')", told))
    end
    told = complaints({row("FixWindow", "absent", ', "maximum": "13.0", "reason": "the release carries the class itself", "effect": "NSClassFromString answers nil"')})
    if told ~= "" then
        table.insert(found, string.format("an absent row inside its release window is refused (says '%s')", told))
    end
    told = complaints({row("FixOwed", "owed", ', "reason": "build it", "effect": "NSClassFromString answers nil"')})
    if told ~= "" then
        table.insert(found, string.format("an owed row is refused (says '%s')", told))
    end
    os.tryrm(root)
end

function named_twice(backports, found)
    local root = scratch_root("registry_test_named_twice")
    os.tryrm(root)
    os.mkdir(path.join(root, "registry"))
    os.mkdir(path.join(root, "registry", "Fix"))
    local function told()
        local _, incomplete = backports.registry(root, root)
        return table.concat(incomplete, "; ")
    end
    local function write(where, entries)
        io.writefile(path.join(root, "registry", where), string.format('{"framework": "Fix", "entries": [%s]}', table.concat(entries, ", ")))
    end
    local function entry(api, status)
        return string.format('{"api": "%s", "kind": "function", "introduced": "8.0", "status": "%s", "effect": "none", "reason": "because"}', api, status)
    end
    os.tryrm(root)
    os.mkdir(path.join(root, "registry"))
    os.mkdir(path.join(root, "registry", "Fix"))
    write("Fix.json", {entry("fix_one", "implemented"), entry("fix_both", "implemented")})
    write("Fix/part.json", {entry("fix_two", "owed")})
    if told() ~= "" then
        table.insert(found, "a name in one file and another in a second is refused, not reported: " .. told())
    end
    write("Fix/part.json", {entry("fix_two", "owed"), entry("fix_both", "owed")})
    local twice = told()
    if not twice:find("fix_both is named by both registry/Fix.json and registry/Fix/part.json", 1, true) then
        table.insert(found, "a name in registry/Fix.json and registry/Fix/part.json must be refused naming both paths, not '" .. twice .. "'")
    end
    write("Fix/part.json", {entry("fix_both", "owed"), entry("fix_both", "owed")})
    if not told():find("fix_both is named by both", 1, true) then
        table.insert(found, "a name twice in one file is refused as well, not '" .. told() .. "'")
    end
    os.tryrm(root)
    os.mkdir(path.join(root, "registry"))
    io.writefile(path.join(root, "registry", "Fix.json"),
                 '{"framework": "Fix", "entries": [{"api": "FixView.size", "kind": "property", "introduced": "8.0", "status": "implemented", "facts": "x"},'
                 .. '{"api": "-[FixView size]", "kind": "method", "introduced": "8.0", "status": "implemented", "facts": "x"}]}')
    if told() ~= "" then
        table.insert(found, "the two spellings of one property are two names and are not a duplicate: " .. told())
    end
    os.tryrm(root)
end

function spelling(backports, found)
    local root = scratch_root("registry_test_spelling")
    os.tryrm(root)
    local function complaints(api, kind)
        io.writefile(path.join(root, "registry", "Fix.json"), string.format('[{"api": "%s", "kind": "%s", "introduced": "8.0", "minimum": "6.0", "status": "implemented"}]', api, kind))
        local _, incomplete = backports.registry(root, root)
        return table.concat(incomplete, "; ")
    end
    for _, spelled in ipairs({{"-[FixView draw:]", "method"}, {"+[FixView make:]", "method"}, {"FixView.size", "property"}, {"FixView.draw", "method"}, {"FixView.size()", "property"}}) do
        local told = complaints(spelled[1], spelled[2])
        if told ~= "" then
            table.insert(found, string.format("the %s %s is refused: %s", spelled[2], spelled[1], told))
        end
    end
    for _, spelled in ipairs({{"FixView.draw:", "method"}, {"FixView.size:", "property"}, {"[FixView draw:]", "method"}, {"-[FixView]", "method"}}) do
        local told = complaints(spelled[1], spelled[2])
        if not told:find(spelled[1] .. " is a " .. spelled[2] .. " not spelled", 1, true) then
            table.insert(found, string.format("the %s %s is not refused by name (says '%s')", spelled[2], spelled[1], told))
        end
    end
    os.tryrm(root)
end

function unreadable(backports, found)
    local root = scratch_root("registry_test_unreadable")
    os.tryrm(root)
    os.mkdir(path.join(root, "registry"))
    local function complaints(rows)
        io.writefile(path.join(root, "registry", "Fix.json"), '{"framework": "Fix", "entries": [' .. table.concat(rows, ", ") .. ']}')
        local _, incomplete = backports.registry(root, root)
        return table.concat(incomplete, "; ")
    end
    local function row(api, kind, status, extra)
        return string.format('{"api": "%s", "kind": "%s", "introduced": "9.0", "minimum": "6.0", "status": "%s"%s}',
                             api, kind, status, extra or "")
    end
    local told = complaints({row("+[FixView isEnabledByDefault]", "class", "implemented")})
    if not told:find("is a class spelled +[FixView isEnabledByDefault]", 1, true) then
        table.insert(found, string.format("a class row spelled as a method is not refused by name (says '%s')", told))
    end
    told = complaints({row("FixView.size", "property", "implemented"), row("-[FixView size]", "method", "owed", ', "reason": "draw it ourselves", "effect": "respondsToSelector: answers NO"')})
    if not told:find("they are one API in two spellings", 1, true) then
        table.insert(found, string.format("two spellings of one API that answer differently are not refused (says '%s')", told))
    elseif not told:find("FixView.size is implemented", 1, true) or not told:find("-[FixView size] is owed", 1, true) then
        table.insert(found, string.format("the refusal does not name both spellings with their statuses (says '%s')", told))
    end
    told = complaints({row("FixView.size", "property", "implemented"),
                      row("-[FixView setSize:]", "method", "owed", ', "reason": "iOS 6 has no such setter", "effect": "nothing is resized"')})
    if told ~= "" then
        table.insert(found, string.format("a property carried and its setter absent are refused as one API in two spellings (says '%s')", told))
    end
    told = complaints({row("FixView.size", "property", "implemented"), row("-[FixView size]", "method", "implemented", ', "facts": "facts/Fix.md"')})
    if told ~= "" then
        table.insert(found, string.format("two spellings of one API that answer alike are refused (says '%s')", told))
    end
    os.tryrm(root)
end

function recipe_lists(recipe)
    local lists, at = {}, 1
    while true do
        local pos = recipe:find("table.join(", at, true)
        if not pos then break end
        local before = recipe:sub(pos - 200, pos - 1)
        local which = nil
        local libraries_at = recipe:find("local libraries = table%.join%(")
        if libraries_at and pos > libraries_at then
            which = "libraries"
        elseif before:find('add%("links"', 1) then
            which = "links"
        end
        if which then
            local paren = recipe:find("(", pos, true)
            local pieces, walk, paren_depth, brace = {}, paren + 1, 0, 0
            while walk <= #recipe do
                local c = recipe:sub(walk, walk)
                if c == "(" then
                    paren_depth = paren_depth + 1
                elseif c == ")" then
                    if paren_depth == 0 then break end
                    paren_depth = paren_depth - 1
                elseif c == "{" and paren_depth == 0 and brace == 0 then
                    local open_at, close_at, inner = walk, walk, 0
                    while close_at <= #recipe do
                        local d = recipe:sub(close_at, close_at)
                        if d == "{" then
                            inner = inner + 1
                        elseif d == "}" then
                            inner = inner - 1
                            if inner == 0 then break end
                        end
                        close_at = close_at + 1
                    end
                    table.insert(pieces, {open = open_at, close = close_at,
                                          list = recipe:sub(open_at + 1, close_at - 1)})
                    walk = close_at + 1
                elseif c == "{" then
                    brace = brace + 1
                elseif c == "}" then
                    brace = brace - 1
                end
                walk = walk + 1
            end
            for index, piece in ipairs(pieces) do
                piece.sources = {}
                local stop = paren
                if index > 1 then stop = pieces[index - 1].close end
                local pos2 = stop
                while true do
                    local found = recipe:find("package:config", pos2 + 1)
                    if not found or found > piece.open then break end
                    local open_q = recipe:find('("', found, true)
                    local shut_q = recipe:find('")', found, true)
                    if open_q and shut_q and shut_q < piece.open then
                        table.insert(piece.sources, recipe:sub(open_q + 2, shut_q - 1))
                    end
                    pos2 = found
                end
                piece.libraries = {}
                for library in piece.list:gmatch('"([%w]+Backports)"') do
                    table.insert(piece.libraries, library)
                end
            end
            for _, piece in ipairs(pieces) do
                piece.which = which
                table.insert(lists, piece)
            end
        end
        at = pos + 1
    end
    return lists
end

function wiring(backports, root, found)


    local recipe = io.readfile(path.join(root, "xmake.lua"))
    if not recipe then
        table.insert(found, "the package has no xmake.lua, so no config of it can be read")
        return
    end
    local declared, order = {}, {}
    for name in recipe:gmatch('add_configs%("([%w_]+)"') do
        if not declared[name] then
            declared[name] = true
            order[#order + 1] = name
        end
    end
    local lists = recipe_lists(recipe)
    if #lists == 0 then
        table.insert(found, "the recipe's two library lists are not readable, so nothing here can say what they build")
        return
    end

    local declares = {}
    for _, library in ipairs(backports.libraries()) do
        declares[library.name] = library.libraries or {}
    end

    local function builds_for(name)
        local built = {}
        for _, piece in ipairs(lists) do
            local fires = #piece.sources == 0
            for _, source in ipairs(piece.sources) do
                if source == name then fires = true end
            end
            if fires then
                for _, library in ipairs(piece.libraries) do built[library] = true end
            end
        end
        return built
    end

    for _, name in ipairs(order) do
        if name ~= "sources" then
            local used = false
            for _, piece in ipairs(lists) do
                for _, source in ipairs(piece.sources) do
                    if source == name then used = true end
                end
            end
            if not used then
                table.insert(found, string.format('the config "%s" is declared but no clause of either library list tests it, so it builds no library at all', name))
            end
        end
    end
    for _, piece in ipairs(lists) do
        for _, source in ipairs(piece.sources) do
            if not declared[source] then
                table.insert(found, string.format('a clause tests package:config("%s") and no add_configs declares it, so that clause is always false and %s is never built',
                                                  source, (#piece.libraries > 0) and table.concat(piece.libraries, ", ") or "nothing at all"))
            end
        end
    end
    local named = {}
    for _, piece in ipairs(lists) do
        for _, library in ipairs(piece.libraries) do
            named[library] = true
        end
    end
    for _, library in ipairs(backports.libraries()) do
        if library.name ~= "FoundationBackports" and not named[library.name] then
            table.insert(found, library.name .. " is in the library table and named by no list of the recipe, so no config builds it and the registry is never checked against the backports")
        end
    end

    local owed = {
        ["avkit/GraphicsBackports"] = true,
        ["usernotificationsui/GraphicsBackports"] = true,
        ["notificationcenter/GraphicsBackports"] = true,
    }
    local count, gaps = 0, {}
    for _, name in ipairs(order) do
        if name ~= "sources" then
            local built = builds_for(name)
            local missing = {}
            for library in pairs(built) do
                if library ~= "FoundationBackports" then
                    for _, dep in ipairs(declares[library] or {}) do
                        if dep:endswith("Backports") and dep ~= "FoundationBackports" and not built[dep] then
                            missing[dep] = true
                        end
                    end
                end
            end
            local names = {}
            for dep in pairs(missing) do names[#names + 1] = dep end
            table.sort(names)
            for _, dep in ipairs(names) do
                count = count + 1
                gaps[name .. "/" .. dep] = true
                if not owed[name .. "/" .. dep] then
                    table.insert(found, string.format('the config "%s" builds a library that links -l%s, and no clause of the recipe builds it: Undefined symbols at link time. Add the clause and this goes',
                                                      name, dep))
                end
            end
        end
    end
    local invisible = {}
    for entry in pairs(owed) do
        if not gaps[entry] and not invisible[entry] then
            table.insert(found, string.format('the table of main\'s gaps lists "%s" and the arm does not find it and cannot see why: it is either fixed, in which case the row goes, or a gap in one of the recipe\'s two lists alone, in which case it is named below', entry))
        end
    end
    local split = 0
    for _, name in ipairs(order) do
        if name ~= "sources" then
            local function per(which)
                local got = {}
                for _, piece in ipairs(lists) do
                    if piece.which == which then
                        local fires = #piece.sources == 0
                        for _, source in ipairs(piece.sources) do
                            if source == name then fires = true end
                        end
                        if fires then
                            for _, library in ipairs(piece.libraries) do got[library] = true end
                        end
                    end
                end
                return got
            end
            local linked, built = per("links"), per("libraries")
            local named = {}
            for library in pairs(linked) do
                if not built[library] then
                    named[#named + 1] = library
                end
            end
            table.sort(named)
            for _, library in ipairs(named) do
                split = split + 1
                table.insert(found, string.format('the config "%s" names -l%s in the recipe\'s links list and the libraries list does not build it for that config, so a project asking for that config alone is told to link a dylib this package never built: name it in BOTH lists, from ONE expression, so the two cannot drift',
                                                  name, library))
            end
        end
    end
    if split > 0 then
        print(string.format("        the single-config arm found %d library named in links and not built for that config", split))
    end

    if count > 0 then
        local tabulated, invisible_count = 0, 0
        for _ in pairs(owed) do tabulated = tabulated + 1 end
        for _ in pairs(invisible) do invisible_count = invisible_count + 1 end
        print(string.format("        the arm found %d gaps and the table of main's holds %d entries: %d found, %d the arm cannot see, %d neither found nor explained",
                            count, tabulated, count, invisible_count, tabulated - count - invisible_count))
    end
end
