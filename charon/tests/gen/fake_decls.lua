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

function rows_body(rows)
    local out = {}
    for _, cells in ipairs(rows) do
        assert(#cells == 21, "an IR row has twenty-one cells")
        table.insert(out, "printf '" .. table.concat(cells, "\\t") .. "\\n'")
    end
    return table.concat(out, "; ")
end
