import("fixtures")

function failures(opt)
    local found = {}
    local folder = fixtures.scratch()
    local runtime = path.join(opt.modules, "..", "packages", "i", "iphoneos-sdk", "blocks", "BlocksRuntime.m")
    local probe = path.join(os.scriptdir(), "blocks", "blocks_probe.m")
    local modes = {
        {"without a system blocks runtime", {"-DCHARON_WITHOUT_NATIVE", "-Ddlsym=charon_test_dlsym", "-DMALLOC_BLOCK_CLASS=\"__CharonMallocBlock\""}},
        {"forwarding to the system blocks runtime", {"-DMALLOC_BLOCK_CLASS=\"__NSMallocBlock__\""}}
    }
    for index, mode in ipairs(modes) do
        local program = path.join(folder, "probe" .. index)
        fixtures.run(folder, "xcrun", table.join({"clang", "-fno-objc-arc", "-w", "-framework", "Foundation"}, mode[2], {runtime, probe, "-o", program}))
        local output = try { function () return os.iorunv(program) end, catch { function (errors) table.insert(found, mode[1] .. ": " .. tostring(errors)) end } }
        if output and not output:find("failures 0", 1, true) then
            table.insert(found, mode[1] .. ": " .. output:trim())
        end
    end
    os.tryrm(folder)
    return found
end
