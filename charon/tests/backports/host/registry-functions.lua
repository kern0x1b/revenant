-- registry-functions.lua: the names of the function entries a host differential renames in the port's objects.
--
--   xmake l registry-functions.lua <registry folder> <file.json>...
--
-- Prints the api of every entry of kind "function" in the named registry files, with its trailing "()" removed,
-- one name per line. A differential passes these to the compiler as -D renames so the port's objects and the host's
-- answers can sit in one binary. The names come from the registry, so a function added there is renamed too.
-- A file that is not there is an error: a missing file would rename nothing, and the differential would compare the
-- host with itself.
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
