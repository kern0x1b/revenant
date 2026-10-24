function failures(opts)
    local emulator = import("emulator", {rootdir = opts.modules, anonymous = true})
    local failures = 0
    local function check(name, got, want)
        if got ~= want then
            print(string.format("  %s FAIL: got %s, want %s", name, tostring(got), tostring(want)))
            failures = failures + 1
        end
    end

    check("a boot that made progress recently is not expired", emulator.boot_expired(70000, 69000, 0, 60), false)
    check("a boot silent for longer than the deadline is expired", emulator.boot_expired(130000, 69000, 0, 60), true)
    check("a boot inside its first deadline is not expired", emulator.boot_expired(30000, 0, 0, 60), false)
    check("a boot past the ceiling is expired even while it progresses",
          emulator.boot_expired(601000, 600500, 0, 60), true)
    check("the ceiling is ten deadlines", emulator.boot_expired(599000, 598900, 0, 60), false)

    local out = {}
    if failures > 0 then
        out[#out + 1] = string.format("%d failures", failures)
    end
    return out
end
