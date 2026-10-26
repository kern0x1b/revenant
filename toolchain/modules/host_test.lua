import("private.action.run.runenvs")

function run(target, opt)
    local envs = opt.runenvs
    if not envs then
        local addenvs, setenvs = runenvs.make(target)
        envs = runenvs.join(addenvs, setenvs)
    end
    local rundir = opt.rundir or target:rundir()
    local targetfile = path.absolute(target:targetfile())
    local runargs = table.wrap(opt.runargs or target:get("runargs"))
    local autogendir = path.join(target:autogendir(), "tests")
    local logname = opt.name:gsub("[/\\>=<|%*]", "_")
    local outfile = path.absolute(path.join(autogendir, logname .. ".out"))
    local errfile = path.absolute(path.join(autogendir, logname .. ".err"))
    os.mkdir(autogendir)
    os.tryrm(outfile)
    os.tryrm(errfile)
    local status, syserrors = os.execv("/bin/sh", table.join({"-c", '"$0" "$@"; exit $?', targetfile}, runargs),
        {try = true, curdir = rundir, envs = envs, stdout = outfile, stderr = errfile})
    local outdata = os.isfile(outfile) and io.readfile(outfile) or ""
    local errdata = os.isfile(errfile) and io.readfile(errfile) or ""
    if #outdata > 0 then
        opt.stdout = outdata
    end
    if #errdata > 0 then
        opt.stderr = errdata
    end
    if status == nil or status < 0 then
        opt.errors = string.format("run %s died without an exit code: %s", opt.name, syserrors or "unknown reason")
        return false
    elseif status > 128 then
        opt.errors = string.format("run %s died by signal %d", opt.name, status - 128)
        return false
    elseif status == 0 then
        if opt.expect_failure then
            opt.errors = string.format("run %s exited 0, but a negative case must fail", opt.name)
            return false
        end
        return true
    elseif opt.expect_failure then
        return true
    end
    opt.errors = string.format("run %s failed, exit code: %d", opt.name, status)
    return false
end
