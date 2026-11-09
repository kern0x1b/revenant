local aliases = import("host_alias", {rootdir = path.join(os.scriptdir(), "..", "tools"), anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local source = path.join(backports, "src", "Accelerate")
local tests = path.join(backports, "tests", "vimage_scale")

function main()
    local out = workspace.run("backports-tests", "VImageScale")
    local objects, sources = {}, {}
    for _, name in ipairs({"vImageScale7", "vImageScale8"}) do
        local object = path.join(out, name .. ".o")
        os.vrunv("clang", {"-fobjc-arc", "-Wall", "-Werror", "-I", source, "-c", path.join(source, name .. ".m"), "-o", object})
        table.insert(objects, object)
        table.insert(sources, path.join(source, name .. ".m"))
    end
    local exe = path.join(out, "scale_test")
    os.vrunv("clang", table.join({"-std=gnu11", "-Wall", "-Werror", path.join(tests, "scale_test.c")}, objects, aliases.flags(sources), {"-framework", "Accelerate", "-ldl", "-o", exe}))
    os.vrunv(exe)
end
