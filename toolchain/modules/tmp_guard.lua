function forbid(label)
    local real_dir, real_file = os.tmpdir, os.tmpfile
    local function guard(name, real)
        return function (...)
            local info = debug.getinfo(2, "S")
            if info and info.short_src and info.short_src:startswith("@programdir") then
                return real(...)
            end
            raise("%s calls %s, which is the system temporary folder: a test works in a folder of its own under the scratch of the checkout (fixtures.scratch() in a light suite, workspace.fresh(name) elsewhere)", label, name)
        end
    end
    os.tmpdir = guard("os.tmpdir", real_dir)
    os.tmpfile = guard("os.tmpfile", real_file)
    return function ()
        os.tmpdir, os.tmpfile = real_dir, real_file
    end
end
