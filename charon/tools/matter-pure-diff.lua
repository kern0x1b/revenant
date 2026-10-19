-- The Matter differential of behaviour: the port's answers against the host's, line by line.
--
-- tests/backports/host/matter/pure.m is one program with no device on the other end. The host's answers are what its
-- own framework gives (run.sh). This product has NO port-side answers: its library carries the cluster and data
-- classes only, so pure.m does not link against it and no port file exists to pass here. Each file prints
-- "name<TAB>answer" per line, and this reads the two files and says which names differ, for a product that carries
-- the classes pure.m asks about.
--
-- A name in one file and not the other is a difference too, and the direction of it is the finding: the host answers
-- for a name the port does not carry, or the port carries a name the host does not. A name neither answers is the
-- third case and is not a difference - it is a row of the surface no framework of either kind has, which the host
-- differential says of the surface as a whole.
--
-- Usage: xmake l tools/matter-pure-diff.lua <host.tsv> <port.tsv> [--out file]
import("core.base.json")

local function read(file)
    local found, order = {}, {}
    for line in io.lines(file) do
        local name, answer = line:match("^([^\t]*)\t(.*)$")
        if name then
            if found[name] == nil then
                table.insert(order, name)
            end
            found[name] = answer
        end
    end
    return found, order
end

function main(host, port, ...)
    local outfile
    local arguments = {...}
    for index = 1, #arguments - 1 do
        if arguments[index] == "--out" then
            outfile = arguments[index + 1]
        end
    end
    outfile = outfile or path.join(os.scriptdir(), "..", ".agent-work", "matter-pure-diff.tsv")
    assert(os.isfile(host), "%s is not there: sh tests/backports/host/matter/run.sh writes the host's answers", host)
    assert(os.isfile(port), "%s is not there: this product has no port-side pure.m answers (its library carries the cluster and data classes only)", port)
    local theirs, their_order = read(host)
    local ours, our_order = read(port)

    local same, differ, only_host, only_port, neither = 0, {}, {}, {}, 0
    local names = {}
    for _, name in ipairs(their_order) do names[name] = true end
    for _, name in ipairs(our_order) do names[name] = true end
    for _, name in ipairs(table.orderkeys(names)) do
        local a, b = theirs[name], ours[name]
        if a and b then
            if a == b then
                same = same + 1
            else
                table.insert(differ, {name = name, host = a, port = b})
            end
        elseif a then
            only_host[name] = a
        elseif b then
            only_port[name] = b
        else
            neither = neither + 1
        end
    end

    print("Matter behaviour: %d names, %d the same answer, %d a different answer", #names, same, #differ)
    print("  only the host answers %d, only the port answers %d", table.orderkeys(only_host) and #table.orderkeys(only_host) or 0,
          #table.orderkeys(only_port))
    for _, entry in ipairs(differ) do
        printf("  DIFF %s\n    host: %s\n    port: %s\n", entry.name, entry.host, entry.port)
    end
    for _, name in ipairs(table.orderkeys(only_host)) do
        printf("  HOST ONLY %s: %s\n", name, only_host[name])
    end
    for _, name in ipairs(table.orderkeys(only_port)) do
        printf("  PORT ONLY %s: %s\n", name, only_port[name])
    end

    local lines = {}
    for _, entry in ipairs(differ) do
        table.insert(lines, string.format("diff\t%s\t%s\t%s", entry.name, entry.host, entry.port))
    end
    for _, name in ipairs(table.orderkeys(only_host)) do
        table.insert(lines, string.format("host_only\t%s\t%s", name, only_host[name]))
    end
    for _, name in ipairs(table.orderkeys(only_port)) do
        table.insert(lines, string.format("port_only\t%s\t%s", name, only_port[name]))
    end
    os.mkdir(path.directory(outfile))
    io.writefile(outfile, #lines > 0 and (table.concat(lines, "\n") .. "\n") or "")
    print("wrote %d differences to %s", #lines, outfile)
    return #differ == 0 and #table.orderkeys(only_host) == 0 and #table.orderkeys(only_port) == 0
end
