import("core.base.json")
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})

function main(root, outfile)
    local files = table.join(os.files(path.join(root, "registry", "*.json")), os.files(path.join(root, "registry", "*", "*.json")))
    byteorder.sort(files)
    local out = io.open(outfile, "w")
    -- "kind" is appended as a 5th column, not inserted before "introduced": every existing
    -- reader keys columns by position (framework=0, api=1, status=2, introduced=3), and an
    -- insert in the middle would silently shift "introduced" into every reader that does
    -- p[3]-by-index without ever raising. Appending is safe for all of them.
    out:write("framework\tapi\tstatus\tintroduced\tkind\n")
    for _, file in ipairs(files) do
        local held = json.decode(io.readfile(file))
        local fw = held.framework or ""
        for _, entry in ipairs(held.entries or held) do
            out:write(string.format("%s\t%s\t%s\t%s\t%s\n", fw, entry.api, entry.status or "", entry.introduced or "", entry.kind or ""))
        end
    end
    out:close()
    print("wrote " .. outfile)
end
