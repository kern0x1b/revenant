-- A stand-in for the declaration extractor (tools/found/decls.cc), for the tests of the driver (tools/found/ir.lua) that test the
-- driver's own rules and need no real parse: a shell script that answers the three questions the driver asks first (--target,
-- --version, --list) and runs a body for any other call, which is the run on the framework. The real extractor is built from
-- tools/found (xmake -P tools/found) and is tested by tools/found/tests/run.lua; nothing here needs it built.

-- Writes the stand-in to file. body is the shell text of the run on the framework; version is the identity line --version prints (default
-- "libclang-fixture"); list is the shell text --list prints (default: the framework Fixture alone).
function write(file, body, version, list)
    local text = table.concat({
        "#!/bin/sh",
        "case \"$1\" in",
        "  --target) echo arm64-apple-ios ;;",
        "  --version) echo '" .. (version or "libclang-fixture") .. "' ;;",
        "  --list) " .. (list or "printf 'Fixture\\t/fixture/Fixture.framework\\n'") .. " ;;",
        "  *) " .. body .. " ;;",
        "esac",
        ""}, "\n")
    io.writefile(file, text)
    os.iorunv("chmod", {"755", file})
end

-- The shell body that prints one row of the IR (twenty-one cells, tab separated) for each of rows, a list of cell lists.
function rows_body(rows)
    local out = {}
    for _, cells in ipairs(rows) do
        assert(#cells == 21, "an IR row has twenty-one cells")
        table.insert(out, "printf '" .. table.concat(cells, "\\t") .. "\\n'")
    end
    return table.concat(out, "; ")
end
