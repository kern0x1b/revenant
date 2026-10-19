import("core.base.json")

function main(folder, ...)
    for _, file in ipairs({...}) do
        local filepath = path.join(folder, file)
        assert(os.isfile(filepath), "registry-functions: no registry file " .. filepath)
        local data = json.decode(io.readfile(filepath))
        assert(data.entries, "registry-functions: " .. filepath .. " has no entries")
        for _, entry in ipairs(data.entries) do
            if entry.kind == "function" then
                print((entry.api:gsub("%(%)$", "")))
            end
        end
    end
end
