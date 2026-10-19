local lib = import("vtlib", {rootdir = os.scriptdir(), anonymous = true})

function main(path, old, new)
    if not path or not old or not new then
        raise("mutate.lua: pass FILE OLD NEW")
    end
    local text = lib.read_text(path)
    local count = lib.count_plain(text, old)
    if count ~= 1 then
        io.stderr:write(string.format("mutate.py: %s appears %d times in %s, so the mutation would not be a mutation\n",
            lib.py_repr(old), count, path))
        os.exit(1)
    end
    local s, e = string.find(text, old, 1, true)
    lib.write_text(path, string.sub(text, 1, s - 1) .. new .. string.sub(text, e + 1))
end
