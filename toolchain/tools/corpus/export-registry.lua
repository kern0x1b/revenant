import("core.base.json")
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})

function main(root, outfile)
    local files = table.join(os.files(path.join(root, "registry", "*.json")), os.files(path.join(root, "registry", "*", "*.json")))
    byteorder.sort(files)
    local out = io.open(outfile, "w")
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
