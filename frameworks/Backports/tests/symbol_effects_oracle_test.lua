local workspace = import("@addon.revenant.workspace", {anonymous = true})
local TESTS = path.absolute(os.scriptdir())
local PROBE = path.join(TESTS, "symbol_effects", "main.swift")
local RUNTIME = path.absolute(path.join(TESTS, "..", "..", "..", "toolchain", "src", "swift-runtime", "overlay", "Symbols"))
local MUTATED_LINE = "options.repetition = .count(1)"
local MUTATED_TO = "options.repetition = .count(2)"

local function xcrun(args)
    return os.iorunv("xcrun", args):trim()
end

local function compile(work, name, sources)
    local output = path.join(work, name)
    local flags = {"-Onone", "-module-name", "SymbolEffectsProbe", "-sdk", xcrun({"--sdk", "macosx", "--show-sdk-path"}), "-o", output,
                   "-module-cache-path", path.join(work, "swift-modules"), "-Xcc", "-fmodules-cache-path=" .. path.join(work, "clang-modules")}
    os.vrunv("xcrun", table.join({"swiftc"}, flags, sources))
    return output
end

local function lines_of(text)
    local lines = {}
    for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
        table.insert(lines, line)
    end
    return lines
end

local function differing(expected, actual)
    local expected_lines, actual_lines = lines_of(expected), lines_of(actual)
    local found = {}
    for index = 1, math.max(#expected_lines, #actual_lines) do
        if expected_lines[index] ~= actual_lines[index] then
            table.insert(found, string.format("line %d\n  macOS:    %s\n  backport: %s", index,
                expected_lines[index] or "<missing>", actual_lines[index] or "<missing>"))
        end
    end
    return found
end

function main()
    local work = workspace.fresh("symbol-effects-oracle")
    local oracle = os.iorunv(compile(work, "oracle", {PROBE}))
    local backport = os.iorunv(compile(work, "backport", table.join({PROBE}, os.files(path.join(RUNTIME, "*.swift")))))
    local mismatch = differing(oracle, backport)
    assert(#mismatch == 0, "the backport's Symbols disagrees with macOS:\n" .. table.concat(mismatch, "\n"))

    local damaged = path.join(work, "damaged")
    os.mkdir(damaged)
    local sources = {}
    for _, file in ipairs(os.files(path.join(RUNTIME, "*.swift"))) do
        local text = io.readfile(file)
        if path.filename(file) == "SymbolEffectOptions.swift" then
            local start, finish = string.find(text, MUTATED_LINE, 1, true)
            assert(start and not string.find(text, MUTATED_LINE, finish + 1, true),
                "the negative control needs exactly one `" .. MUTATED_LINE .. "` in SymbolEffectOptions.swift")
            text = string.sub(text, 1, start - 1) .. MUTATED_TO .. string.sub(text, finish + 1)
        end
        local copy = path.join(damaged, path.filename(file))
        io.writefile(copy, text)
        table.insert(sources, copy)
    end
    local broken = os.iorunv(compile(work, "damaged_backport", table.join({PROBE}, sources)))
    local detected = differing(oracle, broken)
    assert(#detected > 0, "the negative control passed: a damaged copy of the backport's Symbols agrees with macOS, so the comparison proves nothing")

    os.tryrm(work)
    print(string.format("SYMBOL_EFFECTS_ORACLE_TEST passed (%d probe lines agree with macOS, negative control detected %d differing lines)",
        #lines_of(oracle) - 1, #detected))
end
