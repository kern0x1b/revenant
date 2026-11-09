import("fixtures")
import("core.base.json")

local NOT_OVERLAYS = {Cxx = true, CxxStdlib = true, SwiftOnoneSupport = true, _RegexParser = true}

local function sdk_has(sdk, name)
    return os.isdir(path.join(sdk, "usr", "lib", "swift", name .. ".swiftmodule"))
        or os.isdir(path.join(sdk, "System", "Library", "Frameworks", name .. ".framework", "Modules", name .. ".swiftmodule"))
end

local function dump(opt, folder, name, resources)
    local overlay = resources ~= nil
    local out = path.join(folder, (overlay and "overlay-" or "sdk-") .. name .. ".json")
    local version = path.filename(opt.sdk):match("iPhoneOS([%d%.]+)%.sdk")
    local argv = {"-dump-sdk", "-module", name, "-sdk", opt.sdk, "-o", out,
                  "-target", overlay and "armv7-apple-ios6.0" or ("arm64-apple-ios" .. version)}
    if overlay then
        table.join2(argv, {"-resource-dir", resources})
    end
    os.vrunv(path.join(opt.swift, "bin", "swift-api-digester"), argv)
    return json.loadfile(out)
end

local function parameters(signature)
    local list = signature:match("^<(.-)>$")
    if not list then
        return {}
    end
    local names = {}
    for entry in (list:match("^(.-) where ") or list):gmatch("[^,]+") do
        local name = entry:match("^%s*(%S+)")
        local bound = signature:find(name .. " : Swift.Error", 1, true)
        table.insert(names, bound and "any Error" or "Int")
    end
    return names
end

local function collect(node, ancestors, found)
    if type(node) ~= "table" then
        return
    end
    local current = ancestors
    if node.kind == "TypeDecl" then
        local sibling = {}
        for _, ancestor in ipairs(ancestors) do
            table.insert(sibling, ancestor)
        end
        local provided = #ancestors > 0 and ancestors[#ancestors].provided or 0
        local arguments = type(node.genericSig) == "string" and parameters(node.genericSig) or {}
        local own = {}
        for index = provided + 1, #arguments do
            table.insert(own, arguments[index])
        end
        local spelled = node.name
        if #own > 0 and not node.name:find("<", 1, true) then
            spelled = node.name .. "<" .. table.concat(own, ", ") .. ">"
        end
        table.insert(sibling, {name = node.name, spelled = spelled, provided = math.max(provided, #arguments)})
        current = sibling
        if node.declKind == "Enum" and type(node.usr) == "string" and node.usr:startswith("s:") then
            local cases = {}
            for _, child in ipairs(node.children or {}) do
                if child.declKind == "EnumElement" then
                    table.insert(cases, child.name)
                end
            end
            local names, spellings = {}, {}
            for _, ancestor in ipairs(current) do
                table.insert(names, ancestor.name)
                table.insert(spellings, ancestor.spelled)
            end
            found[table.concat(names, ".")] = {
                exhaustive = node.isEnumExhaustive == true,
                nonexhaustive = table.contains(node.declAttributes or {}, "Nonexhaustive"),
                cases = cases,
                spelled = table.concat(spellings, "."),
                owner = node.moduleName
            }
        end
    end
    for _, child in ipairs(node.children or {}) do
        collect(child, current, found)
    end
end

local function enums(document)
    local found = {}
    collect(document.ABIRoot, {}, found)
    return found
end

local function patterns(cases)
    local listed = {}
    for _, name in ipairs(cases) do
        table.insert(listed, ".`" .. name .. "`")
    end
    return "case " .. table.concat(listed, ", ") .. ":"
end

local function client(module, entries)
    local lines = {"import " .. module, ""}
    for index, entry in ipairs(entries) do
        local pattern = patterns(entry.cases)
        local type = entry.spelled
        if entry.sdk_exhaustive then
            table.insert(lines, string.format("func closedBare%d(_ value: %s) -> Int {\n    switch value {\n    %s return 0\n    }\n}\n", index, type, pattern))
            table.insert(lines, string.format("func closedDefault%d(_ value: %s) -> Int {\n    switch value {\n    %s return 0\n    default: return 1 // expected-warning{{default will never be executed}}\n    }\n}\n", index, type, pattern))
        else
            table.insert(lines, string.format("func openUnknown%d(_ value: %s) -> Int {\n    switch value {\n    %s return 0\n    @unknown default: return 1\n    }\n}\n", index, type, pattern))
            table.insert(lines, string.format("func openBare%d(_ value: %s) -> Int {\n    switch value { // expected-warning{{may have additional unknown values}} expected-note{{handle unknown values using \"@unknown default\"}}\n    %s return 0\n    }\n}\n", index, type, pattern))
        end
    end
    return table.concat(lines, "\n")
end

function failures(opt)
    local found = {}
    local resources = fixtures.runtime_resources()
    if not resources then
        table.insert(found, "swift-runtime must be installed for iphoneos before this test runs; configure with "
                            .. "./xmakew f -p iphoneos -a armv7, then require revenant@swift-runtime")
        return found
    end
    local folder = fixtures.scratch()
    local swift = import("apple.swift", {rootdir = opt.modules, anonymous = true})
    local compared, clients = 0, 0
    for _, file in ipairs(os.dirs(path.join(resources, "iphoneos", "*.swiftmodule"))) do
        local name = path.basename(file)
        if not NOT_OVERLAYS[name] and sdk_has(opt.sdk, name) then
            local overlay = enums(dump(opt, folder, name, resources))
            local sdk = enums(dump(opt, folder, name))
            local entries = {}
            local ordered = table.keys(overlay)
            table.sort(ordered)
            for _, key in ipairs(ordered) do
                local ours = overlay[key]
                local theirs = sdk[key] or sdk[key:gsub("^Revenant", "")]
                if theirs and #ours.cases > 0 then
                    compared = compared + 1
                    local ours_exhaustive = ours.exhaustive and not ours.nonexhaustive
                    if ours_exhaustive ~= theirs.exhaustive then
                        table.insert(found, string.format("%s.%s is %s in the overlay and %s in the SDK, so a client's switch is diagnosed differently", name, key,
                                                          ours_exhaustive and "exhaustive" or "open", theirs.exhaustive and "exhaustive" or "open"))
                    end
                    ours.sdk_exhaustive = theirs.exhaustive
                    table.insert(entries, ours)
                end
            end
            if #entries > 0 then
                local source = path.join(folder, "client-" .. name .. ".swift")
                io.writefile(source, client(name, entries))
                local argv = swift.runtime_flags({architecture = "armv7", deployment = "6.0", sdk = opt.sdk, resources = resources, module = "Client" .. name})
                table.join2(argv, {"-swift-version", "5", "-Xfrontend", "-disable-availability-checking", "-module-cache-path", path.join(folder, "cache"),
                                   "-emit-sil", "-o", path.join(folder, "client-" .. name .. ".sil"), "-Xfrontend", "-verify", source})
                local refused = fixtures.refusal(function ()
                    fixtures.run(folder, path.join(opt.swift, "bin", "swiftc"), argv)
                end)
                clients = clients + #entries
                if refused then
                    table.insert(found, string.format("the client of the %s enumerations (@unknown default and no default, as the SDK allows them) was diagnosed differently from what the SDK's exhaustivity says: %s",
                                                      name, refused))
                end
            end
        end
    end
    if compared == 0 or clients == 0 then
        table.insert(found, "no enumeration of the overlays was found in the SDK, so nothing was compared")
    end
    os.tryrm(folder)
    return found
end
