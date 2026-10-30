local lowered = import("lowered", {rootdir = path.join(os.scriptdir(), "..", "..", "modules", "apple"), anonymous = true})
local workspace = import("workspace", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})
local json = import("core.base.json")

local function child(node, name)
    for _, entry in ipairs(node.contents or {}) do
        if entry.name == name then
            return entry
        end
    end
end

local function node_at(vfs, file)
    for _, root in ipairs(vfs.roots) do
        local rest = file:sub(#root.name + 1)
        if file:sub(1, #root.name) == root.name and (rest == "" or rest:sub(1, 1) == "/") then
            local node = root
            for part in rest:gmatch("[^/]+") do
                node = node and child(node, part)
            end
            return node
        end
    end
end

local function names_in(vfs, dir)
    local node = node_at(vfs, dir)
    local names = {}
    for _, entry in ipairs(node and node.contents or {}) do
        table.insert(names, entry.name)
    end
    table.sort(names)
    return table.concat(names, ", ")
end

function failures()
    local found = {}
    local output = workspace.run("vfs-directory")
    os.rm(output)
    local real = path.join(output, "real")
    local copies = path.join(output, "lowered")
    os.mkdir(path.join(real, "Sub", "Deeper"))
    os.mkdir(copies)
    io.writefile(path.join(real, "A.h"), "real A\n")
    io.writefile(path.join(real, "Other.h"), "real Other\n")
    io.writefile(path.join(real, "Sub", "B.h"), "real B\n")
    io.writefile(path.join(real, "Sub", "Deeper", "C.h"), "real C\n")
    local lowered_a = path.join(copies, "A.h")
    local lowered_b = path.join(copies, "B.h")
    local extra = path.join(copies, "Extra.h")
    io.writefile(lowered_a, "lowered A\n")
    io.writefile(lowered_b, "lowered B\n")
    io.writefile(extra, "extra\n")

    local roots = {
        [real] = {["A.h"] = lowered_a, ["Extra.h"] = extra},
        [path.join(real, "Sub")] = {["B.h"] = lowered_b},
    }
    local text = "{\"version\": 0, \"case-sensitive\": false, \"roots\": [\n" .. table.concat(lowered.directory_roots(roots), ",\n") .. "\n]}"
    local vfs = json.decode(text)
    if not vfs then
        table.insert(found, "the overlay is not valid JSON: " .. text)
        return found
    end
    if #vfs.roots ~= 1 or vfs.roots[1].name ~= real then
        table.insert(found, "the overlay lists " .. #vfs.roots .. " roots, not the one real directory: a directory inside a root must be listed in its parent")
    end

    local function resolves(file, expected)
        local node = node_at(vfs, file)
        if not node or node.type ~= "file" or node["external-contents"] ~= expected then
            table.insert(found, file .. " does not resolve to " .. expected .. " in the overlay")
        end
    end
    local function lists(dir, expected)
        if names_in(vfs, dir) ~= expected then
            table.insert(found, dir .. " lists " .. names_in(vfs, dir) .. ", not " .. expected)
        end
    end

    lists(real, "A.h, Extra.h, Other.h, Sub")
    lists(path.join(real, "Sub"), "B.h, Deeper")
    lists(path.join(real, "Sub", "Deeper"), "C.h")
    resolves(path.join(real, "A.h"), lowered_a)
    resolves(path.join(real, "Other.h"), path.join(real, "Other.h"))
    resolves(path.join(real, "Extra.h"), extra)
    resolves(path.join(real, "Sub", "B.h"), lowered_b)
    resolves(path.join(real, "Sub", "Deeper", "C.h"), path.join(real, "Sub", "Deeper", "C.h"))
    return found
end
