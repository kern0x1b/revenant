local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))

function main()
    local out = workspace.run("backports-tests", "LibSystemDispatch")
    local source = path.join(backports, "src", "libSystem")
    local compat = path.join(backports, "..", "..", "toolchain", "src", "apple-compat")
    local flags = {"-std=gnu11", "-Wall", "-Werror", "-fblocks", "-I", path.join(backports, "src"), "-I", source,
                   "-I", path.join(compat, "include")}
    local objects = {}
    local function compile(file, extra)
        local object = path.join(out, path.basename(file) .. ".o")
        os.vrunv("xcrun", table.join({"clang", "-c"}, flags, extra or {}, {"-o", object, file}))
        table.insert(objects, object)
    end
    compile(path.join(backports, "tests", "libsystem_dispatch", "main.c"))
    compile(path.join(source, "RevenantDispatchData.c"), {"-Ddispatch_data_create=revenant_test_dispatch_data_create"})
    compile(path.join(source, "RevenantMemsetS.c"))
    compile(path.join(compat, "src", "memset_s.c"))
    local binary = path.join(out, "libsystem_dispatch")
    os.vrunv("xcrun", table.join({"clang", "-o", binary}, objects))
    local output = os.iorunv(binary)
    io.write(output)
    assert(output:find("checks passed", 1, true), "the libSystem dispatch fixture did not finish")
end
