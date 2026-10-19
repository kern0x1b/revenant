import("fixtures")

function failures(opt)
    local found = {}
    local folder = fixtures.scratch()
    local arclite = path.join(opt.modules, "..", "packages", "i", "iphoneos-sdk", "arclite")
    local probe = path.join(os.scriptdir(), "weak", "weak_probe.m")
    local modes = {
        {"without a system weak reference runtime", {"-DCHARON_WITHOUT_NATIVE", "-Ddlsym=charon_test_dlsym"}},
        {"forwarding to the system weak reference runtime", {}}
    }
    for index, mode in ipairs(modes) do
        local objects = {}
        for _, source in ipairs(os.files(path.join(arclite, "*.m"))) do
            local object = path.join(folder, index .. "-" .. path.basename(source) .. ".o")
            fixtures.run(folder, "xcrun", table.join({"clang", "-fno-objc-arc", "-w"}, mode[2], {"-c", source, "-o", object}))
            table.insert(objects, object)
        end
        local probe_object = path.join(folder, index .. "-probe.o")
        fixtures.run(folder, "xcrun", table.join({"clang", "-fobjc-arc", "-w"}, mode[2], {"-c", probe, "-o", probe_object}))
        local program = path.join(folder, "probe" .. index)
        fixtures.run(folder, "xcrun", table.join({"clang", "-framework", "Foundation"}, objects, {probe_object, "-o", program}))
        local output = try { function () return os.iorunv(program) end, catch { function (errors) table.insert(found, mode[1] .. ": " .. tostring(errors)) end } }
        if output and not output:find("failures 0", 1, true) then
            table.insert(found, mode[1] .. ": " .. output:trim())
        end
    end
    os.tryrm(folder)
    return found
end
