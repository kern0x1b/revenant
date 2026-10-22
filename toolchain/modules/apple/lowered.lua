local LOWERINGS = {
    {
        name = "os",
        directory = {"usr", "include", "os"},
        file = "lock.h",
        find = "#define OS_UNFAIR_LOCK_AVAILABILITY \\\n\t\t__API_AVAILABLE(macos(10.12), ios(10.0), tvos(10.0), watchos(3.0))",
        replace = "#define OS_UNFAIR_LOCK_AVAILABILITY",
    },
    {
        name = "Foundation",
        directory = {"System", "Library", "Frameworks", "Foundation.framework", "Headers"},
        file = "NSJSONSerialization.h",
        find = "NSJSONWritingSortedKeys API_AVAILABLE(macos(10.13), ios(11.0), watchos(4.0), tvos(11.0)) = (1UL << 1),",
        replace = "NSJSONWritingSortedKeys = (1UL << 1),",
    },
}

local function directory_of(sdk, lowering)
    local parts = {sdk}
    table.join2(parts, lowering.directory)
    return path.join(table.unpack(parts))
end

local function lowered(sdk, lowering)
    local text = io.readfile(path.join(directory_of(sdk, lowering), lowering.file))
    local start, stop = text:find(lowering.find, 1, true)
    if not start then
        raise("the iPhoneOS SDK at %s declares %s without the availability the backports lower", sdk, lowering.file)
    end
    return text:sub(1, start - 1) .. lowering.replace .. text:sub(stop + 1)
end

local function write_if_changed(file, text)
    if os.isfile(file) and io.readfile(file) == text then
        return
    end
    io.writefile(file, text)
end

function overlay(sdk, out)
    local roots = {}
    for _, lowering in ipairs(LOWERINGS) do
        local copy = path.join(out, lowering.name, lowering.file)
        os.mkdir(path.join(out, lowering.name))
        write_if_changed(copy, lowered(sdk, lowering))
        table.insert(roots, string.format([[
    {
      "name": "%s",
      "type": "directory",
      "contents": [
        {"name": "%s", "type": "file", "external-contents": "%s"}
      ]
    }]], directory_of(sdk, lowering), lowering.file, copy))
    end
    local vfs = path.join(out, "vfs.yaml")
    write_if_changed(vfs, string.format([[
{
  "version": 0,
  "case-sensitive": false,
  "roots": [
%s
  ]
}
]], table.concat(roots, ",\n")))
    return vfs
end
