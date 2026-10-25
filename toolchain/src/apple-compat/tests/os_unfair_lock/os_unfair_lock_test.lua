local lowered = import("@addon.revenant.apple.lowered", {anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})

local function compiles(sdk, vfs, source, log)
    local code = os.execv("xcrun", {"clang", "-target", "armv7-apple-ios6.0", "-isysroot", sdk,
                                    "-Werror=unguarded-availability-new", "-Werror=unguarded-availability",
                                    "-ivfsoverlay", vfs, "-c", source, "-o", log .. ".o"},
                          {try = true, stdout = log, stderr = log})
    return code == 0, io.readfile(log) or ""
end

function main()
    local dir = path.absolute(os.scriptdir())
    local compat = path.absolute(path.join(dir, "..", ".."))
    local sources = {}
    for _, name in ipairs({"lock", "trylock", "unlock", "assert_owner", "assert_not_owner"}) do
        table.insert(sources, path.join(compat, "src", "os_unfair_lock_" .. name .. ".c"))
    end
    local test = path.join(dir, "os_unfair_lock_test.c")
    local out = workspace.run("apple-compat-dispatch")
    local apple, ours = path.join(out, "apple"), path.join(out, "ours")
    os.vrunv("xcrun", {"clang", "-O1", "-o", apple, test, "-lpthread"})
    os.vrunv("xcrun", table.join({"clang", "-O1", "-I", path.join(compat, "include"), "-o", ours, test}, sources, {"-lpthread"}))
    local expected = os.iorunv(apple)
    local actual = os.iorunv(ours)
    assert(actual == expected, "os_unfair_lock differs from the host's:\n" .. expected .. "---\n" .. actual)

    local sdk = workspace.sdk()
    local vfs = lowered.overlay(sdk, path.join(out, "overlay"))
    local probes = path.join(out, "probes")
    os.mkdir(probes)
    local lock = path.join(probes, "lock.c")
    io.writefile(lock, "#include <os/lock.h>\nvoid f(os_unfair_lock *l) { os_unfair_lock_lock(l); os_unfair_lock_unlock(l); }\n")
    local flags = path.join(probes, "flags.c")
    io.writefile(flags, "#include <os/lock.h>\nvoid g(os_unfair_lock *l) { os_unfair_lock_lock_with_flags(l, 0); }\n")
    local ok, text = compiles(sdk, vfs, lock, path.join(probes, "lock.log"))
    assert(ok, "the lowered os/lock.h does not compile the backported members at iOS 6.0:\n" .. text)
    local refused, refusal = compiles(sdk, vfs, flags, path.join(probes, "flags.log"))
    assert(not refused and refusal:find("os_unfair_lock_lock_with_flags' is only available on iOS 18", 1, true),
           "the lowered header must keep the iOS 18 flags API guarded")
end
