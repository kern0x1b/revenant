local macho = import("macho", {anonymous = true})

local FOLDER = "/usr/lib/revenant/org.revenant.backports"
local VERSION = "1.0.0"

function folder()
    return FOLDER
end

function version()
    return VERSION
end

function flags()
    return {"-Wl,-current_version," .. VERSION, "-Wl,-compatibility_version," .. VERSION}
end

function packed(text)
    local major, minor, patch = text:match("^(%d+)%.(%d+)%.(%d+)$")
    return (tonumber(major) << 16) | (tonumber(minor) << 8) | tonumber(patch)
end

local function unpacked(value)
    return string.format("%d.%d.%d", value >> 16, (value >> 8) & 0xFF, value & 0xFF)
end

local function backports(name)
    return name ~= nil and name:sub(1, #FOLDER + 1) == FOLDER .. "/"
end

function problems(data)
    local expected = packed(VERSION)
    local found = {}
    for _, image in ipairs(macho.images(data)) do
        if backports(image.identity) and (image.current_version ~= expected or image.compatibility_version ~= expected) then
            table.insert(found, string.format("%s declares current version %s and compatibility version %s, but every Backports library declares %s",
                                              image.identity, unpacked(image.current_version), unpacked(image.compatibility_version), VERSION))
        end
        for index, name in ipairs(image.libraries) do
            local loaded = image.library_versions[index]
            if backports(name) and loaded.compatibility > expected then
                table.insert(found, string.format("loads %s with compatibility version %s, above the %s every Backports library declares: dyld refuses such a load on the device",
                                                  name, unpacked(loaded.compatibility), VERSION))
            end
        end
    end
    return found
end

function check(file)
    local found = problems(io.readfile(file, {encoding = "binary"}))
    if #found > 0 then
        raise("%s: %s", file, table.concat(found, "; "))
    end
end
