local macho = import("apple.macho", {rootdir = path.join(os.scriptdir(), "..", "..", "..", "toolchain", "modules"), anonymous = true})

local ARCHIVE = "!<arch>\n"
local MAGIC_LE = {[0xFEEDFACE] = true, [0xFEEDFACF] = true}

local function is_archive(data)
    return data:sub(1, #ARCHIVE) == ARCHIVE
end

local function is_image(data, at)
    return MAGIC_LE[(string.unpack("<I4", data, at + 1))] == true
end

function is_product(file)
    if not os.isfile(file) then
        return false
    end
    local handle = io.open(file, "rb")
    local head = handle:read(8) or ""
    handle:close()
    if #head < 8 then
        return false
    end
    return head == ARCHIVE or is_image(head, 0) or head:sub(1, 4) == "\202\254\186\190"
end

function files_under(path_)
    if os.isfile(path_) then
        return {path_}
    end
    local found = {}
    for _, file in ipairs(os.files(path.join(path_, "**"))) do
        if is_product(file) then
            table.insert(found, file)
        end
    end
    table.sort(found)
    return found
end

local function images_of(data)
    if not is_archive(data) then
        return macho.images(data)
    end
    local found = {}
    for _, member in ipairs(macho.archive_members(data)) do
        if is_image(data, member.offset) then
            table.insert(found, macho.image(data, member.offset))
        end
    end
    return found
end

local function text_sections(data, name)
    local chunks = {}
    for _, found in ipairs(images_of(data)) do
        for _, section in ipairs(found.sections) do
            if section.segment == "__TEXT" and section.name == name then
                for _, segment in ipairs(found.segments) do
                    if segment.name == section.segment then
                        local at = found.base + segment.fileoff + (section.addr - segment.vmaddr)
                        table.insert(chunks, data:sub(at + 1, at + section.size))
                    end
                end
            end
        end
    end
    return chunks
end

local function unique(list, seen, name)
    if not seen[name] then
        seen[name] = true
        table.insert(list, name)
    end
end

local function undefined_of(file)
    local names, seen = {}, {}
    for line in os.iorunv("nm", {"-u", file}):gmatch("[^\n]+") do
        local name = line:match("^%s*U%s+(%S+)$") or line:match("^%s*(%S+)$")
        if name and name:sub(-1) ~= ":" then
            unique(names, seen, name)
        end
    end
    return names
end

function read(file)
    local data = macho.read(file)
    local selectors, seen = {}, {}
    for _, chunk in ipairs(text_sections(data, "__objc_methname")) do
        for name in chunk:gmatch("([^%z]+)") do
            unique(selectors, seen, name)
        end
    end
    return {file = file, undefined = undefined_of(file), selectors = selectors}
end
