local cached_program

function program()
    if os.getenv("CCACHE_DISABLE") then
        return nil
    end
    if cached_program then
        return cached_program
    end
    local given = os.getenv("CCACHE")
    if given and given ~= "" then
        cached_program = os.isexec(given) and given or nil
    else
        for _, folder in ipairs((os.getenv("PATH") or ""):split(path.envsep())) do
            local found = path.join(folder, "ccache")
            if os.isexec(found) then
                cached_program = found
                break
            end
        end
    end
    return cached_program
end

function wrapped(compiler, arguments)
    local wrapper = program()
    if not wrapper or not compiler then
        return compiler, arguments
    end
    return wrapper, table.join({compiler}, arguments)
end

function iorunv(compiler, arguments, opt)
    local program, argv = wrapped(compiler, arguments)
    return os.iorunv(program, argv, opt)
end

function execv(compiler, arguments, opt)
    local program, argv = wrapped(compiler, arguments)
    return os.execv(program, argv, opt)
end
