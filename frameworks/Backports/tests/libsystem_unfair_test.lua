local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))

function main()
    local out = workspace.run("backports-tests", "LibSystemUnfair")
    local source = path.join(backports, "src", "libSystem")
    local compat = path.join(backports, "..", "..", "toolchain", "src", "apple-compat")
    local flags = {"-std=gnu11", "-Wall", "-Werror", "-I", path.join(backports, "src"), "-I", source,
                   "-I", path.join(compat, "src"), "-I", path.join(compat, "include")}
    local objects = {}
    local function compile(file)
        local object = path.join(out, path.basename(file) .. ".o")
        os.vrunv("xcrun", table.join({"clang", "-c"}, flags, {"-o", object, file}))
        table.insert(objects, object)
    end
    compile(path.join(backports, "tests", "libsystem_unfair", "main.c"))
    compile(path.join(source, "RevenantUnfairLock.c"))
    compile(path.join(source, "RevenantClockGettimeNsecNp.c"))
    for _, name in ipairs({"__ulock_wait", "__ulock_wake", "clock_gettime", "clock_gettime_nsec_np"}) do
        compile(path.join(compat, "src", name .. ".c"))
    end
    local binary = path.join(out, "libsystem_unfair")
    os.vrunv("xcrun", table.join({"clang", "-o", binary}, objects, {"-lpthread"}))
    local output = os.iorunv(binary)
    io.write(output)
    assert(output:find("checks passed", 1, true), "the libSystem unfair lock and clock fixture did not finish")
end
