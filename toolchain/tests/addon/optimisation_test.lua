import("fixtures")

local FLAGS = {"-target", "armv7-apple-ios6.0", "-mcpu=cortex-a9", "-mfpu=neon", "-O2", "-Wno-incompatible-sysroot", "-S"}

local MISSED = {
    {name = "xor16_alias", pattern = "veor", reason = "a 16-byte xor of pointers that may alias is scalar: 16 loads, 16 eors and 16 stores per byte lane, where NEON does it in three instructions"},
    {name = "mul_add_words_carry64", pattern = "umaal", reason = "a multiply-add with a 64-bit carry keeps the carry's zero high half in adds and adc, and does not form umaal, which the 32-bit carry gets"},
}

local CONTROLS = {
    {name = "xor16_restrict", pattern = "veor", reason = "the same loop with restrict pointers is vectorised, so the backend can do it"},
    {name = "mul_add_words_carry32", pattern = "umaal", reason = "the same multiply-add with a 32-bit carry forms umaal"},
}

local function function_body(assembly, name)
    local start = assembly:find("\n_" .. name .. ":", 1, true)
    if not start then
        return nil
    end
    local stop = assembly:find("-- End function", start, true) or #assembly
    return assembly:sub(start, stop)
end

function failures(opt)
    local found = {}
    local folder = fixtures.scratch()
    local source = path.join(path.directory(opt.modules), "tests", "data", "optimisation", "codegen.c")
    local output = path.join(folder, "codegen.s")
    fixtures.run(folder, opt.clang, table.join(FLAGS, {"-isysroot", opt.sdk, source, "-o", output}))
    local assembly = io.readfile(output)
    for _, case in ipairs(MISSED) do
        local body = function_body(assembly, case.name)
        if not body then
            table.insert(found, case.name .. " is not in the compiled output")
        elseif body:find(case.pattern, 1, true) then
            table.insert(found, case.name .. " is no longer missed, it has " .. case.pattern .. " now: " .. case.reason .. "; move it to the controls")
        end
    end
    for _, case in ipairs(CONTROLS) do
        local body = function_body(assembly, case.name)
        if not body then
            table.insert(found, case.name .. " is not in the compiled output")
        elseif not body:find(case.pattern, 1, true) then
            table.insert(found, case.name .. " lost " .. case.pattern .. ": " .. case.reason)
        end
    end
    os.tryrm(folder)
    return found
end
