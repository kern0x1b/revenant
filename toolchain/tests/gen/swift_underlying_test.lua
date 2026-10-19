local TOOLS = path.join(os.scriptdir(), "..", "..", "tools")
local SCRATCH = path.join(os.scriptdir(), "..", "..", "build", "swift-underlying-test")

local function write(filepath, text)
    os.mkdir(path.directory(filepath))
    local handle = assert(io.open(filepath, "wb"), "cannot write " .. filepath)
    handle:write(text)
    handle:close()
end

local function words_of(command)
    local words = {}
    for word in string.gmatch(command, "'([^']*)'") do
        table.insert(words, word)
    end
    return words
end

local function flag_value(words, flag)
    for i, word in ipairs(words) do
        if word == flag then
            return true, words[i + 1]
        end
    end
    return false, nil
end

function main()
    local roundtrip = import("gen.swift_roundtrip", {rootdir = TOOLS, anonymous = true})
    local failures = 0
    local function check(ok, label)
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end

    os.rm(SCRATCH)
    local headers = path.join(SCRATCH, "headers")
    write(path.join(headers, "Frameworks", "Fix.framework", "Modules", "module.modulemap"),
          "framework module Fix {\n  umbrella header \"Fix.h\"\n  export *\n}\n")
    write(path.join(headers, "Frameworks", "Fix.framework", "Headers", "Fix.h"), "#pragma clang system_header\n")
    write(path.join(headers, "Frameworks", "Other.framework", "Headers", "Other.h"), "#pragma clang system_header\n")

    local module_dir = path.join(SCRATCH, "out", "Fix", "module")
    os.mkdir(module_dir)
    local folder = roundtrip.underlying_of(headers, module_dir, "Fix")
    check(folder ~= nil, "a module with a module map has an underlying folder")
    if folder ~= nil then
        check(os.isfile(path.join(folder, "Fix.framework", "Modules", "module.modulemap")),
              "the folder links the module's own framework, module map included")
        check(not os.isfile(path.join(folder, "Other.framework", "Headers", "Other.h")),
              "the folder holds no other framework of the headers tree")
    end

    local other_dir = path.join(SCRATCH, "out", "Other", "module")
    os.mkdir(other_dir)
    check(roundtrip.underlying_of(headers, other_dir, "Other") == nil, "a module with no module map has no underlying folder")
    check(roundtrip.underlying_of(headers, other_dir, "Missing") == nil, "a module the headers tree lacks has no underlying folder")

    local source = path.join(SCRATCH, "out", "Fix", "Fix.swift")
    local with = roundtrip.compile_item("arm64e-apple-ios26.2", "/sdk", source, module_dir, "Fix", folder)
    local words = words_of(with.command)
    local has_import, _ = flag_value(words, "-import-underlying-module")
    local has_f, f_value = flag_value(words, "-F")
    check(has_import, "the compile imports the underlying module: " .. with.command)
    check(has_f and f_value == folder, "the compile puts the module's folder on -F: " .. with.command)
    local has_name, name_value = flag_value(words, "-module-name")
    check(has_name and name_value == "Fix", "the compile is under the module's name")

    local without = roundtrip.compile_item("arm64e-apple-ios26.2", "/sdk", source, other_dir, "Other", nil)
    local bare = words_of(without.command)
    check(not flag_value(bare, "-import-underlying-module") and not flag_value(bare, "-F"),
          "a compile with no underlying folder has no -F and no -import-underlying-module")

    local sdk = path.join(SCRATCH, "sdk")
    write(path.join(sdk, "usr", "include", "Clangy", "module.modulemap"), "module Clangy [system] {\n  umbrella header \"Clangy.h\"\n}\n")
    local sdk_item = roundtrip.compile_item("arm64e-apple-ios26.2", sdk, source, other_dir, "Clangy", nil)
    local sdk_words = words_of(sdk_item.command)
    check(flag_value(sdk_words, "-import-underlying-module") and not flag_value(sdk_words, "-F"),
          "a clang module of the SDK's include tree is imported as the underlying module, with no -F")
    local plain = roundtrip.compile_item("arm64e-apple-ios26.2", sdk, source, other_dir, "Other", nil)
    check(not flag_value(words_of(plain.command), "-import-underlying-module"),
          "a module with no clang module is not given an underlying import")

    print("swift underlying test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end
