local steps = import("steps", {rootdir = path.directory(os.scriptdir()), anonymous = true})

local HERE = os.scriptdir()

function run(opt)
    opt = opt or {}
    local build = opt.build or steps.env("BUILD") or steps.workspace().fresh("charon-uttypetags-host")
    local probe = path.join(build, "probe")
    os.vrunv("xcrun", {"clang", "-fobjc-arc", "-w", "-I" .. HERE, path.join(HERE, "probe.m"), "-framework", "Foundation",
                       "-framework", "CoreServices", "-o", probe})
    local table_file = path.join(build, "host.txt")
    os.execv(probe, {}, {stdout = table_file})
    return table_file
end

function main()
    steps.guard(function ()
        print(run())
    end)
end
