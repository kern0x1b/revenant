local MEMBERS = {
    {
        member = "os_unfair_lock",
        header = {
            name = "os",
            directory = {"usr", "include", "os"},
            file = "lock.h",
            find = "#define OS_UNFAIR_LOCK_AVAILABILITY \\\n\t\t__API_AVAILABLE(macos(10.12), ios(10.0), tvos(10.0), watchos(3.0))",
            replace = "#define OS_UNFAIR_LOCK_AVAILABILITY",
        },
    },
    {
        member = "NSJSONWritingSortedKeys",
        header = {
            name = "Foundation",
            directory = {"System", "Library", "Frameworks", "Foundation.framework", "Headers"},
            file = "NSJSONSerialization.h",
            find = "NSJSONWritingSortedKeys API_AVAILABLE(macos(10.13), ios(11.0), watchos(4.0), tvos(11.0)) = (1UL << 1),",
            replace = "NSJSONWritingSortedKeys = (1UL << 1),",
        },
        overlay = {
            file = {"stdlib", "public", "Darwin", "Foundation", "JSONEncoder.swift"},
            find = "        @available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *)\n        public static let sortedKeys    = OutputFormatting(rawValue: 1 << 1)",
            replace = "        public static let sortedKeys    = OutputFormatting(rawValue: 1 << 1)",
        },
    },
}

local function directory_of(sdk, header)
    local parts = {sdk}
    table.join2(parts, header.directory)
    return path.join(table.unpack(parts))
end

local function replaced(text, lowering, where, member)
    local start, stop = text:find(lowering.find, 1, true)
    if not start then
        raise("%s declares %s without the availability the backports lower", where, member)
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
    for _, entry in ipairs(MEMBERS) do
        local header = entry.header
        local copy = path.join(out, header.name, header.file)
        os.mkdir(path.join(out, header.name))
        local text = io.readfile(path.join(directory_of(sdk, header), header.file))
        write_if_changed(copy, replaced(text, header, "the iPhoneOS SDK at " .. sdk .. " in " .. header.file, entry.member))
        table.insert(roots, string.format([[
    {
      "name": "%s",
      "type": "directory",
      "contents": [
        {"name": "%s", "type": "file", "external-contents": "%s"}
      ]
    }]], directory_of(sdk, header), header.file, copy))
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

function swift_overlays(root)
    for _, entry in ipairs(MEMBERS) do
        local lowering = entry.overlay
        if lowering then
            local file = path.join(root, table.unpack(lowering.file))
            io.writefile(file, replaced(io.readfile(file), lowering, "the Swift overlay " .. file, entry.member))
        end
    end
end
