import("macho")
import("bundle")
import("core.base.json")

local function listing(folder)
    local files = {}
    for _, file in ipairs(os.files(path.join(folder, "**"))) do
        if not os.islink(file) then
            files[path.relative(file, folder)] = file
        end
    end
    return files
end

local function difference(relative, slices, paths)
    if not relative:endswith(".plist") then
        return relative .. " differs between slices"
    end
    local loaded = {}
    for _, file in ipairs(paths) do
        table.insert(loaded, bundle.read_plist(file))
    end
    local keys = {}
    for _, content in ipairs(loaded) do
        for key in pairs(content) do
            local values = {}
            for _, other in ipairs(loaded) do
                values[json.encode({other[key] == nil and "(absent)" or other[key]})] = true
            end
            if #table.keys(values) > 1 then
                keys[key] = true
            end
        end
    end
    local described = {}
    for _, key in ipairs(table.orderkeys(keys)) do
        local values = {}
        for index, content in ipairs(loaded) do
            table.insert(values, slices[index] .. ": " .. tostring(content[key]))
        end
        table.insert(described, key .. " (" .. table.concat(values, ", ") .. ")")
    end
    local advice = keys.MinimumOSVersion and ". Each slice derives MinimumOSVersion from its own target; pin it in app.plist-file or app.plist" or ""
    return relative .. " differs between slices in " .. table.concat(described, "; ") .. advice
end

function plan(bundles, slices)
    local listings = {}
    local every = {}
    for _, folder in ipairs(bundles) do
        local files = listing(folder)
        table.insert(listings, files)
        for relative in pairs(files) do
            every[relative] = true
        end
    end
    local problems, binaries, partial = {}, {}, {}
    for _, relative in ipairs(table.orderkeys(every)) do
        local paths = {}
        for _, files in ipairs(listings) do
            if not files[relative] then
                table.insert(partial, relative)
                paths = nil
                break
            end
            table.insert(paths, files[relative])
        end
        if paths then
            local kinds = 0
            for _, file in ipairs(paths) do
                kinds = kinds + (macho.is_macho(file) and 1 or 0)
            end
            if kinds == #paths then
                table.insert(binaries, relative)
            elseif kinds > 0 then
                table.insert(problems, relative .. " is a Mach-O in some slices and not in others")
            else
                local first = io.readfile(paths[1], {encoding = "binary"})
                for index = 2, #paths do
                    if io.readfile(paths[index], {encoding = "binary"}) ~= first then
                        table.insert(problems, difference(relative, slices, paths))
                        break
                    end
                end
            end
        end
    end
    if #partial > 0 then
        table.insert(problems, 1, "present in only some slices: " .. table.concat(partial, ", "))
    end
    return binaries, problems
end

function merge(bundles, slices, destination)
    local binaries, problems = plan(bundles, slices)
    if #problems > 0 then
        raise("the slices of %s cannot be merged: %s", path.filename(destination), table.concat(problems, "; "))
    end
    os.tryrm(destination)
    os.vcp(bundles[1], destination)
    local merged = {}
    for _, relative in ipairs(binaries) do
        local output = path.join(destination, relative)
        local inputs = {}
        for _, folder in ipairs(bundles) do
            table.insert(inputs, path.join(folder, relative))
        end
        os.vrunv("xcrun", table.join({"lipo", "-create"}, inputs, {"-output", output}))
        local architectures = os.iorunv("xcrun", {"lipo", "-archs", output}):trim():split("%s+")
        if #architectures ~= #bundles then
            raise("%s came out with %s from %d slices; two slices built for the same architecture cannot be told apart", output, table.concat(architectures, ", "), #bundles)
        end
        table.insert(merged, output)
    end
    return merged
end
