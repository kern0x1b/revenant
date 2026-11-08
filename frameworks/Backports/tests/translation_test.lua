local swift = import("@addon.revenant.apple.swift", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local sources = path.join(backports, "src", "Translation")
local shim = path.join(sources, "Translation.swift")

local function run(compiler, arguments, log)
    return os.execv(compiler, arguments, {try = true, stdout = log, stderr = log}) == 0
end

local function oracle(sdk)
    local folder = path.join(sdk, "System", "Library", "Frameworks", "_Translation_SwiftUI.framework", "Modules", "_Translation_SwiftUI.swiftmodule")
    local interfaces = os.files(path.join(folder, "*.swiftinterface"))
    assert(#interfaces > 0, "the SDK has no Swift interface of the Translation cross-import overlay under " .. folder)
    return interfaces[1]
end

local function enclosed(text, open)
    local depth = 0
    for index = open, #text do
        local char = text:sub(index, index)
        if char == "(" then
            depth = depth + 1
        elseif char == ")" then
            depth = depth - 1
            if depth == 0 then
                return text:sub(open + 1, index - 1)
            end
        end
    end
end

local function split(list)
    local parts, depth, start, index = {}, 0, 1, 1
    while index <= #list do
        local char = list:sub(index, index)
        if list:sub(index, index + 1) == "->" then
            index = index + 1
        elseif char:find("[%(%[<]") then
            depth = depth + 1
        elseif char:find("[%)%]>]") then
            depth = depth - 1
        elseif char == "," and depth == 0 then
            table.insert(parts, list:sub(start, index - 1))
            start = index + 1
        end
        index = index + 1
    end
    table.insert(parts, list:sub(start))
    return parts
end

local function declaration(text, owner)
    local at = text:find("func translationPresentation(", 1, true)
    assert(at, owner .. " declares no translationPresentation")
    local list = enclosed(text, text:find("(", at, true))
    assert(list, owner .. " declares translationPresentation without closing its parameter list")
    local version
    for found in text:sub(1, at):gmatch("@available%(iOS%s+([%d%.]+)") do
        version = found
    end
    assert(version, owner .. " declares translationPresentation without an iOS availability")
    local parameters = {}
    for _, part in ipairs(split(list)) do
        local label, rest = part:match("^%s*([%a_][%w_]*)%s*:%s*(.-)%s*$")
        assert(label, owner .. " declares a translationPresentation parameter that has no label and type: " .. part)
        local kind, default = rest:match("^(.-)%s+=%s+(.+)$")
        table.insert(parameters, {label = label, type = kind or rest, default = default})
    end
    return {list = (list:gsub("%s+", " ")):trim(), parameters = parameters, version = version}
end

local IGNORED = {["==(lhs:rhs:)"] = true, ["hash(into:)"] = true, hashValue = true}
local MODIFIERS = {"static", "mutating", "final", "convenience", "nonisolated", "private%(set%)", "override", "required"}

local function labels(list)
    local names = {}
    for _, part in ipairs(split(list)) do
        table.insert(names, (part:match("^%s*([%a_][%w_]*)") or "") .. ":")
    end
    return table.concat(names)
end

local function declared_member(rest)
    local stripped = rest
    local changed = true
    while changed do
        changed = false
        for _, modifier in ipairs(MODIFIERS) do
            local after = stripped:match("^" .. modifier .. "%s+(.*)$")
            if after then
                stripped = after
                changed = true
            end
        end
    end
    local kind, name = stripped:match("^(struct)%s+([%w_]+)")
    if not kind then
        kind, name = stripped:match("^(class)%s+([%w_]+)")
    end
    if not kind then
        kind, name = stripped:match("^(enum)%s+([%w_]+)")
    end
    if kind then
        return kind, name
    end
    name = stripped:match("^func%s+([^%s%(<]+)%s*[%(<]")
    if name then
        local open = stripped:find("(", 1, true)
        return "func", name .. "(" .. labels(enclosed(stripped, open) or "") .. ")"
    end
    if stripped:match("^init%s*%(") then
        return "init", "init(" .. labels(enclosed(stripped, stripped:find("(", 1, true)) or "") .. ")"
    end
    name = stripped:match("^[vl][ae][rt]%s+([%w_]+)")
    if name then
        return "value", name
    end
    name = stripped:match("^typealias%s+([%w_]+)")
    if name then
        return "typealias", name
    end
end

local function surface(text)
    local members = {}
    local stack = {}
    for line in text:gmatch("[^\n]+") do
        local trimmed = line:trim()
        local _, opened = trimmed:gsub("{", "")
        local _, closed = trimmed:gsub("}", "")
        local owner = {}
        for _, name in ipairs(stack) do
            if name ~= "" then
                table.insert(owner, name)
            end
        end
        local inside = #stack > 0 and stack[#stack] ~= "" or #stack == 0
        local public = trimmed:find("%f[%w]public%s")
        local pushed = ""
        if inside then
            local kind, name
            if public then
                kind, name = declared_member(trimmed:sub(public + 7))
            else
                name = trimmed:match("^case%s+([%w_]+)")
                kind = name and "case"
            end
            if kind and not IGNORED[name] and not name:find("^__") then
                members[table.concat(owner, ".") .. " " .. kind .. " " .. name] = true
                if opened > closed and (kind == "struct" or kind == "class" or kind == "enum") then
                    pushed = name
                end
            end
        end
        for index = 1, opened - closed do
            table.insert(stack, index == 1 and pushed or "")
        end
        for _ = 1, closed - opened do
            table.remove(stack)
        end
    end
    return members
end

local function differences(declared, implemented)
    local missing, extra = {}, {}
    for key in pairs(declared) do
        if not implemented[key] then
            table.insert(missing, key)
        end
    end
    for key in pairs(implemented) do
        if not declared[key] then
            table.insert(extra, key)
        end
    end
    table.sort(missing)
    table.sort(extra)
    return missing, extra
end

local function signatures(text, owner, name)
    local found = {}
    local at = 0
    while true do
        at = text:find("func " .. name .. "(", at + 1, true)
        if not at then
            break
        end
        local list = enclosed(text, text:find("(", at, true))
        assert(list, owner .. " declares " .. name .. " without closing its parameter list")
        local version
        for each in text:sub(1, at):gmatch("@available%(iOS%s+([%d%.]+)") do
            version = each
        end
        assert(version, owner .. " declares " .. name .. " without an iOS availability")
        table.insert(found, {list = (list:gsub("%s+", " ")):trim(), version = version})
    end
    assert(#found > 0, owner .. " declares no " .. name)
    return found
end

local function task_consumer(version, guarded)
    local lines = {
        "import SwiftUI",
        "import Translation",
        "",
    }
    if guarded then
        table.insert(lines, "@available(iOS " .. version .. ", *)")
    end
    local body = {
        "struct Translating: View {",
        "    @State private var configuration: TranslationSession.Configuration?",
        "    let pairs: [String: String]",
        "",
        "    var body: some View {",
        "        Text(\"ABC\")",
        "        .translationTask(self.configuration, action: { session in",
        "            do {",
        "                var requests: [TranslationSession.Request] = []",
        "                for (identifier, text) in pairs {",
        "                    requests.append(TranslationSession.Request(sourceText: text, clientIdentifier: identifier))",
        "                }",
        "                let responses = try await session.translations(from: requests)",
        "                var results: [String: String] = [:]",
        "                for response in responses {",
        "                    if let identifier = response.clientIdentifier {",
        "                        results[identifier] = \"\\(response.targetText)\"",
        "                    }",
        "                }",
        "                _ = results",
        "            } catch let error {",
        "                print(\"Translation error: \\(error)\")",
        "            }",
        "        })",
        "        .translationTask(source: Locale.Language(identifier: \"en\"), target: nil) { session in",
        "            _ = session.sourceLanguage",
        "        }",
        "    }",
        "",
        "    func restart(source: String, target: String) {",
        "        if let current = self.configuration, current.source?.languageCode?.identifier == source, current.target?.languageCode?.identifier == target {",
        "            self.configuration?.invalidate()",
        "        } else {",
        "            self.configuration = .init(source: Locale.Language(identifier: source), target: Locale.Language(identifier: target))",
        "        }",
        "    }",
        "}",
    }
    return table.concat(lines, "\n") .. "\n" .. table.concat(body, "\n") .. "\n"
end

local function consumer(declared, guarded, every)
    local names, passed = {}, {}
    for _, parameter in ipairs(declared.parameters) do
        if every or not parameter.default then
            table.insert(names, parameter.label .. ": " .. parameter.type)
            table.insert(passed, parameter.label .. ": " .. parameter.label)
        end
    end
    local lines = {"import SwiftUI", "import Translation", ""}
    if guarded then
        table.insert(lines, "@available(iOS " .. declared.version .. ", *)")
    end
    table.insert(lines, "func present(_ view: Color, " .. table.concat(names, ", ") .. ") -> some View {")
    table.insert(lines, "    view.translationPresentation(" .. table.concat(passed, ", ") .. ")")
    table.insert(lines, "}")
    return table.concat(lines, "\n") .. "\n"
end

function main()
    local runtime = os.getenv("REVENANT_SWIFT_RUNTIME")
    local compiler = os.getenv("REVENANT_SWIFT_COMPILER")
    local modules = os.getenv("REVENANT_TEST_MODULES")
    assert(runtime and runtime ~= "", "REVENANT_SWIFT_RUNTIME is unset: run this through the swift_backports_tests target")
    assert(compiler and compiler ~= "", "REVENANT_SWIFT_COMPILER is unset: run this through the swift_backports_tests target")
    assert(modules and modules ~= "", "REVENANT_TEST_MODULES is unset: run this through the swift_backports_tests target")
    local sdk = workspace.sdk()
    local declared = declaration(io.readfile(oracle(sdk)), "the SDK")
    local implemented = declaration(io.readfile(shim), "the shim")
    assert(implemented.list == declared.list, string.format("the shim's translationPresentation takes\n  %s\nwhere the SDK declares\n  %s", implemented.list, declared.list))
    assert(implemented.version == declared.version, string.format("the shim declares translationPresentation for iOS %s, the SDK for iOS %s", implemented.version, declared.version))
    local sdk_view = io.readfile(oracle(sdk))
    local declared_tasks = signatures(sdk_view, "the SDK", "translationTask")
    local implemented_tasks = signatures(io.readfile(shim), "the shim", "translationTask")
    assert(#implemented_tasks == #declared_tasks, string.format("the shim declares %d translationTask overloads, the SDK %d", #implemented_tasks, #declared_tasks))
    for index, task in ipairs(declared_tasks) do
        assert(implemented_tasks[index].list == task.list, string.format("the shim's translationTask takes\n  %s\nwhere the SDK declares\n  %s", implemented_tasks[index].list, task.list))
        assert(implemented_tasks[index].version == task.version, string.format("the shim declares translationTask for iOS %s, the SDK for iOS %s", implemented_tasks[index].version, task.version))
    end
    local interfaces = os.files(path.join(sdk, "System", "Library", "Frameworks", "Translation.framework", "Modules", "Translation.swiftmodule", "*.swiftinterface"))
    assert(#interfaces > 0, "the SDK has no Swift interface of the Translation framework")
    local session_text = {}
    for _, file in ipairs(os.files(path.join(sources, "*.swift"))) do
        if file ~= shim then
            table.insert(session_text, io.readfile(file))
        end
    end
    local missing, extra = differences(surface(io.readfile(interfaces[1])), surface(table.concat(session_text, "\n")))
    assert(#missing == 0 and #extra == 0, string.format("the Translation shim differs from the SDK's Translation interface:\n  missing: %s\n  extra: %s", table.concat(missing, "\n           "), table.concat(extra, "\n         ")))

    local search = {}
    for folder in modules:gmatch("[^:]+") do
        table.join2(search, {"-I", folder})
    end
    local out = workspace.run("backports-tests", "Translation")
    os.rm(out)
    os.mkdir(out)
    local function flags_for(module)
        local flags = swift.runtime_flags({architecture = "armv7", deployment = "6.0", sdk = sdk,
                                           resources = path.join(runtime, "lib", "swift"), module = module, optimize = "none"})
        table.join2(flags, search, {"-I", path.join(runtime, "lib", "swift", "iphoneos"), "-swift-version", "5"})
        return flags
    end
    local log = path.join(out, "shim.log")
    local built = table.join(flags_for("Translation"), {"-emit-module", "-emit-module-path", path.join(out, "Translation.swiftmodule")}, os.files(path.join(sources, "*.swift")))
    if not run(compiler, built, log) then
        raise("the Translation shim does not compile for armv7 iOS 6: %s", io.readfile(log) or "")
    end
    local using = table.join(flags_for("TranslationUse"), {"-I", out})
    for name, source in pairs({every = consumer(declared, true, true), required = consumer(declared, true, false)}) do
        local file = path.join(out, name .. ".swift")
        local result = path.join(out, name .. ".log")
        io.writefile(file, source)
        if not run(compiler, table.join(using, {"-typecheck", file}), result) then
            raise("a call of translationPresentation with the arguments the SDK declares (%s) does not typecheck against the shim: %s", name, io.readfile(result) or "")
        end
    end
    local task_file = path.join(out, "task.swift")
    local task_log = path.join(out, "task.log")
    io.writefile(task_file, task_consumer(declared_tasks[1].version, true))
    if not run(compiler, table.join(using, {"-typecheck", task_file}), task_log) then
        raise("a use of translationTask and TranslationSession the way Telegram's translation view does it does not typecheck against the shim: %s", io.readfile(task_log) or "")
    end
    local task_unguarded = path.join(out, "task_unguarded.swift")
    local task_unguarded_log = path.join(out, "task_unguarded.log")
    io.writefile(task_unguarded, task_consumer(declared_tasks[1].version, false))
    if run(compiler, table.join(using, {"-typecheck", task_unguarded}), task_unguarded_log) then
        raise("translationTask typechecks on iOS 6 without an availability guard: the shim is not marked iOS %s", declared_tasks[1].version)
    end
    local task_diagnostic = io.readfile(task_unguarded_log) or ""
    if not task_diagnostic:find("is only available in iOS " .. declared_tasks[1].version .. " or newer", 1, true) then
        raise("the unguarded translationTask fails for another reason than iOS %s availability: %s", declared_tasks[1].version, task_diagnostic)
    end
    local unguarded = path.join(out, "unguarded.swift")
    local unguarded_log = path.join(out, "unguarded.log")
    io.writefile(unguarded, consumer(declared, false, false))
    if run(compiler, table.join(using, {"-typecheck", unguarded}), unguarded_log) then
        raise("translationPresentation typechecks on iOS 6 without an availability guard: the shim is not marked iOS %s", declared.version)
    end
    local diagnostic = io.readfile(unguarded_log) or ""
    if not diagnostic:find("is only available in iOS " .. declared.version .. " or newer", 1, true) then
        raise("the unguarded use fails for another reason than iOS %s availability: %s", declared.version, diagnostic)
    end
end
