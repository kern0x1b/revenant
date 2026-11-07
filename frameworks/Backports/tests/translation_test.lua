local swift = import("@addon.revenant.apple.swift", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local shim = path.join(backports, "src", "Translation", "Translation.swift")

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
    local built = table.join(flags_for("Translation"), {"-emit-module", "-emit-module-path", path.join(out, "Translation.swiftmodule"), shim})
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
